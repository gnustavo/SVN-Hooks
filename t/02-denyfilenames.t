# -*- cperl -*-

use strict;
use warnings;
use lib 't';
use Test::More;

require "test-functions.pl";

if (can_svn()) {
    plan tests => 5;
}
else {
    plan skip_all => 'Cannot find or use svn commands.';
}

my $t    = reset_repo();
my $wc   = catdir($t, 'wc');
my $file = catfile($wc, 'file');

set_hook(<<'EOS');
use SVN::Hooks::DenyFilenames;
EOS

set_conf(<<'EOS');
DENY_FILENAMES('string');
EOS

work_nok('cant parse config', 'DENY_FILENAMES: got "string" while expecting a qr/Regex/ or a', <<"EOS");
echo txt >$file
svn add -q --no-auto-props $file
svn ci -mx $file
EOS

set_conf(<<'EOS');
DENY_FILENAMES(qr/[^a-z0-9]/i, qr/substring/, [qr/custommessage/ => 'custom message']);
EOS

work_ok('valid', <<"EOS");
svn ci -mx $file
EOS

work_nok('invalid', 'DENY_FILENAMES: filename not allowed: file', <<"EOS");
echo txt >${file}_
svn add -q --no-auto-props ${file}_
svn ci -mx ${file}_
EOS

work_nok('second invalid', 'DENY_FILENAMES: filename not allowed: withsubstringinthemiddle', <<"EOS");
echo txt >$t/wc/withsubstringinthemiddle
svn add -q --no-auto-props $t/wc/withsubstringinthemiddle
svn ci -mx $t/wc/withsubstringinthemiddle
EOS

work_nok('custom message', 'DENY_FILENAMES: custom message: withcustommessage', <<"EOS");
echo txt >$t/wc/withcustommessage
svn add -q --no-auto-props $t/wc/withcustommessage
svn ci -mx $t/wc/withcustommessage
EOS

