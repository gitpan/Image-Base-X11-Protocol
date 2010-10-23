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


package Image::Base::X11::Protocol::Window;
use 5.004;
use strict;
use warnings;
use Carp;
use vars '$VERSION', '@ISA';

$VERSION = 2;

use Image::Base::X11::Protocol::Drawable;
@ISA = ('Image::Base::X11::Protocol::Drawable');

# uncomment this to run the ### lines
#use Smart::Comments;

sub new {
  my ($class, %params) = @_;
  ### X11-Protocol-Window new()

  if (! defined $params{'-colormap'}) {
    my %attrs = $params{'-X'}->GetWindowAttributes ($params{'-window'});
    $params{'-colormap'} = $attrs{'colormap'};
  }
  if (my $win = delete $params{'-window'}) {
    $params{'-drawable'} = $win;
  }
  return $class->SUPER::new (%params);
}

sub DESTROY {
  my ($self) = @_;
  ### X11-Protocol-Window DESTROY
  _free_bitmap_gc($self);
  shift->SUPER::DESTROY (@_);
}
sub _free_bitmap_gc {
  my ($self) = @_;
  if (my $bitmap_gc = delete $self->{'_bitmap_gc'}) {
    ### FreeGC bitmap_gc: $bitmap_gc
    $self->{'-X'}->FreeGC ($bitmap_gc);
  }
}

my %get_window_attributes = (-colormap => 1,
                             -visual   => 1);
sub _get {
  my ($self, $key) = @_;
  ### X11-Protocol-Window _get(): $key

  if (! exists $self->{$key}) {
    if ($get_window_attributes{$key}) {
      my $attr = ($self->{'_during_get'}->{'GetWindowAttributes'} ||= do {
        my %attr = $self->{'-X'}->GetWindowAttributes ($self->{'-drawable'});
        foreach my $field ('visual') {
          if (! exists $self->{"-$field"}) {  # unchanging
            $self->{"-$field"} = $attr{$field};
          }
        }
        \%attr
      });
      return $attr->{substr($key,1)};
    }
  }
  return $self->SUPER::_get($key);
}

sub set {
  my ($self, %params) = @_;

  if (exists $params{'-drawable'}) {
    _free_bitmap_gc ($self);
    delete $self->{'-visual'};  # must be refetched, or provided in %params
  }

  my $width  = delete $params{'-width'};
  my $height = delete $params{'-height'};

  # set -drawable before applying -width and -height
  $self->SUPER::set (%params);

  if (defined $width || defined $height) {
    $self->{'-X'}->ConfigureWindow
      ($self->{'-drawable'},
       (defined $width  ? (width => $width)   : ()),
       (defined $height ? (height => $height) : ()));
  }
}

sub xy {
  my ($self, $x, $y, $colour) = @_;
  if (@_ >= 4 && $colour eq 'None' &&  $self->{'-X'}->{'ext'}->{'SHAPE'}) {
    $self->{'-X'}->ShapeRectangles ($self->{'-drawable'},
                                    'Bounding',
                                    'Subtract',
                                    0,0, # offset
                                    'YXBanded',
                                    [ $x,$y, 1,1 ]);
  } else {
    shift->SUPER::xy (@_);
  }
}

sub line {
  my ($self, $x1,$y1, $x2,$y2, $colour) = @_;
  ### X11-Protocol-Window line(): $x1,$y1, $x2,$y2, $colour

  if ($colour eq 'None' &&  (my $X = $self->{'-X'})->{'ext'}->{'SHAPE'}) {
    my $width = $x2 - $x1 + 1;
    my $height = $y2 - $y1 + 1;
    my ($bitmap, $bitmap_gc) = _make_bitmap_and_gc ($self, $width, $height);
    ### PolySegment: $bitmap, $bitmap_gc, 0,0, $width-1,$height-1
    $X->PolySegment ($bitmap, $bitmap_gc, 0,0, $width-1,$height-1);
    $X->ShapeMask ($self->{'-drawable'},
                   'Bounding',
                   'Subtract',
                   $x1,$y1, # offset
                   $bitmap);
    $X->FreePixmap ($bitmap);
  } else {
    shift->SUPER::line (@_);
  }
}

sub rectangle {
  my ($self, $x1, $y1, $x2, $y2, $colour, $fill) = @_;
  ### Window rectangle: $x1, $y1, $x2, $y2, $colour, $fill
  if ($colour eq 'None' &&  $self->{'-X'}->{'ext'}->{'SHAPE'}) {
    $self->{'-X'}->ShapeRectangles ($self->{'-drawable'},
                                    'Bounding',
                                    'Subtract',
                                    0,0, # offset
                                    'YXBanded',
                                    [ $x1, $y1,
                                      $x2 - $x1 + 1,
                                      $y2 - $y1 + 1 ]);
  } else {
    $self->SUPER::rectangle ($x1, $y1, $x2, $y2, $colour, $fill);
  }
}

