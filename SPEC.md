# Delf — translation specification

**Version:** 0.1, 18 November 2026

**Audience:** an LLM (or person) asked to produce a Delf version of existing Delphi
code, or to transpile Delf back to standard Delphi.

**Status:** Stage 1 is designed. Stage 2 is shaped but not specified. Anything not
described here does not exist yet — if you need it, say so rather than inventing it.

---

## 1. What Delf is

Delf is Delphi with the type system it should have had. It transpiles to readable
standard Delphi (10.4+, targeting 13) that a Delphi programmer could have written by
hand and can step through in the debugger.

Three rules govern every design decision, and they should govern your translations too:

1. **Would Embarcadero plausibly ship this?** Prefer keywords over glyphs, Pascal
   shapes over imported ones, extensions of existing constructs over new ones.
   *Second check:* **does any language do this, and if none does, why not?** Shape is
   the easy half of the filter. Several languages independently declining a feature is
   evidence about the feature, not about their conservatism.
2. **Boring output is a feature.** The transpiled Delphi must be recognisable. A
   demonstration whose output nobody can read has undermined itself.
3. **The reader is an experienced Delphi programmer who has not seen Rust, Haskell
   or F#.** Every construct must be guessable from context on first reading.

### What Delf is not

Delf is not a functional language. Loops stay loops. Statements stay statements.
Mutation stays available and idiomatic. The functional layer is a separate, later
language (**Paskell**) built on top of Delf, and it is out of scope here.

---

## 2. The stage line — read this before translating anything

**Stage 1 changes declarations. Stage 2 changes control flow.**

This is the single most important constraint on a translation. A Stage 1 rewrite of a
Delphi program has the same shape as the original: the same loops, the same order of
statements, the same functions. What changes is what things are *declared as*, and
what the compiler can therefore check.

| Stage 1 — use freely | Stage 2 — DO NOT USE unless explicitly asked |
|---|---|
| Sum types, `match`, exhaustiveness | Lazy sequences, `seq of T` pipelines |
| `Optional<T>` and its `Map`/`AndThen`/`OrDefault` | `.Map(...).Filter(...).Sum` over collections |
| Field sections (`immutable`, `required`, `owned`) | Fusion, `{$FUSE}` |
| Type inference on bindings and generic calls | `yield` / generators |
| `λ` lambdas | User-written combinator libraries |
| Free generic functions, UFCS | Persistent/immutable collections |
| Tuples, spontaneous records | Typestate |
| Ownership: scope-bound locals, `Free` consumes | |
| Non-null references | |
| Subtractive rules (§8) | |

**Why the line is there.** A Delphi programmer reading a Stage 1 rewrite sees Pascal
with better types and is persuaded. The same programmer reading
`Total := Lines.Map(...).Filter(...).Sum` sees a different language and stops reading.
Stage 1 has to land first.

**The one deliberate exception:** `Optional<T>`'s methods are Stage 1 even though they
chain. They are sugar over a two-arm `match`, not an evaluation strategy, and without
them `Optional` is worse than the `TryGetValue` it replaces. The test:
`Grid.Lookup(P).AndThen(...)` is a *type* operation on a single value — allowed.
`Items.Map(...).Sum` is a *control flow* replacement over a collection — Stage 2.

---

## 3. Declarations

### 3.1 Sum types

A sum type is a generalised enum: an enum whose members may carry payloads.

**Vertical form** — bars lead every arm, including the first. One `;` ends the whole
declaration. No punctuation between arms.

```pascal
type
  TStep =
    | Moved (Pos: TPoint)
    | Turned(Facing: TDir)
    | Exited;
```

**Horizontal form** — for single-line declarations, use the existing enum syntax:

```pascal
type
  TDir  = (Up, Right, Down, Left);
  TCell = (Open, Wall);
```

Both forms declare the same kind of type. A sum whose arms all have no payload **is**
an ordinary Delphi enum, and should be written with parens. Bars are the vertical-layout
marker only.

**Style rule:** use parens when it fits on one line and no arm has a payload; use bars
otherwise. Never mix on one declaration.

**Payload fields** are named and use parameter-list punctuation: `;` between fields,
`,` to share a type.

```pascal
type
  TExpr =
    | Num(Value: Double)
    | Add(L, R: TExpr)
    | Mul(L, R: TExpr);
```

Field names are scoped to their arm, so two arms may use the same field name:

```pascal
type
  TChunk =
    | Digits(Value: Int64)
    | Text  (Value: string);
```

**Arms are immutable.** A constructed value's payload cannot be modified. This is not
style: it is what guarantees sum values are acyclic, which is what makes the recursive
encoding sound.

### 3.2 Construction and qualification

Arm names are bare wherever the expected type is known, and qualified where nothing
supplies it. This is the same rule as literals taking their type from context.

```pascal
var P: TStep := Exited;          // annotation supplies it
Result := Moved(Next);           // result type supplies it
Handle(Turned(Turn(D)));         // parameter type supplies it
| Digits(_), Text(_): Less       // scrutinee and result type supply it

var P := TStep.Exited;           // nothing supplies it -> qualify
```

If two sums in scope declare the same arm name and nothing disambiguates, that is an
error listing both candidates, and the qualified form is required.

