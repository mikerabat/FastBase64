unit FastBase64;

// basically a translation from https://github.com/lemire/fastbase64/blob/master/src/chromiumbase64.c

interface

uses Types;

// base64 encoding/decoding based on the great work on
// Daniel Lemiere: https://github.com/lemire/fastbase64/
function Base64Encode( buf : PByte; len : integer; doPad : boolean = True ) : RawByteString; overload;
procedure Base64Encode( dest : PAnsiChar; buf : PByte; len : integer; doPad : boolean = True ); overload;
function Base64Decode( base64Str : RawByteString; dest : PByte; isPadded : boolean = True ) : boolean; overload;
function Base64Decode( base64Str : RawByteString; var dest : TByteDynArray; isPadded : boolean = True ) : boolean; overload;
function Base64Decode( base64Str : PAnsiChar; base64StrLen : integer; dest : PByte; isPadded : boolean = True ) : boolean; overload;

implementation

{$IFDEF CPUX64}
{$DEFINE x64}
{$ENDIF}
{$IFDEF cpux86_64}
{$DEFINE x64}
{$ENDIF}

{$IFDEF CPU86}
{$DEFINE x86}
{$ENDIF}
{$IFDEF CPUX86}
{$DEFINE x86}
{$ENDIF}

{$IFDEF CPU386}
{$DEFINE x86}
{$ENDIF}


uses FastBase64Const, {$IFDEF x64}AVXBase64_x64{$ELSE}AVXBase64_x86{$ENDIF};

{$REGION 'Chromium based encoding'}

type
  TBase64EncodeTable = Array[0..255] of AnsiChar;
  PBase64EncodeTable = ^TBase64EncodeTable;

