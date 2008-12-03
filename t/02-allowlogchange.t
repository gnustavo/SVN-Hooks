#!/usr/bin/perl

use strict;
use warnings;
use lib 't';
use Test::More;

require "test-functions.pl";

if (has_svn()) {
    plan tests => 8;
}
else {
    plan skip_all => 'Need svn commands in the PATH.';
}

my $t = reset_repo();
chomp(my $cwd = `pwd`);
my $repo = "file://$t/repo";

set_hook(<<'EOS');
use SVN::Hooks::AllowLogChange;
EOS

work_ok('setup', <<"EOS");
touch $t/wc/file
svn add -q --no-auto-props $t/wc/file
svn ci -mx $t/wc/file
EOS

set_conf(<<'EOS');
ALLOW_LOG_CHANGE({});
EOS

work_nok('invalid argument' => 'ALLOW_LOG_CHANGE: invalid argument', <<"EOS");
svn ps svn:log --revprop -r 1 message $repo
EOS

set_conf(<<"EOS");
ALLOW_LOG_CHANGE();
EOS

work_nok('nothing but svn:log' => 'ALLOW_LOG_CHANGE: the revision property svn:xpto cannot be changed.', <<"EOS");
svn ps svn:xpto --revprop -r 1 value $repo
EOS

work_nok('cannot delete' => 'ALLOW_LOG_CHANGE: a revision log can only be modified, not added or deleted.', <<"EOS");
svn pd svn:log --revprop -r 1 $repo
EOS

set_conf(<<"EOS");
ALLOW_LOG_CHANGE('x$ENV{USER}');
EOS

work_nok('deny user' => 'ALLOW_LOG_CHANGE: you are not allowed to change a revision log.', <<"EOS");
svn ps svn:log --revprop -r 1 value $repo
EOS

set_conf(<<"EOS");
ALLOW_LOG_CHANGE($ENV{USER});
EOS

work_ok('can modify', <<"EOS");
svn ps svn:log --revprop -r 1 value $repo
EOS

set_conf(<<"EOS");
ALLOW_LOG_CHANGE(qr/./);
EOS

work_ok('can modify with regexp', <<"EOS");
svn ps svn:log --revprop -r 1 value2 $repo
EOS

set_conf(<<'EOS');
ALLOW_LOG_CHANGE(qr/^,/);
EOS

work_nok('deny user with regexp' => 'ALLOW_LOG_CHANGE: you are not allowed to change a revision log.', <<"EOS");
svn ps svn:log --revprop -r 1 value3 $repo
EOS

