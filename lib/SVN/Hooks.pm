package SVN::Hooks;

use warnings;
use strict;
use File::Basename;
use Memoize;
use SVN::Look;

use Exporter qw/import/;
our @EXPORT = qw/run_hook/;

=head1 NAME

SVN::Hooks - A framework for implementing Subversion hooks.

=head1 VERSION

Version 0.30

=cut

our $VERSION = '0.30';

=head1 SYNOPSIS

A single, simple script like the following can be used as any kind of
Subversion hook.

    #!/usr/bin/perl

    use SVN::Hooks;
    use SVN::Hooks::DenyFilenames;
    use SVN::Hooks::DenyChanges;
    use SVN::Hooks::CheckProperty;
    ...

    run_hook($0, @ARGV);

=head1 CONFIGURATION

Of course, you'll have to configure the plugins (the sub-modules of
SVN::Hooks), but this is just another (almost as) simple Perl script
like this.

    # Accept only letters, digits, underlines, periods, and hifens
    DENY_FILENAMES(qr/[^-\/\.\w]/i);

    # Disallow modifications in the tags directory
    DENY_UPDATE(qr:^tags:);

    # OpenOffice.org documents need locks
    CHECK_PROPERTY(qr/\.(?:od[bcfgimpst]|ot[ghpst])$/i => 'svn:needs-lock');

=head1 USER TUTORIAL

In order to really understand what this is all about you'll need to
understand L<Subversion|http://subversion.tigris.org/> and its
L<hooks|http://svnbook.red-bean.com/nightly/en/svn.reposadmin.create.html#svn.reposadmin.create.hooks>.

Subversion is a version control system, and as such it is used to
maintain current and historical versions of files and
directories. Each revision maintains information about all the changes
introduced since the previous one: date, author, log message, files
changed, files renamed, etc.

Subversion uses a client/server model. The server maintains the
B<repository>, which is the database containing all the historical
information we talked about above. The users use a Subversion client
tool to query and change the repository but also to maintain one or
More B<working areas>. A working area is a directory in the user
machine containing a copy of a particular revision of the
repository. The user can use the client tool to make all sorts of
changes in his working area and to "commit" them all in an atomic
operation that bumps the repository to a new revision.

A hook is a specifically named program that is called by the
Subversion server during the execution of some operations. There are
exactly nine hooks which must reside under the C<conf> directory in
the repository. When you create a new repository, you get nine
template files in this directory, all of them having the C<.tmpl>
suffix and helpful instructions inside explaining how to convert them
into working hooks.

When Subversion is performing a commit operation on behalf of a
client, for example, it calls first the C<start-commit> hook, then the
C<pre-commit> hook, and then the C<post-commit> hoook. The first two
can gather all sorts of information about the specific commit
transaction being performed and decide to reject it in case it doesn't
comply to a set of policies. The C<post-commit> can be used to log or
alert interested parties about the commit just done.

There are several useful L<hook scripts
available|http://svn.apache.org/repos/asf/subversion/trunk/contrib/hook-scripts/>,
mainly for those three associated with the commit operation. However,
when you try to combine the functionality of two or more of those
scripts in a single hook you normally end up facing two problems.

=over

=item B<Complexity>

In order to integrate the funcionality of more than one script you
have to write a driver script that's called by Subversion and calls
all the other scripts in order, passing to them the arguments they
need. Moreover, some of those scripts may have configuration files to
read and you may have to maintain several of them.

=item B<Inefficiency>

This arrangement is inefficient in two ways. First because each script
runs is a separate process, which usually have a high startup cost
because they are, well, scripts and not binaries. And second, because
as each script is called in turn they have no memory of the scripts
called before and have to gather the information about the transaction
again and again, normally by calling the C<svnlook> command, which
spawns yet another process.

=back

SVN::Hooks is a framework for implementing Subversion hooks that tries
to solve these problems.