const CHAR62 : AnsiChar = '+';
      CHAR63 : AnsiChar = '/';
      CHARPAD  : AnsiChar = '=';


      e0 : TBase64EncodeTable = (
           'A',  'A',  'A',  'A',  'B',  'B',  'B',  'B',  'C',  'C',
           'C',  'C',  'D',  'D',  'D',  'D',  'E',  'E',  'E',  'E',
           'F',  'F',  'F',  'F',  'G',  'G',  'G',  'G',  'H',  'H',
           'H',  'H',  'I',  'I',  'I',  'I',  'J',  'J',  'J',  'J',
           'K',  'K',  'K',  'K',  'L',  'L',  'L',  'L',  'M',  'M',
           'M',  'M',  'N',  'N',  'N',  'N',  'O',  'O',  'O',  'O',
           'P',  'P',  'P',  'P',  'Q',  'Q',  'Q',  'Q',  'R',  'R',
           'R',  'R',  'S',  'S',  'S',  'S',  'T',  'T',  'T',  'T',
           'U',  'U',  'U',  'U',  'V',  'V',  'V',  'V',  'W',  'W',
           'W',  'W',  'X',  'X',  'X',  'X',  'Y',  'Y',  'Y',  'Y',
           'Z',  'Z',  'Z',  'Z',  'a',  'a',  'a',  'a',  'b',  'b',
           'b',  'b',  'c',  'c',  'c',  'c',  'd',  'd',  'd',  'd',
           'e',  'e',  'e',  'e',  'f',  'f',  'f',  'f',  'g',  'g',
           'g',  'g',  'h',  'h',  'h',  'h',  'i',  'i',  'i',  'i',
           'j',  'j',  'j',  'j',  'k',  'k',  'k',  'k',  'l',  'l',
           'l',  'l',  'm',  'm',  'm',  'm',  'n',  'n',  'n',  'n',
           'o',  'o',  'o',  'o',  'p',  'p',  'p',  'p',  'q',  'q',
           'q',  'q',  'r',  'r',  'r',  'r',  's',  's',  's',  's',
           't',  't',  't',  't',  'u',  'u',  'u',  'u',  'v',  'v',
           'v',  'v',  'w',  'w',  'w',  'w',  'x',  'x',  'x',  'x',
           'y',  'y',  'y',  'y',  'z',  'z',  'z',  'z',  '0',  '0',
           '0',  '0',  '1',  '1',  '1',  '1',  '2',  '2',  '2',  '2',
           '3',  '3',  '3',  '3',  '4',  '4',  '4',  '4',  '5',  '5',
           '5',  '5',  '6',  '6',  '6',  '6',  '7',  '7',  '7',  '7',
           '8',  '8',  '8',  '8',  '9',  '9',  '9',  '9',  '+',  '+',
           '+',  '+',  '/',  '/',  '/',  '/' );

      e1 : Array[0..255] of AnsiChar = (
           'A',  'B',  'C',  'D',  'E',  'F',  'G',  'H',  'I',  'J',
           'K',  'L',  'M',  'N',  'O',  'P',  'Q',  'R',  'S',  'T',
           'U',  'V',  'W',  'X',  'Y',  'Z',  'a',  'b',  'c',  'd',
           'e',  'f',  'g',  'h',  'i',  'j',  'k',  'l',  'm',  'n',
           'o',  'p',  'q',  'r',  's',  't',  'u',  'v',  'w',  'x',
           'y',  'z',  '0',  '1',  '2',  '3',  '4',  '5',  '6',  '7',
           '8',  '9',  '+',  '/',  'A',  'B',  'C',  'D',  'E',  'F',
           'G',  'H',  'I',  'J',  'K',  'L',  'M',  'N',  'O',  'P',
           'Q',  'R',  'S',  'T',  'U',  'V',  'W',  'X',  'Y',  'Z',
           'a',  'b',  'c',  'd',  'e',  'f',  'g',  'h',  'i',  'j',
           'k',  'l',  'm',  'n',  'o',  'p',  'q',  'r',  's',  't',
           'u',  'v',  'w',  'x',  'y',  'z',  '0',  '1',  '2',  '3',
           '4',  '5',  '6',  '7',  '8',  '9',  '+',  '/',  'A',  'B',
           'C',  'D',  'E',  'F',  'G',  'H',  'I',  'J',  'K',  'L',
           'M',  'N',  'O',  'P',  'Q',  'R',  'S',  'T',  'U',  'V',
           'W',  'X',  'Y',  'Z',  'a',  'b',  'c',  'd',  'e',  'f',
           'g',  'h',  'i',  'j',  'k',  'l',  'm',  'n',  'o',  'p',
           'q',  'r',  's',  't',  'u',  'v',  'w',  'x',  'y',  'z',
           '0',  '1',  '2',  '3',  '4',  '5',  '6',  '7',  '8',  '9',
           '+',  '/',  'A',  'B',  'C',  'D',  'E',  'F',  'G',  'H',
           'I',  'J',  'K',  'L',  'M',  'N',  'O',  'P',  'Q',  'R',
           'S',  'T',  'U',  'V',  'W',  'X',  'Y',  'Z',  'a',  'b',
           'c',  'd',  'e',  'f',  'g',  'h',  'i',  'j',  'k',  'l',
           'm',  'n',  'o',  'p',  'q',  'r',  's',  't',  'u',  'v',
           'w',  'x',  'y',  'z',  '0',  '1',  '2',  '3',  '4',  '5',
           '6',  '7',  '8',  '9',  '+',  '/' );

      e2  : Array[0..255] of AnsiChar = (
           'A',  'B',  'C',  'D',  'E',  'F',  'G',  'H',  'I',  'J',
           'K',  'L',  'M',  'N',  'O',  'P',  'Q',  'R',  'S',  'T',
           'U',  'V',  'W',  'X',  'Y',  'Z',  'a',  'b',  'c',  'd',
           'e',  'f',  'g',  'h',  'i',  'j',  'k',  'l',  'm',  'n',
           'o',  'p',  'q',  'r',  's',  't',  'u',  'v',  'w',  'x',
           'y',  'z',  '0',  '1',  '2',  '3',  '4',  '5',  '6',  '7',
           '8',  '9',  '+',  '/',  'A',  'B',  'C',  'D',  'E',  'F',
           'G',  'H',  'I',  'J',  'K',  'L',  'M',  'N',  'O',  'P',
           'Q',  'R',  'S',  'T',  'U',  'V',  'W',  'X',  'Y',  'Z',
           'a',  'b',  'c',  'd',  'e',  'f',  'g',  'h',  'i',  'j',
           'k',  'l',  'm',  'n',  'o',  'p',  'q',  'r',  's',  't',
           'u',  'v',  'w',  'x',  'y',  'z',  '0',  '1',  '2',  '3',
           '4',  '5',  '6',  '7',  '8',  '9',  '+',  '/',  'A',  'B',
           'C',  'D',  'E',  'F',  'G',  'H',  'I',  'J',  'K',  'L',
           'M',  'N',  'O',  'P',  'Q',  'R',  'S',  'T',  'U',  'V',
           'W',  'X',  'Y',  'Z',  'a',  'b',  'c',  'd',  'e',  'f',
           'g',  'h',  'i',  'j',  'k',  'l',  'm',  'n',  'o',  'p',
           'q',  'r',  's',  't',  'u',  'v',  'w',  'x',  'y',  'z',
           '0',  '1',  '2',  '3',  '4',  '5',  '6',  '7',  '8',  '9',
           '+',  '/',  'A',  'B',  'C',  'D',  'E',  'F',  'G',  'H',
           'I',  'J',  'K',  'L',  'M',  'N',  'O',  'P',  'Q',  'R',
           'S',  'T',  'U',  'V',  'W',  'X',  'Y',  'Z',  'a',  'b',
           'c',  'd',  'e',  'f',  'g',  'h',  'i',  'j',  'k',  'l',
           'm',  'n',  'o',  'p',  'q',  'r',  's',  't',  'u',  'v',
           'w',  'x',  'y',  'z',  '0',  '1',  '2',  '3',  '4',  '5',
           '6',  '7',  '8',  '9',  '+',  '/' );

      //cUrle0 : TBase64EncodeTable = (
