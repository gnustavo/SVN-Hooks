package SVN::Hooks::DenyFilenames;

use strict;
use warnings;
use Carp;
use SVN::Hooks;

use Exporter qw/import/;
my $HOOK = 'DENY_FILENAMES';
our @EXPORT = ($HOOK);

our $VERSION = $SVN::Hooks::VERSION;

=head1 NAME

SVN::Hooks::DenyFilenames - Deny some file names.

=head1 SYNOPSIS

This SVN::Hooks plugin is used to disallow the addition of some file
names.

It's active in the C<pre-commit> hook.

It's configured by the following directive.

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

Example:

        DENY_FILENAMES(
            qr/\.(doc|xls|ppt)$/i, # ODF only, please
            [qr/\.(exe|zip|jar)/i => 'No binaries, please!'],
        );

=cut

my @Checks;

sub DENY_FILENAMES {

    foreach my $check (@_) {
	if (ref $check eq 'Regexp') {
	    push @Checks, [$check => 'filename not allowed'];
	} elsif (ref $check eq 'ARRAY') {
	    @$check == 2
		or croak "$HOOK: array arguments must have two arguments.\n";
	    ref $check->[0] eq 'Regexp'
		or croak "$HOOK: got \"$check->[0]\" while expecting a qr/Regex/.\n";
	    ! ref $check->[1]
		or croak "$HOOK: got \"$check->[1]\" while expecting a string.\n";
	    push @Checks, $check;
	} else {
	    croak "$HOOK: got \"$check\" while expecting a qr/Regex/ or a [qr/Regex/, 'message'].\n";
	}
    }

    PRE_COMMIT(\&pre_commit);

    return 1;
}

sub pre_commit {
    my ($svnlook) = @_;
    my $errors;
  ADDED:
    foreach my $added ($svnlook->added()) {
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

Copyright 2008-2009 CPqD, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1; # End of SVN::Hooks::DenyFilenames
