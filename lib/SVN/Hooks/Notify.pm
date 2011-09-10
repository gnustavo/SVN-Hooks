package SVN::Hooks::Notify;

use strict;
use warnings;
use SVN::Hooks;

use Exporter qw/import/;
my $HOOK = 'NOTIFY';
our @EXPORT = qw/NOTIFY_DEFAULTS NOTIFY/;

our $VERSION = $SVN::Hooks::VERSION;

=head1 NAME

SVN::Hooks::Notify - Subversion activity notification.

=head1 SYNOPSIS

This SVN::Hooks plugin sends notification emails for Subversion
repository activity. It is actually a simple wrapper around the
SVN::Notify module.

It's active in the C<post-commit> hook.

It's configured by the following directives.

=head2 NOTIFY_DEFAULTS(%HASH)

This directive allows you to specify default arguments for the
SVN::Notify constructor.

	NOTIFY_DEFAULTS(
	    user_domain => 'cpqd.com.br',
	    sendmail    => '/usr/sbin/sendmail',
	    language    => 'pt_BR',
	);
	NOTIFY_DEFAULTS(smtp => 'smtp.cpqd.com.br');

Please, see the SVN::Notify documentation to know about all the
available options.

=cut

my %Defaults;

sub NOTIFY_DEFAULTS {
    %Defaults = @_;

    return 1;
}

=head2 NOTIFY(%HASH)

This directive merges the options received with the defaults obtained
from NOTIFY_DEFAULTS and passes the result to the SVN::Notify
constructor.

Note that neither the C<repos_path> nor the C<revision> options need
to be specified. They are grokked automatically.

	NOTIFY(
	    to        => 'commit-list@example.com',
            with_diff => 1,
	);

	NOTIFY(
	    to_email_map => {
                '^trunk/produtos|^branches' => 'commit-list@example.com',
                '^conf' => 'admin@example.com',
	    },
            subject_prefix => '[REPO] ',
            attach_diff  => 1,
	);

=cut

my %Options;

sub NOTIFY {
    %Options = @_;

    POST_COMMIT(\&post_commit);

    return 1;
};

sub post_commit {
    my ($svnlook) = @_;

    require SVN::Notify;

    my $notifier = SVN::Notify->new(
	%Defaults,
	%Options,
	repos_path => $svnlook->repo(),
	revision   => $svnlook->rev(),
    );
    $notifier->prepare;
    $notifier->execute;
    return;
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

Copyright 2008-2011 CPqD, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1; # End of SVN::Hooks::Notify
