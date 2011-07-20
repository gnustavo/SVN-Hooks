# -*- cperl -*-

use strict;
use warnings;
use lib 't';
use Test::More;

require "test-functions.pl";

my $io_available = 1;

if (not can_svn()) {
    plan skip_all => 'Cannot find or use svn commands.';
}
elsif (not eval {require Email::Send}) {
    plan skip_all => 'Need Email::Send';
}
elsif (not eval {require Email::Simple::Creator}) {
    plan skip_all => 'Need Email::Simple::Creator';
}
elsif (! Email::Send->new()->mailer_available('IO')) {
    $io_available = 0;
    plan tests => 7;
}
else {
    plan tests => 17;
}

my $t    = reset_repo();
my $wc   = catdir($t, 'wc');

set_hook(<<'EOS');
use SVN::Hooks::Mailer;
EOS

sub work {
    my $file = catfile($wc, $_[0]);
    <<"EOS";
echo txt >$file
svn add -q --no-auto-props $file
svn ci -mmessage $wc
EOS
}

set_conf(<<'EOS');
EMAIL_CONFIG();
EOS

work_nok('config sans args', 'EMAIL_CONFIG: requires two arguments', work('f'));

set_conf(<<'EOS');
EMAIL_CONFIG(WHAT => 1);
EOS

work_nok('config invalid', 'EMAIL_CONFIG: unknown option', work('f'));

set_conf(<<'EOS');
EMAIL_COMMIT(1);
EOS

work_nok('commit odd args', 'EMAIL_COMMIT: odd number of arguments', work('f'));

set_conf(<<'EOS');
EMAIL_COMMIT(what => 1);
EOS

work_nok('commit invalid opt', 'EMAIL_COMMIT: unknown option', work('f'));

set_conf(<<'EOS');
EMAIL_COMMIT(match => 1);
EOS

work_nok('commit invalid match', "EMAIL_COMMIT: 'match' argument must be a qr/Regexp/", work('f'));

set_conf(<<'EOS');
EMAIL_COMMIT(match => qr/./);
EOS

work_nok('commit missing from', "EMAIL_COMMIT: missing 'from' address", work('f'));

set_conf(<<'EOS');
EMAIL_COMMIT(match => qr/./, from => 's@a.b');
EOS

work_nok('commit missing to', "EMAIL_COMMIT: missing 'to' address", work('f'));

exit 0 unless $io_available;

my $log = '02-mailer.log';

set_conf(<<'EOS');
EMAIL_CONFIG(IO => '02-mailer.log');
EMAIL_COMMIT(
    match => qr/^a/,
    tag   => 'A',
    from  => 'from@example.net',
    to    => 'to@example.net',
    diff  => undef,
);
EMAIL_COMMIT(
    match => qr/^b/,
    tag   => 'B',
    from  => 'from@example.net',
    to    => 'to@example.net',
    diff  => ['--no-diff-deleted'],
);
EOS

work_ok('commit none', work('none'));

ok(! -f $log, 'commit none dontsend');

work_ok('commit A', work('a'));

ok(-f $log, 'commit A send');

my $mail = `cat $log`;
  like($mail, qr/Subject: \[A\]/, 'commit A right');
unlike($mail, qr/Subject: \[B\]/, 'commit A right sans B');

unlink $log;

work_ok('commit B', work('b'));

ok(-f $log, 'commit B send');

$mail = `cat $log`;
  like($mail, qr/Subject: \[B\]/, 'commit B right');
unlike($mail, qr/Subject: \[A\]/, 'commit B right sans A');

unlink $log;
