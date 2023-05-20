program Base64Benchmark;

// ###########################################
// #### Benchmark testing against the Delphi standard
// #### base64 library from Indy
// ###########################################

{$APPTYPE CONSOLE}

{$R *.res}

uses
  SysUtils,
  idGlobal,
  {$IF CompilerVersion < 30}
  Windows,
  {$ELSE}
  WinApi.Windows,
  {$ENDIF}
  Classes,
  idCoderMime,
  FastBase64 in 'FastBase64.pas',
  AVXBase64_x64 in 'AVXBase64_x64.pas',
  AVXBase64_x86 in 'AVXBase64_x86.pas',
  FastBase64Const in 'FastBase64Const.pas';

procedure BenchmarkBase64;
var //ts : TStopWatch;
    startT, stopT, freq : Int64;
    buf : TidBytes;
    i: integer;
    j: Integer;
    base64Buf : RawByteString;
    decodeBuf : TidBytes;
    destStream : TMemoryStream;
    s : string;
  const cBufSize : Array[0..14] of integer = (1, 2, 3, 4, 7, 12, 15, 48, 49, 50, 200, 2000, 10000, 1000000, 10000000);
begin
     QueryPerformanceFrequency(freq);
     destStream := TMemoryStream.Create;
     try
        //RandSeed := 79929;     // just a seed to get the same results for debugging,...
        Randomize;

        for i in cBufSize do
        begin
             SetLength(buf, i);
             for j := 0 to Length(buf) - 1 do
               buf[j] := Random(255);
             SetLength(decodeBuf, i );

             SetLength(base64Buf, ((i + 2) div 3) * 4);
             destStream.Size := Length(base64Buf);

           //  ts.Reset; ts.Start;
             QueryPerformanceCounter(startT);
             Base64Encode(PAnsiChar(base64Buf), @buf[0], i, True );
             QueryPerformanceCounter(stopT);
             Writeln(Format('%d bytes encoding took: %.3fms', [i, (stopT - startT)/freq*1000]));

             QueryPerformanceCounter(startT);
             if not Base64Decode(base64Buf, @decodeBuf[0], True) then
             begin
                  Writeln('Failed to decode in bufsize ' + IntToStr(i));
                  exit;
             end;
             QueryPerformanceCounter(stopT);
             Writeln(Format('%d bytes decoding took: %.3fms', [i, (stopT - startT)/freq*1000]));


             // ###########################################
             // #### compare to reference encoding
             destStream.Position := 0;
             QueryPerformanceCounter(startT);
             TIdEncoderMIME.EncodeBytes(buf, destStream);
             QueryPerformanceCounter(stopT);
             Writeln(Format('%d bytes reference encoding took: %.3fms', [i, (stopT - startT)/freq*1000]));

             if not CompareMem( PAnsiChar(base64Buf), PAnsiChar(destStream.Memory), Length(base64Buf)) then
             begin
                  Writeln('Encode failed to base method in buffer ' + IntToStr(i));
                  exit;
             end;

             s := String(base64Buf);  // need to make it unicode...
             QueryPerformanceCounter(startT);
             TIdDecoderMIME.DecodeString(s);
             QueryPerformanceCounter(stopT);
             Writeln(Format('%d bytes reference decoding took: %.3fms', [i, (stopT - startT)/freq*1000]));
        end;//
     finally
            destStream.Free;
     end;
end;

begin
  try
    { TODO -oUser -cConsole Main : Code hier einfügen }
    BenchmarkBase64;
    readln;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
