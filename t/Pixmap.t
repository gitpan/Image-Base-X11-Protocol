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

  plan tests => 15;
}

use_ok ('Image::Base::X11::Protocol::Pixmap');
diag "Image::Base version ", Image::Base->VERSION;

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

my $want_version = 2;
is ($Image::Base::X11::Protocol::Pixmap::VERSION,
    $want_version, 'VERSION variable');
is (Image::Base::X11::Protocol::Pixmap->VERSION,
    $want_version, 'VERSION class method');

ok (eval { Image::Base::X11::Protocol::Pixmap->VERSION($want_version); 1 },
    "VERSION class check $want_version");
my $check_version = $want_version + 1000;
ok (! eval { Image::Base::X11::Protocol::Pixmap->VERSION($check_version); 1 },
    "VERSION class check $check_version");

#------------------------------------------------------------------------------
# new() bitmap

{
  my $rootwin = $X->{'root'};
  my %rootwin_geom = $X->GetGeometry ($rootwin);
  my %rootwin_attrs = $X->GetWindowAttributes ($rootwin);

  my $image = Image::Base::X11::Protocol::Pixmap->new
    (-X          => $X,
     -depth      => 1,
     -width      => 10,
     -height     => 10);
  my $pixmap = $image->get('-pixmap');
  isnt ($pixmap, 0, 'bitmap -pixmap created');

  is ($image->get('-depth'), 1, "bitmap -depth");
  is ($image->get('-colormap'), undef, "bitmap -colormap");

  $X->FreePixmap ($pixmap);
  $X->QueryPointer($X->{'root'});  # sync
  ok (1, 'FreePixmap and sync');
}

#------------------------------------------------------------------------------
# new() for_window

{
  my $rootwin = $X->{'root'};
  my %rootwin_geom = $X->GetGeometry ($rootwin);
  my %rootwin_attrs = $X->GetWindowAttributes ($rootwin);

  my $image = Image::Base::X11::Protocol::Pixmap->new
    (-X          => $X,
     -width      => 10,
     -height     => 20,
     -for_window => $rootwin);
  my $pixmap = $image->get('-pixmap');
  isnt ($pixmap, 0, '-pixmap created');

  is ($image->get('-depth'),  $rootwin_geom{'depth'}, "-depth");
  is ($image->get('-width'),  10, "-width");
  is ($image->get('-height'), 20, "-height");

  is ($image->get('-colormap'),
      $rootwin_attrs{'colormap'},
      "-colormap default from root window attributes");

  $X->FreePixmap ($pixmap);
  $X->QueryPointer($X->{'root'});  # sync
  ok (1, 'FreePixmap and sync');
}

exit 0;
