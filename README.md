# FastBase64
Fast base 64 encoding/decoding using AVX2 extension. 

The project is working with Delphi (2010 and up) and FPC in both intel flavors - x64 and x86.
It is based on the paper "Faster Base64 Encoding and Decoding using AVX2 Instructions" by Lamire et al. 
and the great work on: https://github.com/lemire/fastbase64/ . This one here is basically a 
pure ASM version of their work. 

## Usage

To use the code one needs to add the "FastBase64.pas" file to the your project and add the
source search path to the library path so the dependencies are loaded too. 
This enables AVX encoding/decoding in case the AVX2 instruction set is avaliabe.

## Stats

The files were tested against the standard Delphi implementation that is shipped via the great
Indy library.
I created a small benchmark app that shows that achieves up to 10 times faster encoding/decoding speed.

## Design considerations

The project could use global constants but the disassembler could not handle that well so there
is another variable passed to the en/decoding routines that hold a pointer to the constants.

I basically used the disassembly routines from https://github.com/mikerabat/mrmath to get the 
equivalent "db instructions" for the AVX set that are missing up until Delphi 11.3.