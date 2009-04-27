# -*- cperl -*-

use strict;
use warnings;
use lib 't';
use Test::More;

require "test-functions.pl";

if (not has_svn()) {
    plan skip_all => 'Need svn commands in the PATH.';
}
elsif (not eval {require JIRA::Client}) {
    plan skip_all => 'Need JIRA::Client';
}
else {
    plan tests => 14;
}

my $t = reset_repo();

set_hook(<<'EOS');
use SVN::Hooks::CheckJira;
EOS

sub work {
    my ($msg) = @_;
    <<"EOS";
if [ -f $t/wc/file ]; then
  echo line >>$t/wc/file
else
  touch $t/wc/file
  svn add -q --no-auto-props $t/wc/file
fi
svn ci -m'$msg' --force-log $t/wc
EOS
}

set_conf(<<'EOS');
CHECK_JIRA_CONFIG();
EOS

work_nok('config sans args', 'CHECK_JIRA_CONFIG: requires three or four arguments', work(''));

set_conf(<<'EOS');
CHECK_JIRA_CONFIG('http://jira.atlassian.com/', 'user', 'pass', 'asdf');
EOS

work_nok('invalid fourth arg', 'CHECK_JIRA_CONFIG: fourth argument must be a Regexp', work(''));

set_conf(<<'EOS');
CHECK_JIRA();
EOS

work_nok('accept invalid first arg', 'CHECK_JIRA: first arg must be a qr/Regexp/ or the string \'default\'.', work(''));

set_conf(<<'EOS');
CHECK_JIRA(default => 'invalid');
EOS

work_nok('accept invalid second arg', 'CHECK_JIRA: second argument must be a HASH-ref.', work(''));

set_conf(<<'EOS');
CHECK_JIRA(default => {invalid => 1});
EOS

work_nok('invalid option', 'CHECK_JIRA: unknown option \'invalid\'.', work(''));

set_conf(<<'EOS');
CHECK_JIRA(default => {projects => 1});
EOS

work_nok('invalid projects arg', 'CHECK_JIRA: projects\'s value must match', work(''));

set_conf(<<'EOS');
CHECK_JIRA(default => {require => undef});
EOS

work_nok('undefined arg', 'CHECK_JIRA: undefined require\'s value', work(''));

set_conf(<<'EOS');
CHECK_JIRA(default => {check_one => 1});
EOS

work_nok('invalid code arg', 'CHECK_JIRA: check_one\'s value must be a CODE-ref', work(''));

set_conf(<<'EOS');
CHECK_JIRA(qr/./ => {});
EOS

work_nok('not configured', 'CHECK_JIRA: plugin not configured. Please, use the CHECK_JIRA_CONFIG directive', work(''));

################################################
# From now on the checks need a JIRA connection.

SKIP: {
    skip 'online checks are disabled', 5 unless -e 't/online.enabled';

    set_conf(<<'EOS');
CHECK_JIRA_CONFIG('http://no.way.to.get.there', 'user', 'pass');
CHECK_JIRA(qr/./);
EOS

    work_nok('no server', 'CHECK_JIRA_CONFIG: cannot connect to the JIRA server:', work('[TST-1] no server'));

    my $config = <<'EOS';
CHECK_JIRA_CONFIG('http://jira.atlassian.com/', 'jiraclient', '4jCSVpK7', qr/^\[([^\]]+)\]/);
EOS

    set_conf($config . <<'EOS');
CHECK_JIRA(qr/asdf/);
EOS

    work_ok('no need to accept', work('ok'));

    set_conf($config . <<'EOS');
sub fix_for {
    my ($version) = @_;
    return sub {
	my ($jira, $issue) = @_;
	foreach my $fv ($issue->{fixVersion}) {
	    return if $version eq $fv;
	}
	die "CHECK_JIRA: issue $issue->{key} not scheduled for version $version.\n";
    }
}

CHECK_JIRA(qr/./, {check_one => fix_for('future-version')});
EOS

    work_nok('no keys', 'CHECK_JIRA: you must cite at least one JIRA issue key in the commit message', work('no keys'));

    work_nok('not valid', 'CHECK_JIRA: issue ZYX-1 is not valid:', work('[ZYX-1]'));

    work_nok('check_one', 'CHECK_JIRA: issue TST-18099 not scheduled for version future-version.', work('[TST-18099]'));
}
