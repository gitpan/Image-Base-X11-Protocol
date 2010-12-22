#!/usr/bin/perl -w

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

use 5.004;
use strict;
use warnings;
use Test::More;

use lib 't';
use MyTestHelpers;
BEGIN { MyTestHelpers::nowarnings() }

use X11::Protocol;
my $X;
BEGIN {
  my $display = $ENV{'DISPLAY'};
  defined $display
    or plan skip_all => 'No DISPLAY set';

  # pass display arg so as not to get a "guess" warning
  eval { $X = X11::Protocol->new ($display); }
    or plan skip_all => "Cannot connect to X server -- $@";
  $X->QueryPointer($X->{'root'});  # sync
}
plan tests => 4688;

use_ok ('Image::Base::X11::Protocol::Drawable');
diag "Image::Base version ", Image::Base->VERSION;

# uncomment this to run the ### lines
#use Smart::Comments;

# screen number integer 0, 1, etc
sub X_chosen_screen_number {
  my ($X) = @_;
  foreach my $i (0 .. $#{$X->{'screens'}}) {
    if ($X->{'screens'}->[$i]->{'root'} == $X->{'root'}) {
      return $i;
    }
  }
  die "Oops, current screen not found";
}
my $X_screen_number = X_chosen_screen_number($X);


diag "";
diag "X server info";
diag "vendor: ",$X->{'vendor'};
diag "release_number: ",$X->{'release_number'};
diag "protocol_major_version: ",$X->{'protocol_major_version'};
diag "protocol_minor_version: ",$X->{'protocol_minor_version'};
diag "byte_order: ",$X->{'byte_order'};
diag "num screens: ",scalar(@{$X->{'screens'}});
diag "width_in_pixels: ",$X->{'width_in_pixels'};
diag "height_in_pixels: ",$X->{'height_in_pixels'};
diag "width_in_millimeters: ",$X->{'width_in_millimeters'};
diag "height_in_millimeters: ",$X->{'height_in_millimeters'};
diag "root_visual: ",$X->{'root_visual'};
{
  my $visual = $X->{'visuals'}->{$X->{'root_visual'}};
  diag "  depth: ",$visual->{'depth'};
  diag "  class: ",$visual->{'class'},
    ' ', $X->interp('VisualClass', $visual->{'class'});
  diag "  colormap_entries: ",$visual->{'colormap_entries'};
  diag "  bits_per_rgb_value: ",$visual->{'bits_per_rgb_value'};
  diag "  red_mask: ",sprintf('%#X',$visual->{'red_mask'});
  diag "  green_mask: ",sprintf('%#X',$visual->{'green_mask'});
  diag "  blue_mask: ",sprintf('%#X',$visual->{'blue_mask'});
}
diag "image_byte_order: ",$X->{'image_byte_order'},
  ' ', $X->interp('Significance', $X->{'image_byte_order'});
diag "black_pixel: ",sprintf('%#X',$X->{'black_pixel'});
diag "white_pixel: ",sprintf('%#X',$X->{'white_pixel'});
diag "";


#------------------------------------------------------------------------------
# VERSION

my $want_version = 5;
is ($Image::Base::X11::Protocol::Drawable::VERSION,
    $want_version, 'VERSION variable');
is (Image::Base::X11::Protocol::Drawable->VERSION,
    $want_version, 'VERSION class method');

ok (eval { Image::Base::X11::Protocol::Drawable->VERSION($want_version); 1 },
    "VERSION class check $want_version");
my $check_version = $want_version + 1000;
ok (! eval { Image::Base::X11::Protocol::Drawable->VERSION($check_version); 1 },
    "VERSION class check $check_version");

#------------------------------------------------------------------------------
# _X_rootwin_to_screen_number()

{
  my $screens_aref = $X->{'screens'};
  my $good = 1;
  foreach my $screen_number (0 .. $#$screens_aref) {
    my $rootwin = $screens_aref->[$screen_number]->{'root'}
      || die "oops, no 'root' under screen $screen_number";
    my $got = Image::Base::X11::Protocol::Drawable::_X_rootwin_to_screen_number($X,$rootwin);
    if (! defined $got || $got != $screen_number) {
      $good = 0;
      diag "_X_rootwin_to_screen_number() wrong on rootwin $rootwin screen $screen_number";
      diag "got ", (defined $got ? $got : 'undef');
    }
  }
  ok ($good, "_X_rootwin_to_screen_number()");
}

#------------------------------------------------------------------------------
# root window info

