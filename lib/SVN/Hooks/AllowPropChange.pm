package SVN::Hooks::AllowPropChange;

use strict;
use warnings;
use Carp;
use SVN::Hooks;

use Exporter qw/import/;
my $HOOK = 'ALLOW_PROP_CHANGE';
our @EXPORT = ($HOOK);

our $VERSION = $SVN::Hooks::VERSION;

=head1 NAME

SVN::Hooks::AllowPropChange - Allow changes in revision properties.

=head1 SYNOPSIS

This SVN::Hooks plugin is used to allow revision (or non-versioned)
properties (C<svn:author>, C<svn:date>, and C<svn:log>) to be changed
by a group of users.

It's active in the C<pre-revprop-change> hook.

It's configured by the following directive.

=head2 ALLOW_PROP_CHANGE(PROP => WHO, ...)

This directive enables the change of revision properties.

By default any change is denied unless explicitly allowed by the
directive. You can use the directive more than once.

The PROP argument specifies the propertie(s) that are to be configured
depending on its type. If no argument is given, no user can change any
property.

=over

=item STRING

Specify a single property by name (C<author>, C<date>, or C<log>).

=item REGEXP

Specify all properties that match the Regexp.

=back

The optional WHO arguments specify the users that are allowed to make
those changes. If absent, no user can change a log message. Otherwise,
it specifies the allowed users depending on its type.

=over

=item STRING

Specify a single user by name.

=item REGEXP

Specify the class of users whose names are matched by the Regexp.

=back

	ALLOW_PROP_CHANGE('svn:log' => 'jsilva'); # jsilva can change svn:log
	ALLOW_PROP_CHANGE(qr/./ => qr/silva$/); # any *silva can change any property

=cut

my @Specs;

sub ALLOW_PROP_CHANGE {
    my @args = @_;

    my @whos;

    foreach my $arg (@args) {
	if (not ref $arg or ref $arg eq 'Regexp') {
	    push @whos, $arg;
	}
	else {
	    croak "$HOOK: invalid argument '$arg'\n";
	}
    }

    @whos != 0
	or croak "$HOOK: you must specify at least the first argument\n";

    my $prop = shift @whos;
    push @Specs, [$prop => \@whos];

    PRE_REVPROP_CHANGE(\&pre_revprop_change);

    return 1;
}

sub pre_revprop_change {
    my ($svnlook, $rev, $author, $propname, $action) = @_;

    $propname =~ /^svn:(?:author|date|log)$/
	or croak "$HOOK: the revision property $propname cannot be changed.\n";

    $action eq 'M'
	or croak "$HOOK: revision properties can only be modified, not added or deleted.\n";

    foreach my $spec (@Specs) {
	my ($prop, $whos) = @$spec;
	if (! ref $prop) {
	    next if $propname ne $prop;
	}
	else {
	    next if $propname !~ $prop;
	}
	for my $who (@$whos) {
	    if (! ref $who) {
		return if $author eq $who;
	    }
	    else {
		return if $author =~ $who;
	    }
	}
    }

    croak "$HOOK: you are not allowed to change property $propname.\n";
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

Copyright 2009 CPqD, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1; # End of SVN::Hooks::AllowPropChange
