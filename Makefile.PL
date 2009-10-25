use strict;
use warnings;
use ExtUtils::MakeMaker qw(WriteMakefile prompt);
use IO::Socket ();
use Getopt::Long  qw(GetOptions);

# clean up the testing flag files.
unlink('t/online.enabled', 't/author.enabled');

my $usage        = "$0 [--online-tests] [--author-tests]\n";
my $online_tests = 0;
my $author_tests = 0;
GetOptions(
    'online-tests' => \$online_tests,
    'author-tests' => \$author_tests,
) or die $usage;

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
    open(ENABLED, ">t/online.enabled") or die "Can't touch ./t/online.enabled: $!";
    close(ENABLED)                     or die "Can't touch ./t/online.enabled: $!";
}

if ($author_tests) {
    open(ENABLED, ">t/author.enabled") or die "Can't touch ./t/author.enabled: $!";
    close(ENABLED)                     or die "Can't touch ./t/author.enabled: $!";
}

WriteMakefile(
    NAME                => 'SVN::Hooks',
    AUTHOR              => 'Gustavo Chaves <gnustavo@cpan.org>',
    VERSION_FROM        => 'lib/SVN/Hooks.pm',
    ABSTRACT_FROM       => 'lib/SVN/Hooks.pm',
    PL_FILES            => {},
    PREREQ_PM => {
	'Email::Send'   => 0,
	'Email::Simple' => 0,
	'Email::Simple::Creator' => 0,
	'SVN::Look'     => 0,
	'SVN::Notify'   => 0,
        'Test::More'    => 0,
	'XMLRPC::Lite'  => 0,
	'JIRA::Client'  => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'SVN-Hooks-*' },
);
