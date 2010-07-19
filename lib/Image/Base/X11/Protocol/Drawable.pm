# Copyright 2010 Kevin Ryde

# This file is part of Image-Base-X11-Protocol.
#
# Image-Base-X11-Protocol is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as published
# by the Free Software Foundation; either version 3, or (at your option) any
# later version.
#
# Image-Base-X11-Protocol is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Image-Base-X11-Protocol.  If not, see <http://www.gnu.org/licenses/>.


package Image::Base::X11::Protocol::Drawable;
use 5.004;
use strict;
use warnings;
use Carp;
use List::Util;
use X11::Protocol 0.56; # version 0.56 for robust_req() fix
use vars '$VERSION', '@ISA';

$VERSION = 1;

use Image::Base;
@ISA = ('Image::Base');

# uncomment this to run the ### lines
#use Smart::Comments;

sub new {
  my $class = shift;
  if (ref $class) {
    croak "Cannot clone base drawable";
  }
  return bless {
                # these not documented as yet
                -colour_to_pixel => {  },
                -gc_colour => '',
                -gc_pixel  => -1,

                @_ }, $class;
}

# This not working yet.  Good to CopyArea when screen,depth,colormap permit,
# is it worth the trouble though?
#
# =item C<$new_image = $image-E<gt>new_from_image ($class, key=E<gt>value,...)>
# 
# Create and return a new image of type C<$class>.
# 
# Target class C<Image::Base::X11::Protocol::Pixmap> is recognised and done by
# CopyArea of the C<$image> drawable into the new pixmap.  Other classes are
# left to the plain C<Image::Base> C<new_from_image>.
# 
# sub new_from_image {
#   my $self = shift;
#   my $new_class = shift;
# 
#   if (! ref $new_class
#       && $new_class->isa('Image::Base::X11::Protocol::Pixmap')) {
#     my %param = @_;
#     my $X = $self->{'-X'};
#     if ($param{'-X'} == $X) {
#       my ($depth, $width, $height, $colormap)
#         = $self->get('-screen','-depth','-width','-height');
#       my ($new_screen, $new_depth)
#         = $new_class->_new_params_screen_and_depth(\%params);
#       if ($new_screen == $screen
#           && $new_depth == $depth
#           && $new_colormap == $colormap) {
# 
#         my $new_image = $new_class->new (%param);
# 
#         ### copy to new Pixmap
#         my ($width, $height) = $self->get('-width','-height');
#         my ($new_width, $new_height) = $new_image->get('-width','-height');
#         $X->CopyArea ($self->{'-drawable'},        # src
#                       $new_image->{'-drawable'},   # dst
#                       _gc_created($self),
#                       0,0,  # src x,y
#                       min ($width,$new_width), min ($height,$new_height)
#                       0,0); # dst x,y
#         return $new_image;
#       }
#     }
#   }
#   return $self->SUPER::new_from_image ($new_class, @_);
# }
# sub _gc_created {
#   my ($self) = @_;
#   return ($self->{'-gc_created'} ||= do {
#     my $gc = $self->{'-X'}->new_rsrc;
#     ### CreateGC: $gc
#     $self->{'-X'}->CreateGC ($gc, $self->{'-drawable'});
#     $gc
#   });
# }

sub DESTROY {
  my ($self) = @_;
  ### X11-Protocol-Drawable DESTROY
  _free_gc_created ($self);
  shift->SUPER::DESTROY (@_);
}
sub _free_gc_created {
  my ($self) = @_;
  if (my $gc = delete $self->{'-gc_created'}) {
    ### FreeGC: $gc
    $self->{'-X'}->FreeGC ($gc);
  }
}

sub get {
  my ($self) = @_;
  local $self->{'_during_get'} = {};
  return shift->SUPER::get(@_);
}
my %get_geometry = (-depth         => 1,
                    -root          => 1,
                    -x             => 1,
                    -y             => 1,
                    -width         => 1,
                    -height        => 1,
                    -border_width  => 1,

                    # with extra crunching
                    -screen => 1);

