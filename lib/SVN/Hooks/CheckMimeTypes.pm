package SVN::Hooks::CheckMimeTypes;

use strict;
use warnings;
use Carp;
use SVN::Hooks;

use Exporter qw/import/;
my $HOOK = 'CHECK_MIMETYPES';
our @EXPORT = ($HOOK);

our $VERSION = $SVN::Hooks::VERSION;

=head1 NAME

SVN::Hooks::CheckMimeTypes - Require the svn:mime-type property.

=head1 SYNOPSIS

This SVN::Hooks plugin checks if the files added to the repository
have the B<svn:mime-type> property set. Moreover, for text files, it
checks if the properties B<svn:eol-style> and B<svn:keywords> are also
set.

The plugin was based on the
L<check-mime-type.pl|http://svn.digium.com/view/repotools/check-mime-type.pl>
script.

It's active in the C<pre-commit> hook.

It's configured by the following directive.

=head2 CHECK_MIMETYPES([MESSAGE])

This directive enables the checking, causing the commit to abort if it
doesn't comply.

The MESSAGE argument is an optional help message shown to the user in
case the commit fails. Note that by default the plugin already inserts
a rather verbose help message in case of errors.

	CHECK_MIMETYPES("Use TortoiseSVN -> Properties menu option to set properties.");

=cut

sub CHECK_MIMETYPES {
    my ($help) = @_;
    my $conf = $SVN::Hooks::Confs->{$HOOK};
    $conf->{help} = $help;
    $conf->{'pre-commit'} = \&pre_commit;
    return 1;
}

$SVN::Hooks::Inits{$HOOK} = sub {
    return {};
};

sub pre_commit {
    my ($self, $svnlook) = @_;

    my @errors;

    foreach my $added ($svnlook->added()) {
	next if $added =~ m:/$:; # disregard directories
	my $props = $svnlook->proplist($added);
	unless (my $mimetype = $props->{'svn:mime-type'}) {
	    push @errors, "property svn:mime-type is not set for: $added";
	}
	elsif ($mimetype =~ m:^text/:) {
	    for my $prop ('svn:eol-style', 'svn:keywords') {
		push @errors, "property $prop is not set for text file: $added"
		    unless exists $props->{$prop};
	    }
	}
    }

    if (@errors) {
	my $message = "$HOOK:\n" . join("\n", @errors) . <<'EOS';

Every added file must have the svn:mime-type property set. In
addition, text files must have the svn:eol-style and svn:keywords
properties set.

For binary files try running
svn propset svn:mime-type application/octet-stream path/of/file

For text files try
svn propset svn:mime-type text/plain path/of/file
svn propset svn:eol-style native path/of/file
svn propset svn:keywords 'Author Date Id Revision' path/of/file

EOS
	if (my $help = $self->{help}) {
	    $message .= $help;
	}
	else {
	    $message .= <<"EOS";
You may want to consider uncommenting the auto-props section
in your ~/.subversion/config file. Read the Subversion book
(http://svnbook.red-bean.com/), Chapter 7, Properties section,
Automatic Property Setting subsection for more help.
EOS
	}
	croak $message;
    }
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

=head1 ACKNOWLEDGEMENTS

To the author of the C<check-mime-type.pl> script at
L<http://svn.digium.com/view/repotools/check-mime-type.pl>.

=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 CPqD, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of SVN::Hooks::CheckMimeTypes
