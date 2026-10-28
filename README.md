# Delf

**Delphi with a modern functional-influenced type system, transpiling to plain Delphi.**

Delf is an aspirational Delphi preprocessor design project. 
A Delf file is Delphi with additions of syntax and code-correctness:
- sum types (`Optional`, Rust Results) and
- pattern matching (`match`) - in place of nil and sentinel values, 
- raw tuples,
- lambdas with inferred types,  `λch -> ord(ch)`
- arrow function notation and   `function test: (char -> byte)`
- no implicit conversions,
- mandatory exhaustive cases,
- checking for exhaustive, empty, or invalid compiler directives.

A transpiler, **delfc**, turns it into readable, standard Delphi (currently compiling on dcc32, dcc64), that a Delphi programmer could have written
by hand and can step through in the debugger.

Inspired by several ideas: 
- "Correct by construction"
- "Make illegal states impossible to represent"
- "Parse don't validate"
- functional influences: expression-based, implicit loops, immutability encouraged, 1st class functions, strong generic type inference.
  
A stricter, **more** functional, **Paskell**, is a separate idea for later.

This repository is the public summary: the approach, what works today, what's planned, and the evidence. 
The design work itself, the specification, the notes and delfc's source, lives in a private repository for now.

## The approach

- **Stage 1 changes declarations; Stage 2 changes control flow.**

  A Stage 1 rewrite has the same shape as the original: the same loops, statements and order.
  What changes is what things are *declared as*, and so what the compiler can check. 
  Stage 2 (lazy sequences, pipelines, fusion, generators) comes later.
- **Predict first, then compile.** 

  Every claim about what dcc32 does is a prediction until it
  has been compiled, and the prediction is written down *before* the experiment runs, so a
  wrong one stays recorded as wrong. 49 experiments so far: [EXPERIMENTS.md](EXPERIMENTS.md).
- **The Door.** 

  Rename any Delphi file to `.delf` and nothing changes: the same output, no
  new errors .. but some increased checks as warnings or hints. 
  delfc is checked against real code, over 17,000 files from the
  Delphi RTL and VCL and 116 open-source repositories: [CORPUS.md](CORPUS.md).
- **Better safety without red tape.** 

  A safety rule that makes the writer repeat themselves is a sign the syntax is missing something.
- **Ideally no cost at run time.** 

  delfc's output should be as fast as good hand-written Delphi: [PERFORMANCE.md](PERFORMANCE.md).

## What works today

delfc, atm a proof of concept in Python on a tree-sitter grammar, translates:

- **Stage 1's syntax:** 
  `λ` lambdas, 
  function types `(A -> B)`, 
  free generic functions with type inference from arguments and from the expected type (`_` for a slot left to infer),
  tuples and destructuring, 
  record literals, 
  UFCS (`Xs.Map(F)` for `Map(Xs, F)`),
  `const X := …`, 
  `for const`, 
  `for var (i, X) in Xs.Enumerate`, 
  `[0..10_000]`
- **Sum types and `match`**
  exhaustive, 
  with nested patterns, 
  `match` on strings, 
  a mandatory trapdoor `else` for corrupt values, and 
  the built-in `Optional<T>` with narrowing,  `if S is Present(V) then …`.
- **Conditional compilation:** 
  every `{$IFDEF}` branch translated, each configuration checked, 
  including the project's own builds from its `.dproj`, 
  and constant arrays' lengths counted against their entries in every configuration.
- **Real projects:** 
  the units a file uses are read, for their types, routines and helpers, with names resolved as dcc32 resolves them.

Plain Delphi passes through delfc byte-identical; it gets only checks. Every test's output
compiles on dcc32 and dcc64 as predicted. On the large corpus, a Delphi file renamed to
`.delf` gets an error in about 1.5% of cases, mostly conditional-compilation fragments.

## What's planned

- **Language:** Delf enums scoped in the output; `match` with guards and several
  scrutinees; recursive sums; partial application; type comments (`{:: T}` as hint and
  assert, `{:: ?}` as query); field sections (`required`, `immutable`, `owned`, `once`);
  ownership; then Stage 2.
- **delfc:** an `Ord` constraint, and delfc writing a generic routine out once per type
  (monomorphisation), which experiments 48 and 49 show is worth 1.6–2.2×; more RTL units;
  older project formats.
- **Migration:** tools that tell a developer a file's move from `.pas` to `.delf` changed
  nothing it shouldn't: a per-file door check, the routines the output changes, generated
  characterization tests.
- **An algorithms library** after C++'s `<algorithm>`, written in Delf, measured against
  hand-written Delphi and against C++ itself.
- **Rewriting libraries in Delf**, to show nicer, more robust code at no cost in speed.
- **In the long run, with no hurry:** the toolchain in Delphi.

## The slides

Two decks, as PDFs in [`docs/`](docs/):

- [*Finding the start*](docs/Finding-the-start.pdf): one search, written every way Delf allows, and what delfc writes.
- [*The big ideas*](docs/Delf-big-ideas.pdf): the present as a proof of concept, then the future.

## More

- [EXPERIMENTS.md](EXPERIMENTS.md): the 49 experiments and what each settled.
- [CORPUS.md](CORPUS.md): the code delfc is tested on, and how.
- [PERFORMANCE.md](PERFORMANCE.md): delfc's output against hand-written Delphi and C++.
