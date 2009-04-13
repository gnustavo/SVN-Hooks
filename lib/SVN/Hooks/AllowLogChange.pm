package SVN::Hooks::AllowLogChange;

use warnings;
use strict;
use SVN::Hooks;

use Exporter qw/import/;
my $HOOK = 'ALLOW_LOG_CHANGE';
our @EXPORT = ($HOOK);

our $VERSION = $SVN::Hooks::VERSION;

=head1 NAME

SVN::Hooks::AllowLogChange - Allow changes in revision log messages.

=head1 SYNOPSIS

This SVN::Hooks plugin is used to allow revision log changes by some
users.

It's deprecated. You should use SVN::Hooks::AllowPropChange instead.

It's active in the C<pre-revprop-change> hook.

It's configured by the following directive.

=head2 ALLOW_LOG_CHANGE(WHO, ...)

This directive enables the change of revision log messages, which are
mantained in the C<svn:log> revision property.

The optional WHO argument specifies the users that are allowed to make
those changes. If absent, any user can change a log
message. Otherwise, it specifies the allowed users depending on its
type.

=over

=item STRING

Specify a single user by name.

=item REGEXP

Specify the class of users whose names are matched by the
Regexp.

=back

	ALLOW_LOG_CHANGE();
	ALLOW_LOG_CHANGE('jsilva');
	ALLOW_LOG_CHANGE(qr/silva$/);

=cut

sub ALLOW_LOG_CHANGE {
    my $conf = $SVN::Hooks::Confs->{$HOOK};

    foreach my $who (@_) {
	if (! ref $who or ref $who eq 'Regexp') {
	    push @{$conf->{users}}, $who;
	}
	else {
	    die "$HOOK: invalid argument '$who'\n";
	}
    }

    $conf->{'pre-revprop-change'} = \&pre_revprop_change;
}

$SVN::Hooks::Inits{$HOOK} = sub {
    return { users => [] };
};

sub pre_revprop_change {
    my ($self, $rev, $author, $propname, $action) = @_;

    $propname eq 'svn:log'
	or die "$HOOK: the revision property $propname cannot be changed.\n";

    $action eq 'M'
	or die "$HOOK: a revision log can only be modified, not added or deleted.\n";

    # If no users are specified, anyone can do it.
    return unless @{$self->{users}};

    for my $user (@{$self->{users}}) {
	return if ! ref $user and $author eq $user or $author =~ $user;
    }

    die "$HOOK: you are not allowed to change a revision log.\n";

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

Copyright 2008 CPqD, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1; # End of SVN::Hooks::AllowLogChange
