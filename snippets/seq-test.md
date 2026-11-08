```python
{APPTYPE CONSOLE}
program seq_test;
uses System.SysUtils;

function IsPrime(x:integer):boolean;
begin
   exit(true);
end;

begin
    const Primes := From(2).Filter(IsPrime).Take(25);
    Writeln(Primes.Map(IntToStr).Join(' '));
    Writeln(Primes.Count, ' ', Primes.Sum);
    Writeln(Iterate(1, λx -> x * 2).TakeWhile(λx -> x < 1000).Map(IntToStr).Join(','));

    Names ← ['ann', 'bob', 'cy'];
    // const Names: TArray<string> = ['ann', 'bob', 'cy'];
    for var P in From(1).Zip(Names).ToArray do
      Writeln(P[0], ' ', P[1]);
    Writeln(From(1000).Filter(IsPrime).First.OrDefault(-1));
end.
```