{
  my $num_screens = scalar(@{$X->{'screens'}});
  my $check_screen = $num_screens - 1;
  my $check_screen_info = $X->{'screens'}->[$check_screen];
  diag "use screen number $check_screen for checking";

  my $image = Image::Base::X11::Protocol::Drawable->new
    (-X => $X,
     -drawable => $X->{'screens'}->[$check_screen]->{'root'});
  isa_ok ($image, 'Image::Base');
  isa_ok ($image, 'Image::Base::X11::Protocol::Drawable');

  is ($image->VERSION,  $want_version, 'VERSION object method');
  ok (eval { $image->VERSION($want_version); 1 },
      "VERSION object check $want_version");
  ok (! eval { $image->VERSION($check_version); 1 },
      "VERSION object check $check_version");

  cmp_ok ($image->get('-width'), '>=', 1, 'get() -width');
  is ($image->get('-width'), $check_screen_info->{'width_in_pixels'},
      'get() -width');

  cmp_ok ($image->get('-height'), '>=', 1, 'get() -height');
  is ($image->get('-height'), $check_screen_info->{'height_in_pixels'},
      'get() -height');

  cmp_ok ($image->get('-depth'), '>=', 1, 'get() -depth');
  is ($image->get('-depth'), $check_screen_info->{'root_depth'},
      'get() -depth');

  cmp_ok ($image->get('-screen'), '>=', 0, 'get() -screen');
  is ($image->get('-screen'), $check_screen, 'get() -screen');

  # no default in the Drawable class
  is ($image->get('-colormap'), undef, 'get() -colormap');
}

#------------------------------------------------------------------------------
# bitmap
{
  my $check_screen = 0;
  my $rootwin = $X->{'screens'}->[$check_screen]->{'root'};

  my $bitmap = $X->new_rsrc;
  $X->CreatePixmap ($bitmap,
                    $rootwin,
                    1,  # depth
                    21, 10);

  my $image = Image::Base::X11::Protocol::Drawable->new
    (-X => $X,
     -drawable => $bitmap);

  is ($image->get('-width'),  21, 'bitmap get() -width');
  is ($image->get('-height'), 10, 'bitmap get() -height');
  is ($image->get('-depth'),   1, 'bitmap get() -depth');
  is ($image->get('-screen'),  0, 'bitmap get() -screen');

  diag "MyTestImageBase on bitmap";
  require MyTestImageBase;
  local $MyTestImageBase::white = 1;
  local $MyTestImageBase::black = 0;
  MyTestImageBase::check_image ($image);

  $X->FreePixmap ($bitmap);
  $X->QueryPointer($X->{'root'});  # sync
}

#------------------------------------------------------------------------------
# pixmap

{
  my $pixmap = $X->new_rsrc;
  $X->CreatePixmap ($pixmap,
                    $X->{'root'},
                    $X->{'root_depth'},
                    21, 10);

  my $image = Image::Base::X11::Protocol::Drawable->new
    (-X => $X,
     -drawable => $pixmap);
  isa_ok ($image, 'Image::Base');
  isa_ok ($image, 'Image::Base::X11::Protocol::Drawable');

  is ($image->VERSION,  $want_version, 'VERSION object method');
  ok (eval { $image->VERSION($want_version); 1 },
      "VERSION object check $want_version");
  ok (! eval { $image->VERSION($check_version); 1 },
      "VERSION object check $check_version");

  is ($image->get('-width'),  21, 'get() -width');
  is ($image->get('-height'), 10, 'get() -height');
  is ($image->get('-depth'),  $X->{'root_depth'}, 'get() -depth');

  is ($image->get('-screen'), $X_screen_number, 'get() -screen_number');
  is ($image->get('-colormap'), undef, 'get() -colormap');

  #
  # add_colours
  #

  diag "add_colours()";
  $image->set('-colormap', $X->{'default_colormap'});
  $image->add_colours('black', 'white', '#FF00FF', '#0000AAAAbbbb');

  #
  # line
  #
  $image->rectangle (0,0, 19,9, 'black', 1);
  $image->line (5,5, 7,7, 'white', 0);
  is ($image->xy (4,4), 'black');
  is ($image->xy (5,5), 'white');
  is ($image->xy (5,6), 'black');
  is ($image->xy (6,6), 'white');
  is ($image->xy (7,7), 'white');
  is ($image->xy (8,8), 'black');

  $image->rectangle (0,0, 19,9, 'black', 1);
  $image->line (0,0, 2,2, 'white', 1);
  is ($image->xy (0,0), 'white');
  is ($image->xy (1,1), 'white');
  is ($image->xy (2,1), 'black');
  is ($image->xy (3,3), 'black');

  #
  # xy
  #

  $image->xy (2,2, 'black');
  $image->xy (3,3, 'white');
  is ($image->xy (2,2), 'black', 'xy()  ');
  is ($image->xy (3,3), 'white', 'xy() *');

  #
  # rectangle
  #

  # hollow
  $image->rectangle (0,0, 19,9, 'black', 1);
  $image->rectangle (5,5, 7,7, 'white', 0);
  is ($image->xy (5,5), 'white');
  is ($image->xy (5,6), 'white');
  is ($image->xy (5,7), 'white');

  is ($image->xy (6,5), 'white');
  is ($image->xy (6,6), 'black');
  is ($image->xy (6,7), 'white');

  is ($image->xy (7,5), 'white');
  is ($image->xy (7,6), 'white');
  is ($image->xy (7,7), 'white');

  is ($image->xy (8,8), 'black');
  #


  # filled
  $image->rectangle (0,0, 19,9, 'black', 1);
  $image->rectangle (5,5, 7,7, 'white', 1);
  is ($image->xy (5,5), 'white');
  is ($image->xy (5,6), 'white');
  is ($image->xy (5,7), 'white');

  is ($image->xy (6,5), 'white');
  is ($image->xy (6,6), 'white');
  is ($image->xy (6,7), 'white');

  is ($image->xy (7,5), 'white');
  is ($image->xy (7,6), 'white');
  is ($image->xy (7,7), 'white');

  is ($image->xy (8,8), 'black');
  #

  diag "MyTestImageBase on pixmap depth=$X->{'root_depth'}";
  require MyTestImageBase;
  local $MyTestImageBase::white = 'white';
  local $MyTestImageBase::black = 'black';
  MyTestImageBase::check_image ($image);

  $X->FreePixmap ($pixmap);
  $X->QueryPointer($X->{'root'});  # sync
  ok (1, 'successful destroy and sync');
}