sub _get {
  my ($self, $key) = @_;
  ### X11-Protocol-Drawable _get(): $key

  if (! exists $self->{$key} && $get_geometry{$key}) {
    my $X = $self->{'-X'};
    my %geom = $X->GetGeometry ($self->{'-drawable'});

    foreach my $gkey (keys %get_geometry) {
      if (! defined $self->{$gkey}) {
        $self->{$gkey} = $geom{substr($gkey,1)};
      }
    }
    if (! defined $self->{'-screen'}) {
      $self->{'-screen'}
        = _X_rootwin_to_screen_number ($X, $geom{'root'});
    }
  }
  return $self->SUPER::_get($key);
}

sub set {
  my ($self, %params) = @_;

  if (exists $params{'-pixmap'}) {
    $params{'-drawable'} = delete $params{'-pixmap'};
  }
  if (exists $params{'-window'}) {
    $params{'-drawable'} = delete $params{'-window'};
  }

  if (exists $params{'-drawable'}) {
    _free_gc_created ($self);
    delete @{$self}{keys %get_geometry}; # hash slice
  }
  if (exists $params{'-colormap'}) {
    %{$self->{'-colour_to_pixel'}} = ();  # clear
  }
  if (exists $params{'-gc'}) {
    # no longer know what colour is in the gc, or not unless included in
    # %params
    $self->{'-gc_colour'} = '';
    $self->{'-gc_pixel'} = -1;
  }

  %$self = (%$self, %params);
}

sub xy {
  my ($self, $x, $y, $colour) = @_;
  ### xy
  ### $x
  ### $y
  ### $colour
  my $X = $self->{'-X'};
  my $drawable = $self->{'-drawable'};
  if (@_ == 4) {
    $X->PolyPoint ($drawable, _gc_colour($self,$colour),
                   'Origin', $x,$y);
    return;
  }

  my @reply = $X->robust_req('GetImage', $drawable,
                             $x, $y, 1, 1, ~0, 'ZPixmap');
  if (! ref $reply[0]) {
    if ($reply[0] eq 'Match') {
      ### Match error reading offscreen
      return '';
    }
    croak "Error reading pixel: ",join(' ',@reply);
  }
  my ($depth, $visual, $bytes) = @{$reply[0]};

  # X11::Protocol 0.56 shows named 'LeastSiginificant' in the pod, but the
  # code gives raw number '0'
  if ($X->{'image_byte_order'} eq 'LeastSiginificant'
      || $X->{'image_byte_order'} eq 0) {
    #### reverse for LSB image format
    $bytes = reverse $bytes;
  }
  #### $depth
  #### $visual
  #### $bytes
  my $pixel = unpack ('N', $bytes);
  #### pixel: sprintf '%X', $pixel
  #### pixel_to_colour: $self->pixel_to_colour($pixel)
  if (defined ($colour = $self->pixel_to_colour($pixel))) {
    return $colour;
  }
  if (my $colormap = $self->{'-colormap'}) {
    #### query: $X->QueryColors ($self->get('-colormap'), $pixel)
    my ($rgb) = $X->QueryColors ($self->get('-colormap'), $pixel);
    #### $rgb
    return sprintf('#%04X%04X%04X', @$rgb);
  }
  return $pixel;
}
sub Image_Base_Other_xy_points {
  my $self = shift;
  my $colour = shift;
  my $gc = _gc_colour($self,$colour);
  my $X = $self->{'-X'};

  # PolyPoint is 3xCARD32 header,drawable,gc then room for maxlen-3 words of
  # X,Y values.  X and Y are INT16 each, hence room for (maxlen-3)*2
  # individual points.  Is there any value sending somewhat smaller chunks
  # though?  250kbytes is a typical server limit.
  #
  my $maxpoints = 2*($X->{'maximum_request_length'} - 3);
  ### $maxpoints

  while (@_ > $maxpoints) {
    ### splice down from: scalar(@_)
    $X->PolyPoint ($self->{'-drawable'}, $gc, 'Origin',
                   splice @_, 0,$maxpoints);
  }
  ### PolyPoint: scalar(@_)
  $self->{'-X'}->PolyPoint ($self->{'-drawable'}, $gc, 'Origin', @_);
}

# not yet a documented feature ...
sub pixel_to_colour {
  my ($self,$pixel) = @_;
  my $hash = ($self->{'-pixel_to_colour'} ||= do {
    ### colour_to_pixel hash: $self->{'-colour_to_pixel'}
    ({ reverse %{$self->{'-colour_to_pixel'}} }) # force anon hash
  });
  return $hash->{$pixel};
}

