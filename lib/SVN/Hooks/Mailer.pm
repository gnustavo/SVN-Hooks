package SVN::Hooks::Mailer;
# ABSTRACT: Send emails after successful commits.

use strict;
use warnings;

use Carp;
use SVN::Hooks;

use Exporter qw/import/;
my $HOOK = 'MAILER';
our @EXPORT = qw/EMAIL_CONFIG EMAIL_COMMIT/;

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

=cut

1; # End of SVN::Hooks::Mailer
