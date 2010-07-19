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
  $X->sync;

  plan tests => 3807;
}
use_ok ('Image::Base::X11::Protocol::Drawable');

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

#------------------------------------------------------------------------------
# VERSION

my $want_version = 1;
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
      diag "_X_rootwin_to_screen_number() wrong on rootwin $rootwin screen $screen_number\ngot ", (defined $got ? $got : 'undef');
    }
  }
  ok ($good, "_X_rootwin_to_screen_number()");
}

#------------------------------------------------------------------------------
# new()

{
  my $bitmap = $X->new_rsrc;
  $X->CreatePixmap ($bitmap,
                    $X->{'root'},
                    1,  # depth
                    21, 10);

  my $image = Image::Base::X11::Protocol::Drawable->new
    (-X => $X,
     -drawable => $bitmap,
     -depth => 1);

  require MyTestImageBase;
  local $MyTestImageBase::white = 1;
  local $MyTestImageBase::black = 0;
  MyTestImageBase::check_image ($image);

  $X->FreePixmap ($bitmap);
  $X->sync;
}

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

  require MyTestImageBase;
  local $MyTestImageBase::white = 'white';
  local $MyTestImageBase::black = 'black';
  MyTestImageBase::check_image ($image);

  $X->FreePixmap ($pixmap);
  $X->sync;
  ok (1, 'successful destroy and sync');
}

exit 0;
