package SVN::Hooks::CheckCapability;

use strict;
use warnings;
use Carp;
use SVN::Hooks;

use Exporter qw/import/;
my $HOOK = 'CHECK_CAPABILITY';
our @EXPORT = ($HOOK);

our $VERSION = $SVN::Hooks::VERSION;

=head1 NAME

SVN::Hooks::CheckCapability - Check the svn client capabilities.

=head1 SYNOPSIS

This SVN::Hooks plugin checks if the Subversion client implements the
required capabilities.

It's active in the C<start-commit> hook.

It's configured by the following directive.

=head2 CHECK_CAPABILITY(CAPABILITY...)

This directive enables the checking, causing the commit to abort if it
doesn't comply.

The arguments are a list of capability names. Every capability
specified must be supported by the client in order to the hook to
succeed.

Example:

	CHECK_CAPABILITY('mergeinfo');

=cut

sub CHECK_CAPABILITY {
    my @capabilities = @_;

    my $conf = $SVN::Hooks::Confs->{$HOOK};
    $conf->{capabilities} = \@capabilities;
    $conf->{'start-commit'} = \&start_commit;
    return 1;
}

$SVN::Hooks::Inits{$HOOK} = sub {
    return { capabilities => [] };
};

sub start_commit {
    my ($self, $user, $capabilities) = @_;

    $capabilities ||= ''; # pre 1.5 svn clients don't pass the capabilities

    # Create a hash to facilitate the checks
    my %supported;
    @supported{split /:/, $capabilities} = undef;

    # Grok which required capabilities are missing
    my @missing = grep {! exists $supported{$_}} @{$self->{capabilities}};

    if (@missing) {
	croak "$HOOK: Your subversion client does not support the following capabilities:\n\n\t",
	    join(', ', @missing),
	    "\n\nPlease, consider upgrading to a newer version of your client.\n";
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

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1; # End of SVN::Hooks::CheckCapability
