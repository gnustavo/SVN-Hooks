# -*- cperl -*-

use strict;
use warnings;
use lib 't';
use Test::More;

require "test-functions.pl";

if (has_svn()) {
    plan tests => 10;
}
else {
    plan skip_all => 'Need svn commands in the PATH.';
}

my $t = reset_repo();

set_hook(<<'EOS');
use SVN::Hooks::DenyChanges;
EOS

set_conf(<<'EOS');
DENY_ADDITION('string');
EOS

work_nok('conf: no regex', 'DENY_CHANGES: all arguments must be qr/Regexp/', <<"EOS");
touch $t/wc/f
svn add -q --no-auto-props $t/wc/f
svn ci -mx $t/wc/f
EOS

set_conf(<<'EOS');
DENY_ADDITION(qr/add/, qr/ADD/);
DENY_DELETION(qr/del/);
DENY_UPDATE  (qr/upd/);
EOS

work_nok('deny add', 'Cannot add:', <<"EOS");
touch $t/wc/add
svn add -q --no-auto-props $t/wc/add
svn ci -mx $t/wc/add
EOS

work_nok('deny second arg', 'Cannot add:', <<"EOS");
touch $t/wc/ADD
svn add -q --no-auto-props $t/wc/ADD
svn ci -mx $t/wc/ADD
EOS

work_ok('add del upd', <<"EOS");
touch $t/wc/del $t/wc/upd
svn add -q --no-auto-props $t/wc/del $t/wc/upd
svn ci -mx $t/wc/del $t/wc/upd
EOS

work_nok('deny del', 'Cannot delete:', <<"EOS");
svn rm -q $t/wc/del
svn ci -mx $t/wc/del
EOS

work_nok('deny upd', 'Cannot update:', <<"EOS");
echo adsf >$t/wc/upd
svn ci -mx $t/wc/upd
EOS

work_ok('update f', <<"EOS");
echo adsf >$t/wc/f
svn ci -mx $t/wc/f
EOS

work_ok('del f', <<"EOS");
svn del -q $t/wc/f
svn ci -mx $t/wc/f
EOS

# Grok the author name
my $author;
open my $svn, '-|', "svn info $t/wc/del"
    or die "Can't exec svn info\n";
while (<$svn>) {
    if (/Author: (.*)$/) {
	$author = $1;
    }
}
close $svn;
ok(defined $author, 'grok author');

set_conf(<<"EOS");
DENY_ADDITION(qr/add/);
DENY_EXCEPT_USERS($author);
EOS

work_ok('except user', <<"EOS");
touch $t/wc/add
svn add -q --no-auto-props $t/wc/add
svn ci -mx $t/wc/add
EOS