Instead of having separate scripts implementing different
functionality you have a single script using a single simple
configuration file. Different plugins, implemented by Perl modules in
the SVN::Hooks:: namespace, implement the different
functionality. Moreover, a single script can be used to implement all
the nine standard hooks, because each plugin knows when to perform
based on the context in which they were called.

=head2 Plugins

Each plugin is implemented as a Perl module. The main ones are
described succinctly below. Please, see their own documentation for
more details.

=over

=item SVN::Hooks::AllowPropChange

Allow changes in revision properties.

=item SVN::Hooks::CheckCapability

Check if the Subversion client implements the required capabilities.

=item SVN::Hooks::CheckJira

Integrate Subversion with the
L<JIRA|http://www.atlassian.com/software/jira/> ticketing system.

=item SVN::Hooks::CheckLog

Check if the log message in a commit conforms to a Regexp.

=item SVN::Hooks::CheckMimeTypes

Check if the files added to the repository have the C<svn:mime-type>
property set. Moreover, for text files, check if the properties
C<svn:eol-style> and C<svn:keywords> are also set.

=item SVN::Hooks::CheckProperty

Check for specific properties for specific kinds of files.

=item SVN::Hooks::CheckStructure

Check if the files and directories being added to the repository
conform to a specific structure.

=item SVN::Hooks::DenyChanges

Deny the addition, modification, or deletion of specific files and
directories in the repository. Usually used to deny modifications in
the C<tags> directory.

=item SVN::Hooks::DenyFilenames

Deny the addition of files which file names doesn't comply with a
Regexp. Usually used to disallow some characteres in the filenames.

=item SVN::Hooks::Notify

Sends notification emails after successful commits.

=item SVN::Hooks::UpdateConfFile

Allows you to maintain Subversion configuration files versioned in the
same repository where they are used. Usually used to maintain the
configuration file for the hooks and the repository access control
file.

=back

=head2 Example usage

In the Subversion server, go to the C<hooks> directory under the
directory where the repository was created. You should see there the
nine hook templates. Create a script there using all the plugins in
which you are interested.

	$ cd /path/to/repo/hooks
	$ cat svn-hooks.pl
	#!/usr/bin/perl

	use strict;
	use warnings;
	use SVN::Hooks;
	use SVN::Hooks::AllowPropChange;
	use SVN::Hooks::CheckCapability;
	use SVN::Hooks::CheckJira;
	use SVN::Hooks::CheckLog;
	use SVN::Hooks::CheckMimeTypes;
	use SVN::Hooks::CheckProperty;
	use SVN::Hooks::CheckStructure;
	use SVN::Hooks::DenyChanges;
	use SVN::Hooks::DenyFilenames;
	use SVN::Hooks::Notify;
	use SVN::Hooks::UpdateRepoFile;

	run_hook($0, @ARGV);
	$ chmod +x svn-hooks.pl

This script will serve for any hook. Create symbolic links pointing to
it for each hook you are interested in.

	$ ln -s svn-hooks.pl start-commit
	$ ln -s svn-hooks.pl pre-commit
	$ ln -s svn-hooks.pl post-commit
	$ ln -s svn-hooks.pl pre-revprop-change

The default configuration file for the hook is called
C<svn-hooks.conf> in the C<conf> directory under the directory where
the repository was created. It's just another Perl script calling
special functions acting as configuration directives that were defined
by the plugins.

	$ cd ../conf
	$ cat svn-hooks.conf
	DENY_FILENAMES(qr:[^-/\.\w]:i);

        CHECK_CAPABILITY('mergeinfo');

	CHECK_MIMETYPES();

	# Binary+editable files must have the svn:needs-lock property set
	CHECK_PROPERTY(qr/\.(?:do[ct]x?|xl[bst]x?|pp[st]x?|rtf|od[bcfgimpst]|ot[ghpst]|sd[acdpsw]|s[tx][cdiw]|mpp|vsd)$/i
			   => 'svn:needs-lock');

	DENY_UPDATE(qr:^tags:);

	1;

