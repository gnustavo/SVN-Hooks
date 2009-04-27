# -*- cperl -*-

use strict;
use warnings;
use lib 't';
use Test::More;

require "test-functions.pl";

if (has_svn()) {
    plan tests => 20;
}
else {
    plan skip_all => 'Need svn commands in the PATH.';
}

my $t = reset_repo();

set_hook(<<'EOS');
use SVN::Hooks::CheckProperty;
EOS

set_conf(<<'EOS');
CHECK_PROPERTY();
EOS

work_nok('conf: no first arg', 'CHECK_PROPERTY: first argument must be a STRING or a qr/Regexp/', <<"EOS");
touch $t/wc/f
svn add -q --no-auto-props $t/wc/f
svn ci -mx $t/wc/f
EOS

set_conf(<<'EOS');
CHECK_PROPERTY(bless({}, 'Nothing'));
EOS

work_nok('conf: wrong first arg', 'CHECK_PROPERTY: first argument must be a STRING or a qr/Regexp/', <<"EOS");
svn ci -mx $t/wc/f
EOS

set_conf(<<'EOS');
CHECK_PROPERTY('string');
EOS

work_nok('conf: no second arg', 'CHECK_PROPERTY: second argument must be a STRING', <<"EOS");
svn ci -mx $t/wc/f
EOS

set_conf(<<'EOS');
CHECK_PROPERTY('s', qr/asdf/);
EOS

work_nok('conf: wrong second arg', 'CHECK_PROPERTY: second argument must be a STRING', <<"EOS");
svn ci -mx $t/wc/f
EOS

set_conf(<<'EOS');
CHECK_PROPERTY('s', 's', bless({}, 'Nothing'));
EOS

work_nok('conf: wrong third arg', 'CHECK_PROPERTY: third argument must be undefined, or a NUMBER, or a STRING, or a qr/Regexp/', <<"EOS");
svn ci -mx $t/wc/f
EOS

set_conf(<<'EOS');
CHECK_PROPERTY('w1', 'prop');
CHECK_PROPERTY('w2', 'prop', 0);
CHECK_PROPERTY('w3', 'prop', 1);
CHECK_PROPERTY('w4', 'prop', 'value');
CHECK_PROPERTY('w5', 'prop', qr/^value$/);
CHECK_PROPERTY(qr/w6/, 'prop');
EOS

work_nok('check(string, string, undef) fail', 'property prop must be set for: w', <<"EOS");
touch $t/wc/w1
svn add -q --no-auto-props $t/wc/w1
svn ci -mx $t/wc/w1
EOS

work_ok('check(string, string, undef) succeed', <<"EOS");
svn ps prop x $t/wc/w1
svn ci -mx $t/wc/w1
EOS

work_nok('check(string, string, false) fail', 'property prop must not be set for: w', <<"EOS");
touch $t/wc/w2
svn add -q --no-auto-props $t/wc/w2
svn ps prop x $t/wc/w2
svn ci -mx $t/wc/w2
EOS

work_ok('check(string, string, false) succeed', <<"EOS");
svn pd prop $t/wc/w2
svn ci -mx $t/wc/w2
EOS

work_nok('check(string, string, true) fail', 'property prop must be set for: w', <<"EOS");
touch $t/wc/w3
svn add -q --no-auto-props $t/wc/w3
svn ci -mx $t/wc/w3
EOS

work_ok('check(string, string, true) succeed', <<"EOS");
svn ps prop x $t/wc/w3
svn ci -mx $t/wc/w3
EOS

work_nok('check(string, string, string) fail because not set',
	 'property prop must be set to "value" for: w', <<"EOS");
touch $t/wc/w4
svn add -q --no-auto-props $t/wc/w4
svn ci -mx $t/wc/w4
EOS

work_nok('check(string, string, string) fail because of wrong value',
	 'property prop must be set to "value" and not to "x" for: w', <<"EOS");
svn ps prop x $t/wc/w4
svn ci -mx $t/wc/w4
EOS

work_ok('check(string, string, string) succeed', <<"EOS");
svn ps prop value $t/wc/w4
svn ci -mx $t/wc/w4
EOS

work_nok('check(string, string, regex) fail because not set',
	 'property prop must be set and match "(?-xism:^value$)" for: w', <<"EOS");
touch $t/wc/w5
svn add -q --no-auto-props $t/wc/w5
svn ci -mx $t/wc/w5
EOS

work_nok('check(string, string, regex) fail because of wrong value',
	 'property prop must match "(?-xism:^value$)" but is "x" for: w', <<"EOS");
svn ps prop x $t/wc/w5
svn ci -mx $t/wc/w5
EOS

work_ok('check(string, string, regex) succeed', <<"EOS");
svn ps prop value $t/wc/w5
svn ci -mx $t/wc/w5
EOS

work_nok('check(regex, string, undef) fail', 'property prop must be set for: w', <<"EOS");
touch $t/wc/w6
svn add -q --no-auto-props $t/wc/w6
svn ci -mx $t/wc/w6
EOS

work_ok('check(regex, string, undef) succeed', <<"EOS");
svn ps prop x $t/wc/w6
svn ci -mx $t/wc/w6
EOS

work_ok('succeed because dont match file name', <<"EOS");
touch $t/wc/NOMATCH
svn add -q --no-auto-props $t/wc/NOMATCH
svn ci -mx $t/wc/NOMATCH
EOS

