#!/usr/bin/perl

use strict;
use warnings;
use lib 't';
use Test::More;

require "test-functions.pl";

if (eval {require SVN::Notify}) {
    plan tests => 1;
}
else {
    plan skip_all => 'Need SVN::Notify.';
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