#------------------------------------------------------------------------------
# add_colours()

sub step_seq_num {
  my ($X) = @_;
  my $seq = $X->send('QueryPointer',$X->{'root'});
  my $reply;
  $X->add_reply ($seq, \$reply);
  $X->handle_input_for($seq);
  $X->delete_reply ($seq);
  return $seq;
}

sub run_seq_to_FF00 {
  my ($X) = @_;
  my $target = 0xFF00;
  my $limit = 100;
  my $count = 0;
  my $seq = step_seq_num($X);

  for (;;) {
    my $diff = ($target - $seq) & 0xFFFF;
    ### $diff
    if ($diff < 10) {
      diag "run_seq_to_FF00() $count steps to seq $seq";
      last;
    }
    my @pending;
    for (;;) {
      last if ($diff < 10 || @pending > 2048);
      $seq = $X->send('QueryPointer',$X->{'root'});
      push @pending, $seq;
      my $reply;
      $X->add_reply ($seq, \$reply);
      $count++;
      $diff--;
    }
    $X->handle_input_for($seq);
    foreach my $pending (@pending) {
      $X->delete_reply ($pending);
    }
    if (--$limit < 0) {
      diag "run_seq_to_FF00(): oops, cannot get seq to 0xFF00";
      die;
    }
  }
}

my $rgb = 2;
sub next_test_colour {
  return sprintf('#%06X',$rgb++);
}

{
  my $pixmap = $X->new_rsrc;
  $X->CreatePixmap ($pixmap,
                    $X->{'root'},
                    $X->{'root_depth'},
                    21, 10);
  my $image = Image::Base::X11::Protocol::Drawable->new
    (-X => $X,
     -drawable => $pixmap,
     -colormap => $X->{'default_colormap'});

  {
    diag "add_colours() error received";
    my $error_seen = 0;
    local $X->{'error_handler'} = sub {
      $error_seen = 1;
    };
    $X->send('QueryPointer',0);

    my $colour = next_test_colour();
    $image->add_colours($colour);
    is ($error_seen, 1, 'add_colours() with pending error - error handled');
    ok (defined $image->{'-colour_to_pixel'}->{$colour},
        'add_colours() with pending error - colour allocated');
  }

  {
    my @colours = map {next_test_colour()} 1 .. 5000;
    diag "add_colours() ",scalar(@colours);
    $image->add_colours(@colours);
  }
  {
    my @colours = map {next_test_colour()} 1 .. 5000;
    diag "add_colours() ",scalar(@colours)," with seq wraparound";
    run_seq_to_FF00($X);
    $image->add_colours(@colours);
  }

  $X->FreePixmap ($pixmap);
  $X->QueryPointer($X->{'root'});  # sync
  ok (1, 'successful destroy and sync');
}


exit 0;
