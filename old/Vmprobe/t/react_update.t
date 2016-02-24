use common::sense;
use Test::More qw/no_plan/;
use Clone qw/clone/;

use Vmprobe::ReactUpdate;


sub apply_update {
    my ($desc, $input, $update, $expected) = @_;

    my $orig = Clone::clone($input);

    my $output = Vmprobe::ReactUpdate::update($input, $update);

    is_deeply($output, $expected, "update applied correctly ($desc)");
    ok($input != $output, "new structure created ($desc)");
    is_deeply($input, $orig, "original not modified ($desc)");
}


## set

apply_update(
  "simple set",
  {},
  { a => { '$set' => 1 } },
  { a => 1 },
);

apply_update(
  "nested set",
  { a => { b => 1 }, c => 2, },
  { a => { b => { '$set' => 5 } } },
  { a => { b => 5 }, c => 2, },
);

apply_update(
  "set, auto-vivify",
  { c => 2 },
  { a => { b => { '$set' => 5 } } },
  { a => { b => 5 }, c => 2, },
);

## unset

apply_update(
  "unset",
  { a => { b => 1, z => 2 }, c => 2, },
  { a => { '$unset' => 'b' } },
  { a => { z => 2 }, c => 2, },
);

apply_update(
  "unset auto-vivify",
  {},
  { a => { '$unset' => 'b' } },
  { a => {}, },
);

## merge

apply_update(
  "merge",
  { a => 1, b => 2, },
  { '$merge' => { c => 3, d => { e => 4 } } },
  { a => 1, b => 2, c => 3, d => { e => 4 } },
);

apply_update(
  "merge overwrites",
  { a => 1, b => 2, c => 9 },
  { '$merge' => { c => 3, d => { e => 4 } } },
  { a => 1, b => 2, c => 3, d => { e => 4 } },
);

apply_update(
  "merge auto-vivify",
  {},
  { a => { b => { '$merge' => { c => 1 } } } },
  { a => { b => { c => 1 } } },
);

## push

apply_update(
  "push",
  { a => [ 0, ], },
  { a => { '$push' => [ 1, 2, ] } },
  { a => [ 0, 1, 2 ], },
);

apply_update(
  "push auto-vivify",
  {},
  { a => { '$push' => [ 1, 2, ] } },
  { a => [ 1, 2 ], },
);

## unshift

apply_update(
  "unshift",
  { a => [ 0, ], },
  { a => { '$unshift' => [ 1, 2, ] } },
  { a => [ 1, 2, 0 ], },
);

apply_update(
  "unshift auto-vivify",
  {},
  { a => { '$unshift' => [ 1, 2, ] } },
  { a => [ 1, 2 ], },
);

## splice

apply_update(
  "splice add",
  { a => [ 0, 1, ], },
  { a => { '$splice' => [ [ 1, 0, 8, 9, ] ] } },
  { a => [ 0, 8, 9, 1 ], },
);

apply_update(
  "splice del",
  { a => [ 0, 1, 2 ], },
  { a => { '$splice' => [ [ 1, 1, 8, 9, ] ] } },
  { a => [ 0, 8, 9, 2 ], },
);

apply_update(
  "splice multi",
  { a => [ 0, 1, 2 ], },
  { a => { '$splice' => [ [ 1, 1, 8, 9, ], [ 0, 2, 6, {a => 1}, ] ] } },
  { a => [ 6, { a => 1 }, 9, 2 ], },
);

apply_update(
  "splice auto-vivify",
  {},
  { a => { '$splice' => [ [ 0, 0, 8, 9, ] ] } },
  { a => [ 8, 9 ], },
);
