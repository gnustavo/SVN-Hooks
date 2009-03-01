use strict;
use warnings;
use lib 't';
use Test::More;

require "test-functions.pl";

if (not has_svn()) {
    plan skip_all => 'Need svn commands in the PATH.';
}
elsif (! eval {require SVN::Notify}) {
    plan skip_all => 'Need SVN::Notify.';
}
else {
    plan tests => 1;
}

my $t = reset_repo();

set_hook(<<'EOS');
use SVN::Hooks::Notify;
EOS

sub work {
    my $text = '';
    for my $file (@_) {
	$text .= <<"EOS";
touch $t/wc/$file
svn add -q --no-auto-props $t/wc/$file
EOS
    }
    $text .= <<"EOS";
svn ci -mmessage $t/wc
EOS
}

set_conf(<<'EOS');
NOTIFY_DEFAULTS();
NOTIFY(to_email_map => {'dontmatch' => 'none@nowhere.com'});
EOS

work_ok('load and config', work('f'));
