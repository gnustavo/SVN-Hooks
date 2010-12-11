# -*- cperl -*-

use strict;
use warnings;
use lib 't';
use Test::More;

require "test-functions.pl";

if (can_svn()) {
    plan tests => 7;
}
else {
    plan skip_all => 'Cannot find or use svn commands.';
}

my $t = reset_repo();

set_hook(<<'EOS');
use SVN::Hooks::Generic;
EOS

set_conf(<<'EOS');
GENERIC(1);
EOS

work_nok('odd' => 'odd number of arguments', <<"EOS");
touch $t/wc/file.txt
svn add -q --no-auto-props $t/wc/file.txt
svn ci -mx $t/wc/file.txt
EOS

set_conf(<<'EOS');
GENERIC('non_hook' => sub {});
EOS

work_nok('non hook' => 'invalid hook name', <<"EOS");
svn ci -mx $t/wc/file.txt
EOS

set_conf(<<'EOS');
GENERIC('start-commit' => 'non ref');
EOS

work_nok('non ref' => 'should be mapped to a reference', <<"EOS");
svn ci -mx $t/wc/file.txt
EOS

set_conf(<<'EOS');
GENERIC('start-commit' => {});
EOS

work_nok('non array' => 'should be mapped to a CODE-ref or to an ARRAY of CODE-refs', <<"EOS");
svn ci -mx $t/wc/file.txt
EOS

set_conf(<<'EOS');
GENERIC('start-commit' => ['non code']);
EOS

work_nok('non code' => 'should be mapped to CODE-refs', <<"EOS");
svn ci -mx $t/wc/file.txt
EOS

set_conf(<<'EOS');
GENERIC('start-commit' => sub { die "died from within"; });
EOS

work_nok('died from within' => 'died from within', <<"EOS");
svn ci -mx $t/wc/file.txt
EOS

set_conf(<<'EOS');
GENERIC('start-commit' => sub { return 1; });
EOS

work_ok('ok', <<"EOS");
svn ci -mx $t/wc/file.txt
EOS

