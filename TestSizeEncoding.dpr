program TestSizeEncoding;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  SysUtils,
  Classes,
  Types,
  AVXBase64_x64 in 'AVXBase64_x64.pas',
  AVXBase64_x86 in 'AVXBase64_x86.pas',
  FastBase64 in 'FastBase64.pas',
  FastBase64Const in 'FastBase64Const.pas';

var mem : TMemoryStream;
    dest : RawByteString;
    memDecode : TByteDynArray;
    i, j : Integer;
    pMem : PByteArray;
    doPad : boolean;
begin
  try
     { TODO -oUser -cConsole Main : Code hier einfügen }
     for doPad in [false, true] do
     begin
          for i := 7 to 127 do
          begin
               mem := TMemoryStream.Create;
               try
                  mem.SetSize(i);
                  pMem := mem.Memory;
                  for j := 0 to i - 1 do
                  begin
                       pMem^[j] := Byte(random(255));
                  end;

                  dest := Base64Encode(mem.Memory, mem.Size, doPad);

                  if not Base64Decode(dest, memDecode, doPad ) then
                     raise Exception.Create('Failed to Decode');

                  if Length(memDecode) <> mem.Size then
                     raise Exception.Create('Bad Size');

                  if not CompareMem(mem.Memory, @memDecode[0], Length(memDecode)) then
                     raise Exception.Create('Bad encode/decode');

               finally
                      mem.Free;
               end;
          end;

      end;
      writeln('Test passed');
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
  readln;
end.
