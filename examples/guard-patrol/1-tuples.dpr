{$APPTYPE CONSOLE}
program GuardPatrol;

{ examples/06-guard-patrol, written with what delfc transpiles today (17 Oct).
  Points and steps are tuples, destructured where they're used.

  after.delf's Advance returns a sum, TStep = | Moved(Pos) | Turned(Facing) | Exited.
  With no sum types yet it returns a tuple of a plain enum and both payloads,
  only one of which means anything for a given kind. after.delf's matches on
  TDir are written here as `case`. dcc32 can't see that a case covering every
  value is exhaustive (experiment 20: W1035), so each one ends in a `noreturn`
  Unreachable: the same output `match` will generate for itself.

  Input: the puzzle's published sample (AoC 2024 day 6, part 1).

  Predicted output (Claude, 17 Oct, before compiling; the turn count from a
  ten-line Python model of the puzzle, the rest from the puzzle text):
    start: 4 6
    turns: 10
    visited: 41 }

uses
  System.SysUtils, Delf.Tuples;

type
  {$SCOPEDENUMS ON}
  TDir  = (Up, Right, Down, Left);
  {$SCOPEDENUMS OFF}
  {$SCOPEDENUMS ON}
  TStep = (Moved, Turned, Exited);
  {$SCOPEDENUMS OFF}

procedure Unreachable; noreturn;
begin
  raise EInvalidOpException.Create('unreachable');
end;

function Step(D: TDir): TTuple<Integer, Integer>;
begin
  case D of
    TDir.Up   : Exit( TTuple<Integer, Integer>.Create(0, -1) );
    TDir.Right: Exit( TTuple<Integer, Integer>.Create(1, 0) );
    TDir.Down : Exit( TTuple<Integer, Integer>.Create(0, 1) );
    TDir.Left : Exit( TTuple<Integer, Integer>.Create(-1, 0) );
  else
    Unreachable;
  end;
end;

function Turn(D: TDir): TDir;
begin
  case D of
    TDir.Up   : Exit( TDir.Right );
    TDir.Right: Exit( TDir.Down );
    TDir.Down : Exit( TDir.Left );
    TDir.Left : Exit( TDir.Up );
  else
    Unreachable;
  end;
end;

// ' ' off the grid: Optional<Char> will say None instead
function Lookup(const Grid: TArray<string>; const P: TTuple<Integer, Integer>): Char;
begin
  var __dpp_1 := P; const X = __dpp_1.Item0; const Y = __dpp_1.Item1;
  if (Y < 0) or (Y >= Length(Grid))    or
     (X < 0) or (X >= Length(Grid[Y])) then Exit( ' ' );
  Exit( Grid[Y].Chars[X] );
end;

function Start(const Grid: TArray<string>): TTuple<Integer, Integer>;
begin
  for var Y := 0 to High(Grid) do
    if Grid[Y].Contains('^') then Exit( TTuple<Integer, Integer>.Create(Grid[Y].IndexOf('^'), Y) );
  Exit( TTuple<Integer, Integer>.Create(-1, -1) );
end;

// the kind says which of the other two means something: Moved -> the point, Turned -> the direction
function Advance(const Grid: TArray<string>; const P: TTuple<Integer, Integer>; D: TDir): TTuple<TStep, TTuple<Integer, Integer>, TDir>;
begin
  var __dpp_2 := Step(D); const DX = __dpp_2.Item0; const DY = __dpp_2.Item1;
  const Next: TTuple<Integer, Integer> = TTuple<Integer, Integer>.Create(P.Item0 + DX, P.Item1 + DY);
  case Lookup(Grid, Next) of
    ' ': Exit( TTuple<TStep, TTuple<Integer, Integer>, TDir>.Create(TStep.Exited, P, D) );
    '#': Exit( TTuple<TStep, TTuple<Integer, Integer>, TDir>.Create(TStep.Turned, P, Turn(D)) );
  else
         Exit( TTuple<TStep, TTuple<Integer, Integer>, TDir>.Create(TStep.Moved, Next, D) );
  end;
end;

begin
  const Grid: TArray<string> = [
    '....#.....',
    '.........#',
    '..........',
    '..#.......',
    '.......#..',
    '..........',
    '.#..^.....',
    '........#.',
    '#.........',
    '......#...'];

  var P       := Start(Grid);
  var D       := TDir.Up;
  var Turns   := 0;
  var Visited := 1;
  var Seen    : TArray<TArray<Boolean>>;
  SetLength(Seen, Length(Grid), Length(Grid[0]));
  Seen[P.Item1][P.Item0] := True;
  WriteLn('start: ', P.Item0, ' ', P.Item1);

  while True do
  begin
    var __dpp_3 := Advance(Grid, P, D); const Kind = __dpp_3.Item0; const Q = __dpp_3.Item1; const E = __dpp_3.Item2;
    var __dpp_4 := Q; const QX = __dpp_4.Item0; const QY = __dpp_4.Item1;
    case Kind of
      TStep.Moved : begin
                if not Seen[QY][QX] then Inc(Visited);
                Seen[QY][QX] := True;
                P := Q;
              end;
      TStep.Turned: begin Inc(Turns); D := E end;
      TStep.Exited: Break;
    end;
  end;

  WriteLn('turns: ', Turns);
  WriteLn('visited: ', Visited);
end.
