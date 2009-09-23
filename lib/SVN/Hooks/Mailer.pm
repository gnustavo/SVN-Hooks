package SVN::Hooks::Mailer;

use warnings;
use strict;
use SVN::Hooks;
use Email::Send;
use Email::Simple;
use Email::Simple::Creator;

use Exporter qw/import/;
my $HOOK = 'MAILER';
our @EXPORT = qw/EMAIL_CONFIG EMAIL_COMMIT/;

our $VERSION = 0.11;

=head1 NAME

SVN::Hooks::Mailer - Send emails after succesful commits.

=head1 SYNOPSIS

This SVN::Hooks plugin sends notification emails after succesful
commits. It's deprecated. You should use SVN::Hooks::Notify instead.

The emails contain information about the commit like this:

	Subject: [TAG] Commit revision 153 by jsilva

	Author:   jsilva
	Revision: 153
	Date:     2008-09-16 11:03:35 -0300 (Tue, 16 Sep 2008)
	Added files:
	    trunk/conf/svn-hooks.conf
	Deleted files:
	    trunk/conf/hooks.conf
	Updated files:
	    trunk/conf/passwd
	Log Message:
	    Setting up the conf directory.

It's active in the C<post-commit> hook.

It's configured by the following directives.

=head2 EMAIL_CONFIG()

SVN::Hooks::Mailer uses Email::Send to send emails.

This directive allows you to chose a particular mailer to send email
with.

	EMAIL_CONFIG(Sendmail => '/usr/sbin/sendmail');
	EMAIL_CONFIG(SMTP => 'smtp.example.com');
	EMAIL_CONFIG(IO => '/path/to/file');

The first two are the most common. The last can be used for debugging.

=cut

sub EMAIL_CONFIG {
    die "EMAIL_CONFIG: requires two arguments"
	if @_ != 2;

    my ($opt, $arg) = @_;
    my $conf = $SVN::Hooks::Confs->{$HOOK};

    $conf->{sender} = Email::Send->new({mailer => $opt});
    if    ($opt eq 'Sendmail') {
	-x $arg or die "EMAIL_CONFIG: not an executable file ($arg)";
	$Email::Send::Sendmail::SENDMAIL = $arg;
    }
    elsif ($opt eq 'SMTP') {
	$conf->{sender}->mailer_args([Host => $arg]);
    }
    elsif ($opt eq 'IO') {
	$conf->{sender}->mailer_args([$arg]);
    }
    else {
	die "EMAIL_CONFIG: unknown option '$opt'"
    }

    1;
}

my %valid_options = (
    match    => undef,
    tag      => undef,
    from     => undef,
    to       => undef,
    cc       => undef,
    bcc      => undef,
    reply_to => undef,
    diff     => undef,
);

=head2 EMAIL_COMMIT(HASH_REF)

This directive receives a hash-ref specifying the email that must be
sent. The hash may contain the following key/value pairs:

=over

=item match => qr/Regexp/

The email will be sent only if the Regexp matches at least one of the
files changed in the commit. If it doesn't exist, the email will be
sent always.

=item from => 'ADDRESS'

The email address that will be used in the From: header. If it doesn't
exist, the from address will usually be the user running Subversion.

=item to => 'ADDRESS, ...'

The email addresses to which the email will be sent. This key is
required.

=item tag => 'STRING'

If present, the subject will be prefixed with '[STRING] '.

=item cc, bcc, reply_to => 'ADDRESS, ...'

These are optional email addresses used in the respective email
headers.

=item diff => [STRING, ...]

If this key is specified, the email will also contain the GNU-style
diff of changed files in the commit. If its value is an ARRAY REF its
values will be passed as extra options to the 'svnlook diff'
command. There are three of them:

=over

=item C<--no-diff-deleted>

Do not print differences for deleted files

=item C<--no-diff-added>

Do not print differences for added files.

=item C<--diff-copy-from>

Print differences against the copy source.

=back

=back

=cut

sub EMAIL_COMMIT {
    die "EMAIL_COMMIT: odd number of arguments"
	if @_ % 2;

    # Check and normalize options
    my %o = @_;

    foreach my $o (keys %o) {
	unless (exists $valid_options{$o}) {
	    my $valid_options = join ', ', sort keys %valid_options;
	    die <<"EOS";
EMAIL_COMMIT: unknown option '$o'
The valid options are: $valid_options
EOS
	}
    }

    if (exists $o{match}) {
	die "EMAIL_COMMIT: 'match' argument must be a qr/Regexp/"
	    unless ref $o{match} eq 'Regexp';
    }
    else {
	$o{match} = qr/./;	# match all
    }

    foreach my $header (qw/from to/) {
	die "EMAIL_COMMIT: missing '$header' address"
	    unless exists $o{$header};
    }

    my $conf = $SVN::Hooks::Confs->{$HOOK};
    push @{$conf->{projects}}, \%o;

    $conf->{'post-commit'} = \&post_commit;

    1;
}

$SVN::Hooks::Inits{$HOOK} = sub {
    return { sender => {}, projects => [] };
};

sub post_commit {
    my ($self, $svnlook) = @_;

    my ($body, $rev, $author, $date);

  PROJECT:
    foreach my $p (@{$self->{projects}}) {
	foreach my $file ($svnlook->changed()) {
	    if ($file =~ $p->{match}) {
		unless ($body) {
		    $rev    = $svnlook->rev();
		    $author = $svnlook->author();
		    $date   = $svnlook->date();

		    $body = <<"EOS";
Author:   $author
Revision: $rev
Date:     $date
EOS

		    my $changed = $svnlook->changed_hash();
		    foreach my $change (qw/added deleted updated prop_modified/) {
			my $list = $changed->{$change};
			if (@$list) {
			    $body .= join "\n    ", "\u$change files:", @$list;
			    $body .= "\n";
			}
		    }

		    my $log = $svnlook->log_msg();
		    $log    =~ s/^/    /g;		# indent every line
		    $body  .= "Log Message:\n$log\n";

		    if (exists $p->{diff}) {
			my $opts = $p->{diff};
			my $diff = $svnlook->diff((ref $opts and ref $opts eq 'ARRAY') ? @$opts : ());
			$body   .= "\n$diff";
		    }
		}
		_send_email($self->{sender}, $p, $rev, $author, $body);
		next PROJECT;
	    }
	}
    }
}

sub _send_email {
    my ($sender, $project, $rev, $author, $body) = @_;

    my $subject = "Commit revision $rev by $author";

    if ($project->{tag}) {
	$subject = "[$project->{tag}] $subject";
    }

    # Necessary headers
    my @headers = (
	From    => $project->{from},
	To      => $project->{to},
	Subject => $subject,
    );

    # Optional headers
    foreach my $header (qw/reply_to cc bcc/) {
	if (my $addrs = $project->{$header}) {
	    $header =~ tr/_/-/;
	    push @headers, ($header => $addrs);
	}
    }

    my $email = Email::Simple->create(
	header => \@headers,
	body   => $body,
    );

    my $result = $sender->send($email);
    die "$result" if ! $result;
}

=head1 AUTHOR

Gustavo Chaves, C<< <gnustavo@cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-svn-hooks-checkmimetypes at rt.cpan.org>, or through the web
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

Copyright 2008-2009 CPqD, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1; # End of SVN::Hooks::Mailer
