package SVN::Hooks::CheckJira;

use strict;
use warnings;
use Carp;
use SVN::Hooks;
use JIRA::Client;

use Exporter qw/import/;
my $HOOK = 'CHECK_JIRA';
our @EXPORT = qw/CHECK_JIRA_CONFIG CHECK_JIRA/;

our $VERSION = $SVN::Hooks::VERSION;

$SVN::Hooks::Confs->{$HOOK} = {
    checks   => [],
    defaults => {
	require     => 1,
	valid       => 1,
	unresolved  => 1,
	by_assignee => 0,
    },
};

=head1 NAME

SVN::Hooks::CheckJira - Integrate Subversion with the JIRA ticketing system.

=head1 DESCRIPTION

This SVN::Hooks plugin requires that any Subversion commits affecting
some parts of the repository structure must make reference to valid
JIRA issues in the commit log message. JIRA issues are referenced by
their keys which consists of a sequence of uppercase letters separated
by an hyfen from a sequence of digits. E.g., CDS-123, RT-1, and
SVN-97.

It's active in the C<pre-commit> and/or the C<post-commit> hook.

It's configured by the following directives.

=head2 CHECK_JIRA_CONFIG(BASEURL, LOGIN, PASSWORD, [REGEXP])

This directive specifies how to connect and to authenticate to the
JIRA server. BASEURL is the base URL of the JIRA server, usually,
something like C<http://jira.example.com/jira>. LOGIN and PASSWORD are
the credentials of a JIRA user who has browsing rights to the JIRA
projects that will be referenced in the commit logs.

The fourth argument is optional. It must be a qr/Regexp/ object that
will be used to match against the commit logs in order to extract the
list of JIRA issue keys. By default, the JIRA keys are looked for in
the whole commit log. Sometimes this can be suboptimal because the
user can introduce in the message some text that inadvertently looks
like a JIRA issue key whithout being so. With this argument, the log
message is matched against the REGEXP and only the first matched group
(i.e., the part of the message captured by the first parenthesis
(C<$1>)) is used to look for JIRA issue keys.

The JIRA issue keys are extracted from the commit log (or the part of
it specified by the REGEXP) with the following pattern:
C<qr/\b([A-Z]+-\d+)\b/g>;

=cut

sub CHECK_JIRA_CONFIG {
    my ($baseURL, $login, $passwd, $match) = @_;

    if (@_ == 3) {
	$match = qr/(.*)/;
    }
    elsif (@_ == 4) {
	ref $match eq 'Regexp'
	    or croak "CHECK_JIRA_CONFIG: fourth argument must be a Regexp.\n";
    }
    else {
	croak "CHECK_JIRA_CONFIG: requires three or four arguments.\n";
    }

    $baseURL =~ s:/+$::;

    my $conf = $SVN::Hooks::Confs->{$HOOK};
    $conf->{conf} = {
	conf  => [$baseURL, $login, $passwd],
	match => $match,
    };

    return 1;
}

=head2 CHECK_JIRA(REGEXP => {OPT => VALUE, ...})

This directive tells how each part of the repository structure must be
integrated with JIRA.

During a commit, all files being changed are tested against the REGEXP
of each CHECK_JIRA directive, in the order that they were called. If
at least one changed file matches a regexp, the issues cited in the
commit log are checked against their current status on JIRA according
to the options specified after the REGEXP.

The available options are the following:

=over

=item projects => 'PROJKEYS'

By default, the commiter can reference any JIRA issue in the commit
log. You can restrict the allowed keys to a set of JIRA projects by
specifying a comma-separated list of project keys to this option.

=item require => [01]

By default, the log must reference at least one JIRA issue. You can
make the reference optional by passing a false value to this option.

=item valid => [01]

By default, every issue referenced must be valid, i.e., it must exist
on the JIRA server. You can relax this requirement by passing a false
value to this option. (Why would you want to do that, though?)

=item unresolved => [01]

By default, every issue referenced must be unresolved, i.e., it must
not have a resolution. You can relax this requirement by passing a
false value to this option.

=item by_assignee => [01]

By default, the commiter can reference any valid JIRA issue. Passing a
true value to this option you require that the commiter can only
reference issues to which she is the current assignee.

=item check_one => CODE-REF

If the above checks aren't enough you can pass a code reference
(subroutine) to this option. The subroutine will be called once for
each referenced issue with two arguments: the JIRA::Client object used
to talk to the JIRA server and a reference to a RemoteIssue
object. The subroutine must simply return with no value to indicate
success and must die to indicate failure.

