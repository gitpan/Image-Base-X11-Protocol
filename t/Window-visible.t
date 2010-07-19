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


# Fetching back pixel values from a window only works properly when
# visibility state Unobscured, skip if that's not so.

use 5.004;
use strict;
use warnings;
use Test::More;

use lib 't';
use MyTestHelpers;
BEGIN { MyTestHelpers::nowarnings() }

use X11::Protocol;
use Image::Base::X11::Protocol::Window;
use MyTestImageBase;

my $X;
my $display = $ENV{'DISPLAY'};
defined $display
  or plan skip_all => 'No DISPLAY set';

# pass display arg so as not to get a "guess" warning
eval { $X = X11::Protocol->new ($display); }
  or plan skip_all => "Cannot connect to X server -- $@";

my $win = $X->new_rsrc;
my $event_mask = $X->pack_event_mask('VisibilityChange',
                                     'PointerMotion',
                                     'ButtonPress');
my $visibility = 'no VisibilityNotify event seen';
$X->{'event_handler'} = sub {
  my (%event) = @_;
  diag "event ",$event{'name'};
  if ($event{'name'} eq 'VisibilityNotify') {
    diag "visibility ",$event{'state'};
    $visibility = $event{'state'};
  }
};
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
                 event_mask => $event_mask,
                );
$X->MapWindow ($win);
my %win_attrs = $X->GetWindowAttributes ($win);

my $image = Image::Base::X11::Protocol::Window->new
  (-X => $X,
   -window => $win);

$visibility eq 'Unobscured'
  or plan skip_all => "window not visible: $visibility";


plan tests => 1909;
MyTestImageBase::check_image ($image);

exit 0;