//           'A',  'A',  'A',  'A',  'B',  'B',  'B',  'B',  'C',  'C',
//           'C',  'C',  'D',  'D',  'D',  'D',  'E',  'E',  'E',  'E',
//           'F',  'F',  'F',  'F',  'G',  'G',  'G',  'G',  'H',  'H',
//           'H',  'H',  'I',  'I',  'I',  'I',  'J',  'J',  'J',  'J',
//           'K',  'K',  'K',  'K',  'L',  'L',  'L',  'L',  'M',  'M',
//           'M',  'M',  'N',  'N',  'N',  'N',  'O',  'O',  'O',  'O',
//           'P',  'P',  'P',  'P',  'Q',  'Q',  'Q',  'Q',  'R',  'R',
//           'R',  'R',  'S',  'S',  'S',  'S',  'T',  'T',  'T',  'T',
//           'U',  'U',  'U',  'U',  'V',  'V',  'V',  'V',  'W',  'W',
//           'W',  'W',  'X',  'X',  'X',  'X',  'Y',  'Y',  'Y',  'Y',
//           'Z',  'Z',  'Z',  'Z',  'a',  'a',  'a',  'a',  'b',  'b',
//           'b',  'b',  'c',  'c',  'c',  'c',  'd',  'd',  'd',  'd',
//           'e',  'e',  'e',  'e',  'f',  'f',  'f',  'f',  'g',  'g',
//           'g',  'g',  'h',  'h',  'h',  'h',  'i',  'i',  'i',  'i',
//           'j',  'j',  'j',  'j',  'k',  'k',  'k',  'k',  'l',  'l',
//           'l',  'l',  'm',  'm',  'm',  'm',  'n',  'n',  'n',  'n',
//           'o',  'o',  'o',  'o',  'p',  'p',  'p',  'p',  'q',  'q',
//           'q',  'q',  'r',  'r',  'r',  'r',  's',  's',  's',  's',
//           't',  't',  't',  't',  'u',  'u',  'u',  'u',  'v',  'v',
//           'v',  'v',  'w',  'w',  'w',  'w',  'x',  'x',  'x',  'x',
//           'y',  'y',  'y',  'y',  'z',  'z',  'z',  'z',  '0',  '0',
//           '0',  '0',  '1',  '1',  '1',  '1',  '2',  '2',  '2',  '2',
//           '3',  '3',  '3',  '3',  '4',  '4',  '4',  '4',  '5',  '5',
//           '5',  '5',  '6',  '6',  '6',  '6',  '7',  '7',  '7',  '7',
//           '8',  '8',  '8',  '8',  '9',  '9',  '9',  '9',  '-',  '-',
//           '-',  '-',  '_',  '_',  '_',  '_' );
//
//      cUrle1 : Array[0..255] of AnsiChar = (
//           'A',  'B',  'C',  'D',  'E',  'F',  'G',  'H',  'I',  'J',
//           'K',  'L',  'M',  'N',  'O',  'P',  'Q',  'R',  'S',  'T',
//           'U',  'V',  'W',  'X',  'Y',  'Z',  'a',  'b',  'c',  'd',
//           'e',  'f',  'g',  'h',  'i',  'j',  'k',  'l',  'm',  'n',
//           'o',  'p',  'q',  'r',  's',  't',  'u',  'v',  'w',  'x',
//           'y',  'z',  '0',  '1',  '2',  '3',  '4',  '5',  '6',  '7',
//           '8',  '9',  '-',  '_',  'A',  'B',  'C',  'D',  'E',  'F',
//           'G',  'H',  'I',  'J',  'K',  'L',  'M',  'N',  'O',  'P',
//           'Q',  'R',  'S',  'T',  'U',  'V',  'W',  'X',  'Y',  'Z',
//           'a',  'b',  'c',  'd',  'e',  'f',  'g',  'h',  'i',  'j',
//           'k',  'l',  'm',  'n',  'o',  'p',  'q',  'r',  's',  't',
//           'u',  'v',  'w',  'x',  'y',  'z',  '0',  '1',  '2',  '3',
//           '4',  '5',  '6',  '7',  '8',  '9',  '-',  '_',  'A',  'B',
//           'C',  'D',  'E',  'F',  'G',  'H',  'I',  'J',  'K',  'L',
//           'M',  'N',  'O',  'P',  'Q',  'R',  'S',  'T',  'U',  'V',
//           'W',  'X',  'Y',  'Z',  'a',  'b',  'c',  'd',  'e',  'f',
//           'g',  'h',  'i',  'j',  'k',  'l',  'm',  'n',  'o',  'p',
//           'q',  'r',  's',  't',  'u',  'v',  'w',  'x',  'y',  'z',
//           '0',  '1',  '2',  '3',  '4',  '5',  '6',  '7',  '8',  '9',
//           '-',  '_',  'A',  'B',  'C',  'D',  'E',  'F',  'G',  'H',
//           'I',  'J',  'K',  'L',  'M',  'N',  'O',  'P',  'Q',  'R',
//           'S',  'T',  'U',  'V',  'W',  'X',  'Y',  'Z',  'a',  'b',
//           'c',  'd',  'e',  'f',  'g',  'h',  'i',  'j',  'k',  'l',
//           'm',  'n',  'o',  'p',  'q',  'r',  's',  't',  'u',  'v',
//           'w',  'x',  'y',  'z',  '0',  '1',  '2',  '3',  '4',  '5',
//           '6',  '7',  '8',  '9',  '-',  '_' );
//
//      cUrle2  : Array[0..255] of AnsiChar = (
//           'A',  'B',  'C',  'D',  'E',  'F',  'G',  'H',  'I',  'J',
//           'K',  'L',  'M',  'N',  'O',  'P',  'Q',  'R',  'S',  'T',
//           'U',  'V',  'W',  'X',  'Y',  'Z',  'a',  'b',  'c',  'd',
//           'e',  'f',  'g',  'h',  'i',  'j',  'k',  'l',  'm',  'n',
//           'o',  'p',  'q',  'r',  's',  't',  'u',  'v',  'w',  'x',
//           'y',  'z',  '0',  '1',  '2',  '3',  '4',  '5',  '6',  '7',
//           '8',  '9',  '-',  '_',  'A',  'B',  'C',  'D',  'E',  'F',
//           'G',  'H',  'I',  'J',  'K',  'L',  'M',  'N',  'O',  'P',
//           'Q',  'R',  'S',  'T',  'U',  'V',  'W',  'X',  'Y',  'Z',
//           'a',  'b',  'c',  'd',  'e',  'f',  'g',  'h',  'i',  'j',
//           'k',  'l',  'm',  'n',  'o',  'p',  'q',  'r',  's',  't',
//           'u',  'v',  'w',  'x',  'y',  'z',  '0',  '1',  '2',  '3',
//           '4',  '5',  '6',  '7',  '8',  '9',  '+',  '_',  'A',  'B',
//           'C',  'D',  'E',  'F',  'G',  'H',  'I',  'J',  'K',  'L',
//           'M',  'N',  'O',  'P',  'Q',  'R',  'S',  'T',  'U',  'V',
//           'W',  'X',  'Y',  'Z',  'a',  'b',  'c',  'd',  'e',  'f',
//           'g',  'h',  'i',  'j',  'k',  'l',  'm',  'n',  'o',  'p',
//           'q',  'r',  's',  't',  'u',  'v',  'w',  'x',  'y',  'z',
//           '0',  '1',  '2',  '3',  '4',  '5',  '6',  '7',  '8',  '9',
//           '+',  '_',  'A',  'B',  'C',  'D',  'E',  'F',  'G',  'H',
//           'I',  'J',  'K',  'L',  'M',  'N',  'O',  'P',  'Q',  'R',
//           'S',  'T',  'U',  'V',  'W',  'X',  'Y',  'Z',  'a',  'b',
//           'c',  'd',  'e',  'f',  'g',  'h',  'i',  'j',  'k',  'l',
//           'm',  'n',  'o',  'p',  'q',  'r',  's',  't',  'u',  'v',
//           'w',  'x',  'y',  'z',  '0',  '1',  '2',  '3',  '4',  '5',
//           '6',  '7',  '8',  '9',  '+',  '_' );


