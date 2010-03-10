package SVN::Hooks::DenyChanges;

use strict;
use warnings;
use Carp;
use SVN::Hooks;

use Exporter qw/import/;
my $HOOK = 'DENY_CHANGES';
my @HOOKS = ('DENY_ADDITION', 'DENY_DELETION', 'DENY_UPDATE', 'DENY_EXCEPT_USERS');
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

=head2 DENY_EXCEPT_USERS(LIST)

This directive receives a list of user names which are to be exempt
from the rules specified by the other directives.

	DENY_EXCEPT_USERS(qw/john mary/);

This rule exempts users C<john> and C<mary> from the other deny rules.

=cut

sub _deny_change {
    my ($change, @regexes) = @_;

    foreach (@regexes) {
	ref $_ eq 'Regexp'
	    or croak "$HOOK: all arguments must be qr/Regexp/\n";
    }

    my $conf = $SVN::Hooks::Confs->{$HOOK};
    push @{$conf->{$change}}, @regexes;
    $conf->{'pre-commit'} = \&pre_commit;

    return 1;
}

sub DENY_ADDITION {
    my @args = @_;
    return _deny_change(add    => @args);
}

sub DENY_DELETION {
    my @args = @_;
    return _deny_change(delete => @args);
}

sub DENY_UPDATE {
    my @args = @_;
    return _deny_change(update => @args);
}

sub DENY_EXCEPT_USERS {
    my @users = @_;
    my $conf = $SVN::Hooks::Confs->{$HOOK};
    foreach my $user (@users) {
	croak "DENY_EXCEPT_USERS: all arguments must be strings\n"
	    if ref $user;
	$conf->{except}{$user} = undef;
    }

    return 1;
}

$SVN::Hooks::Inits{$HOOK} = sub {
    return {
	add    => [],
	delete => [],
	update => [],
	except => {},
    };
};

sub pre_commit {
    my ($self, $svnlook) = @_;

    # Except users
    return if %{$self->{except}} && exists $self->{except}{$svnlook->author()};

    my @errors;

    foreach my $regex (@{$self->{add}}) {
      ADDED:
	foreach my $file ($svnlook->added()) {
	    if ($file =~ $regex) {
		push @errors, " Cannot add: $file";
		next ADDED;
	    }
	}
    }

    foreach my $regex (@{$self->{delete}}) {
      DELETED:
	foreach my $file ($svnlook->deleted()) {
	    if ($file =~ $regex) {
		push @errors, " Cannot delete: $file";
		next DELETED;
	    }
	}
    }

    foreach my $regex (@{$self->{update}}) {
      UPDATED:
	foreach my $file ($svnlook->updated()) {
	    if ($file =~ $regex) {
		push @errors, " Cannot update: $file";
		next UPDATED;
	    }
	}
    }

    croak "$HOOK:\n", join("\n", @errors), "\n"
	if @errors;

    return;
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
