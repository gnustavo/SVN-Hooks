package SVN::Hooks::UpdateConfFile;

use strict;
use warnings;
use Carp;
use SVN::Hooks;
use File::Spec::Functions;
use File::Temp qw/tempdir/;
use Cwd qw/abs_path/;

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

This directive tells that after a successful commit the file FROM, kept
under version control, must be copied to TO.

FROM can be a string or a qr/Regexp/ specifying the file path relative
to the repository's root (e.g. "trunk/src/version.c").

TO is a path relative to the C</repo/conf> directory in the server. It
can be an explicit file name or a directory, in which case the
basename of FROM is used as the name of the destination file.

If FROM is a qr/Regexp/ TO is evaluated as a string in order to allow
for the interpolation of capture buffers from the regular
expression. This is useful to map the copy operation to a diferent
directory structure, for example.

The optional @ARGS must be a sequence of pairs like these:

=over

=item validator => ARRAY or CODE

A validator is a function or a command (specified by an array of
strings that will be passed to the shell) that will check the contents
of FROM in the pre-commit hook to see if it's valid. If there is no
validator, the contents are considered valid.

The function receives two string arguments: the contents of FROM and
the relative path to FROM.

The command is called with two arguments: the path to a temporary copy
of FROM and the relative path to FROM.

=item generator => ARRAY or CODE

A generator is a function or a command (specified by an array of
strings that will be passed to the shell) that will transform the
contents of FROM in the post-commit hook before copying it to TO. If
there is no generator, the contents are copied as is.

The function receives two string arguments: the contents of FROM and
the relative path to FROM.

The command is called with two arguments: the path to a temporary copy
of FROM and the relative path to FROM.

=item actuator => ARRAY or CODE

An actuator is a function or a command (specified by an array of
strings that will be passed to the shell) that will be invoked after a
successful commit of FROM in the post-commit hook.

The function receives two string arguments: the contents of FROM and
the relative path to FROM.

The command is called with two arguments: the path to a temporary copy
of FROM and the relative path to FROM.

=item rotate => NUMBER

By default, after each successful commit the TO file is overwriten by
the new contents of FROM. With this option, the last NUMBER versions
of TO are kept on disk with numeric suffixes ranging from C<.0> to
C<.NUMBER-1>. This can be useful, for instance, in case you manage to
commit a wrong authz file that denies any subsequent commit.

=back

	UPDATE_CONF_FILE(
	    'conf/authz' => 'authz',
	    validator 	 => ['/usr/local/bin/svnauthcheck'],
	    generator 	 => ['/usr/local/bin/authz-expand-includes'],
            actuator     => ['/usr/local/bin/notify-auth-change'],
	    rotate       => 2,
	);

	UPDATE_CONF_FILE(
	    'conf/svn-hooks.conf' => 'svn-hooks.conf',
	    validator 	 => [qw(/usr/bin/perl -c)],
            actuator     => sub {
                                my ($contents, $file) = @_;
                                die "Can't use Gustavo here." if $contents =~ /gustavo/;
                            },
	    rotate       => 2,
	);

	UPDATE_CONF_FILE(
	    qr:/file(\n+)$:' => 'subdir/$1/file',
	    rotate       => 2,
	);

=cut

my @Config;

sub UPDATE_CONF_FILE {
    my ($from, $to, @args) = @_;

    defined $from and (not ref $from or ref $from eq 'Regexp')
	or croak "$HOOK: invalid first argument.\n";

    defined $to and not ref $to
	or croak "$HOOK: invalid second argument.\n";

    (@args % 2) == 0
	or croak "$HOOK: odd number of arguments.\n";

    file_name_is_absolute($to)
	and croak "$HOOK: second argument cannot be an absolute pathname ($to).\n";

    my %confs = (from => $from, to => $to);

    my %args = @args;

    for my $function (qw/validator generator actuator/) {
	if (my $what = delete $args{$function}) {
	    if (ref $what eq 'CODE') {
		$confs{$function} = $what;
	    }
	    elsif (ref $what eq 'ARRAY') {
		# This should point to list of command arguments
		@$what > 0
		    or croak "$HOOK: $function argument must have at least one element.\n";
		-x $what->[0]
		    or croak "$HOOK: $function argument is not a valid command ($what->[0]).\n";
		$confs{$function} = _functor($SVN::Hooks::Repo, $what);
	    }
	    else {
		croak "$HOOK: $function argument must be a CODE-ref or an ARRAY-ref.\n";
	    }

	    PRE_COMMIT(\&pre_commit);
	}
    }

    if (my $rotate = delete $args{rotate}) {
	$rotate =~ /^\d+$/
	    or croak "$HOOK: rotate argument must be numeric, not '$rotate'";
	$rotate < 10
	    or croak "$HOOK: rotate argument must be less than 10, not '$rotate'";
	$confs{rotate} = $rotate;
    }

    keys %args == 0
	or croak "$HOOK: invalid function names: ", join(', ', sort keys %args), ".\n";

    push @Config, \%confs;

    POST_COMMIT(\&post_commit);

    return 1;
}

