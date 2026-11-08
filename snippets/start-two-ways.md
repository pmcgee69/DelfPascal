Equivalent 

```python
function Start(const Input: TGrid<Char>): Optional<TPoint>;
begin
  for var Row in Input.Rows do
    match Row.Find('^') of
      | Present(x) : Exit( Present(Point(x, Row.Index)) )
      | Absent     : {skip}
    end;
  Exit( Absent );
end;
```


```python
function Start(const Input: TGrid<Char>): Optional<TPoint>;
begin
  for var Row in Input.Rows do
    if Row.Find('^') is Present(x) then Exit( Present(Point(x, Row.Index)) );
  Exit( Absent );
end;
```