sub line {
  my ($self, $x0, $y0, $x1, $y1, $colour) = @_ ;
  $self->{'-X'}->PolySegment ($self->{'-drawable'}, _gc_colour($self,$colour),
                              $x0,$y0, $x1,$y1);
}

sub rectangle {
  my ($self, $x1, $y1, $x2, $y2, $colour, $fill) = @_;
  ### X11-Protocol-Drawable rectangle
  if ($x1 == $x2 || $y1 == $y2) {
    # single pixel wide or high
    $fill = 1;
  } else {
    $fill = !!$fill;  # 0 or 1
  }
  my $method = ($fill ? 'PolyFillRectangle' : 'PolyRectangle');
  ### $method
  ### coords: [ $x1, $y1, $x2-$x1, $y2-$y1 ]

  $self->{'-X'}->request (($fill ? 'PolyFillRectangle' : 'PolyRectangle'),
                          $self->{'-drawable'},
                          _gc_colour($self,$colour),
                          [ $x1, $y1, $x2-$x1+$fill, $y2-$y1+$fill ]);
}

sub Image_Base_Other_rectangles {
  ### X11-Protocol-Drawable rectangles()
  ### count: scalar(@_)
  my $self = shift;
  my $colour = shift;
  my $fill = !! shift;  # 0 or 1

  my $method = ($fill ? 'PolyFillRectangle' : 'PolyRectangle');
  ### $method

  ### coords count: scalar(@_)
  ### coords: @_
  my @rects;
  my @filled;
  while (my ($x1,$y1, $x2,$y2) = splice @_,0,4) {
    ### quad: ($x1,$y1, $x2,$y2)
    if (! $fill && ($x1 == $x2 || $y1 == $y2)) {
      # single pixel wide or high
      push @filled, [ $x1, $y1, $x2-$x1+1, $y2-$y1+1 ];
    } else {
      push @rects, [ $x1, $y1, $x2-$x1+$fill, $y2-$y1+$fill ];
    }
  }
  ### @rects

  my $X = $self->{'-X'};
  my $gc = _gc_colour($self,$colour);

  # PolyRectangle is 3xCARD32 header,drawable,gc then room for maxlen-3
  # words of X,Y,WIDTH,HEIGHT values.  X,Y are INT16 and WIDTH,HEIGHT are
  # CARD16 each, hence room for floor((maxlen-3)/2) rectangles.  Is there
  # any value sending somewhat smaller chunks though?  250kbytes is a
  # typical server limit.  Xlib ZRCTSPERBATCH is just 256 thin line rects,
  # or WRCTSPERBATCH 10 wides.
  #
  my $maxrects = int (($X->{'maximum_request_length'} - 3) / 2);
  ### $maxrects

  foreach my $aref (\@rects, \@filled) {
    if (@$aref) {
      my $drawable = $self->{'-drawable'};
      while (@$aref > $maxrects) {
        ### splice down from: scalar(@$aref)
        $X->$method ($drawable, $gc, splice @$aref, 0,$maxrects);
      }
      ### final: $method, @$aref
      $X->$method ($drawable, $gc, @$aref);
    }
    $method = 'PolyFillRectangle';
  }
}

sub ellipse {
  my ($self, $x1, $y1, $x2, $y2, $colour) = @_;
  ### Drawable ellipse: $x1, $y1, $x2, $y2, $colour
  if ($x1 == $x2 || $y1 == $y2) {
    shift->rectangle(@_,1);
  } else {
    ### PolyArc: $x1, $y1, $x2-$x1+1, $y2-$y1+1, 0, 360*64
    $self->{'-X'}->PolyArc ($self->{'-drawable'}, _gc_colour($self,$colour),
                            [ $x1, $y1, $x2-$x1, $y2-$y1, 0, 360*64 ]);
  }
}

