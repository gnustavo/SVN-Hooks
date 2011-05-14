package SVN::Hooks::Generic;

use strict;
use warnings;
use Carp;
use SVN::Hooks;

use Exporter qw/import/;
my $HOOK = 'GENERIC';
our @EXPORT = ($HOOK);

our $VERSION = $SVN::Hooks::VERSION;

=head1 NAME

SVN::Hooks::Generic - Implement generic checks for all Subversion hooks.

=head1 SYNOPSIS

This SVN::Hooks plugin allows you to easily write generic checks for
all Subversion standard hooks. It's deprecated. You should use the
SVN::Hooks hook defining exported directives instead.

This module is configured by the following directive.

=head2 GENERIC(HOOK => FUNCTION, HOOK => [FUNCTIONS], ...)

This directive associates FUNCTION with a specific HOOK. You can make
more than one association with a single directive call, or you can use
multiple calls to make multiple associations. Moreover, you can
associate a hook with a single function or with a list of functions
(passing them as elements of an array). All functions associated with
a hook will be called in an unspecified order with the same arguments.

Each hook must be associated with functions with a specific signature,
i.e., the arguments that are passed to the function depends on the
hook to which it is associated.

The hooks are specified by their standard names.

The function signatures are the following:

=over

=item post-commit(SVN::Look)

=item post-lock(repos-path, username)

=item post-revprop-change(SVN::Look, username, property-name, action)

=item post-unlock(repos-path, username)

=item pre-commit(SVN::Look)

=item pre-lock(repos-path, path, username, comment, steal-lock-flag)

=item pre-revprop-change(SVN::Look, username, property-name, action)

=item pre-unlock(repos-path, path, username, lock-token, break-unlock-flag)

=item start-commit(repos-path, username, capabilities)

=back

The functions may perform whatever checks they want. If the checks
succeed the function must simply return. Otherwise, they must die with
a suitable error message, which will be sent back to the user
performing the Subversion action which triggered the hook.

The sketch below shows how this directive could be used.

	sub my_start_commit {
	    my ($repo_path, $username, $capabilities) = @_;
	    # ...
	}

	sub my_pre_commit {
	    my ($svnlook) = @_;
	    # ...
	}

	GENERIC(
	    'start-commit' => \&my_start_commit,
	    'pre-commit'   => \&my_pre_commit,
	);

=cut

sub GENERIC {
    my (@args) = @_;

    (@args % 2) == 0
	or croak "$HOOK: odd number of arguments.\n";

    my %args = @args;

    while (my ($hook, $functions) = each %args) {
	$hook =~ /(?:(?:pre|post)-(?:commit|lock|revprop-change|unlock)|start-commit)/
	    or die "$HOOK: invalid hook name ($hook)";
	if (! ref $functions) {
	    die "$HOOK: hook '$hook' should be mapped to a reference.\n";
	} elsif (ref $functions eq 'CODE') {
	    $functions = [$functions];
	} elsif (ref $functions ne 'ARRAY') {
	    die "$HOOK: hook '$hook' should be mapped to a CODE-ref or to an ARRAY of CODE-refs.\n";
	}
	foreach my $foo (@$functions) {
	    ref $foo and ref $foo eq 'CODE'
		or die "$HOOK: hook '$hook' should be mapped to CODE-refs.\n";
	    $SVN::Hooks::Hooks{$hook}{$foo} ||= sub { $foo->(@_); };
	}
    }

    return 1;
}

=head1 AUTHOR

Gustavo Chaves, C<< <gnustavo@cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-svn-hooks-updaterepofile at rt.cpan.org>, or through the web
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

1; # End of SVN::Hooks::Generic
