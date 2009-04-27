# -*- cperl -*-

use strict;
use warnings;
use lib 't';
use Test::More;

require "test-functions.pl";

if (has_svn()) {
    plan tests => 13;
}
else {
    plan skip_all => 'Need svn commands in the PATH.';
}

my $t = reset_repo();

set_hook(<<'EOS');
use SVN::Hooks::CheckStructure;
EOS

set_conf(<<'EOS');
CHECK_STRUCTURE(
    [
	invalid_rhs => 'invalid rhs',
	deny => 0,
	allow => 1,
	file => 'FILE',
	dir => 'DIR',
	sub1 => [
	    sub2 => [
		sub3 => [
		],
	    ],
	],
	qr/regex/ => [
	    just => 1,
	    0 => 'custom error message',
	],
	1 => 'DIR',
    ],
);
EOS

work_nok('invalid_rhs', 'syntax error: unknown string spec (invalid rhs)', <<"EOS");
touch $t/wc/invalid_rhs
svn add -q --no-auto-props $t/wc/invalid_rhs
svn ci -mx $t/wc/invalid_rhs
EOS

work_nok('deny 0', 'invalid path', <<"EOS");
touch $t/wc/deny
svn add -q --no-auto-props $t/wc/deny
svn ci -mx $t/wc/deny
EOS

work_ok('allow 1', <<"EOS");
touch $t/wc/allow
svn add -q --no-auto-props $t/wc/allow
svn ci -mx $t/wc/allow
EOS

work_nok('is not file', 'the component (file) should be a FILE in', <<"EOS");
mkdir $t/wc/file
svn add -q --no-auto-props $t/wc/file
svn ci -mx $t/wc/file
EOS

work_ok('is file', <<"EOS");
svn rm -q --force $t/wc/file
touch $t/wc/file
svn add -q --no-auto-props $t/wc/file
svn ci -mx $t/wc/file
EOS

work_nok('is not dir', 'the component (dir) should be a DIR in', <<"EOS");
touch $t/wc/dir
svn add -q --no-auto-props $t/wc/dir
svn ci -mx $t/wc/dir
EOS

work_ok('is dir', <<"EOS");
svn rm -q --force $t/wc/dir
mkdir $t/wc/dir
svn add -q --no-auto-props $t/wc/dir
svn ci -mx $t/wc/dir
EOS

work_ok('allow sub', <<"EOS");
mkdir -p $t/wc/sub1/sub2/sub3
svn add -q --no-auto-props $t/wc/sub1
svn ci -mx $t/wc/sub1
EOS

work_nok('deny sub', 'the component (deny) is not allowed in', <<"EOS");
touch $t/wc/sub1/sub2/deny
svn add -q --no-auto-props $t/wc/sub1/sub2/deny
svn ci -mx $t/wc/sub1/sub2/deny
EOS

work_ok('regex allow', <<"EOS");
mkdir -p $t/wc/preregexsuf
touch $t/wc/preregexsuf/just
svn add -q --no-auto-props $t/wc/preregexsuf
svn ci -mx $t/wc/preregexsuf
EOS

work_nok('0 error', 'custom error message', <<"EOS");
touch $t/wc/preregexsuf/no
svn add -q --no-auto-props $t/wc/preregexsuf/no
svn ci -mx $t/wc/preregexsuf/no
EOS

work_nok('deny else', 'the component (else) should be a DIR in', <<"EOS");
touch $t/wc/else
svn add -q --no-auto-props $t/wc/else
svn ci -mx $t/wc/else
EOS

work_ok('deny else', <<"EOS");
svn rm -q --force $t/wc/else
mkdir $t/wc/else
svn add -q --no-auto-props $t/wc/else
svn ci -mx $t/wc/else
EOS

