package SVN::Hooks::DenyChanges;

use warnings;
use strict;
use SVN::Hooks;

use Exporter qw/import/;
my $HOOK = 'DENY_CHANGES';
my @HOOKS = ('DENY_ADDITION', 'DENY_DELETION', 'DENY_UPDATE');
our @EXPORT = @HOOKS;

our $VERSION = $SVN::Hooks::VERSION;

=head1 NAME

SVN::Hooks::DenyChanges - Deny some changes in a repository.

=head1 SYNOPSIS

This SVN::Hooks plugin is used to disallow the addition, deletion, or
modification of parts of the repository structure.

It's active in the C<pre-commit> hook.

It's configured by the following directives.

=head2 DENY_ADDITION(REGEXP, ...)

This directive denies the addition of new files matching the Regexps
passed as arguments.

	DENY_ADDITION(qr/\.(doc|xls|ppt)$/); # ODF only, please

=head2 DENY_DELETION(REGEXP, ...)

This directive denies the deletion of files matching the Regexps
passed as arguments.

	DENY_DELETION(qr/contract/); # Can't delete contracts

=head2 DENY_UPDATE(REGEXP, ...)

This directive denies the modification of files matching the Regexps
passed as arguments.

	DENY_UPDATE(qr/^tags/); # Can't modify tags

=cut

sub _deny_change {
    my ($change, @regexes) = @_;

    foreach (@regexes) {
	ref $_ eq 'Regexp'
	    or die "$HOOK: all arguments must be qr/Regexp/\n";
    }

    my $conf = $SVN::Hooks::Confs->{$HOOK};
    push @{$conf->{$change}}, @regexes;
    $conf->{'pre-commit'} = \&pre_commit;
}

sub DENY_ADDITION {
    _deny_change(deny_add    => @_);
}

sub DENY_DELETION {
    _deny_change(deny_delete => @_);
}

sub DENY_UPDATE {
    _deny_change(deny_update => @_);
}

$SVN::Hooks::Inits{$HOOK} = sub {
    return {
	deny_add    => [],
	deny_delete => [],
	deny_update => [],
    };
};

sub pre_commit {
    my ($self, $svnlook) = @_;

    my @errors;

    foreach my $regex (@{$self->{deny_add}}) {
      ADDED:
	foreach my $file ($svnlook->added()) {
	    if ($file =~ $regex) {
		push @errors, " Cannot add: $file";
		next ADDED;
	    }
	}
    }

    foreach my $regex (@{$self->{deny_delete}}) {
      DELETED:
	foreach my $file ($svnlook->deleted()) {
	    if ($file =~ $regex) {
		push @errors, " Cannot delete: $file";
		next DELETED;
	    }
	}
    }

    foreach my $regex (@{$self->{deny_update}}) {
      UPDATED:
	foreach my $file ($svnlook->updated()) {
	    if ($file =~ $regex) {
		push @errors, " Cannot update: $file";
		next UPDATED;
	    }
	}
    }

    die "$HOOK:\n", join("\n", @errors), "\n"
	if @errors;
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

Copyright 2008-2009 CPqD, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1; # End of SVN::Hooks::CheckMimeTypes
