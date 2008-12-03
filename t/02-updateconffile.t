#!/usr/bin/perl

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
use SVN::Hooks::UpdateConfFile;
EOS

set_conf(<<'EOS');
UPDATE_CONF_FILE();
EOS

work_nok('require first arg', 'UPDATE_CONF_FILE: invalid first argument.', <<"EOS");
echo asdf >$t/wc/file
svn add -q --no-auto-props $t/wc/file
svn ci -mx $t/wc/file
EOS

set_conf(<<'EOS');
UPDATE_CONF_FILE('first');
EOS

work_nok('require second arg', 'UPDATE_CONF_FILE: invalid second argument.', <<"EOS");
svn ci -mx $t/wc/file
EOS

set_conf(<<'EOS');
UPDATE_CONF_FILE('first', 'path/second');
EOS

work_nok('second arg is path', 'UPDATE_CONF_FILE: second argument must be a basename, not a path', <<"EOS");
svn ci -mx $t/wc/file
EOS

set_conf(<<'EOS');
UPDATE_CONF_FILE('first', 'second', 'third');
EOS

work_nok('odd number of args', 'UPDATE_CONF_FILE: odd number of arguments.', <<"EOS");
svn ci -mx $t/wc/file
EOS

set_conf(<<'EOS');
UPDATE_CONF_FILE('first', 'second', validator => 'string');
EOS

work_nok('not code-ref', 'UPDATE_CONF_FILE: validator argument must be a CODE-ref or an ARRAY-ref', <<"EOS");
svn ci -mx $t/wc/file
EOS

set_conf(<<'EOS');
UPDATE_CONF_FILE('first', 'second', foo => 'string');
EOS

work_nok('invalid function', 'UPDATE_CONF_FILE: invalid function names:', <<"EOS");
svn ci -mx $t/wc/file
EOS

set_conf(<<'EOS');
UPDATE_CONF_FILE(file => 'file');

sub validate {
    my ($text) = @_;
    if ($text =~ /abort/) {
	die "Aborting!"
    }
    else {
	return 1;
    }
}

UPDATE_CONF_FILE(validate  => 'validate',
                 validator => \&validate);

sub generate {
    my ($text) = @_;
    return "[$text]\n";
}

UPDATE_CONF_FILE(generate  => 'generate',
                 generator => \&generate);
EOS

work_ok('update without validation', <<"EOS");
svn ci -mx $t/wc/file
cmp $t/wc/file $t/repo/conf/file
EOS

work_ok('update valid', <<"EOS");
echo asdf >$t/wc/validate
svn add -q --no-auto-props $t/wc/validate
svn ci -mx $t/wc/validate
cmp $t/wc/validate $t/repo/conf/validate
EOS

work_nok('update aborting', 'UPDATE_CONF_FILE: Validator aborted for:', <<"EOS");
echo abort >$t/wc/validate
svn ci -mx $t/wc/validate
EOS

work_ok('generate', <<"EOS");
echo asdf >$t/wc/generate
svn add -q --no-auto-props $t/wc/generate
svn ci -mx $t/wc/generate
cat >$t/wc/generated <<'EOSS'
[asdf
]
EOSS
cmp $t/wc/generated $t/repo/conf/generate
EOS

