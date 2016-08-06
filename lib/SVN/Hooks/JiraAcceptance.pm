package SVN::Hooks::JiraAcceptance;
# ABSTRACT: Integrate Subversion with the JIRA ticketing system.

use strict;
use warnings;

use Carp;
use Data::Util qw(:check);
use SVN::Hooks;
use XMLRPC::Lite;

use Exporter qw/import/;
my $HOOK = 'JIRA';
our @EXPORT = qw/JIRA_CONFIG JIRA_LOG_MATCH JIRA_ACCEPTANCE/;

=for Pod::Coverage pre_commit

=head1 SYNOPSIS

This SVN::Hooks plugin is deprecated. Please, consider using the
SVN::Hooks::CheckJira plugin instead.

This plugin was derived from version 1.3 of the L<JIRA Commit
Acceptance
Plugin|http://svn.atlassian.com/svn/public/contrib/jira/jira-commitacceptance-plugin/jars/jira-commitacceptance-plugin-1.3-client-scripts.zip>
by ferenc.kiss@midori.hu.

When enabled, it requires that any commits affecting some parts of the
repository structure must make reference to valid JIRA issues in the
commit log message. JIRA issues are referenced by their ids which
consists of a sequence of uppercase letters separated by an hyfen from
a sequence of digits. E.g., CDS-123, RT-1, and SVN-97.

It's active in the C<pre-commit> hook.

It's configured by the following directives.

=head2 JIRA_CONFIG(BASEURL, LOGIN, PASSWORD)

This directive specify how to connect to the JIRA server by specifying
its base URL and the login credentials of a user who has browsing
rights.

=cut

my ($BaseURL, $Login, $Passwd);

sub JIRA_CONFIG {
    @_ == 3 or croak "JIRA_CONFIG: requires three arguments.\n";

    ($BaseURL, $Login, $Passwd) = @_;

    $BaseURL =~ s:/+$::;

    return 1;
}

=head2 JIRA_LOG_MATCH(REGEXP, MESSAGE)

By default the JIRA references are looked for in the commit log
message as a whole. Sometimes this can be suboptimal because the user
can introduce in the message some text that inadvertently looks like a
JIRA reference without being so.

With this directive, the log message is matched against the REGEXP and
only the first group matched (i.e., the part of the message captured
by the first parenthesis (C<$1>)) is used to look for JIRA
references. Moreover, you can pass a help MESSAGE that is shown to the
user in case the JIRA test fails.

	JIRA_LOG_MATCH(
	    qr/^\[([^\]]+)\]/,
	    "The JIRA references must be inside brackets at the beginning of the message.",
	);

=cut

my ($Match, $Help);

sub JIRA_LOG_MATCH {
    my ($regex, $message) = @_;
    is_rx($regex)       or croak "JIRA_LOG_MATCH: first arg must be a qr/Regexp/.\n";
    is_string($message) or croak "JIRA_LOG_MATCH: second arg must be a string.\n";

    $Match = $regex;
    if ($message) {
	chomp $message;
	$Help = <<"EOS";
JIRA_ACCEPTANCE: The administrator offered the following help:
$message
EOS
    }

    return 1;
}

=head2 JIRA_ACCEPTANCE(REGEXP, PROJECT_KEYS)

This directive tells what parts of the repository structure must be
integrated with what JIRA projects.

During a commit, all files being changed are tested against the
REGEXP. If at least one of them matches, then the log message must
contain references to the PROJECT_KEYS.

PROJECT_KEYS can contain multiple comma-separated JIRA project keys
like 'TST,ARP'.  If you specify multiple keys, the commit will be
accepted if at least one project listed accepts it.  Or you can
specify '*' to force using the global commit acceptance settings if
you don't want to specify any exact project key.

	JIRA_ACCEPTANCE(qr/^(trunk|branches/fix)/ => 'CDS,TST');

=cut

my @Checks;

sub JIRA_ACCEPTANCE {
    my ($regex, $project_keys) = @_;
    is_rx($regex)	     or croak "JIRA_ACCEPTANCE: first arg must be a qr/Regexp/.\n";
    is_string($project_keys) or croak "JIRA_ACCEPTANCE: second arg must be a string.\n";

    my %keys;
    foreach (split /,/, $project_keys) {
	$keys{$_} = undef;
    }
    push @Checks, [$regex => \%keys];

    PRE_COMMIT(\&pre_commit);

    return 1;
}

sub pre_commit {
    my ($svnlook) = @_;

    my @files = $svnlook->changed();

    my %keys;

    foreach my $check (@Checks) {
	my ($regex, $project_keys) = @$check;

	for my $file (@files) {
	    if ($file =~ $regex) {
		$keys{$_} = undef foreach keys %$project_keys;
		last;
	    }
	}
    }

    if (%keys) {
	defined $BaseURL
	    or croak "JIRA_ACCEPTANCE: plugin not configured.";

	# Grok JIRA references from the log
	my $jira_refs = $svnlook->log_msg();
	if (defined $Match) {
	    if ($jira_refs =~ $Match) {
		$jira_refs = $1;
	    } else {
		chomp $jira_refs;
		croak <<"EOS";
JIRA_ACCEPTANCE: Could not extract JIRA references from the log message.
$Help
EOS
	    }
	}

	# invoke JIRA web service
	my $result = eval {
	    XMLRPC::Lite
	        ->proxy("$BaseURL/rpc/xmlrpc")
		->call(
		    'commitacc.acceptCommit',
		    $Login,
		    $Passwd,
		    $svnlook->author(),
		    join(',', keys %keys),
		    $jira_refs,
		)
		->result();
	};
	croak "JIRA_ACCEPTANCE: Unable to connect to the JIRA server at \"$BaseURL/rpc/xmlrpc\": $@.\n"
	    if $@;

	# This can happen if there's an error in the JIRA plugin
	$result = 'false|JIRA internal error' unless defined $result;

	my ($acceptance, $comment) = split '\|', $result;

	$acceptance eq 'true'
	    or croak <<"EOS";
JIRA_ACCEPTANCE: JIRA rejected this log with the following message:
$comment
EOS
    }

    return;
}

1; # End of SVN::Hooks::JiraAcceptance
