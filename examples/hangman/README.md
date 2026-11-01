# Hangman, in Delf

A small demo: a game of hangman with the guesses decided in advance, so every run prints the
same. Shows `match` on strings, with several values in one arm and `_` for the rest, and
`for var (i, ch) in Word.Enumerate`.

| File | What | Lines |
|---|---|---:|
| [`1-strings.delf`](1-strings.delf) | Delf | 79 |
| [`1-strings.dpr`](1-strings.dpr) | the Delphi that delfc, Delf's transpiler, wrote from it, unedited | 86 |

## Result

```
e     _ E _ _ _ _
hint  a language, and an oracle
x     no, 4 chances left
l     _ E L _ _ _
p     _ E L P _ _
?     a language, and an oracle
z     no, 3 chances left
d     D E L P _ _
h     D E L P H _
i     D E L P H I
solved, with 3 chances left
```

## Building

```
dcc64 1-strings.dpr
```

No runtime units needed.
