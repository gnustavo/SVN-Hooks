package SVN::Hooks::CheckLog;

use warnings;
use strict;
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

sub CHECK_LOG {
    my ($regexp, $error_message) = @_;

    defined $regexp and ref $regexp eq 'Regexp'
	or die "$HOOK: first argument must be a qr/Regexp/\n";
    not defined $error_message or ! ref $error_message
	or die "$HOOK: second argument must be undefined, or a STRING\n";

    my $conf = $SVN::Hooks::Confs->{$HOOK};
    push @{$conf->{checks}}, {
	regexp => $regexp,
	error  => $error_message,
    };
    $conf->{'pre-commit'} = \&pre_commit;

    1;
}

$SVN::Hooks::Inits{$HOOK} = sub {
    return { checks => [] };
};

sub pre_commit {
    my ($self, $svnlook) = @_;

    my $log = $svnlook->log_msg();

    foreach my $check (@{$self->{checks}}) {
	$log =~ $check->{regexp}
	    or die "$HOOK: ", $check->{error} || "log message must match $check->{regexp}.";
    }
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

Copyright 2008-2009 CPqD, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of SVN::Hooks::CheckLog
