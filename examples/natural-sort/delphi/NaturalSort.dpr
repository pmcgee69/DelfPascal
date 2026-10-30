program NaturalSort;

{ A natural sort in plain Delphi, written as a Delphi programmer would, with no
  thought of Delf: one pass over both names with an index into each. The same
  rules as ..\1-chunks.delf: runs of digits by value (any length), with more
  leading zeros first for the same value; text ignoring case; a run of digits
  before text. Checked against Windows' StrCmpLogicalW, which Explorer sorts with. }

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Character, System.Math, System.Generics.Defaults,
  System.Generics.Collections, System.IOUtils, Winapi.ShLwApi;

// the end of the run of digits that starts at I, and where it starts without its leading zeros
procedure DigitRun(const S: string; I: Integer; out Start, Stop: Integer);
begin
  Stop := I;
  while (Stop <= Length(S)) and S[Stop].IsDigit do
    Inc(Stop);
  Start := I;
  while (Start < Stop - 1) and (S[Start] = '0') do
    Inc(Start);
end;

// the end of the run of text that starts at I
function TextRun(const S: string; I: Integer): Integer;
begin
  Result := I;
  while (Result <= Length(S)) and not S[Result].IsDigit do
    Inc(Result);
end;

function NaturalCompare(const A, B: string): Integer;
var
  I, J: Integer;
  StartA, StopA, StartB, StopB: Integer;
begin
  I := 1;
  J := 1;
  while (I <= Length(A)) and (J <= Length(B)) do
  begin
    if A[I].IsDigit and B[J].IsDigit then
    begin
      DigitRun(A, I, StartA, StopA);
      DigitRun(B, J, StartB, StopB);
      // more digits without the leading zeros is a larger value
      Result := CompareValue(StopA - StartA, StopB - StartB);
      if Result = 0 then
        Result := CompareStr(Copy(A, StartA, StopA - StartA), Copy(B, StartB, StopB - StartB));
      // the same value: more leading zeros first
      if Result = 0 then
        Result := CompareValue(StopB - J, StopA - I);
      if Result <> 0 then
        Exit;
      I := StopA;
      J := StopB;
    end
    else if A[I].IsDigit then
      Exit(-1)
    else if B[J].IsDigit then
      Exit(1)
    else
    begin
      StopA := TextRun(A, I);
      StopB := TextRun(B, J);
      Result := CompareText(Copy(A, I, StopA - I), Copy(B, J, StopB - J));
      if Result <> 0 then
        Exit;
      I := StopA;
      J := StopB;
    end;
  end;
  // one is a prefix of the other, run for run: the shorter first
  Result := CompareValue(Length(A) - I, Length(B) - J);
end;

// sorted by Compare, and names it calls equal (README.md, Readme.md) by their
// characters, so each order is one order: TArray.Sort isn't stable
function Sorted(const Names: TArray<string>; const Compare: TComparison<string>): TArray<string>;
begin
  Result := Copy(Names);
  TArray.Sort<string>(Result, TComparer<string>.Construct(
    function(const A, B: string): Integer
    begin
      Result := Compare(A, B);
      if Result = 0 then
        Result := CompareStr(A, B);
    end));
end;

function Explorer(const A, B: string): Integer;
begin
  Result := StrCmpLogicalW(PChar(A), PChar(B));
end;

const
  Names: TArray<string> = ['file10.txt', 'file2.txt', 'File1.txt', 'file1.txt', 'file02.txt',
                           'a100', 'a20', 'a3b', 'a3a', 'x9z', 'x10y', 'version 1.10',
                           'version 1.9', 'item99999999999999999999', 'item100',
                           'ab1', 'abc', 'a-b', 'a1b', 'x001', 'x01'];

// the names above, beside Explorer's order; or, given a file of names, one per
// line, the neighbours in our order that Explorer puts the other way round
var
  Ours, Theirs: TArray<string>;
  I, Disagree: Integer;
  Mark: string;
begin
  if ParamCount = 0 then
  begin
    Ours := Sorted(Names, NaturalCompare);
    Theirs := Sorted(Names, Explorer);
    for I := 0 to High(Ours) do
    begin
      if Ours[I] = Theirs[I] then
        Mark := ''
      else
        Mark := '<- differs';
      Writeln(Ours[I].PadRight(28), Theirs[I].PadRight(28), Mark);
    end;
    Exit;
  end;
  Ours := Sorted(TFile.ReadAllLines(ParamStr(1), TEncoding.UTF8), NaturalCompare);
  Disagree := 0;
  for I := 0 to High(Ours) - 1 do
    if Explorer(Ours[I], Ours[I + 1]) > 0 then
    begin
      Inc(Disagree);
      Writeln(Ours[I].PadRight(44), ' before  ', Ours[I + 1]);
    end;
  Writeln(Length(Ours), ' names: Explorer puts ', Disagree, ' of ', High(Ours),
          ' neighbours the other way round');
end.
