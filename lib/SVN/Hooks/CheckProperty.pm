package SVN::Hooks::CheckProperty;

use strict;
use warnings;
use Carp;
use SVN::Hooks;

use Exporter qw/import/;
my $HOOK = 'CHECK_PROPERTY';
our @EXPORT = ($HOOK);

our $VERSION = $SVN::Hooks::VERSION;

=head1 NAME

SVN::Hooks::CheckProperty - Check properties in added files.

=head1 SYNOPSIS

This SVN::Hooks plugin checks if some files added to the repository
have some properties set.

It's active in the C<pre-commit> hook.

It's configured by the following directive.

=head2 CHECK_PROPERTY(WHERE, PROPERTY[, VALUE])

This directive enables the checking, causing the commit to abort if it
doesn't comply.

The WHERE argument must be a qr/Regexp/ matching all files that must
comply to this rule.

The PROPERTY argument is the name of the property that must be set for
the files matching WHERE.

The optional VALUE argument specifies the value for PROPERTY depending
on its type:

=over

=item UNDEF or not present

The PROPERTY must be set.

=item NUMBER

If non-zero, the PROPERTY must be set. If zero, the PROPERTY must NOT be set.

=item STRING

The PROPERTY must be set with a value equal to the string.

=item qr/Regexp/

The PROPERTY must be set with a value that matches the Regexp.

=back

Example:

	CHECK_PROPERTY(qr/\.(?:do[ct]|od[bcfgimpst]|ot[ghpst]|pp[st]|xl[bst])$/i
	       => 'svn:needs-lock');

=cut

my @Checks;

sub CHECK_PROPERTY {
    my ($where, $prop, $what) = @_;

    defined $where and (not ref $where or ref $where eq 'Regexp')
	or croak "$HOOK: first argument must be a STRING or a qr/Regexp/\n";
    defined $prop and not ref $prop
	or croak "$HOOK: second argument must be a STRING\n";
    not defined $what or not ref $what or ref $what eq 'Regexp'
	or croak "$HOOK: third argument must be undefined, or a NUMBER, or a STRING, or a qr/Regexp/\n";

    push @Checks, [$where, $prop => $what];
    $SVN::Hooks::Confs{$HOOK}->{'pre-commit'} = \&pre_commit;

    return 1;
}

sub pre_commit {
    my ($self, $svnlook) = @_;

    my @errors;

    foreach my $added ($svnlook->added()) {
	foreach my $check (@Checks) {
	    my ($where, $prop, $what) = @$check;
	    if (ref $where eq 'Regexp' and $added =~ $where or
		    $where eq substr($added, 0, length $where)) {
		my $props = $svnlook->proplist($added);
		my $is_set = exists $props->{$prop};
		if (! defined $what) {
		    $is_set or push @errors, "property $prop must be set for: $added";
		}
		elsif (! ref $what) {
		    if ($what =~ /^\d+$/) {
			if ($what) {
			    $is_set or push @errors, "property $prop must be set for: $added";
			}
			else {
			    $is_set and push @errors, "property $prop must not be set for: $added";
			}
		    }
		    elsif (! $is_set) {
			push @errors, "property $prop must be set to \"$what\" for: $added";
		    }
		    elsif ($props->{$prop} ne $what) {
			push @errors, "property $prop must be set to \"$what\" and not to \"$props->{$prop}\" for: $added";
		    }
		}
		elsif (! $is_set) {
		    push @errors, "property $prop must be set and match \"$what\" for: $added";
		}
		elsif ($props->{$prop} !~ $what) {
		    push @errors, "property $prop must match \"$what\" but is \"$props->{$prop}\" for: $added";
		}
	    }
	}
    }

    croak join("\n", "$HOOK:", @errors), "\n"
	if @errors;

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

Copyright 2008-2009 CPqD, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1; # End of SVN::Hooks::CheckProperty