# return a gc XID set to draw in $colour
sub _gc_colour {
  my ($self, $colour) = @_;
  if ($colour eq 'None') {
    $colour = 'black';
  }
  my $gc = $self->{'-gc'} || $self->{'-gc_created'};
  if ($colour ne $self->{'-gc_colour'}) {
    ### X11-Protocol-Drawable -gc_colour() change: $colour
    my $pixel = $self->colour_to_pixel ($colour);
    $self->{'-gc_colour'} = $colour;

    if ($pixel != $self->{'-gc_pixel'}) {
      $self->{'-gc_pixel'} = $pixel;
      my $X = $self->{'-X'};
      if ($gc) {
        ### ChangeGC to pixel: $pixel
        $X->ChangeGC ($gc, foreground => $pixel);
      } else {
        $gc = $self->{'-gc_created'} = $self->{'-X'}->new_rsrc;
        ### CreateGC with pixel
        ### $gc
        ### $pixel
        $X->CreateGC ($gc, $self->{'-drawable'}, foreground => $pixel);
      }
    }
  }
  return $gc;
}

# return an allocated pixel number
# not yet a documented feature ...
sub colour_to_pixel {
  my ($self, $colour) = @_;
  ### X11-Protocol-Drawable _colour_to_pixel(): $colour
  if ($colour =~ /^^\d+$/) {
    return $colour;  # numeric pixel value
  }
  if ($colour eq 'set') {
    # ENHANCE-ME: maybe all bits set if depth > 1
    return 1;
  }
  if ($colour eq 'clear') {
    return 0;
  }
  if (defined (my $pixel = $self->{'-colour_to_pixel'}->{$colour})) {
    return $pixel;
  }
  $self->add_colours ($colour);
  return $self->{'-colour_to_pixel'}->{$colour};
}

my %colour_to_screen_info_field
  = ('black'         => 'black_pixel',
     '#000000'       => 'black_pixel',
     '#000000000000' => 'black_pixel',
     'white'         => 'white_pixel',
     '#FFFFFF'       => 'white_pixel',
     '#FFFFFFFFFFFF' => 'white_pixel',
    );

