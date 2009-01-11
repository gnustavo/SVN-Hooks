#!/usr/bin/perl

use strict;
use warnings;
use lib 't';
use Test::More;

require "test-functions.pl";

if (not has_svn()) {
    plan skip_all => 'Need svn commands in the PATH.';
}
elsif (not eval {require XMLRPC::Lite}) {
    plan skip_all => 'Need XMLRPC::Lite';
}
else {
    plan tests => 9;
}

my $t = reset_repo();

set_hook(<<'EOS');
use SVN::Hooks::JiraAcceptance;
EOS

sub work {
    my ($msg) = @_;
    <<"EOS";
touch $t/wc/file
svn add -q --no-auto-props $t/wc/file
svn ci -m'$msg' --force-log $t/wc
EOS
}

set_conf(<<'EOS');
JIRA_CONFIG();
EOS

work_nok('config sans args', 'JIRA_CONFIG: requires three arguments', work(''));

set_conf(<<'EOS');
JIRA_CONFIG('http://jira.example.com', 'user', 'pass');
JIRA_LOG_MATCH();
EOS

work_nok('logmatch invalid first arg', 'JIRA_LOG_MATCH: first arg must be a qr/Regexp/', work(''));

set_conf(<<'EOS');
JIRA_CONFIG('http://jira.example.com', 'user', 'pass');
JIRA_LOG_MATCH(qr/./, qr/./);
EOS

work_nok('logmatch invalid second arg', 'JIRA_LOG_MATCH: second arg must be a string.', work(''));

set_conf(<<'EOS');
JIRA_CONFIG('http://jira.example.com', 'user', 'pass');
JIRA_LOG_MATCH(qr/./, 'help');
JIRA_ACCEPTANCE();
EOS

work_nok('accept invalid first arg', 'JIRA_ACCEPTANCE: first arg must be a qr/Regexp/.', work(''));

set_conf(<<'EOS');
JIRA_CONFIG('http://jira.example.com', 'user', 'pass');
JIRA_ACCEPTANCE(qr/./, qr/./);
EOS

work_nok('accept invalid second arg', 'JIRA_ACCEPTANCE: second arg must be a string.', work(''));

set_conf(<<'EOS');
JIRA_ACCEPTANCE(qr/./, '*');
EOS

work_nok('not configured', 'JIRA_ACCEPTANCE: plugin not configured.', work(''));

set_conf(<<'EOS');
JIRA_CONFIG('http://jira.example.com', 'user', 'pass');
JIRA_LOG_MATCH(qr/^\[([^\]]+)\]/, 'help');
JIRA_ACCEPTANCE(qr/./ => '*');
EOS

work_nok('no keys', 'Could not extract JIRA references from the log message', work('no keys'));

set_conf(<<'EOS');
JIRA_CONFIG('http://no.way.to.get.here', 'user', 'pass');
JIRA_LOG_MATCH(qr/^\[([^\]]+)\]/, 'help');
JIRA_ACCEPTANCE(qr/./ => '*');
EOS

work_nok('no server', 'JIRA_ACCEPTANCE: Unable to connect to the JIRA server at', work('[SVN-1] no server'));

set_conf(<<'EOS');
JIRA_CONFIG('http://jira.example.com', 'user', 'pass');
JIRA_LOG_MATCH(qr/^\[([^\]]+)\]/, 'help');
JIRA_ACCEPTANCE(qr/asdf/ => '*');
EOS

work_ok('no need to accept', work('ok'));

# FIXME - we haven't tested actual connections to a JIRA server. Should we fake it?
