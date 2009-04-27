# -*- cperl -*-

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
use SVN::Hooks::CheckMimeTypes;
EOS

set_conf(<<'EOS');
CHECK_MIMETYPES();
EOS

work_nok('miss svn:mime-type' => 'property svn:mime-type is not set for', <<"EOS");
touch $t/wc/file.txt
svn add -q --no-auto-props $t/wc/file.txt
svn ci -mx $t/wc/file.txt
EOS

work_nok('miss svn:eol-style on text file', 'property svn:eol-style is not set for', <<"EOS");
svn ps svn:mime-type text/plain $t/wc/file.txt
svn ci -mx $t/wc/file.txt
EOS

work_nok('miss svn:keywords on text file', 'property svn:keywords is not set for', <<"EOS");
svn ps svn:eol-style native $t/wc/file.txt
svn ci -mx $t/wc/file.txt
EOS

work_ok('all set on text file' => <<"EOS");
svn ps svn:keywords 'Id' $t/wc/file.txt
svn ci -q -mx $t/wc/file.txt
EOS

work_ok('set only svn:mime-type on non-text file', <<"EOS");
touch $t/wc/binary.exe
svn add -q --no-auto-props $t/wc/binary.exe
svn ps svn:mime-type application/octet-stream $t/wc/binary.exe
svn ci -mx $t/wc/binary.exe
EOS