sub pre_commit {
    my ($svnlook) = @_;

  CONF:
    foreach my $conf (@Config) {
	if (my $validator = $conf->{validator}) {
	    my $from = $conf->{from};
	    for my $file ($svnlook->added(), $svnlook->updated()) {
		if (! ref $from) {
		    next if $file ne $from;
		}
		else {
		    next if $file !~ $from;
		}

		my $text = $svnlook->cat($file);

		if (my $generator = $conf->{generator}) {
		    $text = eval { $generator->($text, $file) };
		    defined $text
			or croak "$HOOK: Generator aborted for: $file\n", $@, "\n";
		}

		my $validation = eval { $validator->($text, $file) };
		defined $validation
		    or croak "$HOOK: Validator aborted for: $file\n", $@, "\n";

		next CONF;
	    }
	}
    }
    return;
}

sub post_commit {
    my ($svnlook) = @_;

    my $absbase = abs_path(catdir($SVN::Hooks::Repo, 'conf'));

  CONF:
    foreach my $conf (@Config) {
	my $from = $conf->{from};
	for my $file ($svnlook->added(), $svnlook->updated()) {
	    my $to = $conf->{to};
	    if (! ref $from) {
		next if $file ne $from;
	    }
	    else {
		next if $file !~ $from;
		# interpolate backreferences 
		$to = eval qq{"$to"}; ## no critic
	    }

	    $to = abs_path(catfile($SVN::Hooks::Repo, 'conf', $to));
	    if (-d $to) {
		$to = catfile($to, (File::Spec->splitpath($file))[2]);
	    }

	    $absbase eq substr($to, 0, length($absbase))
		or croak <<"EOS";
$HOOK: post-commit aborted for: $file

This means that $file was committed but the associated
configuration file wasn't generated because its specified
location ($to)
isn't below the repository's configuration directory
($absbase).

Please, correct the ${HOOK}'s second argument.
EOS

	    my $text = $svnlook->cat($file);

	    if (my $generator = $conf->{generator}) {
		$text = eval { $generator->($text, $file) };
		defined $text or croak <<"EOS";
$HOOK: generator in post-commit aborted for: $file

This means that $file was committed but the associated
configuration file wasn't generated in the server at:

  $to

Please, investigate the problem and re-commit the file.

Any error message produced by the generator appears below:

$@
EOS
	    }

	    open my $fd, '>', "$to.new"
		or croak "$HOOK: Can't open file \"$to\" for writing: $!\n";
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

	    if (my $actuator = $conf->{actuator}) {
		my $rc = eval { $actuator->($text, $file) };
		defined $rc or croak <<"EOS";
$HOOK: actuator in post-commit aborted for: $file

This means that $file was committed and the associated
configuration file was generated in the server at:

  $to

But the actuator command that was called after the file generation
didn't work right.

Please, investigate the problem.

Any error message produced by the actuator appears below:

$@
EOS
	    }

	    next CONF;
	}
    }
    return;
}

sub _functor {
    my ($repo_path, $cmdlist) = @_;
    my $cmd = join(' ', @$cmdlist);

    return sub {
	my ($text, $path) = @_;

	my $temp = tempdir('UpdateConfFile.XXXXXX', TMPDIR => 1, CLEANUP => 1);

	# FIXME: this is Unix specific!
	open my $th, '>', "$temp/file"
	    or croak "Can't create $temp/file: $!";
	print $th $text;
	close $th;

	local $ENV{SVNREPOPATH} = $repo_path;
	if (system("$cmd $temp/file 1>$temp/output 2>$temp/error") == 0) {
	    return `cat $temp/output`;
	}
	else {
	    croak `cat $temp/error`;
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

Copyright 2008-2009 CPqD, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1; # End of SVN::Hooks::UpdateConfFile
