unit FastBase64Const;

interface

// ###########################################
// #### Common definitions and constants used in 64 and 32 bit assembler functions
// ###########################################

type
  TYMMB = Array[0..31] of byte;
  TYMMS = Array[0..31] of shortint;
  TYMMDW = Array[0..7] of UInt32;
  TYMMI = Array[0..7] of Int32;

  TXMM = Array[0..3] of Uint32; // for register save


// ###########################################
// #### Decoding constants
// ###########################################
const cLutLo : TYMMB = (
            $15, $11, $11, $11, $11, $11, $11, $11,
            $11, $11, $13, $1A, $1B, $1B, $1B, $1A,
            $15, $11, $11, $11, $11, $11, $11, $11,
            $11, $11, $13, $1A, $1B, $1B, $1B, $1A
        );

      cLutHi : TYMMB = (
            $10, $10, $01, $02, $04, $08, $04, $08,
            $10, $10, $10, $10, $10, $10, $10, $10,
            $10, $10, $01, $02, $04, $08, $04, $08,
            $10, $10, $10, $10, $10, $10, $10, $10
        );
      cLutRoll : TYMMS = (
            0,   16,  19,   4, -65, -65, -71, -71,
            0,   0,   0,   0,   0,   0,   0,   0,
            0,   16,  19,   4, -65, -65, -71, -71,
            0,   0,   0,   0,   0,   0,   0,   0
        );
      cMask2F : TYMMB = (
          $2f, $2f, $2f, $2f, $2f, $2f, $2f, $2f,
          $2f, $2f, $2f, $2f, $2f, $2f, $2f, $2f,
          $2f, $2f, $2f, $2f, $2f, $2f, $2f, $2f,
          $2f, $2f, $2f, $2f, $2f, $2f, $2f, $2f
      );


      cMerge : TYMMDW = (
          $01400140, $01400140, $01400140, $01400140,
          $01400140, $01400140, $01400140, $01400140 );

      cMergeAdd : TYMMDW = (
          $00011000, $00011000, $00011000, $00011000,
          $00011000, $00011000, $00011000, $00011000 );

      cShufOut : TYMMS = (
          2, 1, 0, 6, 5, 4, 10, 9, 8, 14, 13, 12, -1, -1, -1, -1,
          2, 1, 0, 6, 5, 4, 10, 9, 8, 14, 13, 12, -1, -1, -1, -1 );

      cPermOut : TYMMI = ( 0, 1, 2, 4, 5, 6, -1, -1 );


// a record that cumulates the decoding constants so we can use it in
// the AVX routins directly and in older Delphi versions (the disassembler output did not work properly)
type
  TAVXDecodeConst = packed record
    LutLo : TYMMB;
    LutHi  : TYMMB;
    LutRoll : TYMMS;
    Mask2F : TYMMB;
    Merge : TYMMDW;
    MergeAdd : TYMMDW;
    ShufOut : TYMMS;
    PermOut : TYMMI;
  end;
  PAVXDecodeConst = ^TAVXDecodeConst;

// ###########################################
// #### Encoding constants
// ###########################################

// constants used in the encoding process
const cMaskMov : TYMMDW = ($00000000, $80000000, $80000000, $80000000,
                           $80000000, $80000000, $80000000, $80000000 );
      cLut0 : TYMMB = (
    5, 4, 6, 5, 8, 7, 9, 8, 11, 10, 12, 11, 14, 13, 15, 14,
    1, 0, 2, 1, 4, 3, 5, 4, 7, 6, 8, 7, 10, 9, 11, 10 );

      cLut1 : TYMMS = (
    65, 71, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -19, -16, 0, 0,
		65, 71, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -19, -16, 0, 0);

    cMask0 : TYMMDW = ( $0FC0FC00, $0FC0FC00, $0FC0FC00, $0FC0FC00,
                        $0FC0FC00, $0FC0FC00, $0FC0FC00, $0FC0FC00 );
    cMask1 : TYMMDW = ( $04000040, $04000040, $04000040, $04000040,
                        $04000040, $04000040, $04000040, $04000040 );
    cMask2 : TYMMDW = ( $003F03F0, $003F03F0, $003F03F0, $003F03F0,
                        $003F03F0, $003F03F0, $003F03F0, $003F03F0 );
    cMask3 : TYMMDW = ( $01000010, $01000010, $01000010, $01000010,
                        $01000010, $01000010, $01000010, $01000010 );
    cN51 : TYMMDW = ($33333333, $33333333, $33333333, $33333333,
                     $33333333, $33333333, $33333333, $33333333);
    cN25 : TYMMDW = ($19191919, $19191919, $19191919, $19191919,
                     $19191919, $19191919, $19191919, $19191919);
type
  TAVXEncodeConst = packed record
    MaskMov : TYMMDW;
    Lut0 : TYMMB;
    Lut1 : TYMMS;
    Mask0 : TYMMDW;
    Mask1 : TYMMDW;
    Mask2 : TYMMDW;
    Mask3 : TYMMDW;
    N51 : TYMMDW;
    N25 : TYMMDW;
  end;
  PAVXEncodeConst = ^TAVXEncodeConst;

implementation

end.
