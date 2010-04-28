# -*- cperl -*-

use strict;
use warnings;
use lib 't';
use Test::More;

require "test-functions.pl";

if (can_svn()) {
    plan tests => 13;
}
else {
    plan skip_all => 'Cannot find or use svn commands.';
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
UPDATE_CONF_FILE('first', qr/regexp/);
EOS

work_nok('invalid second arg', 'UPDATE_CONF_FILE: invalid second argument', <<"EOS");
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
    my ($text, $file) = @_;
    die "undefined second argument" unless defined $file;
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
    my ($text, $file) = @_;
    die "undefined second argument" unless defined $file;
    return "[$file, $text]\n";
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
[generate, asdf
]
EOSS
cmp $t/wc/generated $t/repo/conf/generate
EOS

set_conf(<<'EOS');
UPDATE_CONF_FILE(subfile => 'subdir');

UPDATE_CONF_FILE(qr/^file(\d)$/ => '$1-file');

sub actuate {
    my ($text, $file) = @_;
    die "undefined second argument" unless defined $file;
    open F, '>', "/tmp/actuated" or die $!;
    print F $text;
    close F;
}

UPDATE_CONF_FILE(actuate  => 'actuate',
                 actuator => \&actuate);
EOS

mkdir "$t/repo/conf/subdir";

work_ok('to subdir', <<"EOS");
echo asdf >$t/wc/subfile
svn add -q --no-auto-props $t/wc/subfile
svn ci -mx $t/wc/subfile
cmp $t/wc/subfile $t/repo/conf/subdir/subfile
EOS

work_ok('regexp', <<"EOS");
echo asdf >$t/wc/file1
svn add -q --no-auto-props $t/wc/file1
svn ci -mx $t/wc/file1
cmp $t/wc/file1 $t/repo/conf/1-file
EOS

work_ok('actuate', <<"EOS");
echo asdf >$t/wc/actuate
svn add -q --no-auto-props $t/wc/actuate
svn ci -mx $t/wc/actuate
cmp $t/wc/actuate /tmp/actuated
EOS
