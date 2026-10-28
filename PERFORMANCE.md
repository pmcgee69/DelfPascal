# Performance

Delf's aim is to be **as efficient as good hand-written Delphi**. C++ is an aspirational
benchmark; the bar that matters is the best Delphi that careful programmers write.

All measurements on one machine, October 2026: Delphi 13 (dcc32 and dcc64 37.0) and
C++Builder (bcc32c and bcc64, LLVM 5.0.2; bcc64x, Clang 20.1.7), `-O2`. Single runs unless
said; one run varies by 10–15%. Each comparison is an experiment with its predictions written
before it ran ([EXPERIMENTS.md](EXPERIMENTS.md), 47–49).

## Quicksort (experiment 49)

The same quicksort in Delf and C++ (middle pivot, Hoare partition, insertion sort below 17
elements, recursion on the smaller side), beside each library's own sort. 10,000,000 values
from one generator in both languages; every sort of a type gives the same checksum. Win64, ms:

| | Integer | Word | AnsiChar |
|---|---|---|---|
| Delf quicksort, one overload per type | 740 | 580 | 367 |
| mORMot2's `QuickSortInteger` / `QuickSortWord` (Arnaud Bouchez) | 768 | 567 | — |
| Spring4D's `TArray.Sort<T>` (Stefan Glienke) | 892 | 709 | — |
| Delf quicksort, one generic through `IComparer<T>` | 1,218 | 857 | 611 |
| The RTL's `TArray.Sort<T>` | 1,249 | 842 | 556 |
| The same quicksort in C++ (bcc64 / bcc64x) | 669 / 656 | 502 / 500 | 335 / 331 |
| `std::sort` (bcc64) | 770 | 543 | 252 |
| `std::sort` (bcc64x) | **272** | **182** | **91** |

Variants, Integer, Win64, two runs each:

| | ms |
|---|---|
| Delf quicksort written with tuples: `(a[i], a[j]) := (a[j], a[i])`, `(i, j) := (i+1, j-1)`, `for const k in [lo+1..hi]` | 740 / 740 |
| The same, plain | 750 / 757 |
| The same with tuples, no insertion sort | 842 / 855 |

## `next_permutation` (experiments 47, 48)

Paul McGee's own `Next_Permutation` (after the SGI STL) on `TList<Integer>`, a Delf version
on `TArray`, and `std::next_permutation`. A full cycle of 12 items, 479,001,599 steps, ms:

| | Win64 | Win32 |
|---|---|---|
| The original, `TList<Integer>`, `Word` indexes | 9,395 | 9,825 |
| Delf, `TArray`, one overload per type | 1,873 | 2,713 |
| Delf, one generic through `IComparer<T>` | 4,065 | 5,074 |
| `std::next_permutation` (bcc64 / bcc32c) | 852 | 1,028 |
| `std::next_permutation` (bcc64x) | 981 | — |

`Word` and `AnsiChar` are within a few percent of `Integer` for the overloads; bcc32c's
`char` is twice its `int`; `-O3` is no different from `-O2`.

## What they say

1. **Delf's output meets the bar:** its quicksort is within about 4% of mORMot2's, the
   fastest hand-written Delphi sort in the corpus.
2. **delfc's translation costs nothing measurable,** tuples and ranges included: the output
   is the Delphi one would write.
3. **Comparing through `IComparer<T>` costs 1.5× to 2.2×,** and the RTL's own sort pays it.
   A Delphi generic can't write `A < B` on a type parameter, so it compares through an
   interface, as Haskell passes a type class's dictionary. Writing the routine once per type,
   as C++ templates and Rust do (monomorphisation), removes the cost; for Delf that means an
   `Ord` constraint and delfc writing the per-type copies itself.
4. **On the same algorithm, Delphi and C++ are within about 10%.** C++'s advantage is its
   library: bcc64x's `std::sort` is 2.7× faster than any quicksort written here, in either
   language. A faster Delphi sort is an algorithm to port (introsort), not a compiler to wait for.

## Next

Several runs per build and the median; why `next_permutation`'s gap to C++ is larger than
quicksort's; introsort in Delf, against `TArray.Sort`, Spring4D and mORMot2; the collections of
Erik van Bilsen's GrijjyFoundation and Neslib; monomorphisation in delfc.
