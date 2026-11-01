unit Demo.OptionalGrids;

{ Demo.Grids for 06's phase 5 (user, 23 Oct: "opt version can have its own
  grid unit"). Demo code, not a library decision.

  Partial, where Demo.Grids is total: there is nothing off the grid. Two
  ways to read, todo-naming.md's pair: Grid[P] for a position known to be
  good, which raises off the grid, and TryGet(P) for one that might not be,
  which answers Absent. The [y][x] order stays in here.

  Map and Rows (user, 23 Oct): the program reads its input as a TGrid<Char>,
  finds the start in it a row at a time (each row knows its Index), and maps
  it to the other two grids. The loops are Delf's for var (i, X) in
  Xs.Enumerate (user). }

interface

uses Delf.Prelude,
  System.SysUtils, System.Types, System.Generics.Defaults, Delf.Optional;

type
  // one row of a grid, and where it is
  TGridRow<T> = record
    Index : Integer;                      // y
    Cells : TArray<T>;
    // where Value first is in the row, if anywhere
    function Find(const Value: T): Optional<Integer>;
  end;

  TGrid<T> = record
  strict private
    FCells : TArray<TArray<T>>;           // [y][x]
    function  Get(const P: TPoint): T;
    procedure Put(const P: TPoint; const Value: T);
  public
    // Width by Height, every cell Fill
    constructor Create(Width, Height: Integer; const Fill: T); overload;
    // one row per line, one cell per character
    constructor Create(const Lines: TArray<string>; const Convert: TFunc<Char, T>); overload;
    function Width: Integer;
    function Height: Integer;
    function Contains(const P: TPoint): Boolean;
    function TryGet(const P: TPoint): Optional<T>;
    // the same shape, each cell through F
    function Map<U>(const F: TFunc<T, U>): TGrid<U>;
    // the rows, top to bottom, for for … in
    function Rows: TArray<TGridRow<T>>;
    property Items[const P: TPoint]: T read Get write Put; default;
  end;

implementation

constructor TGrid<T>.Create(Width, Height: Integer; const Fill: T);
begin
  SetLength(FCells, Height, Width);
  for var y := 0 to Height - 1 do
    for var x := 0 to Width - 1 do FCells[y][x] := Fill;
end;

constructor TGrid<T>.Create(const Lines: TArray<string>; const Convert: TFunc<Char, T>);
begin
  SetLength(FCells, Length(Lines));
  for var y := 0 to High(Lines) do
  begin
    const Line = Lines[y];
    SetLength(FCells[y], Line.Length);
    for var x := 0 to Length(Line) - 1 do
    begin
      const Ch = Line[Low(Line) + x];
      FCells[y][x] := Convert(Ch)
    end
  end;
end;

function TGrid<T>.Width: Integer;
begin
  if Length(FCells) = 0 then Exit( 0 );
  Exit( Length(FCells[0]) );
end;

function TGrid<T>.Height: Integer;
begin
  Exit( Length(FCells) );
end;

function TGrid<T>.Contains(const P: TPoint): Boolean;
begin
  Exit( (P.y >= 0) and (P.y < Length(FCells))       and
        (P.x >= 0) and (P.x < Length(FCells[P.y])) );
end;

function TGrid<T>.Get(const P: TPoint): T;
begin
  if not Contains(P) then
    raise ERangeError.CreateFmt('(%d, %d) is off the grid', [P.x, P.y]);
  Exit( FCells[P.y][P.x] );
end;

procedure TGrid<T>.Put(const P: TPoint; const Value: T);
begin
  if not Contains(P) then
    raise ERangeError.CreateFmt('(%d, %d) is off the grid', [P.x, P.y]);
  FCells[P.y][P.x] := Value;
end;

function TGrid<T>.TryGet(const P: TPoint): Optional<T>;
begin
  if not Contains(P) then Exit( Optional<T>.Absent );
  Exit( Optional<T>.Present(FCells[P.y][P.x]) );
end;

// through the public Create and [ ]: TGrid<U> is another type
function TGrid<T>.Map<U>(const F: TFunc<T, U>): TGrid<U>;
begin
  Result := TGrid<U>.Create(Width, Height, Default(U));
  for var y := 0 to High(FCells) do
  begin
    const Row = FCells[y];
    for var x := 0 to High(Row) do
    begin
      const Cell = Row[x];
      Result[Point(x, y)] := F(Cell)
    end
  end
end;

// the rows share the grid's cells: a dynamic array is a reference
function TGrid<T>.Rows: TArray<TGridRow<T>>;
begin
  SetLength(Result, Length(FCells));
  for var y := 0 to High(FCells) do
  begin
    const Cells = FCells[y];
    Result[y].Index := y;
    Result[y].Cells := Cells
  end;
end;

// = (and so match) doesn't take an unconstrained T, so the comparer does it
function TGridRow<T>.Find(const Value: T): Optional<Integer>;
begin
  const Same = TEqualityComparer<T>.Default;
  for var x := 0 to High(Cells) do
  begin
    const Cell = Cells[x];
    if Same.Equals(Cell, Value) then Exit( Optional<Integer>.Present(x) )
  end;
  Exit( Optional<Integer>.Absent );
end;

end.
