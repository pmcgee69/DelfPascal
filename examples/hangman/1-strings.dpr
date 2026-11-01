{$APPTYPE CONSOLE}
program Hangman;

{ A small Delf demo for a forum post, after 06's guard patrol (user,
  23 Oct): match on strings, and for … in with the index, Enumerate. The
  guesses are a constant, so every run prints the same.

  The user's edits: TMatches; TInitArray<T>.Create(Length, Fill), from the
  prelude (Delphi's own TArray<T>.Create takes the elements); and
  Found.ToString, a free function by UFCS. 27 Oct (the user): ToString and its
  helper Symbol made one, the conditional expression inline and the
  character taken from Enumerate.

  Predicted output (Claude, 23 Oct, before compiling):
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
    solved, with 3 chances left }

uses Delf.Prelude,
  System.SysUtils, System.StrUtils;

const
  Word    = 'DELPHI';
  Guesses : TArray<string> = ['e', 'hint', 'x', 'l', 'p', '?', 'z', 'd', 'h', 'i', 'quit'];
  Lives   = 5;

type
  TMatches = TArray<Boolean>;


function ToString(const Found: TMatches): string;
begin
  Result := '';
  for var i := 0 to Length(Word) - 1 do
  begin
    const ch = Word[Low(Word) + i];
    Result := Result + ( if Found[i] then ch else '_' ) + ' '
  end
end;


function Reveal(Letter: Char; var Found: TMatches): Boolean;
begin
  Result := False;
  for var i := 0 to Length(Word) - 1 do
  begin
    const Ch = Word[Low(Word) + i];
    if Ch = Letter then begin Found[i] := True; Result := True; end
  end;
end;

function Solved(const Found: TMatches): Boolean;
begin
  for var F {const} in Found do if not F then Exit( False );
  Exit( True );
end;

begin
  var Found := TInitArray<Boolean>.Create( Length(Word), False );
  var Left  := Lives;

  for var Guess {const} in Guesses do
  begin
    Write(Guess.PadRight(6));
    case IndexStr(Guess.ToUpper, ['HINT', '?', 'QUIT']) of
      0..1 : writeln('a language, and an oracle');
      2    : begin writeln('bye'); Break; end;
    else
      if Reveal(Guess.ToUpper.Chars[0], Found) then
         writeln(ToString(Found))
      else
         begin Dec(Left); writeln('no, ', Left, ' chances left'); end;
    end;

    if Solved(Found) then begin writeln('solved, with ', Left, ' chances left'); Break; end;
    if Left = 0      then begin writeln('hanged'); Break; end;
  end;
end.