// SPECIAL DECODE TABLES FOR LITTLE ENDIAN (INTEL) CPUS

const d0 : Array[0..255] of UInt32 = (
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $000000f8, $01ffffff, $01ffffff, $01ffffff, $000000fc,
           $000000d0, $000000d4, $000000d8, $000000dc, $000000e0, $000000e4,
           $000000e8, $000000ec, $000000f0, $000000f4, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $00000000,
           $00000004, $00000008, $0000000c, $00000010, $00000014, $00000018,
           $0000001c, $00000020, $00000024, $00000028, $0000002c, $00000030,
           $00000034, $00000038, $0000003c, $00000040, $00000044, $00000048,
           $0000004c, $00000050, $00000054, $00000058, $0000005c, $00000060,
           $00000064, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $00000068, $0000006c, $00000070, $00000074, $00000078,
           $0000007c, $00000080, $00000084, $00000088, $0000008c, $00000090,
           $00000094, $00000098, $0000009c, $000000a0, $000000a4, $000000a8,
           $000000ac, $000000b0, $000000b4, $000000b8, $000000bc, $000000c0,
           $000000c4, $000000c8, $000000cc, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff );


     d1: Array[0..255] of UInt32 = (
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $0000e003, $01ffffff, $01ffffff, $01ffffff, $0000f003,
           $00004003, $00005003, $00006003, $00007003, $00008003, $00009003,
           $0000a003, $0000b003, $0000c003, $0000d003, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $00000000,
           $00001000, $00002000, $00003000, $00004000, $00005000, $00006000,
           $00007000, $00008000, $00009000, $0000a000, $0000b000, $0000c000,
           $0000d000, $0000e000, $0000f000, $00000001, $00001001, $00002001,
           $00003001, $00004001, $00005001, $00006001, $00007001, $00008001,
           $00009001, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $0000a001, $0000b001, $0000c001, $0000d001, $0000e001,
           $0000f001, $00000002, $00001002, $00002002, $00003002, $00004002,
           $00005002, $00006002, $00007002, $00008002, $00009002, $0000a002,
           $0000b002, $0000c002, $0000d002, $0000e002, $0000f002, $00000003,
           $00001003, $00002003, $00003003, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff );


     d2 : Array[0..255] of UInt32 = (
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $00800f00, $01ffffff, $01ffffff, $01ffffff, $00c00f00,
           $00000d00, $00400d00, $00800d00, $00c00d00, $00000e00, $00400e00,
           $00800e00, $00c00e00, $00000f00, $00400f00, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $00000000,
           $00400000, $00800000, $00c00000, $00000100, $00400100, $00800100,
           $00c00100, $00000200, $00400200, $00800200, $00c00200, $00000300,
           $00400300, $00800300, $00c00300, $00000400, $00400400, $00800400,
           $00c00400, $00000500, $00400500, $00800500, $00c00500, $00000600,
           $00400600, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $00800600, $00c00600, $00000700, $00400700, $00800700,
           $00c00700, $00000800, $00400800, $00800800, $00c00800, $00000900,
           $00400900, $00800900, $00c00900, $00000a00, $00400a00, $00800a00,
           $00c00a00, $00000b00, $00400b00, $00800b00, $00c00b00, $00000c00,
           $00400c00, $00800c00, $00c00c00, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff );

     d3 : Array[0..255] of UInt32 = (
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $003e0000, $01ffffff, $01ffffff, $01ffffff, $003f0000,
           $00340000, $00350000, $00360000, $00370000, $00380000, $00390000,
           $003a0000, $003b0000, $003c0000, $003d0000, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $00000000,
           $00010000, $00020000, $00030000, $00040000, $00050000, $00060000,
           $00070000, $00080000, $00090000, $000a0000, $000b0000, $000c0000,
           $000d0000, $000e0000, $000f0000, $00100000, $00110000, $00120000,
           $00130000, $00140000, $00150000, $00160000, $00170000, $00180000,
           $00190000, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $001a0000, $001b0000, $001c0000, $001d0000, $001e0000,
           $001f0000, $00200000, $00210000, $00220000, $00230000, $00240000,
           $00250000, $00260000, $00270000, $00280000, $00290000, $002a0000,
           $002b0000, $002c0000, $002d0000, $002e0000, $002f0000, $00300000,
           $00310000, $00320000, $00330000, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff, $01ffffff,
           $01ffffff, $01ffffff, $01ffffff, $01ffffff );


