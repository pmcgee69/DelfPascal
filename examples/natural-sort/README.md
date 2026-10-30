# A natural sort, four ways

`file2` before `file10`: names sorted as people expect, with runs of digits compared by
value. The same program four ways, checked against Windows' own `StrCmpLogicalW`, the
function Explorer sorts with.

| File | What | Lines |
|---|---|---:|
| [`1-chunks.delf`](1-chunks.delf) | **Delf**: a name is a list of chunks, a sum type `Digits(…) \| Text(…)`, compared with `match` | 131 |
| [`1-chunks.dpr`](1-chunks.dpr) | the Delphi that delfc, Delf's transpiler, wrote from it, unedited: plain Delphi, using Delf's small runtime unit `Delf.Prelude` (for `Take`) | 213 |
| [`delphi/NaturalSort.dpr`](delphi/NaturalSort.dpr) | **plain Delphi**, written as a Delphi programmer would: one pass over both names with an index into each | 110 |
| [`cpp/natural_sort23.cpp`](cpp/natural_sort23.cpp) | **C++23**: `std::variant` for the chunks, `std::visit` over two of them, `std::views::zip` | 110 |

The rules, the same in all four:
- digits compare by value, kept as text so any length works (`item99999999999999999999`);
- for the same value, more leading zeros come first (`file02` before `file2`), as Explorer
  has it;
- text compares ignoring case;
- a run of digits comes before text.

## Result

Over 21 names, chosen to catch the hard cases, each version prints its own order beside
Explorer's. All three print the same 21 lines, and every row agrees with Explorer:

```
a1b           a3a           a3b           a20           a100          a-b
ab1           abc           file1.txt     File1.txt     file02.txt    file2.txt
file10.txt    item100       item99999999999999999999    version 1.9   version 1.10
x001          x01           x9z           x10y
```

(Run on Delphi 13's dcc64 and C++Builder 13's bcc64x, Win64, 31 Oct 2026.)

## Building

```
dcc64 -U<runtime> 1-chunks.dpr                      (the Delf version, as delfc wrote it)
dcc64 delphi\NaturalSort.dpr
bcc64x -O2 -std=c++23 cpp\natural_sort23.cpp -lshlwapi -o natural_sort23.exe
```

`<runtime>` is the folder with Delf's runtime units (`Delf.Prelude.pas`, `Delf.Optional.pas`,
`Delf.Tuples.pas`), plain Delphi too.

## What writing it in Delf showed

- **The sum type says what a name is made of.** `TChunk = | Digits(Value: string) |
  Text(Value: string)`, and the comparison is a `match`, checked for every case. The plain
  Delphi version keeps the same knowledge in index arithmetic.
- **Delf wants a `match` on a pair.** The C++ version compares two chunks with one
  `std::visit` over both, four cases in one place. Delf today needs a `match` inside a
  function per first chunk (`DigitsAgainst`, `TextAgainst`). With a `match` on a pair:

  ```pascal
  Exit( match (A, B) of
          | (Digits(X), Digits(Y)) : CompareDigits(X, Y)
          | (Digits(_), Text(_))   : -1
          | (Text(_),   Digits(_)) : 1
          | (Text(S),   Text(T))   : CompareText(S, T)
        end );
  ```

  That's planned, not built.
- **A nested `match` as an arm's value** isn't translated by delfc yet (it wrote invalid
  Delphi, without a word; to be fixed).
- **A span, built for this.** `NaturalCompare`'s loop works out its bound first, then
  enumerates that many chunks of one name: `for const (I, P) in X.Take(N).Enumerate do`.
  `Take` is a span, a view of part of the array, with no copy: the array, a start and a count.
  It was added to Delf's library because of this loop; the first version, `Copy(X, 0, N)`,
  copied the chunks on every comparison.
- **`Zip`** would let the loop read as C++'s `std::views::zip` does, walking both names'
  chunks together.
