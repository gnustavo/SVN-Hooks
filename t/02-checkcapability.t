# -*- cperl -*-

use strict;
use warnings;
use lib 't';
use Test::More;

require "test-functions.pl";

if (has_svn()) {
    plan tests => 3;
}
else {
    plan skip_all => 'Need svn commands in the PATH.';
}

my $t = reset_repo();

set_hook(<<'EOS');
use SVN::Hooks::CheckCapability;
EOS

set_conf(<<'EOS');
CHECK_CAPABILITY();
EOS

work_ok('setup', <<"EOS");
touch $t/wc/f
svn add -q --no-auto-props $t/wc/f
svn ci -mx $t/wc/f
EOS

set_conf(<<'EOS');
CHECK_CAPABILITY('nonexistent-capability');
EOS

work_nok('conf: nonexistent capability', 'CHECK_CAPABILITY: Your subversion client does not support', <<"EOS");
echo asdf >>$t/wc/f
svn ci -mx $t/wc/f
EOS

set_conf(<<'EOS');
CHECK_CAPABILITY('mergeinfo');
EOS

if (`svn help` =~ /\bmergeinfo\b/) {
    work_ok('has mergeinfo', <<"EOS");
echo asdf >>$t/wc/f
svn ci -mx $t/wc/f
EOS
}
else {
    work_nok('do not has mergeinfo', 'CHECK_CAPABILITY: Your subversion client does not support', <<"EOS");
echo asdf >>$t/wc/f
svn ci -mx $t/wc/f
EOS
}