const BADCHAR = $01FFFFFF;

type
  TDecodeArr = Array[0..2] of byte;
  PDecodeArr = ^TDecodeArr;
  TEncodeArr = Array[0..3] of AnsiChar;
  PEncodeArr = ^TEncodeArr;

procedure chromium_base64_encode(dest : PAnsiChar; str : PByte; len : integer; doPad : boolean);
var p : PEncodeArr;
    pinp : PDecodeArr;
    t1, t2, t3 : Byte;
begin
     p := PEncodeArr(dest);
     pinp := PDecodeArr(str);

     while len > 2 do
     begin
          t1 := pInp^[0];
          t2 := pInp^[1];
          t3 := pInp^[2];

          p^[0] := e0[t1];
          p^[1] := e1[((t1 and $03) shl 4) or ((t2 shr 4) and $0F)];
          p^[2] := e1[((t2 and $0F) shl 2) or ((t3 shr 6) and $03)];
          p^[3] := e2[t3];
          inc(p);
          inc(pInp);
          dec(len, 3);
     end;

     case len of
       1: begin
               t1 := pInp^[0];
               p^[0] := e0[t1];
               p^[1] := e1[(t1 and $03) shl 4];
               if doPad then
               begin
                    p^[2] := CHARPAD;
                    p^[3] := CHARPAD;
               end;
          end;
       2: begin
               t1 := pInp^[0];
               t2 := pInp^[1];

               p^[0] := e0[t1];
               p^[1] := e1[((t1 and $03) shl 4) or ((t2 shr 4) and $0F)];
               p^[2] := e1[((t2 and $0F) shl 2)];
               if doPad then
                  p^[3] := CHARPAD;
          end;
     end;
