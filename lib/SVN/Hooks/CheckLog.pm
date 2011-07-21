package SVN::Hooks::CheckLog;

use strict;
use warnings;
use Carp;
use SVN::Hooks;

use Exporter qw/import/;
my $HOOK = 'CHECK_LOG';
our @EXPORT = ($HOOK);

our $VERSION = $SVN::Hooks::VERSION;

=head1 NAME

SVN::Hooks::CheckLog - Check log messages in commits.

=head1 SYNOPSIS

This SVN::Hooks plugin allows one to check if the log message in a
'svn commit' conforms to a Regexp.

It's active in the C<pre-commit> hook.

It's configured by the following directive.

=head2 CHECK_LOG(REGEXP[, MESSAGE])

The REGEXP argument must be a qr/quoted regexp/ which must match the
commit log messages. If it doesn't, then the commit is aborted.

The MESSAGE argument is an optional error message that is shown to the
user in case the check fails.

	CHECK_LOG(qr/.../ => "The log message cannot be empty!");
	CHECK_LOG(qr/^\[(prj1|prj2|prj3)\]/
                  => "The log message must start with a project tag.");

=cut

my @checks;

sub CHECK_LOG {
    my ($regexp, $error_message) = @_;

    defined $regexp and ref $regexp eq 'Regexp'
	or croak "$HOOK: first argument must be a qr/Regexp/\n";
    not defined $error_message or not ref $error_message
	or croak "$HOOK: second argument must be undefined, or a STRING\n";

    push @checks, {
	regexp => $regexp,
	error  => $error_message || "log message must match $regexp.",
    };

    PRE_COMMIT(\&pre_commit);

    return 1;
}

sub pre_commit {
    my ($svnlook) = @_;

    my $log = $svnlook->log_msg();

    foreach my $check (@checks) {
	$log =~ $check->{regexp}
	    or croak "$HOOK: $check->{error}";
    }

    return;
}

=head1 AUTHOR

Gustavo Chaves, C<< <gnustavo@cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-svn-hooks-checkproperty at rt.cpan.org>, or through the web
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

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of SVN::Hooks::CheckLog
