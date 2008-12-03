package SVN::Hooks::UpdateConfFile;

use warnings;
use strict;
use SVN::Hooks;
use File::Temp qw/tempdir/;
use Memoize;

use Exporter qw/import/;
my $HOOK = 'UPDATE_CONF_FILE';
our @EXPORT = ($HOOK);

our $VERSION = $SVN::Hooks::VERSION;

=head1 NAME

SVN::Hooks::UpdateConfFile - Maintain the repository configuration versioned.

=head1 SYNOPSIS

This SVN::Hooks plugin allows you to maintain the repository
configuration files under version control.

The repository configuration is usually kept in the directory C<conf>
under the directory where the repository was created. In a brand new
repository you see there the files C<authz>, C<passwd>, and
C<svnserve.conf>. It's too bad that these important files are usually
kept out of any version control system. This plugin tries to solve
this problem allowing you to keep these files versioned under the same
repository where they are used.

It's active in the C<pre-commit> and the C<post-commit> hooks.

It's configured by the following directive.

=head2 UPDATE_CONF_FILE(FROM, TO, @ARGS)

This directive tells that the file FROM kept under version control
must be copied to TO, a directory relative to the C</repo/conf>
directory in the server, after a succesful commit.

The optional @ARGS must be a sequence of pairs like these:

=over

=item validator => ARRAY or CODE

A validator is a function or a command (specified by an array of
strings that will be passed to the shell) that will check the contents
of FROM in the pre-commit hook to see if it's valid. If there is no
validator, the contents are considered valid.

=item generator => ARRAY or CODE

A generator is a function or a command that will transform the
contents of FROM in the post-commit hook before copying it to TO. If
there is no generator, the contents are copied as is.

=item rotate => NUMBER

By default, after each succesful commit the TO file is overwriten by
the new contents of FROM. With this option, the last NUMBER versions
of TO are kept on disk with numeric suffixes ranging from C<.0> to
C<.NUMBER-1>. This can be useful, for instance, in case you manage to
commit a wrong authz file that denies any subsequent commit.

=back

	UPDATE_CONF_FILE(
	    'conf/authz' => 'authz',
	    validator 	 => ['/usr/local/bin/svnauthcheck'],
	    generator 	 => ['/usr/local/bin/authz-expand-includes'],
	    rotate       => 2,
	);

	UPDATE_CONF_FILE(
	    'conf/svn-hooks.conf' => 'svn-hooks.conf',
	    validator 	 => ['/usr/bin/perl', '-c'],
	    rotate       => 2,
	);

=cut

sub UPDATE_CONF_FILE {
    my ($from, $to, @args) = @_;

    defined $from && ! ref $from
	or die "$HOOK: invalid first argument.\n";

    defined $to && ! ref $to
	or die "$HOOK: invalid second argument.\n";

    (@args % 2) == 0
	or die "$HOOK: odd number of arguments.\n";

    if ($to =~ m:/:) {
	die "$HOOK: second argument must be a basename, not a path ($to).\n";
    }
    else {
	$to = $SVN::Hooks::Repo->{repo_path} . "/conf/$to";
    }

    my $conf = $SVN::Hooks::Confs->{$HOOK};

    $conf->{confs}{$from}{to} = $to;

    my %args = @args;

    for my $name (qw/validator generator/) {
	if (my $what = delete $args{$name}) {
	    if (ref $what eq 'CODE') {
		$conf->{confs}{$from}{$name} = $what;
	    }
	    elsif (ref $what eq 'ARRAY') {
		# This should point to list of command arguments
		@$what > 0
		    or die "$HOOK: $name argument must have at least one element.\n";
		-x $what->[0]
		    or die "$HOOK: $name argument is not a valid command ($what->[0]).\n";
		$conf->{confs}{$from}{$name} = _functor($SVN::Hooks::Repo->{repo_path}, $what);
	    }
	    else {
		die "$HOOK: $name argument must be a CODE-ref or an ARRAY-ref.\n";
	    }
	    $conf->{'pre-commit'} = \&pre_commit;
	}
    }

    if (my $rotate = delete $args{rotate}) {
	$rotate =~ /^\d+$/
	    or die "$HOOK: rotate argument must be numeric, not '$rotate'";
	$rotate < 10
	    or die "$HOOK: rotate argument must be less than 10, not '$rotate'";
	$conf->{confs}{$from}{rotate} = $rotate;
    }

    keys %args == 0
	or die "$HOOK: invalid function names: ", join(', ', sort keys %args), ".\n";

    $conf->{'post-commit'} = \&post_commit;
}

$SVN::Hooks::Inits{$HOOK} = sub {
    return {};
};

sub pre_commit {
    my ($self, $svnlook) = @_;

  CONF:
    while (my ($from, $conf) = each %{$self->{confs}}) {
	if (my $validator = $conf->{validator}) {
	    for my $file (grep {$_ eq $from} $svnlook->added(), $svnlook->updated()) {
		my $text = $svnlook->cat($from);

		if (my $generator = $conf->{generator}) {
		    $text = eval { $generator->($text) };
		    defined $text
			or die "$HOOK: Generator aborted for: $file\n", $@, "\n";
		}

		my $validation = eval { $validator->($text) };
		defined $validation
		    or die "$HOOK: Validator aborted for: $file\n", $@, "\n";

		next CONF;
	    }
	}
    }
}

sub post_commit {
    my ($self, $svnlook) = @_;

  CONF:
    while (my ($from, $conf) = each %{$self->{confs}}) {
	for my $file (grep {$_ eq $from} $svnlook->added(), $svnlook->updated()) {
	    my $text = $svnlook->cat($from);

	    if (my $generator = $conf->{generator}) {
		$text = eval { $generator->($text) };
		defined $text
		    or die <<"EOS";
$HOOK: Generator aborted for: $file

This means that $file was commited but the associated
configuration file wans't updated in the server:

  $conf->{to}

Please, investigate the problem and re-commit the file.

Any error message produced by the generator appears below:

$@
EOS
	    }

	    my $to = $conf->{to};

	    open my $fd, '>', "$to.new"
		or die "$HOOK: Can't open file \"$to\" for writing: $!\n";
	    print $fd $text;
	    close $fd;

	    if (my $rotate = $conf->{rotate}) {
		for (my $i=$rotate-1; $i >= 0; --$i) {
		    rename "$to.$i", sprintf("$to.%d", $i+1)
			if -e "$to.$i";
		}
		rename $to, "$to.0"
		    if -e $to;
	    }

	    rename "$to.new", $to;

	    next CONF;
	}
    }
}

# FIXME: memoize isn't working
# memoize('_functor');
sub _functor {
    my ($repo_path, $cmdlist) = @_;
    my $cmd = join(' ', @$cmdlist);

    return sub {
	my ($text) = @_;

	my $temp = tempdir('UpdateConfFile.XXXXXX', TMPDIR => 1, CLEANUP => 1);

	open my $th, '>', "$temp/file"
	    or die "Can't create $temp/file: $!";
	print $th $text;
	close $th;

	$ENV{SVNREPOPATH} = $repo_path;
	if (system("$cmd $temp/file 1>$temp/output 2>$temp/error") == 0) {
	    return `cat $temp/output`;
	}
	else {
	    die `cat $temp/error`;
	}
    };
}

=head1 AUTHOR

Gustavo Chaves, C<< <gnustavo@cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-svn-hooks-updaterepofile at rt.cpan.org>, or through the web
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

1; # End of SVN::Hooks::UpdateConfFile