end;

type
  TConstAnsiCharArr = Array[0..MaxInt-1] of AnsiChar;
  PConstAnsiCharArr = ^TConstAnsiCharArr;

function chromium_base64_decode(dest : PByte; src : PAnsiChar; len : integer; isPadded : boolean) : boolean;
var leftover : integer;
    i, chunks : integer;
    p : PDecodeArr;
    y : PEncodeArr;
    x : Uint32;
    pX : PDecodeArr;
begin
     Result := False;
     if len <= 0 then
        exit;

     if isPadded and ( (len mod 4 <> 0) ) then
        exit;

     if PConstAnsiCharArr(src)^[len - 1] = CHARPAD then
        dec(len);
     if PConstAnsiCharArr(src)^[len - 1] = CHARPAD then
        dec(len);

     leftOver := len mod 4;
     chunks := len div 4;

     y := PEncodeArr(src);
     p := PDecodeArr(dest);
     pX := @x;

     for i := 0 to chunks - 1 do
     begin
          x := d0[Byte(y^[0])] or d1[Byte(y^[1])] or d2[Byte(y^[2])] or d3[Byte(y^[3])];
          if x >= BADCHAR then
             exit;

          p^ := pX^;
          inc(p);
          inc(y);
     end;

     if leftover = 1 then
     begin
          x := d0[Byte(y^[0])];

          if x >= BADCHAR then
             exit;

          p^[0] := pX^[0];
     end
     else if leftover = 2 then
     begin
          x := d0[Byte(y^[0])] or d1[Byte(y^[1])];

          if x >= BADCHAR then
             exit;

          p^[0] := pX^[0];
     end
     else if leftover = 3 then
     begin
          x := d0[Byte(y^[0])] or d0[Byte(y^[0])] or d1[Byte(y^[1])] or d2[Byte(y^[2])];

          if x >= BADCHAR then
             exit;

          p^[0] := pX^[0];
          p^[1] := pX^[1];
     end;

      Result := True;
end;

{$ENDREGION}

// ###########################################
// #### Interface functions
// ###########################################

var loc_avx_EncA : Array[0..10*32] of byte; // buffer big enough for alignment  32 + sizeof(TAVXEncodeConst)
    loc_avx_decA : Array[0..9*32] of byte; // same for decode
    loc_avx_enc : PAVXEncodeConst;   // ensures alignment to 32 byte
    loc_avx_dec : PAVXDecodeConst;
    HW_AVX2 : boolean = false;
    AVX_OS_SUPPORT : boolean = False;     // 256bit AVX supported in context switch


function IsAVXPresent : boolean;
begin
     Result := HW_AVX2 and AVX_OS_SUPPORT;
end;


{$REGION 'Interface functions'}

function Base64Encode( buf : PByte; len : integer; doPad : boolean = True ) : RawByteString;
var destLen : integer;
begin
     destLen := ( (len + 2) div 3)*4;
     SetLength(Result, destLen);

     Base64Encode(@Result[1], buf, len, doPad);