sub ellipse {
  my ($self, $x1,$y1, $x2,$y2, $colour) = @_;
  ### Window ellipse: $x1,$y1, $x2,$y2, $colour
  if ($colour eq 'None' &&  (my $X = $self->{'-X'})->{'ext'}->{'SHAPE'}) {
    ### use shape
    my $width = $x2 - $x1 + 1;
    my $height = $y2 - $y1 + 1;
    my $win = $self->{'-drawable'};
    my ($bitmap, $bitmap_gc) = _make_bitmap_and_gc ($self, $width, $height);
    $X->PolyArc ($bitmap, $bitmap_gc,
                 [ 0, 0, $width, $height, 0, 365*64 ]);
    $self->{'-X'}->ShapeMask ($self->{'-drawable'},
                            'Bounding',
                            'Subtract',
                            $x1,$y1, # offset
                            $bitmap);
    $X->FreePixmap ($bitmap);
  } else {
    shift->SUPER::ellipse (@_);
  }
}

sub _make_bitmap_and_gc {
  my ($self, $width, $height) = @_;
  my $X = $self->{'-X'};

  my $bitmap = $X->new_rsrc;
  ### CreatePixmap of bitmap: $bitmap
  $X->CreatePixmap ($bitmap, $self->{'-drawable'}, 1, $width, $height);

  my $bitmap_gc = $self->{'_bitmap_gc'};
  if ($bitmap_gc) {
    $X->ChangeGC ($bitmap_gc, foreground => 0);
  } else {
    $bitmap_gc = $X->new_rsrc;
    $X->CreateGC ($bitmap_gc, $bitmap, foreground => 0);
  }
  $X->PolyFillRectangle ($bitmap, $bitmap_gc, [0,0, $width,$height]);
  $X->ChangeGC ($bitmap_gc, foreground => 1);
  return ($bitmap, $bitmap_gc);
}

1;
__END__

#   if (! exists $self->{$key} && $window_attributes{$key}) {
#     return $self->_get_window_attributes->{substr($key,1)};
#   }
# 
# sub _get_window_attributes {
#   my ($self) = @_;
#   return ($self->{'_cache'}->{'GetWindowAttributes'} ||= do {
#     ### X11-Protocol-Drawable GetWindowAttributes: $self->{'-drawable'}
#     my %attrs = $self->{'-X'}->GetWindowAttributes ($self->{'-drawable'});
#     ### \%attrs
#     \%attrs
#   });
# }

=for stopwords undef Ryde colormap ie resizes XID

=head1 NAME

Image::Base::X11::Protocol::Window -- draw into an X11::Protocol window

=for test_synopsis my ($win_xid)

=head1 SYNOPSIS

 use Image::Base::X11::Protocol::Drawable;
 my $X = X11::Protocol->new;

 use Image::Base::X11::Protocol::Window;
 my $image = Image::Base::X11::Protocol::Window->new
               (-X      => $X,
                -window => $win_xid);
 $image->line (0,0, 99,99, '#FF00FF');
 $image->rectangle (10,10, 20,15, 'white');

=head1 CLASS HIERARCHY

C<Image::Base::X11::Protocol::Window> is a subclass of
C<Image::Base::X11::Protocol::Drawable>,

    Image::Base
      Image::Base::X11::Protocol::Drawable
        Image::Base::X11::Protocol::Window

=head1 DESCRIPTION

C<Image::Base::X11::Protocol::Window> extends C<Image::Base> to draw into an
X window by speaking directly to an X server using C<X11::Protocol>.
There's no file load or save, just drawing operations.

As an experimental feature, if the C<X11::Protocol> object has the SHAPE
extension available and initialized then colour "None" means transparent and
drawing it subtracts from the window's shape, making see-though holes.  Is
this worthwhile?

=head1 FUNCTIONS

=over 4

=item C<$image = Image::Base::X11::Protocol::Window-E<gt>new (key=E<gt>value,...)>

Create and return a new image object.  This requires an C<X11::Protocol>
connection object and window XID (an integer).

    $image = Image::Base::X11::Protocol::Window->new
                 (-X      => $x11_protocol_obj,
                  -window => $win_xid);

C<-colormap> is set from the window's current colormap attribute, or pass a
value to save a server round-trip if you know it already or if you want a
different colormap.

There's nothing to create a new X window since there's lots of settings for
it and they seem outside the scope of this image wrapper.

=back

=head1 ATTRIBUTES

=over

=item C<-window> (XID integer)

The target window.  C<-drawable> and C<-window> access the same attribute.

=item C<-width> (integer)

=item C<-height> (integer)

Changing these resizes the window (C<ConfigureWindow>).  See the base
Drawable class for the way fetching uses C<GetGeometry>.

In the current code a window size change made outside this wrapper
(including perhaps by the user through the window manager) is not noticed by
the wrapper and C<-width> and C<-height> remain as the cached values.
A C<GetGeometry> for every C<get> would be the only way to be sure of the
right values, but a server query every time would likely be very slow for
generic image code designed for in-memory images, and of course most of the
time the window size doesn't change.

=item C<-colormap> (integer XID)

Changing this doesn't change the window's colormap attribute, it's just
where the drawing operations should allocate colours.

=back

=head1 SEE ALSO

L<Image::Base>,
L<Image::Base::X11::Protocol::Drawable>,
L<Image::Base::X11::Protocol::Pixmap>,
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
