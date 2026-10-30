# A natural sort, in Delf, Delphi and C++

`file2` before `file10`: names sorted as people expect, with runs of digits compared by
value. The same program in four Delf phases, plain Delphi and C++23, checked against
Windows' own `StrCmpLogicalW`, the function Explorer sorts with. Phases 3 and 4 match it
exactly on 6,000 real file names; phase 4 by stating Explorer's rule, with no call to
Windows in its comparison.

| File | What | Lines |
|---|---|---:|
| [`1-chunks.delf`](1-chunks.delf) | **Delf**: a name is a list of chunks, a sum type `Digits(…) \| Text(…)`, compared with a `match` on a pair, in a loop | 118 |
| [`1-chunks.dpr`](1-chunks.dpr) | the Delphi that delfc, Delf's transpiler, wrote from it, unedited: plain Delphi, using Delf's small runtime unit `Delf.Prelude` (for `Take`) | 200 |
| [`2-pipeline.delf`](2-pipeline.delf) | **Delf, phase 2**: the same, with `Chunks` and `NaturalCompare` as pipelines (`Runs`, `ZipWith`) | 121 |
| [`2-pipeline.dpr`](2-pipeline.dpr) | delfc's Delphi for phase 2 | 199 |
| [`3-windows.delf`](3-windows.delf) | **Delf, phase 3: Explorer's order exactly.** Each name becomes a sort key compared by Windows' own text comparison | 135 |
| [`3-windows.dpr`](3-windows.dpr) | delfc's Delphi for phase 3 | 201 |
| [`4-kinds.delf`](4-kinds.delf) | **Delf, phase 4: Explorer's rule, stated.** Tokens of three kinds, `TKind = (Symbol, Digit, Letter)` in Explorer's order, compared by `Ord` | 179 |
| [`4-kinds.dpr`](4-kinds.dpr) | delfc's Delphi for phase 4 | 266 |
| [`delphi/NaturalSort.dpr`](delphi/NaturalSort.dpr) | **plain Delphi**, written as a Delphi programmer would: one pass over both names with an index into each | 110 |
| [`cpp/natural_sort23.cpp`](cpp/natural_sort23.cpp) | **C++23**: `std::variant` for the chunks, `std::visit` over two of them, `std::views::zip` | 110 |

The rules of phases 1 and 2, the plain Delphi and the C++:
- digits compare by value, kept as text so any length works (`item99999999999999999999`);
- for the same value, more leading zeros come first (`file02` before `file2`), as Explorer
  has it;
- text compares ignoring case;
- a run of digits comes before text.

Phase 3 keeps the first two and takes the rest from Windows, as Explorer does (below: real
names showed the difference).

## Result

Over 21 names, chosen to catch the hard cases, each version prints its own order beside
Explorer's. Every program (the three Delf phases, Delphi, C++23) prints the same 21 lines, and
every row agrees with Explorer:

```
a1b           a3a           a3b           a20           a100          a-b
ab1           abc           file1.txt     File1.txt     file02.txt    file2.txt
file10.txt    item100       item99999999999999999999    version 1.9   version 1.10
x001          x01           x9z           x10y
```

(Run on Delphi 13's dcc64 and C++Builder 13's bcc64x, Win64, 31 Oct 2026.)

### On 2,000 real file names

Given a file of names, one per line, each Delphi and Delf program sorts them and lists the
neighbours in its order that Explorer would put the other way round. On 2,000 distinct file
names taken at random from a development machine's disks (638 with digits), 31 Oct:

- **Both Delf phases and the plain Delphi version agree exactly**, the same 105 pairs: delfc's
  output does what the hand-written program does. (The C++23 version wasn't run on them: it
  prints names as narrow ASCII.)
- **Explorer puts 105 of the 1,999 neighbouring pairs the other way round**, and every one is
  about punctuation, none about digits. Values, leading zeros and long runs of digits agree
  throughout.

| Pairs | Ours first | Explorer first | Why |
|---:|---|---|---|
| 52 | `alpha.txt` | `al_pha.txt` | Windows puts symbols before letters; ours compares upper-cased character codes, and `_` (95) comes after `A`–`Z` |
| 30 | `my-zebra.txt` | `myapple.txt` | Windows' text comparison ignores hyphens: it compares `myzebra` with `myapple` |
| 17 | `icon1.ico` | `icon.ico` | ours puts a run of digits before any text; Windows puts punctuation before digits |
| 6 | | | the same two causes, with `@`, `[`, `(`, a space |

The 21 names above didn't show it: none had a `_` or a `-` beside a letter.

### Phase 3: Explorer's order

The user (31 Oct): *"The point of nat sort is to mirror windows .. so we should do that, as
another version again."* Comparing chunk by chunk with Windows' text comparison got to 24
disagreements, and the rest showed why that can't reach 0: Windows compares *across* the
boundary between letters and digits (`exp_edit` before `exp2l`, since `_` comes before `2`).
So phase 3 turns each name into a **sort key** and lets Windows compare the keys
(`AnsiCompareText`, its `CompareString`): text as it is, and each run of digits as its count
of significant digits, the digits, and 99 less its leading zeros, each count two digits:

```pascal
function KeyPart(const C: TChunk): string;
begin
  Exit( match C of
          | Digits(V) : Format('%.2d%s%.2d', [Bare(V).Length, Bare(V), 99 - (V.Length - Bare(V).Length)])
          | Text(V)   : V
        end );
end;
```

