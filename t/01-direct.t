# -*- cperl -*-

use strict;
use warnings;
use lib 't';
use Test::More;

require "test-functions.pl";

if (can_svn()) {
    plan tests => 2;
}
else {
    plan skip_all => 'Cannot find or use svn commands.';
}

my $t = reset_repo();
chomp(my $cwd = `pwd`);
my $repo = "file://$t/repo";

set_hook(<<'EOS');
START_COMMIT {
    my ($repos_path, $username, $capabilities) = @_;

    length $username
	or die "Empty username not allowed to commit.\n";
};

PRE_COMMIT {
    my ($svnlook) = @_;

    foreach my $added ($svnlook->added()) {
	$added !~ /\.(exe|o|jar|zip)$/
	    or die "Please, don't commit binary files such as '$added'.\n";
    }
};
EOS

work_ok('setup', <<"EOS");
touch $t/wc/file.txt
svn add -q --no-auto-props $t/wc/file.txt
svn ci -mx $t/wc/file.txt
EOS

work_nok('binary' => 'Please, don\'t commit binary files', <<"EOS");
touch $t/wc/file.zip
svn add -q --no-auto-props $t/wc/file.zip
svn ci -mx $t/wc/file.zip
EOS

