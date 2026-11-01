```pascal
// back arrow means Const x := ...
begin
      FnCharToCell  ← λ(ch: Char) -> if ch = '#' then Wall   { Type Assertion }
                                                 else Open;  { ::t Char -> TCell }
                   // function(ch:Char): TCell begin ... end;

      Input ← TGrid<Char>.Create(Lines, Id);  // convert const stringgrid input to TGrid<Char>
      Grid  ← Input.Map(FnCharToCell);        // create identical Grid of TCells
  var Seen := Input.Map(λch -> False);        // create identical Grid of Booleans
end;
```

```pascal
// 'normal'
begin
  const FnCharToCell := λ(ch: Char) -> if ch = '#' then Wall   { Type Assertion }
                                                   else Open;  { ::t Char -> TCell }
                   // function(ch:Char): TCell begin ... end;

  const Input = TGrid<Char>.Create(Lines, Id);  // convert const stringgrid input to TGrid<Char>
  const Grid  = Input.Map(FnCharToCell);        // create identical Grid of TCells
  var   Seen := Input.Map(λch -> False);        // create identical Grid of Booleans
end;
```