end;

procedure Base64Encode( dest : PAnsiChar; buf : PByte; len : integer; doPad : boolean = True ); overload;
var restLen : integer;
    pDest : PAnsiChar;
    pBuf : PByte;
    processed : integer;
begin
     // ###########################################
     // #### Encode up until < 28 bytes are left
     restLen := len;
     pBuf := buf;
     pDest := dest;
     if (len > 28) and IsAVXPresent then
     begin
          restLen := AVXBase64Encode( PByte( dest ), buf, len, loc_AVX_enc );

          processed := len - restLen;
          inc(pBuf, processed);
          inc(pDest, ((processed + 2) div 3)*4);
     end;

     // fill the rest
     if Restlen > 0 then
        chromium_base64_encode( pDest, pBuf, restLen, doPad );
end;

function Base64Decode( base64Str : RawByteString; var dest : TByteDynArray; isPadded : boolean = True ) : boolean;
begin
     if Length(base64Str) = 0 then
        exit(false);

     SetLength(dest, ((Length(base64Str) + 3) div 4) * 3);
     Result := Base64Decode( base64Str, PByte( PAnsiChar(dest) ), isPadded);
end;

function Base64Decode( base64Str : RawByteString; dest : PByte; isPadded : boolean = True ) : boolean;
begin
     if Length(base64Str) = 0 then
        exit(false);

     Result := Base64Decode( PAnsiChar(base64Str), Length( base64Str ), dest, isPadded );

end;

function Base64Decode( base64Str : PAnsiChar; base64StrLen : integer; dest : PByte; isPadded : boolean = True ) : boolean; overload;
var numChunks : integer;
begin
     if base64StrLen = 0 then
        exit(false);

     Result := True;
     if (base64StrLen > 44) and IsAVXPresent then
     begin
          Result := AVXBase64Decode(dest, base64Str, base64Strlen, loc_AVX_dec);
          numChunks := base64StrLen div 32 - 1;
          inc(base64Str, numChunks*32);
          inc(dest, numChunks*24);
          dec(base64StrLen, numChunks*32);
     end;
     Result := Result and chromium_base64_decode(dest, PAnsiChar(base64Str), base64StrLen, isPadded);
end;

{$ENDREGION}

function AlignPtr32( A : Pointer ) : Pointer;
begin
     Result := A;
     if (NativeUint(A) and $1F) <> 0 then
        Result := Pointer( NativeUint(Result) + $20 - NativeUint(Result) and $1F );
end;


{$REGION 'CPU Feature detection'}

// ##############################################################
// #### feature detection code
// ##############################################################

type
  TRegisters = record
    EAX,
    EBX,
    ECX,
    EDX: Cardinal;
  end;

{$IFDEF x64}
function IsCPUID_Available : boolean;
begin
     Result := true;
end;

procedure GetCPUID(Param: Cardinal; out Registers: TRegisters);
var iRBX, iRDI : int64;
{$IFDEF FPC}
begin
{$ENDIF}
asm
   mov iRBX, rbx;
   mov iRDI, rdi;

   MOV     RDI, Registers
   MOV     EAX, Param;
   XOR     RBX, RBX                    {clear EBX register}
   XOR     RCX, RCX                    {clear ECX register}
   XOR     RDX, RDX                    {clear EDX register}
   DB $0F, $A2                         {CPUID opcode}
   MOV     TRegisters(RDI).&EAX, EAX   {save EAX register}
   MOV     TRegisters(RDI).&EBX, EBX   {save EBX register}
   MOV     TRegisters(RDI).&ECX, ECX   {save ECX register}
   MOV     TRegisters(RDI).&EDX, EDX   {save EDX register}

   // epilog
   mov rbx, iRBX;
   mov rdi, IRDI;
{$IFDEF FPC}
end;
{$ENDIF}
end;

{$ELSE}

function IsCPUID_Available: Boolean; register;
{$IFDEF FPC} begin {$ENDIF}
asm
   PUSHFD                 {save EFLAGS to stack}
   POP     EAX            {store EFLAGS in EAX}
   MOV     EDX, EAX       {save in EDX for later testing}
   XOR     EAX, $200000;  {flip ID bit in EFLAGS}
   PUSH    EAX            {save new EFLAGS value on stack}
   POPFD                  {replace current EFLAGS value}
   PUSHFD                 {get new EFLAGS}
   POP     EAX            {store new EFLAGS in EAX}
   XOR     EAX, EDX       {check if ID bit changed}
   JZ      @exit          {no, CPUID not available}
   MOV     EAX, True      {yes, CPUID is available}
