# Copyright (C) 2008 by CPqD

BEGIN { $ENV{PATH} = '/usr/local/bin:/usr/bin:/bin' }

use strict;
use warnings;
use Cwd;
use File::Temp qw/tempdir/;
use File::Spec::Functions qw/catfile path/;
use File::Path;
use File::Copy;

# Make sure the svn messages come in English.
$ENV{LC_MESSAGES} = 'C';

sub can_svn {
  CMD:
    for my $cmd (qw/svn svnadmin svnlook/) {
	for my $path (path()) {
	    next CMD if -x catfile($path, $cmd);
	}
	return 0;
    }

    my $T = tempdir('t.XXXX', DIR => getcwd());
    my $canuseit = system("svnadmin create $T/repo") == 0;
    rmtree($T);

    return $canuseit;
}

our $T;

sub newdir {
    my $num = 1 + Test::Builder->new()->current_test();
    my $dir = "$T/$num";
    mkdir $dir;
    $dir;
}

sub do_script {
    my ($dir, $cmd) = @_;
    {
	open my $script, '>', "$dir/script" or die;
	print $script $cmd;
	close $script;
	chmod 0755, "$dir/script";
    }
    copy("$T/repo/hooks/svn-hooks.pl", "$dir/svn-hooks.pl");
    copy("$T/repo/conf/svn-hooks.conf", "$dir/svn-hooks.conf");

    system("$dir/script 1>$dir/stdout 2>$dir/stderr");
}

sub work_ok {
    my ($tag, $cmd) = @_;
    my $dir = newdir();
    ok((do_script($dir, $cmd) == 0), $tag)
	or diag("work_ok command failed with following stderr:\n", `cat $dir/stderr`);
}

sub work_nok {
    my ($tag, $error_expect, $cmd) = @_;
    my $dir = newdir();
    my $exit = do_script($dir, $cmd);
    if ($exit == 0) {
	fail($tag);
	diag("work_nok command worked but it shouldn't!\n");
	return;
    }

    my $stderr = `cat $dir/stderr`;

    if (! ref $error_expect) {
	ok(index($stderr, $error_expect) >= 0, $tag)
	    or diag("work_nok:\n  '$stderr'\n    does not contain\n  '$error_expect'\n");
    }
    elsif (ref $error_expect eq 'Regexp') {
	like($stderr, $error_expect, $tag);
    }
    else {
	fail($tag);
	diag("work_nok: invalid second argument to test.\n");
    }
}

sub set_hook {
    my ($text) = @_;
    open my $fd, '>', "$T/repo/hooks/svn-hooks.pl"
	or die "Can't create $T/repo/hooks/svn-hooks.pl: $!";
    my $debug = exists $ENV{DBG} ? '-d' : '';
    print $fd <<"EOS";
#!$^X $debug
use strict;
use warnings;
EOS
    if (defined $ENV{PERL5LIB} and length $ENV{PERL5LIB}) {
	foreach my $path (reverse split /:/, $ENV{PERL5LIB}) {
	    print $fd "use lib '$path';\n";
	}
    }
    print $fd <<"EOS";
use lib 'blib/lib';
use SVN::Hooks;
EOS
    print $fd $text, "\n";
    print $fd <<'EOS';
run_hook($0, @ARGV);
EOS
    close $fd;
    chmod 0755 => "$T/repo/hooks/svn-hooks.pl";
}

sub set_conf {
    my ($text) = @_;
    open my $fd, '>', "$T/repo/conf/svn-hooks.conf"
	or die "Can't create $T/repo/conf/svn-hooks.conf: $!";
    print $fd $text, "\n1;\n";
    close $fd;
}

sub reset_repo {
    my $cleanup = exists $ENV{REPO_CLEANUP} ? $ENV{REPO_CLEANUP} : 1;
    $T = tempdir('t.XXXX', DIR => getcwd(), CLEANUP => $cleanup);

    system(<<"EOS");
svnadmin create $T/repo
EOS

    set_hook('');

    foreach my $hook (qw/post-commit post-lock post-refprop-change post-unlock pre-commit
			 pre-lock pre-revprop-change pre-unlock start-commit/) {
	symlink 'svn-hooks.pl' => "$T/repo/hooks/$hook";
    }

    set_conf('');

    system(<<"EOS");
svn co -q file://$T/repo $T/wc
EOS

    return $T;
}

1;
