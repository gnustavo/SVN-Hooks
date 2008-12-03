package SVN::Hooks::DenyFilenames;

use warnings;
use strict;
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

It's configured by the following directives.

=head2 DENY_FILENAMES(REGEXP, ...)

This directive denies the addition of new files matching the Regexps
passed as arguments.

	DENY_FILENAMES(qr/\.(doc|xls|ppt)$/); # ODF only, please

=cut

sub DENY_FILENAMES {
    my @regexes = @_;
    foreach my $regex (@regexes) {
	ref $regex eq 'Regexp'
	    or die "$HOOK: got \"$regex\" while expecting a qr/Regex/.\n";
    }
    my $conf = $SVN::Hooks::Confs->{$HOOK};
    $conf->{checks} = \@regexes;
    $conf->{'pre-commit'} = \&pre_commit;
}

$SVN::Hooks::Inits{$HOOK} = sub {
    return { checks => [] };
};

sub pre_commit {
    my ($self, $svnlook) = @_;
    my @denied;
  ADDED:
    foreach my $added ($svnlook->added()) {
	foreach my $regex (@{$self->{checks}}) {
	    if ($added =~ $regex) {
		push @denied, $added;
		next ADDED;
	    }
	}
    }
    if (@denied) {
	die join("\n",
		 "$HOOK: the files below can't be added because their names aren't allowed:",
		 @denied), "\n";
    }
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

Copyright 2008 CPqD, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1; # End of SVN::Hooks::DenyFilenames
