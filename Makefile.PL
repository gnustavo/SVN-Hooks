use strict;
use warnings;
use File::Spec::Functions;
use ExtUtils::MakeMaker qw(WriteMakefile prompt);
use IO::Socket ();
use Getopt::Long  qw(GetOptions);

# clean up the testing flag files.
my $t_online = catfile('t', 'online.enabled');
my $t_author = catfile('t', 'author.enabled');
unlink($t_online, $t_author);

my $usage        = "$0 [--online-tests] [--author-tests]\n";
my $online_tests = 0;
my $author_tests = 0;
GetOptions(
    'online-tests' => \$online_tests,
    'author-tests' => \$author_tests,
) or die $usage;

# Check if we have a suitable version of the svnlook command.
{
    open my $svnlook, '-|', 'svnlook --version'
	or die "Aborting because I couldn't find the 'svnlook' executable in PATH=$ENV{PATH}.\n";
    $_ = <$svnlook>;
    if (my ($major, $minor, $patch) = (/(\d+)\.(\d+)\.(\d+)/)) {
	$major > 1 || $major == 1 && $minor >= 4
	    or die "I need at least version 1.4.0 of svnlook but you have only $major.$minor.$patch.\n";
    } else {
	die "Can't grok Subversion version from svnlook --version command.\n";
    }
    local $/ = undef;		# slurp mode
    <$svnlook>;
    close $svnlook or die "Can't close svnlook commnand.\n";
}

#
# Check if we have internet connection
# (I lifted this code from Net::DNS, which lifted it from LWP... )
#
unless (defined $online_tests) {
    my $s = IO::Socket::INET->new(
	PeerAddr => "jira.atlassian.com:80",
	Timeout  => 10,
    );
    if ($s) {
	close($s);
	print <<EOT;

You appear to be directly connected to the Internet.  I have some tests
that try to access the Atlassian's JIRA demo server.

EOT
	$online_tests = prompt("Do you want to enable these tests?", "y") =~ /^y/i ? 1 : 0;
    }
}

if ($online_tests) {
    open(ENABLED, '>', $t_online) or die "Can't touch $t_online: $!\n";
    close(ENABLED)                or die "Can't touch $t_online: $!\n";
}

if ($author_tests) {
    open(ENABLED, '>', $t_author) or die "Can't touch $t_author: $!\n";
    close(ENABLED)                or die "Can't touch $t_author: $!\n";
}

my $hooks_pm = catfile('lib', 'SVN', 'Hooks.pm');

WriteMakefile(
    NAME                => 'SVN::Hooks',
    AUTHOR              => 'Gustavo Chaves <gnustavo@cpan.org>',
    VERSION_FROM        => $hooks_pm,
    ABSTRACT_FROM       => $hooks_pm,
    PL_FILES            => {},
    PREREQ_PM => {
	'Email::Send'   => 0,
	'Email::Simple' => 0,
	'Email::Simple::Creator' => 0,
	'SVN::Look'     => '0.21',
	'SVN::Notify'   => 0,
        'Test::More'    => 0,
	'URI::file'     => 0,
	'XMLRPC::Lite'  => 0,
	'JIRA::Client'  => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'SVN-Hooks-*' },
);