Plese, read the JIRA::Client module documentation to understand how to
use these objects.

=item check_all => CODE-REF

Sometimes checking each issue separatelly isn't enough. You may want
to check some relation among all the referenced issues. In this case,
pass a code reference to this option. It will be called once for the
commit. Its first argument is the JIRA::Client object used to talk to
the JIRA server. The following arguments are references to RemoteIssue
objects for every referenced issue. The subroutine must simply return
with no value to indicate success and must die to indicate failure.

=item post_action => CODE-REF

This is not a check, but an opportunity to perform some action after a
successful commit. The code reference passed will be called once
during the post-commit hook phase. Its first argument is the
JIRA::Client object used to talk to the JIRA server. The second
argument is the SVN::Look object that can be used to inspect all the
information about the commit proper.  The following arguments are the
JIRA keys mentioned in the commit log message. The value returned by
the routine, if any, is ignored.

=back

You can set defaults for these options using a CHECK_JIRA directive
with the string C<'default'> as a first argument, instead of a
qr/Regexp/.

    # Set some defaults
    CHECK_JIRA(default => {
        projects    => 'CDS,TST',
        by_assignee => 1,
    });

    # Check if some commits are scheduled, i.e., if they reference
    # JIRA issues that have at least one fix version.

    sub is_scheduled {
        my ($jira, $issue) = @_;
        return scalar @{$issue->{fixVersions}};
    }
    CHECK_JIRA(qr/^(trunk|branches/fix)/ => {
        check_one   => \&is_scheduled,
    });

