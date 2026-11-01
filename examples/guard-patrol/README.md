# The guard patrol, in Delf

Advent of Code 2024, day 6, part 1, on the puzzle's published sample: a guard walks a grid,
turning right at each obstacle, until it leaves the map. The same program in seven versions,
each adding one Delf feature, and beside each the Delphi that delfc, Delf's transpiler, wrote
from it, unedited.

| File | What | Lines |
|---|---|---:|
| [`1-tuples.delf`](1-tuples.delf) | positions and directions as tuples | 126 |
| [`2-match.delf`](2-match.delf) | each step a sum type, `Moved(…) \| Turned(…) \| Exited`, taken apart with `match` | 119 |
| [`3-optional.delf`](3-optional.delf) | a cell off the map is `Absent`: `Optional`, matched with nested patterns | 137 |
| [`3b-optional-grid.delf`](3b-optional-grid.delf) | a side step: the grid as a record, points still tuples | 163 |
| [`4-grid.delf`](4-grid.delf) | `TPoint`, and a generic `TGrid<T>` in a Delf unit of its own, [`Demo.Grids`](Demo.Grids.delf) | 134 |
| [`5-grid-optional.delf`](5-grid-optional.delf) | the grid partial, [`Demo.OptionalGrids`](Demo.OptionalGrids.delf): `TryGet` answers `Optional`, `Start` returns `Optional<TPoint>`, lambdas map the grid | 151 |
| [`5b-grid-inline.delf`](5b-grid-inline.delf) | version 5 with the lambda passed inline, `Input.Map(λch -> …)` | 163 |

Each `.delf` has its `.dpr` beside it, and each unit its `.pas`.

## Result

Every version prints the same:

```
start: (4, 6)
turns: 10
visited: 41
```

(Versions 1 to 4 write the start as `4 6`.)

## Building

```
dcc64 -Uruntime 5-grid-optional.dpr
```

and the same for each version. [`runtime/`](runtime/) holds Delf's small runtime units, plain
Delphi too.
