# Delf

**Delphi with a modern functional-influenced type system, transpiling to plain Delphi.**

**Website: [pmcgee69.github.io/DelfPascal](https://pmcgee69.github.io/DelfPascal/)**: videos, articles and the slides.

Delf is an aspirational Delphi preprocessor design project. 
A Delf file is Delphi with additions of syntax and code-correctness:
- sum types (`Optional`, Rust Results) and
- pattern matching (`match`) - in place of nil and sentinel values, 
- raw tuples,
- lambdas with inferred types,  `λch -> ord(ch)`
- arrow function notation and   `function test: (char -> byte)`
- no implicit conversions,
- mandatory exhaustive cases,
- checking for exhaustive, empty, or invalid conditional-compilation directives.

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

<img width="1250" height="812" alt="image" src="https://github.com/user-attachments/assets/3ca7c18d-6d75-4972-948a-f89e12f3fb9a" />


## The approach

- **Stage 1 changes declarations; Stage 2 changes control flow.**

  A Stage 1 rewrite has the same shape as the original: the same loops, statements and order.
  What changes is what things are *declared as*, and so what the compiler can check. 
  Stage 2 (lazy sequences, pipelines, fusion, generators) comes later.
- **Predict first, then compile.** 

  Every claim about what dcc32 does is a prediction until it
  has been compiled, and the prediction is written down *before* the experiment runs, so a
  wrong one stays recorded as wrong. 60 experiments so far; the first 49 are summarised in
  [EXPERIMENTS.md](EXPERIMENTS.md).
- **The Door.** 

  Rename any Delphi file to `.delf` and nothing changes: the same output, no
  new errors .. but some increased checks as warnings or hints. 
  delfc is checked against real code, 18,524 distinct files from the
  Delphi RTL and VCL and 123 open-source repositories with some of their branches: [CORPUS.md](CORPUS.md).
- **Better safety without red tape.** 

  A safety rule that makes the writer repeat themselves is a sign the syntax is missing something.
- **Ideally no cost at run time.** 

  delfc's output should be as fast as good hand-written Delphi: [PERFORMANCE.md](PERFORMANCE.md).

<img width="1552" height="737" alt="image" src="https://github.com/user-attachments/assets/43cb6612-71c5-40e0-8ce4-2eb810ce21c7" />

## What works today

delfc, atm a proof of concept in Python on a tree-sitter grammar, translates:

- **Stage 1's syntax:** 
  `λ` lambdas, 
  function types `(A -> B)`, 
  free generic functions with type inference from arguments and from the expected type (`_` for a slot left to infer),
  tuples and destructuring, 
  record literals, 
  UFCS (`Xs.Map(F)` for `Map(Xs, F)`),
  a member as a function (`Xs.Map(.ToString)` for `Xs.Map(λx -> x.ToString)`),
  `const X := …`, and its short form `X ← …`,
  `for const`, 
  `for var (i, X) in Xs.Enumerate`, 
  `[0..10_000]`
- **A library** delfc adds as needed, in plain Delphi units: `Filter`, `Map`, `Join`, `Count`,
  `Max`, `Find`, `Take`, `ZipWith`, `Iota`, `CallN` and more on arrays, and `Optional`'s own.
- **Errors where they belong:** a name declared nowhere is an error where it's used, not
  a confusing one later; so is a value given to a `const` binding, or a reserved word used as
  a name. delfc says what to write, where it can.
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
  the units a file uses are read, for their types, routines and helpers, with names resolved as dcc32 resolves them;
  a project's `.delf` files built by dcc64 or dcc32, its messages mapped back to the Delf lines.
- **The editor:** a [Zed](https://zed.dev) extension and a language server, not yet published
  (the [video](https://www.youtube.com/watch?v=JXxUftwcHmQ) shows them). Highlighting, with
  functions and methods told apart by what a call really calls; delfc's errors as you type,
  dcc64's once typing pauses; inferred types as ghost text; hover on any name, a generic
  call's inferred type arguments included; go to definition, into used units and the RTL;
  find references; completion of members and unit names; build tasks.

Plain Delphi passes through delfc byte-identical; it gets only checks. Every test's output
compiles on dcc32 and dcc64 as predicted. On the large corpus, a Delphi file renamed to
`.delf` gets an error of delfc's own in 0.8% of cases (148 of 18,524 files, 5 Nov 2026).

## Around Delf: the preprocessor starter and TreeSitter4D

Two public repositories grew out of delfc, for standard Delphi today.

**[delphi-preprocessor-starter](https://github.com/pmcgee69/delphi-preprocessor-starter)**
is delfc's core as a starting point for your own rules: checks that report and rewrites that
change the source, on a tree-sitter parse of plain Delphi. Nine example rules (`with`
statements, `Assert` messages, merged `uses` clauses, `case` on strings, auto properties,
footnotes after `end.` that become XMLDoc, `[Derive(ToString)]` on an enumeration, and more),
each tested against expected output, and run over a whole codebase before being trusted. The same engine and rules in Python and in Delphi; over Delphi 13's
`source\rtl\common` the two agree line for line and byte for byte.

- **In Zed:** the rules underline what they would change as you type, hover shows the new
  text, and a key applies it.
- **In the Delphi IDE:** a `.dpps` source is rewritten by the rules in a project's
  pre-build event, run by `delphipp.exe`, itself built in the IDE from `delphipp.dproj` (no
  Python needed); the rules' errors are listed in the Messages pane on the source's lines.
  dcc's own errors name the `.dpps` and its lines too: the generated `.pas` carries dcc's
  `{$LINE N 'file'}` directive, so a double-click opens the source, and the debugger steps
  through it ([the video](https://youtu.be/LJM2JrihDWU)). The example's footnotes after `end.`
  become XMLDoc, and Help Insight shows them, with a link to the `.dpps`
  ([the screenshot](https://github.com/pmcgee69/delphi-preprocessor-starter/blob/main/examples/ide/footnotes-help-insight.png)).
  Its enumeration `TMood = (Calm, Excited)`, marked `[Derive(ToString)]`, gets a record helper
  whose `ToString` the greeting prints, `(Excited)`; every line of the generated code names the
  attribute's line, so an error or a step in it lands there. Its `case` on strings becomes an
  `if` chain that keeps each arm on its own line.
  An IDE package shows what the rules change in the editor as you type, with a hover.

**[TreeSitter4D](https://github.com/pmcgee69/TreeSitter4D)** is tree-sitter, the parsing
library under all of this, built with C++Builder's compilers and used from Delphi and
C++Builder programs, Win64 and Win32. The C links straight into the executable with `{$L}`, so
there are no DLLs unless you want them; a [release](https://github.com/pmcgee69/TreeSitter4D/releases)
(v0.2.0) carries the C compiled, so nothing but Delphi is needed. The same tree walker is
written in Delphi, C++17, C++23 and Delf, with delfc's output beside it. The starter's Delphi
side is built on it.

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
- [snippets](snippets/): Delf as posted on the ADUG forum, exactly as written, the same code
  two ways side by side.
- [examples/guard-patrol](examples/guard-patrol/): Advent of Code 2024 day 6 in seven Delf
  versions, each adding a feature (tuples, sum types and `match`, `Optional`, a generic grid,
  lambdas), with what delfc writes from each.
- [examples/hangman](examples/hangman/): a small game: `match` on strings, `Enumerate`.
- [examples/natural-sort](examples/natural-sort/): a natural sort (`file2` before `file10`)
  in Delf, as delfc translates it, in plain Delphi and in C++23, all four checked against
  Explorer's order.
- [delphi-preprocessor-starter](https://github.com/pmcgee69/delphi-preprocessor-starter) and
  [TreeSitter4D](https://github.com/pmcgee69/TreeSitter4D): see
  [Around Delf](#around-delf-the-preprocessor-starter-and-treesitter4d).
