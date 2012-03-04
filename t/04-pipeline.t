#!perl

use warnings;
use strict;
use Test::More;
use Redis;
use lib 't/tlib';
use Test::SpawnRedisServer;
use Test::Exception;

my ($c, $srv) = redis();
END { $c->() if $c }

ok(my $r = Redis->new(server => $srv), 'connected to our test redis-server');

sub pipeline_ok {
  my ($desc, @commands) = @_;
  subtest $desc => sub {
    my (@placeholders, @expected_placeholders, @expected_responses);

    my @responses = $r->pipeline(sub {
      for my $cmd (@commands) {
        my ($method, $args, $expected_response) = @$cmd;
        push @expected_placeholders, placeholder($method);
        push @expected_responses, $expected_response;
        my $placeholder = $r->$method(@$args);
        push @placeholders, $placeholder;
      }
    });

    my $responses_ref = $r->pipeline(sub {
      for my $cmd (@commands) {
        my ($method, $args) = @$cmd;
        $r->$method(@$args);
      }
    });

    is_deeply(\@placeholders, \@expected_placeholders, 'placeholders are correct');
    is_deeply(\@responses, \@expected_responses,
              'list-context responses are correct');
    is_deeply($responses_ref, \@expected_responses,
              'scalar-context responses are correct');
 };
}

pipeline_ok 'empty pipeline', ();

pipeline_ok 'single-command pipeline', (
  [set => [foo => 'bar'], 'OK'],
);

pipeline_ok 'pipeline with embedded error', (
  [set  => [clunk => 'eth'], 'OK'],
  [oops => [], unthrown(q[ERR unknown command 'OOPS'])],
  [get  => ['clunk'], 'eth'],
);

pipeline_ok 'pipeline with multi-bulk reply', (
  [hmset => [kapow => (a => 1, b => 2, c => 3)], 'OK'],
  [hmget => [kapow => qw<c b a>], [3, 2, 1]],
);

pipeline_ok 'large pipeline', (
  (map { [hset => [zzapp => $_ => -$_], 1] } 1 .. 5000),
  [hmget => [zzapp => (1 .. 5000)], [reverse -5000 .. -1]],
  [del => ['zzapp'], 1],
);

throws_ok { $r->pipeline(sub { $r->pipeline(sub {}) }) }
  qr/Nested pipelines are forbidden/,
  'no nested pipelines';

subtest 'txn_exec' => sub {
  is($r->multi, 'OK', 'start MULTI');
  is($r->set(clunk => 'eth'), 'QUEUED', 'txn command 1 queued');
  is($r->rpush(clunk => 'oops'), 'QUEUED', 'txn command 2 queued');
  is($r->get('clunk'), 'QUEUED', 'txn command 3 queued');
  is_deeply([$r->txn_exec], [
    'OK',
    unthrown('ERR Operation against a key holding the wrong kind of value'),
    'eth',
  ], 'correct responses, including unthrown error');
};

throws_ok { $r->txn_exec } qr/ERR EXEC without MULTI/,
  'txn_exec correctly detects error in its EXEC';

done_testing();

sub placeholder {
  my ($command) = @_;
  return bless \$command, 'Redis::X::Placeholder';
}

sub unthrown {
  my ($error) = @_;
  return bless \$error, 'Redis::X::Unthrown';
}

