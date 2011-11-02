package SVN::Hooks::Mailer;

use strict;
use warnings;
use Carp;
use SVN::Hooks;

use Exporter qw/import/;
my $HOOK = 'MAILER';
our @EXPORT = qw/EMAIL_CONFIG EMAIL_COMMIT/;

our $VERSION = $SVN::Hooks::VERSION;

=head1 NAME

SVN::Hooks::Mailer - Send emails after successful commits.

=head1 SYNOPSIS

This SVN::Hooks plugin is deprecated. You should use
SVN::Hooks::Notify instead.

=cut

sub _deprecated {
    croak <<"EOS";
DEPRECATED: The SVN::Hooks::Mailer plugin was deprecated in 2008 and
became nonoperational in version 1.08. You must edit your hook
configuration to remove the directives EMAIL_CONFIG and
EMAIL_COMMIT. You may use the new SVN::Hooks::Notify plugin for
sending email notifications.
EOS
}

=over

=item EMAIL_CONFIG

=cut

sub EMAIL_CONFIG {
    _deprecated();
}

=item EMAIL_COMMIT

=cut

sub EMAIL_COMMIT {
    _deprecated();
}

=back

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

1; # End of SVN::Hooks::Mailer
