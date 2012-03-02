package Redis::AutoloadCache;

use strict;
use warnings;

use base qw<Redis>;

sub __mk_method {
  my $self      = shift;
  my $full_name = shift;
  my $command   = shift;

  my $method = $self->SUPER::__mk_method($full_name, $command);

  no strict 'refs';
  *$full_name = $method;

  return $method;
}

1;