Being a Perl script, it's possible to get fancy with the configuration
file, using variables, functions, and whatever. But for most purposes
it consists just in a series of configuration directives.

Don't forget to end it with the C<1;> statement, though, because it's
evaluated with a C<do> statement and needs to end with a true
expression.

Please, see the plugins documentation to know about the directives.

=head1 PLUGIN DEVELOPER TUTORIAL

Yet to do.

=head1 EXPORT

=head2 run_hook

SVN::Hooks exports a single function, B<run_hook>, which is
responsible to invoke the right plugins depending on the context in
which it was called.

Its first argument must be the name of the hook that was
called. Usually you just pass C<$0> to it, since it knows to extract
the basename of the parameter.

Its second argument must be the path to the directory where the
repository was created.

The remaining arguments depend on the hook for which it's being
called, like this:

=over

=item * start-commit repo-path user capabilities

=item * pre-commit repo-path txn

=item * post-commit repo-path rev

=item * pre-lock repo-path path user

=item * post-lock repo-path user

=item * pre-unlock repo-path path user

=item * post-unlock repo-path user

=item * pre-revprop-change repo-path rev user propname action

=item * post-revprop-change repo-path rev user propname action

=back

But as these are exactly the arguments Subversion passes when it calls
the hooks, you usually call C<run_hook> like this:

	run_hook($0, @ARGV);

=cut

our @Conf_Files = ('conf/svn-hooks.conf');

sub run_hook {
    my ($hook_name, $repo_path, @args) = @_;

    $hook_name = basename $hook_name;

    my $repo = repo($repo_path);

    _load_configs($repo);

    # Substitute a SVN::Look object for the first argument
    # in the hooks where this makes sense.
    if ($hook_name eq 'pre-commit') {
	# The next arg is a transaction number
	$args[0] = SVN::Look->new($repo_path, '-t' => $args[0]);
    }
    elsif ($hook_name =~ /^(?:post-commit|(?:pre|post)-revprop-change)$/) {
	# The next arg is a revision number
	$args[0] = SVN::Look->new($repo_path, '-r' => $args[0]);
    }

    foreach my $conf (values %{$repo->{confs}}) {
	if (my $hook = $conf->{$hook_name}) {
	    $hook->($conf, @args);
	}
    }

    return;
}

memoize('repo');
sub repo {
    my ($repo_path) = @_;

    -d $repo_path or die "not a directory: $_\n";

    my @conf_files;
    foreach my $file (@Conf_Files) {
	my $conf = ($file =~ m:^/:) ? $file : "$repo_path/$file";
	-r $conf or die "can't read: $conf\n";
	push @conf_files, {file => $conf, mtime => 0};
    }

    return {
	repo_path  => $repo_path,
	conf_files => \@conf_files,
	confs      => {},
    };
}

our (%Inits, $Repo, $Confs);

sub _load_configs {
    ($Repo) = @_;

    my $touched = 0;
    foreach my $conf (@{$Repo->{conf_files}}) {
	my $mtime = (stat $conf->{file})[9];
	if ($conf->{mtime} != $mtime) {
	    # Update the mtime of every configuration file
	    $conf->{mtime} = $mtime;
	    $touched = 1;
	}
    }
    return unless $touched;

    # Reset all configuration
    $Confs = $Repo->{confs};
    while (my ($hook_name, $hook_init) = each %Inits) {
	$Confs->{$hook_name} = $hook_init->();
    }

    # Reload all configuration files
    foreach my $conf (@{$Repo->{conf_files}}) {
	package main;
	unless (my $return = do $conf->{file}) {
	    die "couldn't parse $conf->{file}: $@\n" if $@;
	    die "couldn't do $conf->{file}: $!\n"    unless defined $return;
	    die "couldn't run $conf->{file}\n"       unless $return;
	}
	package SVN::Hooks;
    }

    return;
}

=head1 AUTHOR

Gustavo Chaves, C<< <gnustavo@cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-svn-hooks at
rt.cpan.org>, or through the web interface at
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

1; # End of SVN::Hooks
