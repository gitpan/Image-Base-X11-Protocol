#!/usr/bin/perl -w

# Copyright 2010, 2011 Kevin Ryde

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

  plan tests => 7;
}

use_ok ('Image::Base::X11::Protocol::Window');
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

my $want_version = 6;
is ($Image::Base::X11::Protocol::Window::VERSION,
    $want_version, 'VERSION variable');
is (Image::Base::X11::Protocol::Window->VERSION,
    $want_version, 'VERSION class method');

ok (eval { Image::Base::X11::Protocol::Window->VERSION($want_version); 1 },
    "VERSION class check $want_version");
my $check_version = $want_version + 1000;
ok (! eval { Image::Base::X11::Protocol::Window->VERSION($check_version); 1 },
    "VERSION class check $check_version");

#------------------------------------------------------------------------------
# new()

{
  my $win = $X->new_rsrc;
  $X->CreateWindow($win, $X->root,
                   'InputOutput',
                   $X->root_depth,
                   'CopyFromParent',
                   0,0,
                   100,100,
                   5,   # border
                   background_pixel => 0x123456, # $X->{'white_pixel'},
                   override_redirect => 1,
                   colormap => 'CopyFromParent',
                  );
  $X->MapWindow ($win);
  my %win_attrs = $X->GetWindowAttributes ($win);

  my $image = Image::Base::X11::Protocol::Window->new
    (-X => $X,
     -window => $win);

  is ($image->get('-colormap'),
      $win_attrs{'colormap'},
      "-colormap default from window attributes");

  $X->DestroyWindow ($win);
  $X->QueryPointer($X->{'root'});  # sync
  ok (1, 'successful destroy and sync');
}

exit 0;