sub add_colours {
  my $self = shift;
  ### add_colours: @_
  my $X = $self->{'-X'};
  my $colormap = $self->get('-colormap')
    || croak 'No -colormap to add colours to';
  my $colour_to_pixel = $self->{'-colour_to_pixel'};
  my $pixel_to_colour = $self->{'-pixel_to_colour'};

  my @queued;
  my @failed_colours;
  while (@_) {

  COLOUR: while (@_) {
      my $colour = shift;
      next if defined $colour_to_pixel->{$colour};  # already known
      delete $self->{'-pixel_to_colour'};

      if (my $field = $colour_to_screen_info_field{$colour}) {
        if (my $screen_info = _X_colormap_to_screen_info($X,$colormap)) {
          my $pixel = $colour_to_pixel->{$colour} = $screen_info->{$field};
          if ($pixel_to_colour) {
            $pixel_to_colour->{$pixel} = $colour;
          }
          next COLOUR;
        }
      }

      # can't track more than 65535 sequence numbers, do chunks
      last if @queued > 32768;

      my $elem = { colour => $colour };
      my @req;

      # Crib: [:xdigit:] new in 5.6, so just 0-9A-F for now
      if (my @rgb = ($colour =~ /^#([0-9A-F]{2})([0-9A-F]{2})([0-9A-F]{2})$/i)) {
        @req = ('AllocColor', $colormap, map {hex() * 65535/255} @rgb);
      } elsif (@rgb = ($colour =~ /^#([0-9A-F]{4})([0-9A-F]{4})([0-9A-F]{4})$/i)) {
        @req = ('AllocColor', $colormap, map {hex} @rgb);
      } else {
        $elem->{'named'} = 1;
        @req = ('AllocNamedColor', $colormap, $colour);
      }
      my $seq = $elem->{'seq'} = $X->send(@req) & 0xFFFF;
      $X->add_reply ($seq, \$elem->{'data'});

      ### $elem
      push @queued, $elem;
    }

    my $old_error_handler;
    while (my $elem = shift @queued) {
      my $seq = $elem->{'seq'};
      my $colour = $elem->{'colour'};

      my $err;
      local $X->{'error_handler'} = sub {
        my ($X, $data) = @_;
        my ($type, $err_seq) = unpack("xCSLSCxxxxxxxxxxxxxxxxxxxxx", $data);
        if ($err_seq != $seq) {
          goto &$old_error_handler;
        }
        $err = 1;
      };

      ### handle: $seq
      $X->handle_input_for ($seq);
      $X->delete_reply ($seq);
      if ($err) {
        push @failed_colours, $colour;
        next;
      }

      ### named reply: $elem->{'named'} && $X->unpack_reply('AllocNamedColor', $elem->{'data'})
      ### plain reply: ! $elem->{'named'} && $X->unpack_reply('AllocColor', $elem->{'data'})

      my ($pixel) = ($elem->{'named'}
                     ? $X->unpack_reply ('AllocNamedColor', $elem->{'data'})
                     : $X->unpack_reply ('AllocColor', $elem->{'data'}));
      $colour_to_pixel->{$colour} = $pixel;
      if ($pixel_to_colour) {
        $pixel_to_colour->{$pixel} = $colour;
      }
    }
  }
  if (@failed_colours) {
    die "Unknown colour(s): ",join(', ', @failed_colours);
  }
}

# return $X->{'screens'}->[$n] hashref, or undef if $colormap is not the
# default colormap of some screen
sub _X_colormap_to_screen_info {
  my ($X, $colormap) = @_;
  return List::Util::first
    {$_->{'default_colormap'} eq $colormap}
      @{$X->{'screens'}};
}

sub _X_rootwin_to_screen_number {
  my ($X, $rootwin) = @_;
  ### _X_rootwin_to_screen_number(): $rootwin
  my $screens = $X->{'screens'};
  foreach my $i (0 .. $#{$X->{'screens'}}) {
    if ($screens->[$i]->{'root'} == $rootwin) {
      return $i;
    }
  }
  # not a root win
  return undef;
}

1;
__END__

=for stopwords undef Ryde pixmap pixmaps colormap ie XID GC PseudoColor lookups
TrueColor RGB

=head1 NAME

Image::Base::X11::Protocol::Drawable -- draw into an X11::Protocol window or pixmap

=for test_synopsis my ($xid, $colormap)

=head1 SYNOPSIS

 use Image::Base::X11::Protocol::Drawable;
 my $X = X11::Protocol->new;

 my $image = Image::Base::X11::Protocol::Drawable->new
               (-X        => $X,
                -drawable => $xid,
                -colormap => $colormap);
 $image->line (0,0, 99,99, '#FF00FF');
 $image->rectangle (10,10, 20,15, 'white');

=head1 CLASS HIERARCHY

C<Image::Base::X11::Protocol::Drawable> is a subclass of
C<Image::Base>,

    Image::Base
      Image::Base::X11::Protocol::Drawable

=head1 DESCRIPTION

C<Image::Base::X11::Protocol::Drawable> extends C<Image::Base> to draw into
X windows or pixmaps by sending drawing requests to an X server with
C<X11::Protocol>.  There's no file load or save, just drawing operations.

The subclasses C<Image::Base::X11::Protocol::Pixmap> and
C<Image::Base::X11::Protocol::Window> have things specific to a pixmap or
window respectively.  Drawable is the common parts.

Colour names are anything known to the X server (usually in the file
F</etc/X11/rgb.txt>), or 2-digit or 4-digit hex #RRGGBB and #RRRRGGGGBBBB.
Colours used are allocated in a specified C<-colormap>.  For bitmaps pixel
values 1 and 0 can be used directly, plus special names "set" and "clear".

Native X drawing does much more than C<Image::Base> but if you have some
generic pixel twiddling code for C<Image::Base> then this Drawable class
lets you point it at an X window etc.  Drawing into a window is a good way
to show slow drawing progressively, rather than drawing into an image file
etc, and only displaying when complete.  See C<Image::Base::Multiplex> for a
way to do both simultaneously.

=head1 FUNCTIONS

=over 4

=item C<$image = Image::Base::X11::Protocol::Drawable-E<gt>new (key=E<gt>value,...)>

Create and return a new image object.  This requires an C<X11::Protocol>
connection object and a drawable XID (an integer).

    my $image = Image::Base::X11::Protocol::Drawable->new
                  (-X        => $x11_protocol_obj,
                   -drawable => $drawable_xid,
                   -colormap => $X->{'default_colormap'});

A colormap should be given if allocating colours (anything except a bitmap
normally).

=cut

# Not quite yet documented ...
#
# Optional C<-gc> can set a GC (an integer XID) to use for drawing, otherwise
# a new one is created if/when needed and freed when the image is destroyed.
# The C<$image> will consider itself the exclusive user of the C<-gc>
# provided.

=item C<$colour = $image-E<gt>xy ($x, $y)>

=item C<$image-E<gt>xy ($x, $y, $colour)>

Get or set the pixel at C<$x>,C<$y>.

Fetching a pixel is an X server round-trip so reading a big region will be
slow.  The protocol allows a big region or an entire drawable to be read in
one go, so some function for that could be made if needed.

In the current code the colour returned is either the name used to draw it,
or looked up in the C<-colormap> to give 4-digit hex #RRRRGGGGBBBB, or
otherwise a raw pixel value.  If two colour names became the same pixel
value because that was as close as could be represented then fetching might
give either name.  The hex return is 4 digits because that's the range in
the X protocol.

If the drawable is a window then parts overlapped by another window
(including a sub-window) generally read back as an unspecified value.  Parts
of a window which are off-screen have no data at all and the return is
currently an empty string C<"">.  (Would C<undef> or the window background
pixel be better?)

=item C<$image-E<gt>add_colours ($name, $name, ...)>

Allocate colours in the C<-colormap>.  Colour names are the same as for the
drawing functions.  For example,

    $image->add_colours ('red', 'green', '#FF00FF');

The drawing functions automatically add a colour if it doesn't already exist
but using C<add_colours> can do a set of pixel lookups in a single server
round-trip instead of separate individual ones.

If using the default colormap of the screen then names "black" and "white"
are taken from the screen info and don't query the server (neither in the
drawing operations nor C<add_colours>).

All colours, both named and hex, are sent to the server for interpretation.
On a static visual like TrueColor a hex RGB could in principle be turned
into a pixel just on the client side, but the X specs allow non-linear
weirdness in how pixel values ramp to RGB component levels, so only the
server can do it properly.

=back

=head1 ATTRIBUTES

=over

=item C<-drawable> (integer XID)

The target drawable.

=item C<-colormap> (integer XID)

The colormap in which to allocate colours when drawing.

Setting C<-colormap> only affects where colours are allocated.  If the
drawable is a window then the colormap is not set into the window's
attributes.

=item C<-width> (integer, read-only)

=item C<-height> (integer, read-only)

Width and height are read-only.  C<get> queries the server with
C<GetGeometry> when required and then caches.  If you already know the size
then including values in the C<new> will record them ready for later C<get>.
The plain drawing operations don't need the size though.

    $image = Image::Base::X11::Protocol::Drawable->new
                 (-X        => $x11_protocol_obj,
                  -drawable => $id,
                  -width    => 200,      # known values to
                  -height   => 100,      # avoid server query
                  -colormap => $colormap);

=item C<-depth> (integer, read-only)

The depth of the drawable, meaning how many bits per pixel.  C<get> queries
the server when required and then caches, if C<-depth> wasn't provided in
the C<new>.

=back

=head1 BUGS

The pixel values for each colour used in drawing are cached for later
re-use.  This is important to avoid a server round-trip on every drawing
operation, but if you use a lot of different shades then the cache may
become big.  Perhaps some sort of least recently used discard could keep a
lid on it.  The intention is probably to have a colour-to-pixel or some such
property which could be both initialized or manipulated as required.

=head1 SEE ALSO

L<Image::Base>,
L<Image::Base::X11::Protocol::Pixmap>,
L<Image::Base::X11::Protocol::Window>,
L<Image::Base::Multiplex>,
L<X11::Protocol>

=head1 HOME PAGE

http://user42.tuxfamily.org/image-base-x11-protocol/index.html

=head1 LICENSE

Image-Base-X11-Protocol is Copyright 2010 Kevin Ryde

Image-Base-X11-Protocol is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3, or (at your option) any
later version.

Image-Base-X11-Protocol is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
Public License for more details.

You should have received a copy of the GNU General Public License along with
Image-Base-X11-Protocol.  If not, see <http://www.gnu.org/licenses/>.

=cut