`file10.txt` becomes `file021099.txt`; `file2` comes before `file10` because `01…` comes
before `02…`, and `file02` before `file2` because `98` comes before `99` there.

**Result: 0 of 1,999 neighbours the other way round**, on this sample and on a second one
of 2,000 different names (seed 2, 28 names in common), where phases 1 and 2 had 102. A run
of more than 99 significant digits, or 99 leading zeros, would break the key.

### Phase 4: Explorer's rule, stated

The user (31 Oct): *"Comparing via Windows misses the point of the code. There are 3 enum
values .. or 2 nested enums. Can we use the ord of the enums to our advantage?"* Phase 3 was
right, but by handing the decision to Windows; the program no longer said what the rule is.
Phase 4 says it. A name is a list of **tokens**, a run of digits or one other character, and
every token is one of three kinds, declared in Explorer's order:

```pascal
TKind = (Symbol, Digit, Letter);    // Explorer's order: Ord compares them

function CompareTokens(const A, B: TToken): Integer;
begin
  const K = CompareValue(Ord(KindOf(A)), Ord(KindOf(B)));
  if K <> 0 then Exit( K );
  Exit( match (A, B) of
          | (Number(X), Number(Y)) : CompareDigits(X, Y)
          | (Single(C), Single(D)) : CompareValue(Rank(C), Rank(D))
          | _                      : 0      // different kinds: decided above
        end );
end;
```

`Ord` alone puts `_` before letters and `.` before digits, the 69 disagreements of the first
table that weren't about hyphens. Letters compare ignoring case; two symbols by Explorer's
order among them; a hyphen and an apostrophe make no token, since Explorer ignores them. A
name's tokens are a pipeline, `S.Runs(IsDigit).AndThen(ToTokens)`, the list monad's bind.

The one piece of data, Explorer's order among the symbols and the two it ignores, was
measured once with a probe of `StrCmpLogicalW` on each printable ASCII symbol and is written
into the program as constants:

```pascal
Symbols = ' !"#$%&()*,./:;?@[\]^_`{|}~+<=>';   // not ASCII order: +<=> come after ~
Ignored = '-''';
```

"Two nested enums" (`Digits | Text`, with `Symbol | Letter` inside `Text`) names the same
kinds, but Explorer's order interleaves them, symbol, digit, letter, so one enum of three is
what `Ord` can compare.

**Result: 0 of 1,999 neighbours the other way round on all three samples**, the third (seed
3) not used while building phases 3 and 4; phase 1 had 121 there. And the 21 names above.

## Building

```
dcc64 -U<runtime> 1-chunks.dpr                      (the Delf version, as delfc wrote it)
dcc64 -U<runtime> 2-pipeline.dpr                    (phase 2)
dcc64 -U<runtime> 3-windows.dpr                     (phase 3)
dcc64 -U<runtime> 4-kinds.dpr                       (phase 4)
dcc64 delphi\NaturalSort.dpr
bcc64x -O2 -std=c++23 cpp\natural_sort23.cpp -lshlwapi -o natural_sort23.exe
```

`<runtime>` is the folder with Delf's runtime units (`Delf.Prelude.pas`, `Delf.Optional.pas`,
`Delf.Tuples.pas`), plain Delphi too.

Each program run with a file of names (`1-chunks.exe names.txt`) compares on those instead.
`tools/collect.py names.txt <folder>…` picks 2,000 distinct file names under the folders
given (seeded, so repeatable; `SEED=2` for another sample); `tools/kinds.py <output>` groups
the disagreements by the characters where the two names part.

## What writing it in Delf showed

- **The sum type says what a name is made of.** `TChunk = | Digits(Value: string) |
  Text(Value: string)`, and the comparison is a `match`, checked for every case. The plain
  Delphi version keeps the same knowledge in index arithmetic.
- **A `match` on a pair, built for this.** The C++ version compares two chunks with one
  `std::visit` over both, four cases in one place. Delf now does the same, every pair
  covered, or delfc says which is missing:

  ```pascal
  Exit( match (A, B) of
          | (Digits(X), Digits(Y)) : CompareDigits(X, Y)
          | (Digits(_), Text(_))   : -1
          | (Text(_),   Digits(_)) : 1
          | (Text(S),   Text(T))   : CompareText(S, T)
        end );
  ```

  delfc writes it as a `case` on `A` with a `case` on `B` in each arm. The program got there
  in three steps the same day: a function per inner `match`, because a nested `match` came
  out as invalid Delphi (a delfc bug, then fixed); a `match` nested in each arm; this.
- **A span, built for this.** `NaturalCompare`'s loop works out its bound first, then
  enumerates that many chunks of one name: `for const (I, P) in X.Take(N).Enumerate do`.
  `Take` is a span, a view of part of the array, with no copy: the array, a start and a count.
  It was added to Delf's library because of this loop; the first version, `Copy(X, 0, N)`,
  copied the chunks on every comparison.
- **Phase 2: pipelines, built for this too.** Cutting a name into runs, and "the first
  comparison that isn't 0, else the lengths", are each one expression with two library
  routines added for them, `Runs` (Haskell's `groupBy`) and `ZipWith`:

  ```pascal
  Exit( S.Runs(IsDigit).Map(ToChunk) );
  …
  Exit( X.ZipWith(Y, CompareChunks).Find(λC -> C <> 0).OrDefault(CompareValue(X.Length, Y.Length)) );
  ```

  The second is the ordering monoid: compare pair by pair, the first difference wins.
  `ZipWith` compares every pair, where phase 1's loop stops at the first difference; a lazy
  pipeline would stop too.