Plain enum values (user, 21 Oct; revised 29 Oct): an enum is declared as in Delphi, and
**the output** declares every Delf enum scoped and writes its values qualified,
`TDir.North`, between `{$SCOPEDENUMS ON}` and `{$SCOPEDENUMS OFF}` (the output is
generated, and *"not ideally even seen. It will be scoped"*, user, 29 Oct). **The source
isn't made to qualify** (user, 29 Oct: *"We don't necessarily want to force scoping … in delf
source. Its the output"*): `var D := Up` is Delphi's own inference and *"acceptable"*, and
delfc writes `TDir.Up`. Only when two Delf enums share the value, and nothing around it says
which (the expected type, the other side of a comparison or `in`, a `case`'s selector, an
assignment's target, a `for`'s variable), is it an error naming both.
**`{ delf: scopedenums }`** near the top of a file asks for more (user, 29 Oct: *"var D :=
Up is acceptable unless there is a { delf : scopedenums } to require it"*): a value where
nothing supplies its type (an inferred var, an untyped const, `Ord(Up)`) must be written
`TDir.Up`. That was 21 Oct's rule for every file. **`{ delf: scopedenums off }`** turns the
scoping off for a file (user, 29 Oct): its enums are declared unscoped in the output and
their values left as written. It is for a renamed Delphi file whose own enum values sit
inside conditional fragments, where qualifying them is a rewrite that makes the fragment
an error. **Not needed for that any more** (29 Oct; the user: *"isn't the scope issue the scope
text not landing in the correct location with the enum name?"*): a value qualified in place,
inside a fragment, changes no shape, so the fragment stays passive and the merge carries
`TBlockOperation.boBlockCheck` into the branch (FastMM4 renames without the marker; test
`enum_values_fragment.delf`, 🧪 dcc64 with and without the symbol). The marker remains a
file's choice. **A conditionally declared enum stays unscoped**, with a hint: one inside a
conditional's branch, or with a conditional among its values. Its values can mean a different
enum per build (JVCL's JvLookup declares `TDropDownAlign` under `{$IFNDEF WIN32}` and uses the
VCL's otherwise), so one shared line can't be qualified for both (29 Oct). Markers go on a file's first lines (`migration.md` §1).
✅ Built 29 Oct; a sum's tag enum was
already scoped (§9.1). **Limit:** a bare value inside a conditional fragment
(`{$IFDEF X} Large {$ELSE} Small {$ENDIF}` as part of an expression) is rewritten there,
which makes the fragment active, an error in a `.delf` file (`conditionals.md` §3a); write it
qualified, or the whole statement in each branch.

### 3.3 Field sections

Record and class fields are grouped under section keywords, extending the existing
`var` / `const` / `strict private` idiom.

```pascal
type
  TGrid = record
  immutable
    Cells : array of array of TCell;
    Start : TPoint;
  end;

  TService = class
  private
  owned
    FCache : TCache;          // destructor generated
  var
    FLog   : ILogger;         // borrowed; not freed
  end;
```

Sections, in plain English:

- **`required`** — *does it have a value from birth?* Precisely: assigned on **every**
  constructor path, in every overloaded constructor, with a descendant discharging its
  parent's obligations via `inherited Create(...)`.
- **`immutable`** — *can that value change afterwards?* Precisely: no assignment outside a
  constructor, including from the class's own methods. **It says nothing about whether the
  constructor assigns it** — only that the constructor is the sole place an assignment may
  appear. (Confirmed from the original design chat. Deferred "assign once, at any time"
  is a *separate* feature, `once`, not a reading of `immutable` — see
  `docs/todo-threading.md` §2e–2g.) (A constructor may assign a field
  more than once while building it up; that's unobservable from outside, which is one
  reason `Self` must not escape a constructor.)
- **`owned`** — this field's lifetime belongs to this object (the destructor is generated).
- **`var`** — the existing default: mutable, borrowed.

`required` and `immutable` are **independent**, so all four combinations mean something:

```pascal
required immutable    // set at birth; never changes
required              // set at birth; can change later (Status: pending → cleared → settled)
immutable             // may or may not be set at birth; never changes after
var                   // ordinary
```

`required` alone is the genuinely new, useful case: a transaction's status must be valid
from the moment it exists, and it moves on from there.

**Hint on `immutable` without `required`:** *this field may remain at its default;
consider `required`, or `Optional<T>` if absence is meaningful.* An untouched `immutable`
field keeps its zero-fill forever, indistinguishable from a legitimate zero — the
half-built-object problem the design exists to remove. Legal, and occasionally intended
("optional, but decided at construction"), so a hint rather than an error.

**`const` on an object is Delphi's** ✅: it fixes the reference, not the object, so a
`const L: TList<Integer>` can still `L.Add(5)`; `immutable` likewise guards the field, not what
it refers to. Objects for identity, records for values (handover 1). A deep `const` would need
each method to say whether it changes its object, which Delphi's don't; a table of the RTL's
mutating methods would be a guess, and read-only view types are red tape at every call (user,
5 Nov, choosing to leave it: *"great records excellent"*).

**Borrowed is the default everywhere** — parameters and fields. The annotation marks
the transfer, not the common case.

### 3.3a Shortcut properties ✅

A property with only a name and a type gains a field and both accessors (user, 2 Nov: *"what
you wrote looks good for now"*; from Vincent Parrett's *Delphi language enhancements*, 2016,
by way of delphi-preprocessor-starter's `auto-property`):

```pascal
TPerson = class                        TPerson = class
public                                 private
  property Name: string;      ->         FName: string;
end;                                   public
                                         property Name: string read FName write FName;
                                       end;
```

The fields go in a `private` section of their own, just before the property's section, whose
keyword then follows them, so no other member changes visibility. Classes and records alike;
the type may be Delf's own, `property F: (Integer -> Integer);`. **A property before any
visibility keyword is an error** asking for `public` or `published`: the text can't say which
it is, as it depends on `{$M+}`. A field of that name already there is dcc's error (E2004).
Delphi refuses the form (🧪 dcc64: E2128), so nothing valid changes meaning. Tests
`auto_property.delf` (🧪 Claude, dcc64 37.0), `auto_property_errors.delf`. It may yet become
part of field sections above; not decided.

### 3.4 `const` and `var` mean what readers assume

For reference types, Delphi's `const` and `var` parameters describe the *variable*, not
the *referent*: `const L: TList<Integer>` permits mutating the list. In Delf they
describe the referent. `const` forbids mutation through the reference; `var` permits it.

No new keywords. Every existing signature becomes a claim the compiler checks.

**Built, for dynamic arrays ✅** (user, 8 Nov: *"Yes to const in delf"*; an object under `const`
stays Delphi's, the user, 5 Nov). Delphi's `const` on a dynamic array protects the reference:
`A := nil` and `SetLength(A, 5)` are refused, but `A[0] := 5` compiles and the caller's array
changes (🧪 experiment 57, dcc64 and dcc32). In a `.delf` file, delfc makes an element write
through a const parameter or a `const` binding an error, as a write visible in the syntax, with
no guess. Only the file delfc translates, and only the shapes in the Honesty Box's 3.56; test
`const_element_write.delf`. A library `ConstArray<T>`, refused by dcc in every unit, is noted as
a future possibility (BIG_TODO §4), not built.

**A const passed where it could change ✅** (user, 8 Nov: *"We should make a warning or error for passing any const to a var or out parameter"*). dcc lets an inline constant, typed or not, through to a `var` parameter, `{$J+}` or not, and the routine changes it (🧪 experiment 63); `{$J+}` itself doesn't reach inline constants. In a `.delf` file a const binding or a const parameter passed to a `var` or `out` parameter, or to `Inc` or `Dec`, is an error, and a warning under `{ delf: migrate }`; in plain Delphi an inline constant passed so is a hint (user, 8 Nov: *"only a hint for normal .pas, a warning for migrating delf"*). Calls by bare name only (Honesty Box 3.57).

### 3.5 Several `uses` clauses ✅

A section may have several `uses` clauses (a friend of the user's, 1 Nov: *"Uses abc, def;
Uses zzz; Uses a,b,c,d,e,f,g; ... no repeat names of course"*; user: *"1 and then 2"*).
Delphi allows one (🧪 dcc64: `E2029 Declaration expected but 'USES' found` at a second);
delfc makes them one, in the order written, and the order still decides which unit's name
wins. Its use is a unit that depends on a symbol, as a clause of its own in a branch of its
own, which `docs/conditionals.md` §3a's rule (each branch whole) had made a whole clause per
branch:

```pascal
uses System.SysUtils, System.Classes;          // out: uses System.SysUtils, System.Classes
{$IFDEF TRACE}                                  //      {$IFDEF TRACE}
uses System.Diagnostics;                        //      , System.Diagnostics
{$ENDIF}                                        //      {$ENDIF};
```

Errors from delfc, each only where the text shows the clauses surely on in one build (one's
conditionals hold the other's): a unit named in two clauses, or in both a unit's interface and
its implementation; a first clause that is conditional while another follows (the clause must
begin in every build); a conditional holding a clause and other declarations too (the merged
clause would split them). Clauses in different branches of one conditional are Delphi's own
alternatives, one a build, and are left as they are; so is a unit named twice in one clause
(dcc's to judge). The door's samples found both in real code (JVCL, PascalScript), 1 Nov.
Tests `uses_several.delf` (🧪 dcc64, with and without `TRACE`), `uses_several_errors.delf`,
`uses_alternatives.delf`; `poc/delfc/usesmerge.py`.

---

## 4. `match`

### 4.1 Shape

```pascal
match <scrutinee> of
  | <pattern>: <body>
  | <pattern>: <body>
end
```

`of` and `end` as in `case`. `:` separates pattern from body. **No `;` terminating an
arm body.** Bars lead every arm and should align.

`match` is both a statement and an expression. As an expression, all arm bodies must
have the same type (modulo literals taking type from context). Delphi 13's inline `if`
expression is the precedent for the rule and for the syntax position.

```pascal
Result := match D of
  | Up:    ( 0, -1)
  | Right: ( 1,  0)
  | Down:  ( 0,  1)
  | Left:  (-1,  0)
end;
```

### 4.2 Several values: a match on a tuple

✅ **Written as a tuple** (user, 31 Oct: *"i think we had it wrong back then"*, revising chat
2's form; built 31 Oct, from the natural sort). The header is a tuple, and each arm a tuple
pattern of the same width:

```pascal
match (A, B) of
  | (Digits(X), Digits(Y)) : CompareDigits(X, Y)
  | (Digits(_), Text(_))   : -1
  | (Text(_),   Digits(_)) : 1
  | (Text(S),   Text(T))   : CompareText(S, T)
end
```

- **No tuple is built.** Each element is evaluated once, where it is; the output is a `case`
  on the first with a `case` on the second in each arm. (Chat 2's reason for its form, *"don't
  build a tuple just to destructure it"*, footprint, holds for this one too.)
- **A comma at an arm's top level is always *or***, at any width, as in Delphi's `case`
  labels (`| 1, 3, 5 :`). Inside the brackets it separates positions.
- **The width is in every arm.** A pattern of the wrong size is an error naming both sizes,
  so adding a value to the header can't silently change an old arm's meaning.
- **`_`** stands for one position, `(Text(S), _)`, or for the whole arm, `| _ :`.
- **Covered** when every combination of the elements' values is: a missing one is an error
  naming it, `(Digits, Text)`; an arm the ones above already cover can't be reached, an
  error.
- **Where coverage is hard to determine, `_` is insisted on** (user, 31 Oct): an element whose
  values delfc can't list (an `Integer`, a string, a `Char`) is tested only with a literal,
  `'kLt'`, `7`, `-1`, `'x'`, and **the match then ends in `| _ :`**; past 1024 combinations
  the match must end with `| _ :` too. A type delfc can't see is `_` in every arm.
- **A test on such an element makes the match an `if … else if` chain** (31 Oct; the user,
  on the walker: *"look at building the tuple (Kind, Op) match"*), each arm's tests joined by
  `and`, its final `_` the `else` (none when it is empty). An element tested by one arm only
  is written in place, so `and` skips it when a test before it fails, as hand-written code
  would; any other is read once, before the chain. An arm the arms above take whole can't be
  reached, an error.
- **Narrowing on a tuple** is that match, as on one value (§5): `if (R.Kind, R.Op) is
  ('exprBinary', 'kLt') then …` is `match (R.Kind, R.Op) of | ('exprBinary', 'kLt') : … |
  _ : end`, and writes `if (Kind(R) = 'exprBinary') and (Op(R) = 'kLt') then …`.
- Rung 2: or-patterns of tuples, guards, a pattern inside an element's field, a variable
  declared in an arm; a range or a name as the test on an element delfc can't list.

Tests `match_tuple.delf`, `match_tuple_errors.delf`, `match_tuple_open.delf`; the natural
sort, `poc/examples/08-natural-sort`; TreeSitter4D's `TsWalk.delf`.

**What chat 2 had** (handover 2, §3.2), now withdrawn: `match X, Y of | Digits(M),
Digits(N): …`, the arity fixed by the header, the comma meaning *or* at arity 1 and *next
position* above it, with `or` for disjunction there. Handover 2 recorded the trap itself:
*"adding a scrutinee reinterprets commas; an arm with exactly as many alternatives as the
new arity silently changes meaning"*. `match X, Y of` is an error suggesting
`match (X, Y) of`.

### 4.3 Patterns

| Pattern | Tests | Binds |
|---|---|---|
| `1`, `'x'`, `Less` | equality | nothing |
| `1..5` | range | nothing |
| `Digits(M)` | tag | `M` |
| `(Q, R)` | nothing (arity is static) | `Q`, `R` |
| `M` (bare identifier) | nothing | `M` |
| `_` | nothing | nothing |

Patterns nest: `Present(Wall)` is a constructor pattern containing a constructor pattern.
`Digits(0)` tests the tag and the payload and binds nothing.

String literals are ordinary constant patterns, so `match` does what Delphi's `case`
cannot: `match Cmd of | 'quit', 'exit': ... | _: ... end`. `string` is open, so `_` is
mandatory. Matching uses `=` and is case-sensitive; for case-insensitive matching,
transform the scrutinee (`match LowerCase(Cmd) of`) rather than adding syntax.

Payload binding is **positional**, even though the declaration names fields, because
named binding is too wide for a match arm. Named binding is available when you want
only one field:

```pascal
| Node(Value: V): V
```

**Guards** ✅ 🧪: `| Node(L, V, R) when V > 0:`. The first arm that fits and whose guard holds wins,
and the guard can read the arm's bindings. A guard can be false, so **its arm covers nothing**: the
arms without one must still cover the type, or `_` must, and a guarded arm those above have
already taken can't be reached, an error. Guarded arms of one value may name the same field the
same; one name can't mean two fields among them. A guard is a Boolean and, like an arm, can't change
a binding or the scrutinee. On a sum or an enum the output is still a `case`, each label holding its
arms as an `if` chain; on anything else, an `if` chain, reading the scrutinee once (§9.3). Rung 2: a
guard on a tuple, or on an arm declaring a variable.
🧪 `poc/tests/cases/match_guards.delf` on dcc64 and dcc32 (Claude, 3 Nov).

**Tests one inner `case` can't hold** (3 Nov): inside two fields, `Pair(Num(0), Num(0))`; inside
different fields of one tag, `Card(0, _)` and `Card(_, 0)`; a string, `Cmd('quit', _)`; a guard
beside a test. In such a match each test is part of a condition, and the arm **covers nothing**, as
a guarded arm does: the tag's rest needs an arm of its own, or `_`, even if the tests happen to
cover it (the user's rule, 31 Oct: *"If coverage is difficult to determine, insist on _"*). A
match with none of these keeps its inner `case` and its checked coverage. The condition relies on
Delphi's `and` stopping at a false test, so a file with `{$B+}` gets an error. 🧪
`poc/tests/cases/match_tests_inside.delf` on dcc64 and dcc32 (Claude, 3 Nov).

**A match on a class** ✅ (user, 2 Nov: *"how about 'match x.classtype of' AND 'match x is
of'"*, then *"switch to match X is"*: `is` stands in place of `of`). Two forms; each arm names classes, and `_` is mandatory, as a class hierarchy is open:

```pascal
match X.ClassType of                   // the exact class: a TStringList isn't a TStrings
  | TStringList   : 1
  | TList, TQueue : 2                  // also any TClass, or a type declared `class of T`
  | _             : 0
end

match X is                             // with `is`: a TStringList is a TStrings; nil takes `_`
  | TStrings : 1
  | TList    : 2
  | _        : 0
end
```

The first arm that fits wins, so with `is` a class below an ancestor named above it can't be
reached, an error where delfc can read the ancestry (`TPuppy can't be reached: TAnimal takes
every object of it`); on the exact class the order doesn't matter. A class named twice is an
error, and so is `match … is` on a value delfc can see is no object; on a sum, the error points
to `match S of`. So `is` tests a class in a match's header, where `if S is Present(V)` (§5) tests
a sum's arm: there it is one arm's `match S of`. `X` keeps its type in
the arm. With `is`, `| TStrings(S) :` also names the object: `S` is `X`, typed `TStrings`, in that
arm, constant as any binding is, though the object it names can change; `TStrings(_)` tests the class
alone (user, 3 Nov; 🧪 `poc/tests/cases/match_class_bind.delf` on dcc64 and dcc32). The exact-class
form has no object to name, so it can't. A guard may read the name: in the test it is written as the
cast, `(O is TStrings) and (TStrings(O).Count > 0)`, which Delphi's `and` keeps from a failed `is`, so
a file with `{$B+}` gets an error instead. Rung 2: binding in an or-pattern, and a
generic class as a pattern, which the pattern grammar can't write yet. Delphi's `case` on a
string or a class stays Delphi, and dcc's errors are fine there (user, 2 Nov: *"writing case
is wriying delphi .. i'm ok wit hdelphi errors there"*).

**Bindings and the scrutinee are read-only in a match** ✅ (user, 19 Oct). An arm can't
assign a binding or the value being matched, `Inc` it, or pass it to a `var` parameter.
A changed value is written functionally, `D := match D of | Up: Right | …`, each arm giving
the new value. No `var` in either place for now. `match var T of` and a per-binding `var`
(one or the other in a match, never both) are recorded for later, with the examples and
considerations, in [`docs/match-bindings.md`](docs/match-bindings.md).

**An arm can declare a variable that lives on after the match** ✅ (user, 23 Oct):

```pascal
match Start(Input) of
  | Present(Pos) : var GuardPos := Pos
  | Absent       : begin writeln('no start point found'); Exit; end
end;
Seen[GuardPos] := True;           // GuardPos: a TPoint, not an Optional<TPoint>
```

The point (user): the scrutinee is an `Optional<X>`, and the new variable is a plain `X`
from there on, as in Rust, where a value checked with `?` is a real `X` after it. The
output declares the variable before the `case` and assigns it in the arm. **Every other
arm must leave** (`Exit`, `Break`, `Continue`, `Halt`, `raise`), or the variable would
have no value after the match: an error in delfc (Claude's, accepted by the user, *"you
are right about the uninitialised var"*). The user's alternative, recorded in §12: flags
in the output, set by the declaring arm and checked where the variable is read. One arm
only, and only in a match used as a statement (rung 2 for more). In delfc, 23 Oct;
🧪 `poc/examples/06-guard-patrol/5-grid-optional.delf` on dcc32 and dcc64, errors in
`poc/tests/cases/arm_declares_errors.delf`.

**Or-patterns** use the comma, at arity 1 only, exactly as `case` labels do today:

```pascal
match N of
  | 1, 3, 5, 7, 9: 'odd'
  | 0, 2, 4, 6, 8: 'even'
  | _:             'out of range'
end
```

At arity > 1 the comma is the positional separator, so use `or` within a position:
`| Less or Equal, Greater:`. `or` is also legal at arity 1.

Every alternative of an or-pattern must bind the same names at the same types.

**Tuple parens** are optional at the top level (the header already fixed the arity) and
load-bearing below it. A paren in a pattern means "tuple below this point."

### 4.4 Exhaustiveness

Every `match` must be exhaustive. Over closed types (sums, enums, `Optional`) that means
covering every arm; a wildcard counts. Over open types (`Integer`, `string`, `Char`) a
wildcard is mandatory.

**Which types are closed** (user, 19 Oct):
- **Sums, enums, `Optional`, `Boolean`** ✅.
- **Declared subranges** ✅ (`TDigit = 0..9`): `| 0..4: … | 5..9: …` is exhaustive with no
  `_`. delfc checks that the ranges cover the type exactly once: a gap, an overlap or a
  value outside the bounds is an error. An enum subrange (`TTurn = Up..Down`) is closed over
  its slice of the enum. In delfc, 19 Oct; 🧪 dcc32 and dcc64.
- **The 8-bit ordinal types** ✅ (user, 19-20 Oct), `Byte`, `AnsiChar` and `ShortInt`, which
  are subranges in all but name. Full coverage is practical for them, `| #0..#127 : … |
  #128..#255 : …`. In delfc, 20 Oct; 🧪 dcc32 and dcc64.
- **Open:** `Char` (Delphi's `Char` is `WideChar`, 65,536 values), `Integer` and the
  wider integers, strings, floats.
- Recorded for later: Rust's rule, where every integer type is closed and checked by range
  coverage (`match b { 0..=127 => …, 128..=255 => … }` on a `u8`), so `_` is needed only
  when the ranges don't cover the whole type.

**A closed type is only closed if no other value can get in.** Delphi lets other values
in (experiments 27, 29), through a cast, `absolute`, `Move`, a variant record, a file, or
C. A `Boolean` holding 2:
- is true for `if`, but `= True` is false;
- takes neither arm of `case … of True: … False:`;
- under `not` is **true on Win32 and false on Win64**.

`LongBool(2)` says `= True` is true, yet `case … of True:` doesn't take that arm.
Delf's guarantee rests on §8: no implicit conversions, no unchecked casts, so a value
from outside comes in through a checked conversion. An edited output that lets one in
reaches `__dpp_Unreachable` and reports the ordinal. ⚪ `ByteBool`, `WordBool` and
`LongBool` (non-zero is true, for C) can't be closed over `True` and `False`: a `match` on
one should test zero against non-zero, or be refused.

```pascal
Result := match Grid.Lookup(Next) of   // Optional<TCell>, TCell closed
  | Absent:        Exited
  | Present(Wall): Turned(Turn(D))
  | Present(Open): Moved(Next)
end;                                   // no wildcard needed or wanted
```

A bare identifier pattern is irrefutable and makes everything below it unreachable.
That is an error, and a binding pattern that shadows a visible constant is a warning.

### 4.5a Empty arms: a smell on `Optional`, literate on an enum

**On an `Optional` (or any failure case), an empty arm is a smell** — it shrugs at a case
you couldn't answer:

```pascal
match Grid.TryGet(P + D) of      // smell: Absent does nothing
  | Present(C): if C = Alive then inc(N)
  | Absent:     ;
end;
```

Three better forms:

1. **The lookup should be total.** Off-grid isn't absence — in a bounded Game of Life a
   cell outside the grid *is* dead. Pad the grid with a dead border, and `Get` is total.
2. **You wanted a default** → `X.TryGet(K).OrDefault(0)`.
3. **You only care about one case** → narrow: `if X is Present(V) then …`

**`Optional` is for "might not exist", not for "has an obvious default".** Where the
domain answers every input, write a total function (the total/partial split in
`docs/todo-tables-are-functions.md`). Absence removed at the edge of the program — a dead
border, a parse step — beats absence handled at every read.

**On a closed enum, an empty arm is the opposite: it is literate.**

```pascal
for const D in Offsets do
  match Grid.Get(Point + D) of
    | Alive : inc(N)
    | Dead  : {}
  end;
```

This enumerates the domain and states that nothing happens in one case, and exhaustiveness
holds the author to it. Add `Dying` to `TCell` — Brian's Brain — and this stops compiling
until the new case is decided. The terser `if Grid.Get(P + D) = Alive then inc(N)` keeps
compiling, and quietly gets it wrong.

**Spelling the empty body** (`{}` is a comment in Pascal, so the body is genuinely empty):

```pascal
| Dead : ;          // the empty statement — terse, easy to miss
| Dead : {}         // conventional "deliberately nothing"
| Dead : skip       // an explicit no-op word; Ada spells it null;
```

Leaning: allow `;`, make `{}` the formatter's convention. ⚪ undecided.

### 4.5 Chained conditionals are a smell

If a `match` body wants `if ... else if ... else`, the scrutinee is wrong. Find the
function that returns the distinction as data.

```pascal
// wrong
Result := if not Grid.Contains(Next) then Exited
          else if Grid[Next] = Wall  then Turned(Turn(D))
          else Moved(Next);

// right
Result := match Grid.Lookup(Next) of
  | Absent:        Exited
  | Present(Wall): Turned(Turn(D))
  | Present(_):    Moved(Next)
end;
```

---

## 5. `Optional<T>`

Built in, and defined as a sum type:

```pascal
type Optional<T> =
  | Absent
  | Present(Value: T);
```

**Names** ✅ (user, 20 Oct): the arms are **`Present` and `Absent`**. Rust and ML say
`Some`/`None`; Paskell might also allow those (user, not decided). Bind is **`AndThen`**
(user: "might do"), as in Rust; **not `FlatMap`** (user: "definitely not"). An operator
form too, "at some point" (user, 20 Oct): **`>>=`**, Haskell's bind (confirmed by the
user, 21 Oct; first written `>==`). **The default is `OrDefault`** (user, 20 Oct), as Spring4D's
`Nullable<T>.GetValueOrDefault` and `FirstOrDefault` family and .NET spell it, not Java's
`OrElse`. Its lazy form is an overload taking a function, `OrDefault(λ -> Expensive)`
(user chose this over a second name such as `OrElseGet`). Older notes and
the `examples/*/after.delf` files still say `Some`/`None` and `FlatMap`.

**Representation is the transpiler's business, and correctness comes before size.** The
default encoding for every `T` is a flag plus a value. A class `T` *may* be emitted as a
bare pointer, with `nil` as `Absent`, but only as an optimisation, and only where `T` is
guaranteed non-nil. Otherwise `Present(nil)` and `Absent` would be the same bits. Nothing
in Delf promises that `Optional<TFoo>` costs what a `TFoo` costs today.

**The representation may specialise; the interface may not.** `Optional<TFoo>` has
exactly the operations of `Optional<Integer>` (arms, `OrDefault`, `Map`, `AndThen`, `match`)
and none of the reference's (`Free`, `Assigned`, `= nil`). Generic code over `Optional<T>`
never needs to know what kind of `T` it holds. This is C++'s `vector<bool>` lesson, and
Revzin's argument against `T*` as `optional<T&>` (`docs/references.md`). Any one-word
form would depend on monomorphised output (one record per `T`, as in example 06); a Delphi
generic record cannot vary its layout by `T`.

Three doors out, and you must pick one:

```pascal
X := Opt.OrDefault(0);                  // supply a default
X := Opt.OrDefault(λ -> Expensive);     // lazily: the same name, given a function
if Opt is Present(V) then ...           // narrow
Result := match Opt of                  // match
  | Absent:     ...
  | Present(V): ...
end;
```

**Narrowing is a match** (user, 24 Oct): `if S is P then A else B` means exactly
`match S of | P : A | _ : B end`, and with no `else` the `_` arm does nothing. So any
pattern works (`is Present(Moved(P))`, `is Cheque(0, _)`, `is Cash`), `P`'s bindings are
constants in scope in `A` only, and a pattern that always matches is an error (no test).
`is` starts a pattern only when the name after it is an arm of the left side's sum, so
Delphi's `O is TFoo` is unchanged. Rung 1 takes it as the whole condition of an `if`
statement, and of a conditional expression where a match may stand (31 Oct, user, on
TreeSitter4D's `ToString`: *"as if 'is present' else?"*): `Exit( if N is Present(X) then
OneLine(X) else '' )`, `X := …`, `const X := …` are `match N of | Present(X) : … | _ : ''
end` as a value, the same `case`. In `and`, `not`, `while`, a conditional expression inside
a larger one or a Boolean value it is rung 2 (where `if X is Present(C) and (C = Alive)` needs the binding in scope for the
right operand, `docs/todo-naming.md`).

`Map`, `AndThen` and `Filter` are available and are Stage 1 (see §2).

**Every Delphi absence idiom maps to `Optional`:**

| Delphi | Delf |
|---|---|
| `TryGetValue(K, V): Boolean` + out param | `Get(K): Optional<V>` |
| `IndexOf(X): Integer` returning `-1` | `IndexOf(X): Optional<Integer>` |
| `FirstOrDefault` returning `Default(T)` | `First: Optional<T>` |
| `nil` returned from a factory | `Optional<TFoo>` |
| `''` meaning "no value" | `Optional<string>` |
| sentinel seeds (`maxint`, `minint`) to a fold | `Min`/`Max` returning `Optional<T>` |

---

## 6. Bindings, lambdas, generics

```pascal
const G := LoadGrid('input.txt');     // immutable binding, type inferred
var   D := Up;                        // mutable binding
var   Seen : Set<TPoint> := [P];      // annotated

λx -> x * 2                           // one parameter
λ(A, B) -> A + B                      // two parameters
λ -> Expensive                        // no parameters
λ(X: Integer) -> X + 1                // parameter annotated
λ(X): string begin … end              // block form; a result type only here
```

✅ **`X ← e` is `const X := e`** (handover 1's `←`; deployed 1 Nov, user: *"we haven't
deployed the backwards arrow for Const assign, and we do that a lot"*). Legal exactly where
`const` is: a statement, not a `for`-in header. A type is allowed, `S: string ← 'ab'`;
`const X ← e` is legal too ("redundant but unambiguous"); `(Q, R) ← DivMod(17, 5)` binds
consts. Written without spaces it still reads (`T←S+S`): `←` is not an identifier character
in Delf, as `λ` isn't. `T: TTxn ← e` could also be a label `T:` before `TTxn ← e`; the
binding wins. delfc writes exactly what it writes for `const X := e`. Test
`bind_arrow.delf` (🧪 dcc64). The examples still spell `const X :=`; which form they use is
the user's choice.

✅ **`λ` is a lambda only where a lambda's shape follows it** (user, 23 Oct). Delphi takes
`λ` as a name (`constructor λ(_str: string);`, in the user's own code, experiment 32). A
lambda's `λ` is followed, after its parameters, by `->` or a block's `begin` (`: T begin`
with a result type); a name reaches `;`, `:=`, `.` or `)`. delfc reads such a `λ` as a
name and writes it back unchanged (`poc/delfc/lambdanames.py`).

✅ **Record literals name their fields, and only that** (handover 1; the positional form
rejected by the user, 23 Oct). A literal takes its record type from where it goes, so
`Step` can answer `(dx: 0; dy: -1)` for a `TPointDelta` with no name in front. **Never
positional:** `(0, -1)` where a record is expected is an error, not the fields in order.
User: field order would become meaning; reorder `dx, dy` in the declaration and every
`(0, -1)` swaps silently, both being Integers, with nothing to catch it (*"the Boss
argument … look back to first principles"*). Rust and Swift ask for names for the same
reason; C's `{0, -1}` is the counter-example. A tuple stays a tuple.
delfc knows `System.Types`' plain records by their fields (`TPoint`, `TSize`, `TSizeF`,
`TSmallPoint`; the prelude declares them, 25 Oct), so `(X: 3; Y: 4)` is written and
`(3, 4)` is the error for them too; before, it read no RTL record, and a `TPoint` literal
could be neither (🧪 test `record_literal_rtl.delf`, dcc32 and dcc64). A record delfc
can't see is still left to dcc32: a typed array constant has the same parentheses.

✅ **`for var (i, X) in Xs.Enumerate do`: the index and the element** (user, 23 Oct: *"the
other languages have enumerate"*, Python's `enumerate`, Rust's `.enumerate()`; the user's
spelling, `Xs.Enumerate`, and `Enumerate(Xs)` by UFCS). The index first, counted from 0,
for an array and for a string alike (§8, mixed-base indexing). `_` for a name not
wanted. Output: Delphi's own index loop, so it costs what that costs,

```pascal
for var i := 0 to High(Xs) do        // Length(S) - 1 for a string, and S[Low(S) + i]
begin
  const X = Xs[i];
  …
end
```

with `Xs` held in a constant first unless it is a variable (a function's result is
computed once). `Enumerate` is needed: a bare `for var (A, B) in Pairs` would take each
element of an array of pairs apart, which is a different thing (not yet in delfc). Rung 1
in delfc: arrays and strings, two names (`poc/README.md`).

✅ **`for const (X, Y) in Zip(Xs, Ys) do`: an element of each, side by side** (user, 9 Nov:
*"we need zip arrays"*, Python's `zip`, Rust's `.zip()`; `Xs.Zip(Ys)` by UFCS too). As far
as the shorter goes, as `ZipWith` and a sequence's `Zip` do. One name per array, so three
arrays take three names; `_` for one not wanted. The same index loop as `Enumerate`'s, its
bound the least `High` (Delphi 13's `if` expression, held once), so no array of pairs is
made. As a value, `Zip(Xs, Ys)` is that array of pairs, `TArray<(T, U)>` (`Delf.Arrays`).
Test `zip.delf`, 🧪 dcc64.

**Function types are written in brackets** ✅ (user, 17 Oct, chat 4). Two rules, no
exceptions:

1. **Every function type is bracketed**, wherever it is written: parameters, results,
   variables, fields, type declarations, generic arguments.
2. **An arrow never leads straight into another arrow.** The second is bracketed, whether
   it's a type (`A -> (B -> C)`) or a lambda (`λa -> (λb -> a * b)`).

```pascal
function Compose<A, B, C>(F: (A -> B); G: (B -> C)): (A -> C);
function Adder(N: Integer): (Integer -> Integer);
var Add: (Integer -> (Integer -> Integer)) := λX -> (λY -> X + Y);
type TIntFn = (Integer -> Integer);
TArray<(Integer -> string)>
F: ((Integer, Integer) -> Boolean)    // two parameters
G: (() -> string)                     // none
P: (Integer -> ())                    // a procedure: TProc<Integer>
```

Why: a lambda's result annotation, `λ(X): string -> S`, could read `string -> S` as a
function type, leaving no body (`poc/README.md` finding 1). With rule 1, an unbracketed type
can't contain an arrow, so the first unbracketed `->` after a lambda's parameters always
starts the body. Rule 2 removes associativity: nobody has to remember which way
`A -> B -> C` groups. The value mirrors its type: `λX -> (λY -> X + Y)` has type
`Integer -> (Integer -> Integer)`.

**Haskell reads every allowed form the same way** (checked against Haskell's rules: `->` is
right-associative, a lambda body extends as far right as possible). Delf only refuses the
spellings that leave brackets out. One look-alike remains, from handover 1 rather than from
this rule: `(A, B) -> C` takes **two parameters** in Delf and **one pair** in Haskell. A
function taking a tuple is `((A, B)) -> C`, matching the call, `F((A, B))`.

**Result types on lambdas go on the block form only** (🟡 Claude, POC choice 4): in
`λ(X): (Integer -> Integer) -> …` the eye reads `(Integer -> Integer) -> …` as one type, a
function *taking* a function, which is Haskell's most characteristic shape read backwards.
To state an expression lambda's type, annotate the target.

**`()` is notation, not a type** (user): `A -> ()` spells a procedure type and `() -> T` a
function with no parameters. There is no unit value.

**To review once real code is written** (user: this may not prove beautiful or ergonomic).
Candidates: type declarations may not need the brackets (`type TIntFn = Integer -> Integer`
is unambiguous), while generic arguments probably do (`TFunc<(A -> B), C>`); and the
multi-parameter and parameterless forms carry two pairs, `((A, B) -> C)` and `(() -> T)`.
The rule started uniform because one rule is simpler for the grammar and the reader.

**Function types are structural** (verified on dcc32; `experiments/`). Two function types
with the same signature are interchangeable whatever they're named. For nominal
protection (a logger that must not accept `DeleteAccount`), wrap the function in a
single-field record named `Invoke`: `TLogFn = record Invoke: TProc<string>; end`. It's
pointer-sized, distinct wrappers refuse to assign to each other, and `Log.Invoke('x')`
works in plain Delphi.

**Proposed sugar (not yet decided):** anything with a member named `Invoke` may be called
directly, so `Log('x')` means `Log.Invoke('x')`. This extends Delphi's own rule, since
`Invoke` is what makes method references callable, to records. Kotlin (`operator fun
invoke`), C# (`.Invoke`), Scala (`apply`) and C++ (`operator()`) all have the
equivalent. A parameterless `Invoke` requires `()` at the call, to avoid the
call-versus-reference ambiguity.

**A bare parameterless name where a function of no parameters is expected is the
function, not a call** (decided, user, 26 Oct: *"Let's have it minimal where we can"*).
`var Get: (() -> Integer) := Answer` holds `Answer`; a call there is written `Answer()`.
Everywhere else a bare name is still a call, as in Pascal (`var N := Answer`, `L.Free`,
`TStringList.Create`). dcc32 reads it the same way already, except that it refuses a
constructor (🧪 experiment 46: E2010), so delfc writes a constructor used as a function
value as an anonymous method:

```
var Make: (() -> TStringList) := TStringList.Create;
// out: var Make: TFunc<TStringList> := function: TStringList begin Result := TStringList.Create; end;
```

The stronger rule, `()` on every call as in Rust, was set aside for now: every
parameterless call in renamed Delphi would break. Test `function_values.delf`.

**`.Name` is the member of the value a function is given, as that function** ✅ (user, 6 Nov:
*"I prefer .tostring vs inttostr"*; the dot agreed over a bare name, *"Agree"*). Where a
function of one `T` is expected, `.Name` is `λX -> X.Name`, for a parameterless method or a
field of `T`, its own or a helper's:

```
WriteLn(Xs.Map(.ToString).Join(','));     // Xs: TArray<Integer>
WriteLn(Boxes.Map(.Area).Sum);            // a record's method; .W, a field, the same
// out: TArrays.Map<Integer, string>(Xs, function(X: Integer): string begin Result := X.ToString; end)
```

The dot is what marks it: a bare name is always a function, so `Map(Trim)` is the RTL's `Trim`,
and declaring a `ToString` of one's own later changes nothing a line means (the guiding
principles; a bare `Map(ToString)` was built first and set aside). The same idea as UFCS run
backwards (§6: `Xs.Sum` is `Sum(Xs)`); Rust writes `ToString::to_string`, Java
`Object::toString`, Swift `\.count`. A bare `Map(ToString)` with no such function is an error
that names `.ToString`; `.Name` anywhere but a function's place is an error. Test
`method_values.delf`.

**A routine with `const` parameters passes as a function value, as it is** ✅ (user,
29–30 Oct: "2 is great"; wrapping it in a lambda "seems like an ugly idea"). Delphi matches
`const` exactly when a routine is passed (🧪 the user's `_QC/12.3` probe and dcc64 37.0:
E2010 both ways), and the RTL's routines and Delf's own mostly take `const` (`Trim`,
`Kind(const N: TSNode)`). So the library's operations that take a function come twice, with
`TFunc<T, U>` and with `TConstFunc<T, U>` (`reference to function(const Arg: T): U`,
Spring4D's `Func` shape), and Delphi picks by the routine passed: `Lines.Map(Trim)`,
`Field(N, 'operator').Map(Kind)`. The library (`Delf.Arrays.pas`, `Delf.Optional.pas`; its parts in their own units since
5 Nov, user: *"let's divide the prelude parts"*: `Delf.Prelude` holds `Id`, `Args` and
`TInitArray`, `Delf.Arrays` the array operations and spans, `Delf.Points` `TPoint`'s moves):
`Map`, `AndThen` and `Filter` over an `Optional` or an array, each both ways; `Enumerate`,
`Join`, `Args`. A file's own routine of the same signature hides the library's. Test
`library_arrays.delf`. **`Timed` and `ReadLines`** (9 Nov, user: *"make a timing fn, taking a
fn"*, and *"the file can not exist .. we should be using our own principle"*):
`const (R, Ms) := Timed(λ -> Work)` gives `Work`'s result and the milliseconds it took;
`ReadLines(Path)` a file's lines, or `Absent` where it can't be read, so
`if ReadLines(P) is Present(All) then …` and no exception (the reason is lost: Honesty Box
3.61). Test `timed_readlines.delf`. **Searching and summing** (30 Oct, user: "proceed as you think on
Arrays", after Willi Commer's ArrayHelper, `docs/library.md`): `Find` (the first element a test
passes) and `Count` (how many), both ways; `IndexOf`, `Contains`; `Min`, `Max`; `Sum` for
`Integer`, `Int64` and `Double`. All read-only, and where ArrayHelper answers −1 they answer
an `Optional`: `Absent` for not found, or for the `Min` of an empty array. A parameterless one
reads without brackets after a dot (`Xs.Max.OrDefault(0)`, `Xs.Filter(IsEven).Sum`), as
`Length` does (silent decisions 3.18, 3.19). Test `library_search.delf`. **Spans** (31 Oct,
user: "Fix the span feature"; `docs/todo-algorithms-span.md`): `TSpan<T>`, a view of part of
an array without copying it (the array, a start, a count, so it can't dangle), made by
`Take(N)` and `Drop(N)` (clamped) and `Span(Start, Count)` (checked); indexed from 0 and
checked, `Count`, for-in, `Enumerate`, `ToArray`. Test `spans.delf`. **`Runs` and
`ZipWith`** (31 Oct, from the natural sort: user, *"I'm not sure chunks looks very neat"*):
`S.Runs(P)` cuts a string where a test on its characters changes (Haskell's `groupBy`);
`Xs.ZipWith(Ys, F)` is `F` of each pair as far as the shorter goes, eager; a two-argument
`TConstFunc<T1, T2, R>` beside `TFunc<T1, T2, R>`. Test `library_runs_zip.delf`. Also noted (user, "the user wouldn't write the dummy .. delf does"):
delfc could overload on `const`, value or `var`, which Delphi refuses (E2004), with a hidden
tag parameter of an empty record type, for routines that are called, not passed.

**A function type's parameter modes** ✅ (user, 9 Nov: *"let's sort out the var -> syntax and fn
forwarding"*; the proposals, *"no, i like these proposals"*). `(T -> K)` says nothing of modes:
the function can't change what it's given, so it goes out as `TConstFunc<T, K>`, `const`
parameters. A mode that changes meaning is written on its parameter, `(var T -> K)`,
`((A, out B) -> C)`, and goes out as `Delf.Funcs`' types, a letter a parameter (`c`, `v`,
`o`): `TProc_v<Integer>`, `TFunc_coo<…>`. A name passed where its modes aren't the slot's is
**forwarded**: delfc writes a forwarding function there, once, where the name is passed (user:
*"You said wrapper .. do you mean forwarding?"*):

```
function Double(X: Integer): Integer; …
Apply(Double, 6);                          // Apply(const F: (Integer -> Integer); …)
// out: Apply(function(const __dpp_a1: Integer): Integer begin Result := Double(__dpp_a1); end, 6)
```

What fits (the user: *"you can pass anything to a const fn, because it isn't going to be changed
by the fn. The reverse not true"*): a routine taking its parameter by value or `const` fits a
`const`, value or `var` slot (a `var` one with a hint: it can't write back); a `var` or `out`
parameter fits only its own mode, an error otherwise, since a `const` slot may be given a
constant and an `out` one must be assigned. A copy to fake `const` is never inserted (user:
*"blithely throwing in copies in places that might be in loops ... wouldn't be good"*). The
library's operations take both kinds already, so nothing is forwarded there; a spelled
`TFunc<T, K>` keeps its own modes. A forwarding function costs one indirect call (🧪 experiment
67; about 7% on the cheapest comparison, experiment 65), so a file's own higher-order function
best takes `const` routines, Delphi's habit. A mode outside an arrow's parameters, `(var A, B)`,
is an error. Tests `func_modes.delf`, `func_modes_errors.delf`; Honesty Box 3.62.

**Partial application: `_` for an argument left open** ✅ (user, 9 Nov: *"Can we express
currying better now?"*, then *"Yes pls"*; `docs/partial-application.md`, experiment 68). A call
with `_` for some arguments is a function of those: `Add(5, _)` is `(Integer -> Integer)`,
`Names.Count(StartsWith(_, 'A'))`, `Box.Wrap(_)`. **Bare `_` is never a name in a `.delf`** (user:
*"I think delf doesn't allow _ names. We can already do _x"*), so as a whole argument it is the
placeholder; `_x` and `_1` stay names. The bound arguments, and a value's receiver, are evaluated
once, where the partial application is written, and copied: delfc writes an anonymous function
called in place, since a lambda written in place captures the variable, not its value
(experiment 68: 101 where 6 was meant):

```
const AddN := Add(N, _);
// out: const AddN = (function(const __dpp_b1: Integer): TConstFunc<Integer, Integer>
//        begin Result := function(const __dpp_a1: Integer): Integer
//          begin Result := Add(__dpp_b1, __dpp_a1); end; end)(N);
```

A call through it costs about what a direct call does (experiment 68: 32 ms against 31 for 20
million). A `var` or `out` parameter can't be bound, only left open. A generic routine's open
arguments take their type from the bound ones or from the slot; with neither, an error. Tests
`partial_application.delf`, `partial_application_errors.delf`; Honesty Box 3.63.

**Sections: `_` as an operand** ✅ (user, 9 Nov: *"now I want sections!"*, after seeing
`λ (a, b) -> b - a` for C++'s `adjacent_difference` and wanting a `Sub`). `_` beside an
operator makes that operator a function of its holes, left to right: `Ns.Filter(_>0)`,
`Ns.Map(2*_)`, `Ns.Pairwise(_-_)` (each element less the next), `Xs.Count(_<>'b')`. Written
tight, no spaces, so a section reads as one unit (user: *"use (_>0) (_=True) etc"*, *"no
spaces"*); brackets may show its edges, `const Big := (_>4)`. The holes are typed by the
function expected there; with one hole and none expected, by the other operand
(`const Positive := _>0` is `(Integer -> Boolean)`); otherwise an error saying to write the
lambda. The other operand, unless a literal, is evaluated once and copied, as a partial
application's bound argument is: `_>Limit` keeps the `Limit` it was made with. Only the operator
the `_` stands beside: `_ * 2 + 1` is not one function (write the lambda). Tests `sections.delf`,
`sections_errors.delf`; Honesty Box 3.64.

**`._` in a chain is a probe, ignored everywhere** ✅ (user, 9 Nov: *"a.b._.c could be ignored
everywhere, and do the same job as dot"*). `Names._.Map(Len)._.Sum` means
`Names.Map(Len).Sum`. A `.delf` declares no `_`, but Delphi it calls may (door-nov14: Spring4D
Reactive's `._`, dxgettext's `_(S)`, mORMot2's TDocVariant `o._(0)`), so a probe is only on a type
delfc sees whole: an array, span, sequence, Optional, tuple, string or number, or a type declared
in the file; and `._(…)` is always a call. Elsewhere `._` stays as written. In an editor, hover on it
gives the type of the value there, as hover on a chain's dot does; it marks the place for a
debugger's stop or a value later (`docs/todo-ide.md`, *Debugging a chain*). Test `probe.delf`.

Lambda parameter types are inferred from the expected function type. There is **no
tuple destructuring in a lambda parameter list** — use a `match`, or rely on the fact
that pair-producing operations yield named fields (`P.Prev`, `P.Next`).

Generic calls infer their type arguments. `UFP.List_Reduce<integer>(L, Sum, 0)` becomes
`Reduce(L, Sum, 0)`.

**From outside as well as inside** ✅ (user, 25 Oct). A call's type arguments come from
its arguments and also from where its value goes: an `Exit`'s result type, a typed
variable, a parameter. In a function answering `Optional<Optional<Integer>>`,
`Exit( O.Map(λx -> Absent) )` needs nothing written: the body says nothing, the signature
says `U`. The outside type is used first, then the arguments; only one already settled
where the call is (not an outer call's open variables). Test `expected_types.delf`, 🧪
dcc32 and dcc64 as predicted.

When the two sides disagree, the error is at the argument and names both sources, with
where the outside one is stated (user, 25 Oct, asking whether inference would make errors
hard to follow): *"the lambda answers string, but Map's U is Integer, from Lengths' result
(25:46)"*. One error per cause; a fix is offered only where it would type (`Present` only
when what's inside matches). Test `conflict_errors.delf`.

**Overloads that differ in their type parameters** ✅ (user, 25 Oct: the tie-break).
`Twice<T>` taking `(T -> T)` beside `Twice<T, U>` taking `(T -> U)`: with type arguments
written, their number picks the overload, as dcc32's does (experiment 43), `_` included.
Without them, delfc keeps the overloads the call types against, then the most specific,
the one the others become by binding their type parameters (`Twice<T>` is `Twice<T, U>`
with `U = T`). `--explain overloads` gives a hint where the tie-break chose (user). Test
`overloads_explain.delf`, 🧪 dcc32 and dcc64 as predicted.

**`_` for a type argument delfc infers** ✅ (user, 25 Oct). Usually none is written. Where
one must be (a body that says nothing of its type, like `λx -> Absent`), the type arguments
follow the declaration's list, slot by slot, whether the call is written with the dot or
without: Optional's `Map<T, U>` takes two, so `O.Map<_, Optional<Integer>>(λx -> Absent)`
names `U` and leaves `T` to `O`, and `Map<_, …>(O, F)` means the same. A method's list is its
own: `TBox.Apply<U>` takes one, its record's types not among them. A wrong count is an error
with the `_` form as its fix (`Map<_, TPoint>`). dcc32 takes all type arguments or none, so
delfc writes each one out. In plain Delphi `_` stays a name: two corpus projects declare a
type `_` (delphimvcframework, OmniThreadLibrary), and no file writes one as a type argument.
Precedent (Claude, from memory, unchecked): Rust's `_` in type arguments, `collect::<Vec<_>>()`.
Tests `type_arg_holes.delf` (🧪 dcc32 and dcc64 as predicted), `type_arg_holes_errors.delf`.

**`a < b, c > (d)` is type arguments: the syntax decides** ✅ (raised by the user, 17 Oct,
from Rust's turbofish; decided by the user the same day, implemented in delfc). In a comma list (arguments, `[ … ]`, and now Delf's tuples), these
tokens are either two comparisons or one call `a<b, c>(d)`. **dcc32 decides by what `a` is**
(experiment 22, verified): with `a` an integer, `F(a < b, c > (d))` passes two Booleans, and
a local variable hiding a generic method turns the same tokens into comparisons. A
context-free parser can't do that, and the tree-sitter grammars (Delphi's and Delf's) always
read a call, as C# does (`>` followed by `(` closes type arguments). Rust's answer, the
turbofish `parse::<u32>()`, isn't open to Delf, because `Foo<Integer>(Y)` is Delphi's own
spelling.

The rule: **the syntax decides, and names only confirm.** `a < b, c > (…)` is always type
arguments. Where `a` is not a generic routine or type, it is an error naming the fix:
*"bracket the comparisons: `(a < b), (c > (d))`"*. So the highlighter, the transpiler and the
reader agree without looking anything up. A tuple meant as two comparisons is written
`((a < b), (c > (d)))`. This is subtractive (§8): the plain Delphi `F(a < b, c > (d))`, which
dcc32 accepts, becomes an error in Delf. It's rare, since it needs two comparisons with the
second right-hand side in brackets, and the fix is mechanical. Where delfc can't see `a`
(another unit, until it reads interfaces), it gives a hint, not an error. The user, deciding:
*"It's fine for some Delphi code to be called incorrect or flagged"* (§8).

**Conditional expressions** 🟡. Delphi 13's `if C then X else Y` is kept, with four
additions:

1. **`IfThen` gets a hint** ✅ (user). It is a function, so both arguments are evaluated:
   `IfThen(Assigned(P), P.Name, '')` reads `P.Name` on nil: an access violation (experiment
   13d, verified). The expression form evaluates
   only the chosen branch.
2. **A hint, not a rule, inside a larger expression** (user). In
   `Base + if Vip then 10 else 0 + Tax`, dcc32 binds `0 + Tax` together, so `Tax` is inside the
   `else` (experiment 13a, verified). Delf leaves the parse to Delphi and hints: *"the else
   branch extends to the end of the expression; parenthesise the if"*.
3. **Inferred types must be types someone would write.** dcc32 types each constant branch
   like an untyped constant, the smallest fit, then widens: `else 0` gives `[0..127]`,
   `else 200` `Byte`, `else 1000` `[0..32767]`, `else 40000` `Word`, `else 2.5` `Extended`
   (13b, verified). So `var Count := if Reset then 0 else 1` is a **one-byte subrange**:
   `var I := 0` infers `Integer`, but `var J := if True then 0 else 1` infers `[0..127]`
   (13g), and 300 increments raise `EIntOverflow` (13f; silent wrap presumably under `{$Q-}`,
   the directive problem of §12 again). Strings are *not* narrowed: `'a'` against `''` infers
   `string` (13c), so the rule is also inconsistent across types. And `Extended` is 10 bytes on Win32 but `Double` on
   Win64. Rule: *a binding inferred from a conditional gets the type its literals would get
   alone* (`Integer`, `Double`), never an anonymous subrange or `Extended`; the transpiler
   writes the type into the output. With an expected type, both branches convert to it, and
   bare arm names work (`Result := if X >= 0 then Present(Sqrt(X)) else Absent`).
   **Experiment 23 (verified, Win32 and Win64):** a named true constant (`const N = 3`) feeds
   inference exactly like its literal: `var A := N` is `Integer`, and inside a conditional
   it narrows like a literal (`if Vip then N else 0` is `[0..127]`). But "the type its
   literals would get alone" is `Integer` for integers only: **a bare `var G := 2.5` is
   already `Extended` on Win32** (10 bytes; `Double` on Win64), with no conditional
   involved. 🟡 So the rule should say `Integer` and `Double` outright, for every inferred
   binding from a float literal or constant, not only for conditionals.
   **Decided for floats ✅ (user, 19 Oct): `var G := 2.5` and `const H := 2.5` are
   `Double`** on every platform. delfc writes the type out (`var G: Double := 2.5`), in
   `.delf` files only. Plain Delphi passes through unchanged and keeps `Extended` on Win32
   (user: *"will we know if some non-delf file assumes different?"*). Where the two meet:
   passing `G` to a `var X: Extended` parameter is a compile error (E2033), but an
   overload on both `Extended` and `Double` silently picks `Double`, on Win32 only. A hint
   on `var G := 2.5` in plain Delphi is a checker candidate. 🧪 dcc32: `SizeOf(G)` = 8 on
   Win32 and Win64.
4. **Three or more links suggest `match`** (the arity-0 `match` question in §12).

**Rejected:** `if` without `else` yielding `Optional<T>`. A missing branch would silently
change the expression's type; Rust makes this an explicit method (`then_some`). Write
`else Absent`.

**Declarations stay explicit** ✅ (user agreed). Type parameters and full return types are
written on declarations; inference happens at call sites only. `function Logged<A>(V: A;
Log: string): TWriter<A>`, not `function Logged(V: A; Log: string): TWriter`. Reasons:

- A unit's `interface` section has no body to infer a return type from, and other units
  compile against the declaration alone. A signature is a contract.
- **Implicit type parameters are fragile.** The user's narrow rule: the return type names a
  generic with its arguments omitted (`TWriter`, only `TWriter<>` exists), and unknown names
  in the parameters fill the slots. With one parameter this is unambiguous
  (`Logged(V: A; …): TWriter` = `Logged<A>`). It breaks with several: `Pair(X: A; Y: B): TPair`
  could be `TPair<A, B>` or `TPair<B, A>`, and reordering parameters would silently change the
  answer. It also leaves a small typo window: `Logged(V: Strng; …): TWriter` makes `Strng` a
  type parameter instead of an error. (A broad rule, "any undeclared name in a signature is
  a type parameter", is much worse: every mistyped type name stops being *E2003* at the typo.
  Haskell avoids that with a case rule; Delphi has only a convention.) Agreed not worth it.
- The noise is at call sites, which are many, not declarations, which are one.

Free generic functions exist — no need for a carrier record or class. UFCS means
`F(X, Y)` and `X.F(Y)` are the same call, so a free function can be written in method
position.

**A member wins, and delfc says so** ✅ (user, 31 Oct: *"silent shadowing is a big problem"*;
1 Nov, *"Developers have to be able to name their code … But we want to give them the
info"*). Where `X`'s type has a member `F` (its own, inherited, or a helper's) and one of the
writer's routines `F` would take `X`, Delphi calls the member. delfc warns, naming both, as
Kotlin's *"extension is shadowed by a member"*; `F(X)` calls the routine. Where the member
can't take the call (TStringHelper's static `Parse(Value)` against `S.Parse`), it is delfc's
error rather than dcc's E2250. A member's defaults count: it takes the call if the
arguments cover the parameters it has none for. The RTL's own pairs (`S.Trim` beside
`Trim(S)`) are not said. Tests `member_shadows.delf`, `member_shadows_errors.delf`; the
natural sort's `Run[1].IsDigit` shows it (`poc/examples/08-natural-sort/2-pipeline.diag`).

---

### Lazy sequences, `Seq<T>` ✅

(user, 8 Nov: *"Can we tackle pipelines?"*; `docs/lazy-sequences.md`.) A `Seq<T>` is a recipe: nothing runs until a consuming step does, and then each element passes through every step before the next, so a chain stops early and a source may be endless:

```pascal
const Primes := From(2).Filter(IsPrime).Take(25);   // no bound guessed
Writeln(Primes.Map(IntToStr).Join(' '));
```

- Sources, plain functions (the user: *"Plain functions is the go"*; no range syntax): `From(N)`, `Range(A, B)`, `Iterate(X, F)`, `Xs.AsSeq`.
- Lazy steps: `Map`, `Filter`, `Take`, `TakeWhile`, `Drop`, `Zip` with an array.
- Consuming steps: `ToArray`, `Count`, `Sum`, `Join`, `First` (an `Optional`).
- Consumed twice, a sequence runs twice, effects and all; no hint (the user: *"3 no"*).
- An endless source consumed with nothing to stop it is an error (the user: *"4 sure"*).
- Output: `Delf.Seqs`' `TSeqs`, a method reference per sequence (push style, 🧪 experiment 64: faster than the eager arrays and than Spring4D's `IEnumerable<T>`). Two sequences in step need pull style: `Zip` takes an array (note §3.3).

## 7. Ownership

- An owned local is scope-bound: the transpiler emits the `try/finally`.
- `Free` consumes the reference. Using or freeing it again is a compile error.
- Move-on-assign: assigning an owned reference transfers it; the source is dead.
- `owned` fields generate the destructor.
- **Banned:** a Delf class referenced both by object reference and by interface.
- Crossing to the VCL or other foreign code requires an explicit release (see §9).

```pascal
var L := TStringList.Create;      // no Free needed, no try/finally written
L.Add('x');
```

---

## 8. The subtractive half

These are removals. They break existing code and that is the point. The user (17 Oct):
*"It's fine for some Delphi code to be called incorrect or flagged. `with` is an example, and
we have had other examples raised about code we want to check and warn/hint/error."*

- **Non-exhaustive `case` is an error.** Bare `case` over an enum must cover every value
  or have an `else`.
- **`{$BOOLEVAL ON}` rejected.** `and` and `or` always short-circuit. Narrowing cannot
  be sound otherwise.
- **`with` removed.**
- ✅ **`a < b, c > (d)` in a comma list is always type arguments** (§6). Delphi's
  name-dependent reading as two comparisons needs brackets: `(a < b), (c > (d))`.
- ✅ **`[A..B]` in a `for … in` header or on the right of `in` is a range, not a set**
  (user, 19 Oct), so it can go past 255 (`for var I in [0..1000]`); output `for I := A to B`
  and `InRange(X, A, B)`. In plain Delphi, `[A..B]` with bounds that aren't constant gets a
  **warning** (user: *"a warning, I think"*): experiment 24 found bounds past 255 wrap
  silently, and `in` differs between Win32 and Win64. **No warning when both bounds are
  byte-sized** (user, 19 Oct): their type's range lies within 0..255 (`Byte`, `AnsiChar`,
  `Boolean`, an enum, a subrange inside 0..255). `ShortInt` doesn't count: its negative
  values are outside a set's range too. Implemented in delfc (`poc/README.md`). Note: `docs/todo-ranges.md`.
- **No implicit conversions.** Literals take their type from context; nothing else
  converts silently.
- **Unused fields and variables are errors**, not silence.
- **Mixed-base indexing** is gone: `string` and dynamic arrays index consistently.
- **`Succ(High(T))` and `Pred(Low(T))` are always errors.** Today they raise
  `ERangeError` under `{$R+}` and silently produce an out-of-range value under `{$R-}`
  (verified, dcc32; see `experiments/`). Delf removes the dependence on the directive:
  rejected at compile time where the argument is statically known, checked at runtime
  otherwise, regardless of `{$R}`. **This is what makes exhaustive `match` sound.** An
  enum variable holding `Ord = 4` matches no arm, so exhaustiveness is only a guarantee if
  out-of-range values can't be created. The same applies to hard casts such as `TDir(5)`,
  which Delf restricts to checked conversions.
- **A function defines its result on every path** ✅ (user, 17 Oct, "if we can swing
  that"). dcc32 only warns (W1035, which experiment 17 hit on a `case` that covered every
  value). An empty-bodied function lambda is the simplest case and is an error; an
  empty-bodied *procedure* lambda (`λ(Sender) begin end`) is a no-op callback and stays
  legal. How much flow analysis this needs is open.
  **`noreturn` helps** (user, 17 Oct; 🧪 experiment 20). Delphi 13 marks a procedure that
  always raises, and dcc32 then counts a path ending in a call to it as defined: W1035 goes.
  dcc32 checks the mark itself, with **W1080** when a `noreturn` procedure can return (on
  any path), and the program then reads an undefined result. Candidates for Delf, 🟡: W1080
  becomes an error; a `case` made exhaustive by Delf gets `else` plus a call to a `noreturn`
  helper in the output, which gives dcc32 the proof that W1035 asks for (the hoist's two
  W1035s are that shape). Not covered by `noreturn`: "don't ignore what this returns"
  (a `[nodiscard]`). Delphi 13 has none (checked: `System.pas` declares eight compiler
  attributes; an unknown one is W1074 and has no effect).
- **Discarding a result is explicit** 🅿️ **parked by the user, 20 Oct**, after the survey below
  (*"this is good research. I think we can park the idea at this stage"*). Claude's proposal,
  recorded at the user's request, 17 Oct. What's settled so far: a warning, not an error,
  with a way to leave out the RTL; the exceptions are still open. The other end of the
  contract: the callee defines its result on every path, and the caller either uses it or
  says it doesn't want it.
  - Calling a function as a statement, `F(X);`, is an error. Delphi accepts it silently; its
    only lever is `{$X-}` (E2014), which applies to the whole file and turns off the rest of
    the extended syntax with it.
  - The explicit discard is `_ := F(X);`, reusing the tuple wildcard `(Q, _)`. C#, Go and
    Swift spell it the same way. Output: `F(X);`.
  - Opt-out for functions mostly called for their effect: `[discardable]`, after Swift's
    `@discardableResult`, spelled as an attribute like `[ref]`
    ([`docs/todo-attributes.md`](docs/todo-attributes.md)).
  - Open: the existing RTL. `TList.Add` returns an index almost nobody wants, so imported
    routines might get a hint rather than an error, or a list of known side-effect
    functions.
  - **Decided for now ✅ (user, 19 Oct): a warning, not an error**, *"with maybe a flag to
    exclude RTL"*, so routines from the RTL (or any unit not written in Delf) can be left
    out. **Before choosing the default, survey real code** (user: *"we could look in
    codebases like spring4d and others we have noted"*): how often a function is called as
    a statement, and which functions. delfc can't read other units' declarations yet, so
    at first the check sees only functions declared in the same file.
  - **The survey, experiment 30** (🧪 by name, 20 Oct): 0.8–9.0% of call statements discard
    a function's result. What gets discarded falls into five groups, and they suggest the
    warning's exceptions (🟡 Claude, for the user):
    - **C API functions** (`OffsetRect`, `SetWindowPos`, `ReleaseDC`): declared `external`,
      so they can be recognised exactly. This group, not the RTL as a whole, is most of the
      "RTL" noise.
    - **Fluent builders** (`Container.RegisterType<T>.AsSingleton;`): every chain ends by
      discarding the builder. A method returning its own type could be exempt, which is the
      case Swift's `@discardableResult` was made for.
    - **Throw-helpers** that always raise but are typed as functions (Spring's
      `ArgumentOutOfRange: NativeInt`): `noreturn` (experiment 20) is the right marking.
    - **VCL calls whose result is often not needed** (`Perform`, `MessageDlg` with one
      button, `ShowModal`): a real judgement call; a warning is defensible.
    - **Deliberate discards** (test helpers returning an id): what `_ :=` is for.

---

## 9. Transpilation — what the output looks like

### 9.0 The output restates Delf's guarantees where dcc32 can check them

A developer may edit the transpiled output, so its safety should not rest on runtime checks
that Delf proved unnecessary. Rule: **whatever Delf has checked, the output restates in a
form dcc32 also checks** (a constraint, a distinct type, a signature). Where Delphi cannot
express the guarantee, the output is **specialised so the question never arises**, rather
than guarded at runtime.

- **Monomorphised output needs no cast.** `Optional<TCustomer>` becomes a record whose
  presence test is plain `FValue <> nil`. No helper, so no misuse.
- **Generic output splits by constraint.** If `Optional<T>` must stay generic, emit
  `TOptionalRef<T: class>` and `TOptional<T>` and choose per use. Editing the output to write
  `TOptionalRef<Integer>` is then an E2511 compile error. (Revzin's `optional_ref`, harmless
  here because users only ever see `Optional<T>`.)
- **Never emitted:** runtime-checked escapes such as `TCast.ToObject<T>`
  (`docs/library.md`). An unconstrained Delphi generic cannot be made to fail at compile
  time for the wrong `T` (no `static_assert`; `GetTypeKind` folds after type checking,
  experiment 10). Those helpers are for hand-written Delphi only.

**Conditional expressions in the output.** A Delf `if … then … else` expression is emitted
as a Delphi conditional expression *except* when a branch calls through a method reference
**and the result type is a generic type parameter**: then it is emitted as an `if` statement.
dcc32 rejects that combination with E2010, with or without arguments (experiment 12,
verified); the same call with a concrete result type compiles (13h, verified). Since Delf monomorphises, this bites only output that
stays generic.

**Known exception: sum-type getters.** The generated `TStep` has guarded property getters,
so reading `.Pos` on an `Exited` step raises at runtime. Delphi cannot make field access
depend on the tag. Inside Delf, `match` makes the bad read unwritable; in edited output the
runtime guard is the best available. The output should say so in a comment on the getter.
Alternative: a "sealed sums" output mode with `Match<R>` (one handler per arm) as the only
accessor, which makes the bad read unwritable even in edited output, at a cost in speed and
readability (`docs/todo-functional-core.md` §8).

### 9.1 Non-recursive sum type → tagged record

Non-overlapping fields (managed types cannot safely share storage), a `Kind` tag,
static constructor functions, guarded property getters.

```pascal
type
  {$SCOPEDENUMS ON}
  TStepKind = (Moved, Turned, Exited);
  {$SCOPEDENUMS OFF}

  TStep = record
  strict private
    FKind         : TStepKind;
    FMovedPos     : TPoint;
    FTurnedFacing : TDir;
    function GetPos: TPoint;
    function GetFacing: TDir;
  public
    class function Moved (const APos: TPoint): TStep; static; inline;
    class function Turned(AFacing: TDir): TStep;      static; inline;
    class function Exited: TStep;                     static; inline;
    property Kind   : TStepKind read FKind;
    property Pos    : TPoint    read GetPos;
    property Facing : TDir      read GetFacing;
  end;

function TStep.GetPos: TPoint;
begin
  if FKind <> TStepKind.Moved then
    raise EInvalidOpException.Create('TStep.Pos read on wrong arm');
  Result := FMovedPos;
end;
```

**Naming (user, 21 Oct) ✅.** The tag enum is **scoped** in the output, its values are the
arm names, and the output always writes them **qualified**: `TStepKind.Moved`,
`TTxnKind.Cheque`. This replaces 19 Oct's initials (`skMoved`, `tkCheque`). Why:

- An alias carries a type's name but not its values (experiment 31, E2003), so only the
  qualified form works wherever the type does, without the declaring unit in `uses`.
- Scoping keeps the values out of the unit's namespace, which the prefixes did by
  convention. A bare value could be mistaken for the maker `TStep.Exited`, hide an RTL
  routine (an arm `Abort` against `SysUtils.Abort`), or clash with another sum's arm of
  the same name (both 🟡 predicted, not compiled). Initials weren't unique either: `TStepKind` and `TSaleKind` are
  both `sk`.
- Scoped enums are modern Delphi practice, and the output targets Delphi 13.
- The cost is width: `TTxnKind.Cash, TTxnKind.Card :` instead of `tkCash, tkCard :`.

delfc wraps the declaration in `{$SCOPEDENUMS ON}` … `{$SCOPEDENUMS OFF}`, so the file's own
enums keep their setting, and leaves the directives out when the source has already turned
scoping on. Delf source is unchanged: there a bare arm is resolved from the expected type
(§3.2).

**The tag is output-only, for now (user, 21 Oct) ✅.** `Kind` is public in the output
because the generated `case` reads it from outside the record, from other units too. But
Delf code may not read it: `S.Kind` is an error, like a payload read (§9.0), and its fix is
`match S of`, where a bare arm name ignores the payload (`| Moved :`). `match S.Kind of`
said the same as `match S of` (the user noticed), and exposing the tag would tie every
future representation (§9.2, flat pools) to an enum of its arms. Not yet enforced: naming
the kind type (`TStepKind`) in Delf source. **Reason to revisit:** arm-keyed tables, the
plain-Delphi pattern `array[TTxnKind] of Currency`, which is coverage checking for data
and lets the arms be values (looped over, kept in sets, `Kinds.Map(FeeOf)`;
`docs/todo-tables-are-functions.md` §1, §4). A `match` gives the same check as code, so
nothing is lost in checking; revisit if a real program wants the arms as data.

**The cases' order, without the tag: `CompareByOrd(A, B)` (user, 17 Nov) ✅.** The first real
program to want more than a `match` was the natural sort (phase 5): tokens of different kinds
compare by the order `TToken` declares its cases, and the draft wrote that order out again by
hand, `KindRank`, `Symbol` 0, `Digits` 1, `Letter` 2. `CompareByOrd(A, B)`, in the library,
compares two values of one sum type by their cases' declared order, -1, 0 or 1, the payloads
ignored; `A.CompareByOrd(B)` too. As `Ord` of an enum value is its position, so here of a case.
It is an error unless both are values of the same sum type; where one names the sum, the other
may be a bare arm, `CompareByOrd(Dot, Letter('z'))`. delfc writes
`TFunctions.CompareByOrd(Ord(A.Kind), Ord(B.Kind))`, so the tag stays the output's. What
Delf gets is the comparison, not the enum: no position as a number, and no `<` on sum values
(each case's payload may compare its own way, as the natural sort's digits and letters do).
Demo 22; tests `compare_by_ord`, `compare_by_ord_errors`.

When two arms have a field of the same name, both become arm-prefixed in the output
(`Number` in `Cheque` and `Card` → `ChequeNumber`, `CardNumber`) and delfc gives a **hint**
saying so (user, 19 Oct ✅).

**Every runtime guard is unreachable from Delf.** The checker proves `Pos` is only read
under `TStepKind.Moved`. The guards exist for plain-Pascal callers of the generated unit — the
foreign boundary — and cost nothing in Delf-originated code.

### 9.2 Recursive sum type

The split is **recursive by value**, not "recursive". An arm holding the type through a
pointer-shaped field (dynamic array, interface, class reference) is still fine as a
record, since its size is known.

Genuine by-value self-reference and mutual recursion use a sealed class hierarchy
behind a refcounted interface. Because arms are immutable, the value is acyclic by
construction, so refcounting is exact rather than approximate — there is no cycle leak.

**Verified (dcc32, `experiments/` 5a to 5g):**

| Sum type | Encoding |
|---|---|
| Non-recursive, generic or not | tagged record |
| Recursive through a dynamic array, non-generic | tagged record. The full generated shape is verified: tag, private fields, static constructors, getters (5c) |
| Recursive through a dynamic array, **generic** | tagged record **nested in a generic container**, `TTree<T>.TNode`. A plain generic record fails with E2086 *"not yet completely defined"* (5d); nesting avoids it (5e), and the full generated shape works nested (5g) |
| Recursive by value, or mutually recursive | refcounted interface holding `TArray<` itself `>` (5f) |

So classes are needed only for by-value and mutual recursion, and even then as refcounted
interfaces with no `Free`.

**Correction on record:** a report that `TRec<T> = record Data: T; Next: ^TRec<T>; end`
compiles turned out to be wrong. Retested, self-reference through `^` works only
non-generically, like `TArray` (5a versus 5d), and so does `array of` (5h). The E2086
reading stands: a generic record can't refer to itself by any route, so the
nested-container workaround remains necessary. (Pointers
would be unmanaged anyway — manual `Dispose`, unsafe to copy — so refcounted interfaces
remain the choice for by-value recursion.)

**Boundary cost:** a Delf generic recursive sum `TTree<T>` appears to plain-Pascal callers
as `TTree<T>.TNode`. Delphi has no generic type aliases, so the nested name can't be
hidden. Delf users never see it.

### 9.3 `match` → `case`

```pascal
case S.Kind of
  TStepKind.Moved  : begin Seen.AddOrSetValue(S.Pos, True); P := S.Pos; end;
  TStepKind.Turned : D := S.Facing;
  TStepKind.Exited : Break;
end;
```

**An exhaustive `match` gets `else __dpp_Unreachable`** ✅ (user, 19 Oct, "ok for now"), a
`noreturn` helper. Without it dcc32 gives W1035 even on a `case` that covers every value;
with it, none (experiment 20, 🧪 dcc32 and dcc64). If an edit to the output adds an enum
value, the new value raises rather than silently running another arm's code. **It is
given the type's name and the ordinal** ✅ (user, 19 Oct), `__dpp_Unreachable('TDir',
Ord(D))`, and raises `Delf: a match met TDir ordinal 7, which it does not cover`. Not the
value's name: `GetEnumName` reads past its table for a corrupt value (experiment 27). A
scrutinee that isn't a plain name is evaluated once, into a temporary, so the `else`
doesn't evaluate it again. 🧪 dcc32 and dcc64: `TDir(7)` gives that message, and so does a
`Boolean` holding 2 (experiment 29).

**On a closed type, `_` is every other valid value** ✅ (user, 25 Oct: *"_ should mean any
other valid value, I think. and we still have a trapdoor for any other random garbage"*).
delfc writes the values `_` stands for as labels (`TOptionalKind.Absent :`, `Up, Down, Left :`,
`3..9 :`), and the `else` is `__dpp_Unreachable` as for a match with no `_`. So a corrupt tag
raises whether or not the match has a `_`, and narrowing (a match with `_`, §5) gets the same
safeguard. Before, `_` was Delphi's `else`, and a corrupt tag ran the `_` arm (the slide on
versions A–D of 06's `Start`). On an open type (Integer, `Char`, strings) `_` is still the
`else`. 🧪 dcc32 and dcc64: an `Optional<Integer>` with its tag set to 7, narrowed, raises
`Delf: a match met TOptionalKind ordinal 7, which it does not cover`; `sums`, `nested` and
`narrowing` print what they printed before. **A match that assigns** (`X := match …`, a
binding) ends in `X := __dpp_UnreachableAs.Value<T>(…)`, a `noreturn` generic function:
with a managed value in scope, dcc32 forgets a `noreturn` procedure for W1036 (experiment 41).

**A `match` on a string is a `case` too** (31 Oct; before, an `if … else if` chain of `=`
and `or`, from 23 Oct). `case` needs an ordinal, so the scrutinee is looked up among the
arms' labels, in order, with `System.StrUtils`' `IndexStr`, and each arm is a run of
positions: `case IndexStr(Cmd, ['quit', 'exit', 'help']) of 0..1 : …; 2 : … else … end`, the
`_` arm the `else`. When every arm's value is `True` or `False`, the match is a membership
test and becomes `MatchStr(Op, [the labels of the arms that differ from _])`, `not MatchStr`
when `_` is `True` (user: the walker's `Tighter`, *"exit( matchstr(Op, [...] )"*). Both are
case-sensitive, as `=` is, and read the scrutinee once, so no temporary. A long list goes over
the fewest lines within 80 columns, spread evenly. 🧪 dcc64 (Claude, 37.0):
`poc/tests/cases/match_strings.delf`, `match_strings_member.delf`. With a guard, an `if` chain (§4.3).

**A match on a class is an `if … else if` chain** (§4.3; 2 Nov), each arm's classes joined by
`or`, `_` the `else` (none when empty). The scrutinee is read once, into a temporary unless it
is a name: `var T := X.ClassType; if T = TStringList then … else …`, or `if X is TStrings then
… else if X is TList then …`. 🧪 dcc64 (Claude, 37.0): `poc/tests/cases/match_class.delf`;
errors in `match_class_errors.delf`.

**`X in ['a', 'bc']` on a string is `MatchStr` too** (31 Oct, user, on the walker's
`if K in ['exprBinary','exprUnary']`: *"love it"*). A Delphi set can't hold strings (🧪
dcc64: E2015), so Delf gives the form a meaning: `MatchStr(X, ['a', 'bc'])`, case-sensitive,
`X` read once. It applies when every item is a string literal and `X` is a string, or `X`'s
type is unseen and an item isn't one character long. A `Char` keeps Delphi's set, and so does
a list with anything but string literals. 🧪 dcc64 (Claude, 37.0):
`poc/tests/cases/in_strings.delf`.
Whether a `noreturn` *function* (accepted, experiment 20 FUNC) silences W1035 inside an
`if` expression is untested.

Nested patterns decompose into a test plus an inner `case` (in delfc, 23 Oct; 🧪 dcc32 and
dcc64, `poc/tests/cases/nested.delf`): the arms of one tag that test inside a field become
one label whose body is a `case` on that field, the tag's binding arm (`Present(V)`) its
`else`, and an enclosing `_` the `else` of an inner `case` that doesn't cover its field. A
bare name inside an arm binds unless it is a value of the field's enum or an arm of its
sum (🟡 Claude's rule, for review: §4.3's table says a bare name binds, and
`Present(Wall)` needs `Wall` to be a value). A `match` expression in
statement position assigns to a temp. In arbitrary expression position, hoist the temp
to the innermost enclosing statement — **except** under `and` / `or`, where hoisting
across the short-circuit boundary changes evaluation counts; emit a nested `if` instead.

### 9.4 `Optional<T>` → `HasValue` + `Value`

The two-arm sum, same encoding. A bare pointer with a nil test for class `T` is a permitted
optimisation, not a requirement (§5).

Chained `Map`/`AndThen` on `Optional` fuse into sequential early exits:

```pascal
// Delf
Result := Cells.Lookup(P.Y).AndThen(λRow -> Row.Lookup(P.X));

// transpiled
if (P.Y < 0) or (P.Y > High(FCells))      then Exit(TOptionalCell.Absent);
if (P.X < 0) or (P.X > High(FCells[P.Y])) then Exit(TOptionalCell.Absent);
Result := TOptionalCell.Present(FCells[P.Y, P.X]);
```

No intermediate optionals, no closures, no allocation.

### 9.5 Ownership → `try/finally`

Scope-bound locals emit the block. `owned` fields emit the destructor.

### 9.6 Everything else

Nothing in the output is novel Delphi: tagged records, static constructor functions,
`case`, `try/finally`, ordinary generics. Inline variables set the floor at 10.4.

### 9.7 `{ delf: debuglines }`: the output names the `.delf` ✅

A file with **`{ delf: debuglines }`** among its first lines gets dcc's undocumented
`{$LINE N 'file'}` directives in its output (user, 12 Nov: *"in a delf file, we might only use
the {$line} approach with a {delf: debug transpile} or similar line"*, then *"i anticipate
multiple debug flags .. so maybe debuglines"*). dcc's messages, the IDE's Messages pane,
`Assert`'s text and the debugger then name the `.delf` file and its lines. Off by default, so
the output stays plain; delfc's own build and editor map lines back without it.

`{$LINE N 'file'}` makes the next line line N of that file, and the rest of its own line N−1
(found for the DPPS starter, 11 Nov). The output starts with one naming the `.delf` by its full
path. After that, wherever an output line isn't the line after the one before it in the source,
the line before it gets `   {$LINE N}` after its code (before a `//` comment on it). A line
delfc generates takes the source line it came from, so each generated line carries one; a
`match` or a sum type's record names the line it was written on. After each conditional
directive the number is set again, since a directive inside a branch counts only in the
builds that take it. None at the end of a line inside a comment or string running on to the
next, nor after the final `end.` (W1011). 🧪 dcc64 37.0, 12 Nov (Claude, predicted first): an error
on line 22 of a `.delf` reported as `ErrorProbe.delf(22) Error: E2010`, a failed Assert as
`(…AssertProbe.delf, line 21)`; demo 11.

---

## 10. Delphi smell → Delf form

The lookup table for translation. Left column is what to search for in existing code.

| Delphi | Delf | Why |
|---|---|---|
| `record` with a `Kind`/`ok` tag and fields valid only for some tags | sum type | The invariant moves from the programmer's head into the type |
| variant record (`case ... of` in a record) | sum type | Same, and variant records can't hold managed fields at all |
| `TryGetValue(K, V)` | `Get(K): Optional<V>` | Removes the out param, the statement, and the `begin` it needed |
| `IndexOf` = `-1`, `FirstOrDefault`, `Default(T)` | `Optional<T>` | `-1` is a valid Integer; `Default(T)` is indistinguishable from real data |
| `function F(...): Boolean` that also mutates `var` params | sum type return | Boolean cannot say *which* of three things happened |
| bare `case` with no `else` | `match` | Exhaustiveness checked |
| `if C then Exit(True) else Exit(False)` | `Exit(C)` | Always was available |
| chained `if ... else if` over one value's shape | `match` | §4.5 |
| `case IndexStr(S, [...]) of 0, 1: ...` or an `if S = '...'` chain | `match S of \| 'a', 'b': ...` with `\| _:` | Strings are constant patterns; no parallel index list to drift. Case-insensitive → `match LowerCase(S) of`. Prefer matching strings once, at the edge, into an enum |
| `TComparer<T>.Construct(...)` / comparer class | key function `λx -> ...` | `Equals` and `GetHashCode` derive from one expression and cannot disagree |
| parallel `const` table + `case` that must agree | `match` returning the value | One table, checked |
| `inc(D)` / ordinal arithmetic on an enum | `match` | Survives reordering the declaration |
| `trunc(X / 2)` | `X div 2` | Float round trip for integer halving |
| four near-identical functions differing in constants | one function + derived constant set | Transcription drifts; derivation can't |
| `array of string` used as a grid | a grid type with `At: Optional<TCell>` | Removes mixed-base indexing and all bounds arithmetic |
| `Create` with no matching `Free` | scope-bound local | Uncheckable discipline becomes generated code |
| `var L: TList<T>` parameter that is never reassigned | `var` meaning mutable-referent (§3.4) | The keyword starts describing the right thing |
| `word` / `byte` loop counters with `dec` | `Integer` | `dec(0)` wraps rather than faulting |
| global data unit + functions reaching module scope | parsed value passed as a parameter | Parse, don't validate |
| a comment describing the intended expression | write the expression | If it can't be written, that's the finding |

---

## 11. Rules for the translator

**Do:**

1. Keep the program's shape. Same functions, same loops, same order, unless a
   *declaration* change removes the need for one.
2. Introduce a type for anything currently encoded in a convention, a tag field, a
   sentinel or a comment.
3. Parse input into real types once, at the edge, rather than converting repeatedly.
4. State what you removed and why. A translation is an argument.
5. Flag every place the original has a latent bug the new types would have caught.
   These are the evidence the project runs on.
6. Say when something needs Stage 2 rather than quietly using it.

**Don't:**

7. Turn loops into pipelines. That is Stage 2 and it loses the audience.
8. Invent syntax. If the spec doesn't have it, say so.
9. Use `|` on a single-line declaration, or parens on a multi-line one.
10. Add a wildcard arm to a match over a closed type "for safety". It defeats the check.
11. Qualify arm names where the expected type is known.
12. Write a transpiled output you couldn't step through in the Delphi debugger.

**Deliverable shape.** For each source file, produce three artifacts:
`before/` (the original, unchanged), `after.delf`, and `transpiled.pas`. Plus a
`NOTES.md` saying what changed, what it caught, and what needed Stage 2.

---

## 12. Open questions

- **Does `Optional<Optional<T>>` flatten? Decided ✅ (user, 19 Oct): no. The type keeps
  both layers, and the operations decide.** Handover 1 recorded "flattens on
  construction", which broke the uniform-interface rule in §5: a generic `Get` on a map
  whose values are themselves optional could no longer tell "key missing" from "key
  present, value absent". User: *"bind implies flattening (join.fmap). maybe 2a as a base,
  and other operations decide how to utilise it"*. So `Map(F)` with `F` returning an
  `Optional<U>` gives `Optional<Optional<U>>`; bind, `AndThen(F)`, is join after fmap and
  gives `Optional<U>`; `Flatten` (join) is explicit. Rust, Swift and Haskell work the same
  way.
- **`?` for an `Optional` inside a function that returns one?** 🟡 (user, 23 Oct: *"maybe
  '?' might have a use for us"*; Claude's sketch). Rust's `let pos = start(input)?;` is
  the plain value, or, on `None`, a return of `None` from the enclosing function. In Delf,
  `const A := Digits(C)?;` would be `if not` it `then Exit( Absent )`, then a plain `A`:
  the statement form of bind (`>>=`, §5), and the end of the guard staircase in
  `poc/examples/README.md` endnote 1 (03's `ParseMul`), one step per line with no
  nesting. Cautions: the user rejected postfix `?` on types (`TCell?`) as not Delphi, and
  an expression `?` may meet the same objection; and it only works where the function
  returns an `Optional` (or a `Result`). Elsewhere, such as a main block, the arm-declared
  variable (§4.3) is the form.
- **Leaving top-level code in one step?** ⚪ (user, 24 Oct: *"maybe we will let delf use
  `Exit( writeln('...') )` to quit top-level code too. maybe use Halt"*). Today phase 5's
  `Absent` arm is `begin writeln('no start point found'); Exit; end`. In a main block
  Delphi's `Exit` already ends the program, so `Exit( writeln(…) )` would be the short
  form of that; `Halt` would also set an exit code. Rust's counterpart: `unwrap` at the
  top, with `panic_halt` on bare metal (the slides' appendix, `poc/examples/06-guard-patrol/slides/`).
- **Tracking the declaring arm at run time instead?** ⚪ (user, 23 Oct). §4.3 requires
  every arm but the declaring one to leave. The user's alternative: the output keeps a
  flag, set by the declaring arm, and a read of the variable checks it. Other arms could
  then carry on, and a read without a value would fail with a clear message rather than
  read garbage. A run-time check where §4.3 has a compile-time one; not pursued yet.
- `Result` as a type name collides with Delphi's pseudo-variable inside every function
  body. `TResult`? Something else?
- Does arity-0 `match` (a guard ladder, `cond`) earn a place in Stage 1?
- **Coverage a checker can't see, and a larger question behind it** ⚪ (user, 24 Oct).
  `Odd(N)` and `Even(N)` together cover every integer, but delfc can't know that: to it
  they are two opaque guards (§4.3, rung 2). User: *"sometimes we won't be able to tell."*
  The immediate rule (🟡 Claude): **a guarded arm covers nothing** for §4.4, as in Rust,
  Haskell and OCaml, so the last arm is written unguarded (`| _ :` for the even case).
  The user sees this as touching **a larger question not yet expressible**, maybe about
  proofs, or about describing types the way Haskell or Lean might. Recorded unshaped, on
  purpose. Pointers only (🅿️ Claude, not proposed): types carrying a predicate (Lean's
  `{n : Int // n % 2 = 1}`, Liquid Haskell's refinement types); a proved partition (Lean's
  `decide`, as in `proofs/Cousins.lean`); a partition declared once and trusted (F#'s total
  active patterns, GHC's `COMPLETE` pragma). Declared subranges (§4.4) are already the
  simplest case: a closed set of values the checker can count.
- Exact spelling of the foreign-boundary release for VCL ownership.
- **Directives that change semantics.** `{$BOOLEVAL}` decides whether a nil guard is
  safe; `{$I}` decides whether `ReadLn` reports bad input; `{$R}` decides whether
  `Succ` past the end faults (verified); `{$Q}` decides whether `dec` on a `word`
  wraps. In each case correctness depends on a switch that isn't on the line and may not
  be in the file. §8 already rejects `{$B+}`. Is the general rule *no directive may
  change the meaning of a correct program*, with the checks always on?
- **Generic constraints / traits.** Delphi already has `<T: class>`, `<T: record>`,
  `<T: IComparable>`. Delf needs constraints that name *operations* — `Eq`, `Ord`,
  `Ordinal`, possibly `Num` — because `IComparable` only works for classes, which is why
  Delphi collection code drowns in comparer objects. Open thread:
  [`docs/todo-constraints.md`](docs/todo-constraints.md).
- **Which aggregates return `Optional<T>`?** Likely decided by structure rather than
  taste: an operation with an identity (monoid) returns `T` for an empty collection;
  one without (semigroup) returns `Optional<T>`. So `Sum`, `Concat`, `All`, `Any` return
  `T`; `Min`, `Max`, `First`, `Average` return `Optional<T>`. Open thread:
  [`docs/todo-monoids.md`](docs/todo-monoids.md).
- **A block's last expression as its value?** (user's passing thought, 17 Oct, not pursued.)
  Rust marks the value by leaving off the semicolon. Pascal can't, because its `;` is a
  separator: `begin A; B end` and `begin A; B; end` are the same. Kotlin's unmarked rule
  ("the last expression is the result") would collide with Delphi, where a function called
  as a statement discards its result. The likelier route is a stronger expression form
  (conditional expressions, `match`, perhaps local bindings inside an expression), so a
  block is needed only for real statements.
- **List comprehensions: an unexplored idea** (user, 17 Oct). Python's
  `[F(X) for X in Xs if P(X)]`, seen in delfc's own code. The user read it as
  *for … if … expression*, which is the order a Pascal spelling would keep:
  `[for I := 0 to N - 1 do S.Substring(I)]`, where the expression after `do` is the element
  produced on each pass. The user: the simple list forms *"don't look too bad"*, but a
  one-line comprehension used as bind over `Optional`/`TParse` (Scala's `for`/`yield`) does
  not look right. Not explored further.
- **Rejected (user, 17 Oct): Python's negative indices, slices and spread** (`Xs[-1]`,
  `Xs[1:-1]`, `*Xs`).
