# -*- cperl -*-

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
use SVN::Hooks::AllowPropChange;
EOS

work_ok('setup', <<"EOS");
touch $t/wc/file
svn add -q --no-auto-props $t/wc/file
svn ci -mx $t/wc/file
EOS

set_conf(<<'EOS');
ALLOW_PROP_CHANGE({});
EOS

work_nok('invalid argument' => 'ALLOW_PROP_CHANGE: invalid argument', <<"EOS");
svn ps svn:log --revprop -r 1 message $repo
EOS

set_conf(<<"EOS");
ALLOW_PROP_CHANGE(qr/./);
EOS

work_nok('unknowk property' => 'ALLOW_PROP_CHANGE: the revision property svn:xpto cannot be changed.', <<"EOS");
svn ps svn:xpto --revprop -r 1 value $repo
EOS

work_nok('cannot delete' => 'ALLOW_PROP_CHANGE: revision properties can only be modified, not added or deleted.', <<"EOS");
svn pd svn:log --revprop -r 1 $repo
EOS

my $username = getpwuid($<);

set_conf(<<"EOS");
ALLOW_PROP_CHANGE('svn:log' => 'x$username');
EOS

work_nok('deny user' => 'ALLOW_PROP_CHANGE: you are not allowed to change property svn:log.', <<"EOS");
svn ps svn:log --revprop -r 1 value $repo
EOS

set_conf(<<"EOS");
ALLOW_PROP_CHANGE('svn:log' => $username);
EOS

work_ok('can modify', <<"EOS");
svn ps svn:log --revprop -r 1 value $repo
EOS

set_conf(<<"EOS");
ALLOW_PROP_CHANGE('svn:log' => qr/./);
EOS

work_ok('can modify with regexp', <<"EOS");
svn ps svn:log --revprop -r 1 value2 $repo
EOS

set_conf(<<'EOS');
ALLOW_PROP_CHANGE(qr/./ => qr/^,/);
EOS

work_nok('deny user with regexp' => 'ALLOW_PROP_CHANGE: you are not allowed to change property svn:log.', <<"EOS");
svn ps svn:log --revprop -r 1 value3 $repo
EOS

