use strict;
use warnings;
use lib 't';
use Test::More;

require "test-functions.pl";

if (has_svn()) {
    plan tests => 5;
}
else {
    plan skip_all => 'Need svn commands in the PATH.';
}

my $t = reset_repo();

set_hook(<<'EOS');
use SVN::Hooks::CheckLog;
EOS

set_conf(<<'EOS');
CHECK_LOG();
EOS

work_nok('miss regexp' => 'first argument must be a qr', <<"EOS");
touch $t/wc/file.txt
svn add -q --no-auto-props $t/wc/file.txt
svn ci -mx $t/wc/file.txt
EOS

set_conf(<<'EOS');
CHECK_LOG(qr/./, []);
EOS

work_nok('invalid second arg' => 'second argument must be', <<"EOS");
svn ci -mx $t/wc/file.txt
EOS

set_conf(<<'EOS');
CHECK_LOG(qr/without error/);
CHECK_LOG(qr/with error/, 'Error Message');
EOS

work_nok('dont match without error' => 'log message must match', <<"EOS");
svn ci -mx $t/wc/file.txt
EOS

work_nok('dont match with error', 'Error Message', <<"EOS");
svn ci -m'without error' $t/wc/file.txt
EOS

work_ok('match all', <<"EOS");
svn ci -m'without error with error' $t/wc/file.txt
EOS