Note that you need to call CHECK_JIRA at least once with a qr/Regexp/
in order to trigger the checks. A call for (C<'default'> doesn't
count. If you want to change defaults and force checks for every
commit, do this:

    CHECK_JIRA(default => {projects => 'CDS'});
    CHECK_JIRA(qr/./);

The C<'post_action'> pseudo-check can be used to interact with the
JIRA server after a successful commit. For instance, you may want to
add a comment to each refered issue like this:

    # This routine returns a closure that can be passed to
    # post_action.  The closure receives a string to be added as a
    # comment to each issue refered to by the commit message. The
    # commit info can be interpolated inside the comment using the
    # SVN::Look method names inside angle brackets.

    sub add_comment {
        my ($format) = @_;
        return sub {
            my ($jira, $svnlook, @keys) = @_;
            # Substitute keywords in the input comment with calls
            # into the $svnlook reference
	    $format =~ s/\{(\w+)\}/"\$svnlook->$1()"/eeg;
            for my $key (@keys) {
                $jira->addComment($key, $format);
            }
        }
    }

    CHECK_JIRA(qr/./ => {
        post_action => add_comment("Subversion Commit r{rev} by {author} on {date}\n{log_msg}")
    });

=cut

sub _validate_projects {
    my ($opt, $val) = @_;
    defined $val         or croak "$HOOK: undefined $opt\'s value.\n";
    ref $val            and croak "$HOOK: $opt\'s value must be a scalar.\n";
    $val =~ /^[A-Z,]+$/  or croak "$HOOK: $opt\'s value must match /^[A-Z,]+\$/.\n";
    my %projects = map {$_ => undef} grep {/./} split /,/, $val;
    return \%projects;
}

sub _validate_bool {
    my ($opt, $val) = @_;
    defined $val or croak "$HOOK: undefined $opt\'s value.\n";
    return $val;
}

sub _validate_code {
    my ($opt, $val) = @_;
    ref $val and ref $val eq 'CODE'
	or croak "$HOOK: $opt\'s value must be a CODE-ref.\n";
    return $val;
}

my %opt_checks = (
    projects    => \&_validate_projects,
    require     => \&_validate_bool,
    valid       => \&_validate_bool,
    unresolved  => \&_validate_bool,
    by_assignee => \&_validate_bool,
    check_one   => \&_validate_code,
    check_all   => \&_validate_code,
    post_action => \&_validate_code,
);

sub CHECK_JIRA {
    my ($regex, $opts) = @_;
    croak "$HOOK: first arg must be a qr/Regexp/ or the string 'default'.\n"
	unless (ref $regex and ref $regex eq 'Regexp') or (not ref $regex and $regex eq 'default');
    croak "$HOOK: second argument must be a HASH-ref.\n"
	if defined $opts and not (ref $opts and ref $opts eq 'HASH');

    $opts = {} unless defined $opts;
    foreach my $opt (keys %$opts) {
	exists $opt_checks{$opt} or croak "$HOOK: unknown option '$opt'.\n";
	$opts->{$opt} = $opt_checks{$opt}->($opt, $opts->{$opt});
    }

    my $conf = $SVN::Hooks::Confs->{$HOOK};
    if (ref $regex) {
	push @{$conf->{checks}}, [$regex => $opts];
    }
    else {
	while (my ($opt, $val) = each %$opts) {
	    $conf->{defaults}{$opt} = $val;
	}
    }
    $conf->{'pre-commit'} = \&pre_commit;
    $conf->{'post-commit'} = \&post_commit if exists $opts->{post_action};

    return 1;
}

sub _pre_checks {
    my ($self, $svnlook, $keys, $opts) = @_;

    my $conf = $self->{conf};

    # Grok and check each JIRA issue
    my @issues;
    foreach my $key (@$keys) {
	my $issue = eval {$conf->{jira}->getIssue($key)};
	if ($opts->{valid}) {
	    croak "$HOOK: issue $key is not valid: $@\n" if $@;
	}
	$issue or next;
	if ($opts->{unresolved}) {
	    croak "$HOOK: issue $key is already resolved.\n"
		if defined $issue->{resolution};
	}
	if ($opts->{by_assignee}) {
	    my $author = $svnlook->author();
	    croak "$HOOK: committer ($author) is different from issue ${key}'s assignee ($issue->{assignee}).\n"
		if $author ne $issue->{assignee};
	}
	if (my $check = $opts->{check_one}) {
	    $check->($conf->{jira}, $issue);
	}
	push @issues, $issue;
    }

    if (my $check = $opts->{check_all}) {
	$check->($conf->{jira}, @issues) if @issues;
    }

    return;
}

sub _post_action {
    my ($self, $svnlook, $keys, $opts) = @_;

    if (my $action = $opts->{post_action}) {
	$action->($self->{conf}->{jira}, $svnlook, @$keys);
    }

    return;
}

sub _check_if_needed {
    my ($self, $svnlook, $docheck) = @_;

    my $conf = $self->{conf}
	or croak "$HOOK: plugin not configured. Please, use the CHECK_JIRA_CONFIG directive.\n";

    my @files = $svnlook->changed();

    foreach my $check (@{$self->{checks}}) {
	my ($regex, $opts) = @$check;

	for my $file (@files) {
	    if ($file =~ $regex) {

		# Grok the JIRA issue keys from the commit log
		my ($match) = ($svnlook->log_msg() =~ $conf->{match});
		my @keys    = defined $match ? $match =~ /\b[A-Z]+-\d+\b/g : ();

		my %opts = (%{$self->{defaults}}, %$opts);

		if ($opts{require}) {
		    croak "$HOOK: you must cite at least one JIRA issue key in the commit message.\n"
			unless @keys;
		}

		return unless @keys;

		# Check if there is a restriction on the project keys allowed
		if (exists $opts->{projects}) {
		    foreach my $key (@keys) {
			my ($pkey, $pnum) = split /-/, $key;
			croak "$HOOK: issue $key is not allowed. You must cite only JIRA issues for the following projects: ", join(', ', sort keys %{$opts->{projects}}), ".\n"
			    unless exists $opts->{projects}{$pkey};
		    }
		}

		# Connect to JIRA if not yet connected.
		unless (exists $conf->{jira}) {
		    $conf->{jira} = eval {JIRA::Client->new(@{$conf->{conf}})};
		    croak "CHECK_JIRA_CONFIG: cannot connect to the JIRA server: $@\n" if $@;
		}

		$docheck->($self, $svnlook, \@keys, \%opts);
		last;
	    }
	}
    }

    return;
}

sub pre_commit {
    my ($self, $svnlook) = @_;
    _check_if_needed($self, $svnlook, \&_pre_checks);
    return;
}

sub post_commit {
    my ($self, $svnlook) = @_;
    _check_if_needed($self, $svnlook, \&_post_action);
    return;
}

=head1 AUTHOR

Gustavo Chaves, C<< <gnustavo@cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-svn-hooks at rt.cpan.org>, or through the web
interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=SVN-Hooks>.  I will
be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc SVN::Hooks

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=SVN-Hooks>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/SVN-Hooks>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/SVN-Hooks>

=item * Search CPAN

L<http://search.cpan.org/dist/SVN-Hooks>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 CPqD, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1; # End of SVN::Hooks::CheckJira
