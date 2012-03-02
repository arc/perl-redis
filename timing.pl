#! /usr/bin/env perl

use strict;
use warnings;

use lib 't/tlib';
use Test::More;
use Test::SpawnRedisServer;

use Redis;
use Redis::AutoloadCache;
use Benchmark qw<cmpthese>;

my $TASK_SIZE = $ARGV[0] || 1e5;

{
    my ($c, $srv) = redis();
    END { $c->() if $c }

    my $n = 1 + int 1000 / sqrt $TASK_SIZE;
    print "Benchmarking $TASK_SIZE requests $n times ...\n";
    cmpthese($n, {
        cached   => sub { work('Redis::AutoloadCache', $srv) },
        uncached => sub { work('Redis', $srv) },
    });

    print "\n";
}

sub work {
    my ($class, $srv) = @_;
    my $redis = $class->new(server => $srv);
    $redis->hset('k', $_ => $_) for 1 .. $TASK_SIZE;
    $redis->del('k');
}

__END__

=pod

Test platform:

    - Perl 5.14.2, compiled 64-bit without ithreads
    - Redis 2.4.8, compiled 32-bit, and connecting by TCP to localhost
    - 2.53 GHz Intel Core 2 Duo
    - Mac OS 10.6.8

Results:

    $ for n in 100 1000 10000 100000 200000 500000 1000000; do
    >   perl -Ilib timing.pl $n
    > done
    Benchmarking 100 requests 101 times ...
              Rate uncached   cached
    uncached 103/s       --     -10%
    cached   115/s      11%       --

    Benchmarking 1000 requests 32 times ...
               Rate uncached   cached
    uncached 10.8/s       --     -11%
    cached   12.2/s      13%       --

    Benchmarking 10000 requests 11 times ...
               Rate uncached   cached
    uncached 1.09/s       --     -11%
    cached   1.22/s      12%       --

    Benchmarking 100000 requests 4 times ...
             s/iter uncached   cached
    uncached   9.25       --     -11%
    cached     8.20      13%       --

    Benchmarking 200000 requests 3 times ...
                (warning: too few iterations for a reliable count)
                (warning: too few iterations for a reliable count)
             s/iter uncached   cached
    uncached   18.4       --     -11%
    cached     16.5      12%       --

    Benchmarking 500000 requests 2 times ...
                (warning: too few iterations for a reliable count)
                (warning: too few iterations for a reliable count)
             s/iter uncached   cached
    uncached   46.0       --     -11%
    cached     40.8      13%       --

    Benchmarking 1000000 requests 2 times ...
                (warning: too few iterations for a reliable count)
                (warning: too few iterations for a reliable count)
             s/iter uncached   cached
    uncached   92.4       --     -12%
    cached     81.7      13%       --

So caching AUTOLOAD methods yields a reliable speedup for this workload of
between 11% and 13% compared to the uncached version.  Furthermore, that
speedup seems to be stable while varying $TASK_SIZE by several orders of
magnitude.
