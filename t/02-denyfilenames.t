#!/usr/bin/perl

use strict;
use warnings;
use lib 't';
use Test::More;

require "test-functions.pl";

if (has_svn()) {
    plan tests => 4;
}
else {
    plan skip_all => 'Need svn commands in the PATH.';
}

my $t = reset_repo();

set_hook(<<'EOS');
use SVN::Hooks::DenyFilenames;
EOS

set_conf(<<'EOS');
DENY_FILENAMES('string');
EOS

work_nok('cant parse config', 'DENY_FILENAMES: got "string" while expecting a qr/Regex/', <<"EOS");
touch $t/wc/f
svn add -q --no-auto-props $t/wc/f
svn ci -mx $t/wc/f
EOS

set_conf(<<'EOS');
DENY_FILENAMES(qr/[^\w]/i, qr/substring/);
EOS

work_ok('valid', <<"EOS");
svn ci -mx $t/wc/f
EOS

work_nok('invalid', 'DENY_FILENAMES: the files below can\'t be added because their names aren\'t allowed', <<"EOS");
touch $t/wc/f,
svn add -q --no-auto-props $t/wc/f,
svn ci -mx $t/wc/f,
EOS

work_nok('second invalid', 'DENY_FILENAMES: the files below can\'t be added because their names aren\'t allowed', <<"EOS");
touch $t/wc/withsubstringinthemiddle
svn add -q --no-auto-props $t/wc/withsubstringinthemiddle
svn ci -mx $t/wc/withsubstringinthemiddle
EOS