@exit:
end;
{$IFDEF FPC} end; {$ENDIF}

procedure GetCPUID(Param: Cardinal; var Registers: TRegisters);
{$IFDEF FPC} begin {$ENDIF}
asm
   PUSH    EBX                         {save affected registers}
   PUSH    EDI
   MOV     EDI, Registers
   XOR     EBX, EBX                    {clear EBX register}
   XOR     ECX, ECX                    {clear ECX register}
   XOR     EDX, EDX                    {clear EDX register}
   DB $0F, $A2                         {CPUID opcode}
   MOV     TRegisters(EDI).&EAX, EAX   {save EAX register}
   MOV     TRegisters(EDI).&EBX, EBX   {save EBX register}
   MOV     TRegisters(EDI).&ECX, ECX   {save ECX register}
   MOV     TRegisters(EDI).&EDX, EDX   {save EDX register}
   POP     EDI                         {restore registers}
   POP     EBX
end;
{$IFDEF FPC} end; {$ENDIF}

{$ENDIF}


// ###########################################
// #### Local check for AVX support according to
// from https://software.intel.com/en-us/blogs/2011/04/14/is-avx-enabled
// and // from https://software.intel.com/content/www/us/en/develop/articles/how-to-detect-knl-instruction-support.html
procedure InitAVXOSSupportFlags; {$IFDEF FPC}assembler;{$ENDIF}
asm
   {$IFDEF x64}
   push rbx;
   {$ELSE}
   push ebx;
   {$ENDIF}

   xor eax, eax;
   cpuid;
   cmp eax, 1;
   jb @@endProc;

   mov eax, 1;
   cpuid;

   and ecx, $018000000; // check 27 bit (OS uses XSAVE/XRSTOR)
   cmp ecx, $018000000; // and 28 (AVX supported by CPU)
   jne @@endProc;

   xor ecx, ecx ; // XFEATURE_ENABLED_MASK/XCR0 register number = 0
   db $0F, $01, $D0; //xgetbv ; // XFEATURE_ENABLED_MASK register is in edx:eax
   and eax, $E6; //110b
   cmp eax, $E6; //1110 0011 = zmm_ymm_xmm = (7 << 5) | (1 << 2) | (1 << 1);
   jne @@not_supported;

   @@not_supported:

   and eax, $6; //110b
   cmp eax, $6; //1110 0011 = check for AVX os support (256bit) in a context switch
   jne @@endProc;
   {$IFDEF x64}
   mov [rip + AVX_OS_SUPPORT], 1;
   {$ELSE}
   mov AVX_OS_SUPPORT, 1;
   {$ENDIF}

   @@endProc:

   {$IFDEF x64}
   pop rbx;
   {$ELSE}
   pop ebx;
   {$ENDIF}
end;


procedure InitFlags;
var nIds : LongWord;
    reg : TRegisters;
begin
     if IsCPUID_Available then
     begin
          GetCPUID(0, reg);
          nids := reg.EAX;

          if nids >= 7 then
          begin
               GetCPUID($7, reg);
               HW_AVX2        := (reg.EBX and (1 shl 5)) <> 0;
          end;

          // now check the os support
          if HW_AVX2 then
             InitAVXOSSupportFlags;
     end;
end;


{$ENDREGION}

initialization
   InitFlags;

   // ###########################################
   // #### Fill local vars
   loc_avx_Enc := AlignPtr32( @loc_avx_encA );
   loc_avx_dec := AlignPtr32( @loc_avx_DecA );

   loc_avx_Enc^.MaskMov := cMaskMov;
   loc_avx_Enc^.Lut0 := cLut0;
   loc_avx_Enc^.Lut1 := cLut1;
   loc_avx_Enc^.Mask0 := cMask0;
   loc_avx_Enc^.Mask1 := cMask1;
   loc_avx_Enc^.Mask2 := cMask2;
   loc_avx_Enc^.Mask3 := cMask3;
   loc_avx_Enc^.N51 := cN51;
   loc_avx_Enc^.N25 := cN25;

   loc_avx_dec^.LutLo := cLutLo;
   loc_avx_dec^.LutHi := cLutHi;
   loc_avx_dec^.LutRoll := cLutRoll;
   loc_avx_dec^.Mask2F := cMask2F;
   loc_avx_dec^.Merge := cMerge;
   loc_avx_dec^.MergeAdd := cMergeAdd;
   loc_avx_dec^.ShufOut := cShufOut;
   loc_avx_dec^.PermOut := cPermOut;

end.
