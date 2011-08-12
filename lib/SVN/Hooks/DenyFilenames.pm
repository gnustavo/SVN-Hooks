package SVN::Hooks::DenyFilenames;

use strict;
use warnings;
use Carp;
use SVN::Hooks;

use Exporter qw/import/;
my $HOOK = 'DENY_FILENAMES';
our @EXPORT = ($HOOK, 'DENY_FILENAMES_PER_PATH');

our $VERSION = $SVN::Hooks::VERSION;

=head1 NAME

SVN::Hooks::DenyFilenames - Deny some file names.

=head1 SYNOPSIS

This SVN::Hooks plugin is used to disallow the addition of some file
names.

It's active in the C<pre-commit> hook.

It's configured by the following directives.

=head2 DENY_FILENAMES(REGEXP, [REGEXP => MESSAGE], ...)

This directive denies the addition of new files matching the Regexps
passed as arguments. If any file or directory added in the commit
matches one of the specified Regexps the commit is aborted with an
error message telling about every denied file.

The arguments may be compiled Regexps or two-element arrays consisting
of a compiled Regexp and a specific error message. If a file matches
one of the lone Regexps an error message like this is produced:

        DENY_FILENAMES: filename not allowed: filename

If a file matches a Regexp associated with an error message, the
specified error message is substituted for the 'filename not allowed'
default.

Note that this directive specifies a default restriction. If there are
any B<DENY_FILENAMES_PER_PATH> directives (see below) being used, this
one is only used for files that don't match any specific rules there.

Example:

        DENY_FILENAMES(
            qr/\.(doc|xls|ppt)$/i, # ODF only, please
            [qr/\.(exe|zip|jar)/i => 'No binaries, please!'],
        );

=cut

sub _grok_check {
    my ($directive, $check) = @_;
    if (ref $check eq 'Regexp') {
	return [$check => 'filename not allowed'];
    } elsif (ref $check eq 'ARRAY') {
	@$check == 2
	    or croak "$directive: array arguments must have two arguments.\n";
	ref $check->[0] eq 'Regexp'
	    or croak "$directive: got \"$check->[0]\" while expecting a qr/Regex/.\n";
	! ref $check->[1]
	    or croak "$directive: got \"$check->[1]\" while expecting a string.\n";
	return $check;
    } else {
	croak "$directive: got \"$check\" while expecting a qr/Regex/ or a [qr/Regex/, 'message'].\n";
    }
}

my @Checks;			# default restrictions

sub DENY_FILENAMES {
    foreach my $check (@_) {
	push @Checks, _grok_check('DENY_FILENAMES', $check);
    }

    PRE_COMMIT(\&pre_commit);

    return 1;
}

=head2 DENY_FILENAMES_PER_PATH(REGEXP => REGEXP, REGEXP => [REGEXP => MESSAGE], ...)

This directive is more specific than the B<DENY_FILENAMES>, because it
allows one to specify different restrictions in different regions of
the repository tree.

Its arguments are a sequence of rules, each one consisting of a
pair. The first element of each pair is a regular expression
specifying where in the repository this rule applies. It applies if
any file being added matches the regexp. The second element specifies
the restrictions that should be imposed, just like the arguments to
B<DENY_FILENAMES>.

The first rule matching an added file is used to check it. The
following rules aren't tried.

Only if no rules match a particular file will the restrictions defined
by B<DENY_FILENAMES> be imposed.

Example:

        DENY_FILENAMES_PER_PATH(
            qr:/src/:   => [qr/[^\w.-]/ => 'source files must be strict'],
            qr:/doc/:   => qr/[^\w\s.-]/i, # document files allow spaces too.
            qr:/notes/: => qr/^$/,         # notes directory allows anything.
        );

=cut

my @Per_path_checks;		# per path restrictions

sub DENY_FILENAMES_PER_PATH {

    my (@rules) = @_;

    @rules % 2 == 0
	or croak "DENY_FILENAMES_PER_PATH: got odd number of arguments.\n";

    while (@rules) {
	my ($match, $check) = splice @rules, 0, 2;
	ref $match && ref $match eq 'Regexp'
	    or croak "DENY_FILENAMES_PER_PATH: rule prefix isn't a Regexp.\n";

	push @Per_path_checks, [$match => _grok_check('DENY_FILENAMES_PER_PATH', $check)];
    }

    PRE_COMMIT(\&pre_commit);

    return 1;
}

sub pre_commit {
    my ($svnlook) = @_;
    my $errors;
  ADDED:
    foreach my $added ($svnlook->added()) {
	foreach my $rule (@Per_path_checks) {
	    if ($added =~ $rule->[0]) {
		$errors .= "$HOOK: $rule->[1][1]: $added\n"
		    if $added =~ $rule->[1][0];
		next ADDED;
	    }
	}
	foreach my $check (@Checks) {
	    if ($added =~ $check->[0]) {
		$errors .= "$HOOK: $check->[1]: $added\n";
		next ADDED;
	    }
	}
    }

    croak $errors if $errors;
}

=head1 AUTHOR

Gustavo Chaves, C<< <gnustavo@cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-svn-hooks-denyfilenames at rt.cpan.org>, or through the web
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

1; # End of SVN::Hooks::DenyFilenames
