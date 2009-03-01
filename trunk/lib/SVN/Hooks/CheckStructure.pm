package SVN::Hooks::CheckStructure;

use warnings;
use strict;
use SVN::Hooks;

use Exporter qw/import/;
my $HOOK = 'CHECK_STRUCTURE';
our @EXPORT = ($HOOK);

our $VERSION = $SVN::Hooks::VERSION;

=head1 NAME

SVN::Hooks::CheckStructure - Check the structure of a repository.

=head1 SYNOPSIS

This SVN::Hooks plugin checks if the files and directories added to
the repository are allowed by its structure definition. If they don't,
the commit is aborted.

It's active in the C<pre-commit> hook.

It's configured by the following directive.

=head2 CHECK_STRUCTURE(STRUCT_DEF)

This directive enables the checking, causing the commit to abort if it
doesn't comply.

The STRUCT_DEF argument specify the repository strucure with a
recursive data structure consisting of one of:

=over

=item ARRAY REF

An array ref specifies the contents of a directory. The referenced
array must contain a pair number of elements. Each pair consists of a
NAME_DEF and a STRUCT_DEF. The NAME_DEF specifies the name of the
component contained in the directory and the STRUCT_DEF specifies
recursively what it must be.

The NAME_DEF specifies a name in one of these ways:

=over

=item STRING

A string specifies a name directly.

=item REGEXP

A regexp specifies the class of names that match it.

=item NUMBER

A number may be used as an else-clause. A positive number means that
any name not yet matched by the previous pair must conform to the
associated STRUCT_DEF.

A negative number means that no name will do and signals an error. In
this case, if the STRUCT_DEF is a string it is used as a help message
shown to the user.

=back

If no NAME_DEF matches the component being looked for, then it is a
structure violation and the commit fails.

=item STRING

A string must be one of 'FILE' and 'DIR', specifying what the current
component must be.

=item NUMBER

A positive number simply tells that whatever the current component is
is ok and finishes the check succesfully.

A negative number tells that whatever the current component is is a
structure violation and aborts the commit.

=back

Now that we have this semi-formal definition off the way, let's try to
understand it with some examples.

	my $tag_rx    = qr/^[a-z]+-\d+\.\d+$/; # e.g. project-1.0
	my $branch_rx = qr/^[a-z]+-/;	# must start with letters and hifen
	my $project_struct = [
	    'META.yml'    => 'FILE',
	    'Makefile.PL' => 'FILE',
	    ChangeLog     => 'FILE',
	    LICENSE       => 'FILE',
	    MANIFEST      => 'FILE',
	    README        => 'FILE',
	    t => [
		qr/\.t$/  => 'FILE',
	    ],
	    lib => 'DIR',
	];

	CHECK_STRUCTURE(
	    [
		trunk => $project_struct,
		branches => [
		    $branch_rx => $project_rx,
		],
		tags => [
		    $tag_rx => $project_rx,
		],
	    ],
	);

The structure's first level consists of the three usual directories:
C<trunk>, C<tags>, and C<branches>. Anything else in this level is
denied.

Below the C<trunk> we allow some usual files and two directories only:
C<lib> and C<t>. Below C<trunk/t> we may allow only test files with
the C<.t> extension and below C<lib> we allow anything.

We require that each branch and tag have the same structure as the
C<trunk>, which is made easier by the use of the C<$project_struct>
variable. Moreover, we impose some restrictions on the names of the
tags and the branches.

=cut

sub CHECK_STRUCTURE {
    my ($structure) = @_;
    my $conf = $SVN::Hooks::Confs->{$HOOK};
    $conf->{structure} = $structure;
    $conf->{'pre-commit'} = \&pre_commit;
}

$SVN::Hooks::Inits{$HOOK} = sub {
    return {};
};

sub _check_structure {
    my ($structure, $path) = @_;

    my $component = shift @$path;

    if (! defined $structure) {
	return (1);
    }
    elsif (! ref $structure) {
	if ($structure eq 'DIR') {
	    if (defined $component) {
		return (1);
	    }
	    else {
		return (0, "a FILE should be a DIRECTORY in");
	    }
	}
	elsif ($structure eq 'FILE') {
	    if (defined $component) {
		return (0, "a DIRECTORY should be a FILE in");
	    }
	    else {
		return (1);
	    }
	}
	elsif ($structure =~ /^\d+$/) {
	    if ($structure) {
		return (1);
	    }
	    else {
		return (0, "invalid path");
	    }
	}
	else {
	    return (0, "syntax error: unknown string spec ($structure), while checking");
	}
    }
    elsif (ref $structure eq 'ARRAY') {
	if (scalar(@$path) == 0 && $component eq '') {
	    return (1);
	}
	if (scalar(@$structure) % 2 != 0) {
	    return (0, "syntax error: odd number of elements in the structure spec, while checking")
	}
	for (my $s=0; $s<$#$structure; $s+=2) {
	    my ($lhs, $rhs) = @{$structure}[$s, $s+1];
	    if (! ref $lhs) {
		if ($lhs eq $component) {
		    return _check_structure($rhs, $path);
		}
		elsif ($lhs =~ /^\d+$/) {
		    if ($lhs) {
			return _check_structure($rhs, $path);
		    }
		    elsif (! ref $rhs) {
			return (0, "$rhs, while checking");
		    }
		    else {
			return (0, "syntax error: the right hand side of a number must be string, while checking");
		    }
		}
	    }
	    elsif (ref $lhs eq 'Regexp') {
		if ($component =~ $lhs) {
		    return _check_structure($rhs, $path);
		}
	    }
	    else {
		my $what = ref $lhs;
		return (0, "syntax error: the left hand side of arrays in the structure spec must be scalars or qr/Regexes/, not $what, while checking");
	    }
	}
	return (0, "the component ($component) is not allowed in");
    }
    else {
	my $what = ref $structure;
	return (0, "syntax error: invalid reference to a $what in the structure spec, while checking");
    }
}

sub pre_commit {
    my ($self, $svnlook) = @_;

    my @errors;

    foreach my $added ($svnlook->added()) {
	my @added = split '/', $added, -1; # preserve trailing empty components
	my ($code, $error) = _check_structure($self->{structure}, \@added);
	push @errors, "$error: $added" if $code == 0;
    }

    if (@errors) {
	die join("\n", "$HOOK:", @errors), "\n";
    }
}

=head1 AUTHOR

Gustavo Chaves, C<< <gnustavo@cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-svn-hooks-checkstructure at rt.cpan.org>, or through the web
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

1; # End of SVN::Hooks::CheckStructure
