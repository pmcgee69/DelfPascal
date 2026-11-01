


```
{$APPTYPE CONSOLE}
program Hangman;

{ A small Delf demo for a forum post
 -  match on strings
 -  for … in with Enumeration. 
 The guesses are pre-decided, so every run prints the same.

  Output :
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

uses
  System.SysUtils;

const
  Word    = 'DELPHI';
  Guesses : TArray<string> = ['e', 'hint', 'x', 'l', 'p', '?', 'z', 'd', 'h', 'i', 'quit'];
  Lives   = 5;

type
  TMatches = TInitArray<Boolean>;


function ToString(const Found: TMatches): string;
begin
  Result := '';
  for var (i, ch) in Word.Enumerate do
    Result := Result + ( if Found[i] then ch else '_' ) + ' ';
end;


function Reveal(Letter: Char; var Found: TMatches): Boolean;
begin
  Result := False;
  for var (i, ch) in Word.Enumerate do
    if ch = Letter then begin Found[i] := True; Result := True; end;
end;


function Solved(const Found: TMatches): Boolean;
begin
  for const b in Found do if not b then Exit( False );
  Exit( True );
end;


begin
  var Found := TMatches.create( Length(Word), False );
  var Left  := Lives;

  for const Guess in Guesses do
  begin
    Write(Guess.PadRight(6));
    match Guess.ToUpper of
      | 'HINT', '?' : writeln('a language, and an oracle')
      | 'QUIT'      : begin writeln('bye'); Break; end
      | _           : if Reveal(Guess.ToUpper.Chars[0], Found) then
                         writeln(Found.ToString)
                      else
                         begin Dec(Left); writeln('no, ', Left, ' chances left'); end
    end;

    if Solved(Found) then begin writeln('solved, with ', Left, ' chances left'); Break; end;
    if Left = 0      then begin writeln('hanged'); Break; end;
  end;
end.    
```