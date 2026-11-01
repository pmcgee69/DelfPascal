```
{$APPTYPE CONSOLE}
program GuardPatrolGrid_Using_Optional;

{ Input: the puzzle's published sample (AoC 2024 day 6, part 1).  https://adventofcode.com/2024/day/6

The map shows the current position of the guard with ^ (to indicate the guard is currently facing up from the perspective of the map). Any obstructions - crates, desks, alchemical reactors, etc. - are shown as #.
Guards follow a very strict patrol protocol which involves repeatedly following these steps:
- If there is something directly in front of you, turn right 90 degrees.
- Otherwise, take a step forward.

  Output (Claude, 23 Oct, before compiling): 
    start: (4, 6)
    turns: 10
    visited: 41

  No warnings on Win32, Win64  }

uses
  System.SysUtils, System.Types, Demo.OptionalGrids;

const
  Lines: TArray<string> = [
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

type
  TDir  = (Up, Right, Down, Left);
  TCell = (Open, Wall);

  TStep =
    | Moved (Pos: TPoint)            // rust-style enum with payloads 
    | Turned(Facing: TDir)
    | Exited;

function Step(Dir: TDir): TPointDelta;
begin
  Exit( match Dir of
          | Up    : (dx: 0; dy: -1)  // spontaneous records
          | Right : (dx: 1; dy:  0)
          | Down  : (dx: 0; dy:  1)
          | Left  : (dx:-1; dy:  0)
        end
      );
end;

function Turn(Dir: TDir): TDir;
begin
  Exit( match Dir of
          | Up    : Right
          | Right : Down
          | Down  : Left
          | Left  : Up
        end
      );
end;

function Start(const Input: TGrid<Char>): Optional<TPoint>;
begin
  for var Row in Input.Rows do
    match Row.Find('^') of
      | Present(x) : Exit( Present(Point(x, Row.Index)) )
      | Absent     : {skip row}
    end;
  Exit( Absent );
end;

function Advance(const Grid:     TGrid<TCell>; 
                 const GuardPos: TPoint; 
                       Facing:   TDir) : TStep;
begin
  const Next := GuardPos + Step(Facing);
  Exit( match Grid.TryGet(Next) of
          | Present(Wall) : Turned(Turn(Facing))
          | Present(Open) : Moved(Next)
          | Absent        : Exited
        end
      );
end;

// In Delphi,
//   const CharToCell: TFunc<Char, TCell> =
//     function(Ch: Char): TCell begin 
//                                 exit( if Ch = '#' then Wall else Open ); 
//                               end;
// and λch -> False
//   function(ch: char): Boolean begin exit( False ); end
//

begin
  const FnCharToCell := λ(Ch: Char) -> if Ch = '#' then Wall else Open;
  const Input := TGrid<Char>.Create(Lines, Id);
  const Grid  := Input.Map(FnCharToCell);
  var   Seen  := Input.Map(λch -> False);

  match Start(Input) of
    | Present(Pos) : var GuardPos := Pos
    | Absent       : begin writeln('no start point found'); Exit; end
  end;

  Seen[GuardPos] := True;

  var Facing  := Up;
  var Turns   := 0;
  var Visited := 1;

  writeln('start: ', GuardPos.ToString);

  while True do
  begin
    match Advance(Grid, GuardPos, Facing) of
      | Moved(Pos)  : begin
                        if not Seen[Pos] then begin Inc(Visited);  Seen[Pos] := True; end;
                        GuardPos := Pos;
                      end
      | Turned(Dir) : begin Inc(Turns); Facing := Dir; end
      | Exited      : Break
    end;
  end;

  writeln('turns: ', Turns);
  writeln('visited: ', Visited);
end.
```