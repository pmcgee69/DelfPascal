# Experiments

Every claim the design makes about what Delphi's compiler does is checked on dcc32 (and
mostly dcc64) before it is relied on. Each experiment is a small program, one test behind
each `{$DEFINE}`, with **its predictions written in the header before it is compiled**, so a
wrong prediction stays recorded as wrong. Delphi 13 (37.0) throughout. Some are surveys of
real code instead (see [CORPUS.md](CORPUS.md)).

## Function types and method references (1–4, 6, 46)

- A class can implement `TFunc<…>` by supplying `Invoke`, and an interface can inherit from
  one; method references are **structurally typed**: `type X = type TProc<string>` doesn't
  make a distinct type, and neither do two separate `reference to` declarations (4, 4b, 4c).
- A one-field record wrapper is the way to a distinct function type, at pointer size (6, 6b).
- A bare parameterless name is read as a call, or, where a function type is expected, as a
  reference; dcc32 takes every parameterless routine as a function value **except a
  constructor** (46), which delfc therefore writes as an anonymous method.

## Generics, constraints and inference (5, 8, 10, 18, 42, 43)

- Where a recursive record stops: a record may hold `TArray<` itself `>`, a generic one may
  not (E2086), and the workaround is nesting it in a generic container (5a–5h).
- An `Optional<T>` record with a flag and a value; nil tests and narrowing on an
  unconstrained `T`, and where constraints refuse (8, 10a–10g).
- **dcc32 doesn't infer type arguments** through `TArray<T>` (18), from the expected type, or
  through an anonymous method (42), so delfc writes them out.
- Overloads differing only in their type parameters are accepted; the number written picks
  one (43).

## The language's edges (12–16, 20, 22–25, 27–29, 41)

- Milewski's Writer category in plain Delphi (12); Delphi 13's conditional expression,
  `if C then X else Y`, its precedence and typing (13).
- Where Delf's syntax collides with Delphi's (14), among them `O is TObject and X`, which
  dcc32 reads as `(O is TObject) and X`.
- **Plain `const` is by value or by reference depending on size, platform, kind and calling
  convention**; only `const [ref]` is the same everywhere, and a `const` string replaced
  mid-call reads freed memory (15).
- `FreeAndNil` through a property's getter frees the object and leaves the field dangling;
  through an **inline** getter, whether it dangles depends on `{$INLINE}` (16).
- `noreturn`, and when dcc32 forgets it (20, 41).
- `a < b, c > (d)`: dcc32 decides between two comparisons and a generic call by what `a` is
  (22). What type a named constant gives (23).
- **A set range past 255 wraps mod 256, silently**, and `X in [A..B]` differs between Win32
  and Win64 (24). A loop variable can be changed through a `var` parameter (25).
- What goes in the `else` of an exhaustive `case` (27, 28). A `Boolean` holding 2 is true
  for `if`, false for `= True`, and takes neither arm of a `case`; `not B` differs between
  Win32 and Win64 (29).

## Units, conditionals and real code (30–40, 44, 45)

- How often function results are discarded in real code (30). What a type alias and a
  constant carry into another unit (31). What an unused unit in `uses` costs (34).
- **The door** (32): every corpus file through delfc as plain Delphi and renamed to `.delf`,
  run after every change since (see [CORPUS.md](CORPUS.md)).
- Which conditional symbols each compiler defines by itself (33); where conditionals stand
  in real code and what shapes they take (35, 36, 39).
- Two parsers on the same files: tree-sitter-delphi13 and Olaf Monien's DX.DelphiLanguage
  (37); two of DX's lexer rules checked on both compilers, comments don't nest and `0EBH` is
  an integer, and merged into DX (40).
- A latent platform difference in real code, from experiment 24's set ranges (38; details
  with its authors first).
- **Which unit a name means** when two used units declare it: the later one hides the earlier,
  routines marked `overload` merge across units (44). A unit scope name like `SysUtils` works
  only through the `-NS` prefixes; `System.SysUtils` always (45).

## Performance (47–49)

`next_permutation` and quicksort: delfc's output against hand-written Delphi (mORMot2,
Spring4D, the RTL) and C++. See [PERFORMANCE.md](PERFORMANCE.md).

## Planned

What dcc32 infers by itself (19); whether Delphi can load delfc's parser (21); what an enum
with explicit values loses (26).
