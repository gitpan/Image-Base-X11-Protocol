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


# Fetching back pixel values from a window only works properly when
# visibility state Unobscured, skip if that's not so.

use 5.004;
use strict;
use Test;
my $test_count;
BEGIN {
  $test_count = 2313;
  plan tests => $test_count;
}

use lib 't';
use MyTestHelpers;
BEGIN { MyTestHelpers::nowarnings() }
use MyTestImageBase;

use X11::Protocol;
use Image::Base::X11::Protocol::Window;

my $X;
my $display = $ENV{'DISPLAY'};
if (! defined $display) {
  foreach (1 .. $test_count) {
    skip ('No DISPLAY set', 1, 1);
  }
  exit 0;
}

# pass display arg so as not to get a "guess" warning
if (! eval { $X = X11::Protocol->new ($display); }) {
  my $why = "Cannot connect to X server -- $@";
  foreach (1 .. $test_count) {
    skip ($why, 1, 1);
  }
  exit 0;
}

my $width = 100;
my $height = 100;
my $border = 5;

my $under_win = $X->new_rsrc;
$X->CreateWindow ($under_win, $X->root,
                  'InputOutput',
                  $X->root_depth,
                  'CopyFromParent',
                  0,0,
                  $width+$border*2, $height+$border*2,
                  $border,
                  background_pixel => $X->{'white_pixel'},
                  border_pixel => $X->{'black_pixel'},
                  override_redirect => 1,
                  colormap => 'CopyFromParent',
                 );
$X->MapWindow ($under_win);

my $win = $X->new_rsrc;
my $event_mask = $X->pack_event_mask('VisibilityChange',
                                     'PointerMotion',
                                     'ButtonPress');
my $visibility = 'no VisibilityNotify event seen';
$X->{'event_handler'} = sub {
  my (%event) = @_;
  MyTestHelpers::diag("event ",$event{'name'});
  if ($event{'name'} eq 'VisibilityNotify') {
    $visibility = $event{'state'};
    $MyTestImageBase::skip = ($visibility eq 'Unobscured'
                            ? undef
                            : "window not visible: $visibility");
    MyTestHelpers::diag ("  visibility now ", $event{'state'});
    MyTestHelpers::diag ("  skip now ", $MyTestImageBase::skip);
  }
};

# use IO::Select;
# sub X_handle_input_nonblock {
#   my ($X) = @_;
#   $X->flush;
#   my $sel = ($X->{__PACKAGE__.'.sel'}
#              ||= IO::Select->new($X->{'connection'}->fh));
#   while ($sel->can_read) {
#     MyTestHelpers::diag ("handle_input()");
#     $X->handle_input;
#   }
# }
$MyTestImageBase::handle_input = sub {
  $X->QueryPointer($X->{'root'});  # sync
};

$X->CreateWindow($win, $under_win,
                 'InputOutput',
                 $X->root_depth,
                 'CopyFromParent',
                 0,0,
                 $width,$height,
                 $border,
                 background_pixel => 0x123456,
                 border_pixel => $X->{'white_pixel'},
                 override_redirect => 1,
                 colormap => 'CopyFromParent',
                 event_mask => $event_mask,
                );
$X->MapWindow ($win);
my %win_attrs = $X->GetWindowAttributes ($win);

my $image = Image::Base::X11::Protocol::Window->new
  (-X => $X,
   -window => $win);

MyTestImageBase::check_image ($image);

# resetting from None?
# getting border when reading back outermost pixels?
#
# SKIP: {
#   $X->init_extension('SHAPE')
#     or skip 'SHAPE extension not available', 2144;
#
#   $image->rectangle (0,0, $width-1,$height-1, '#000000', 0);
#   # $image->xy(0,0, 'None');
#   # is ($image->xy(0,0), '#FFFFFFFFFFFF',
#   #     'xy() pixel see through to under win');
#
#   # $MyTestImageBase::black = 'black';
#   # $MyTestImageBase::white = 'None';
#   # $MyTestImageBase::white_expect = 'white';
#   # MyTestImageBase::check_image ($image);
# }

exit 0;
