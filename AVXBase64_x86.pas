unit AVXBase64_x86;

interface

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

{$IFDEF x86}

uses FastBase64Const;

function AVXBase64Encode( dest : PByte; buf : PByte; len : integer; avxConst : PAVXEncodeConst ) : integer; assembler;
function AVXBase64Decode( output : PByte; src : PAnsiChar; srcLen : integer; avxConst : PAVXDecodeConst ) : boolean; assembler;

{$ENDIF}

implementation

{$IFDEF x86}

{$IFNDEF FPC}
  {$IF CompilerVersion>=33}
    {$CODEALIGN 16}
    {$ALIGN 16}
  {$IFEND}
{$ENDIF}


{$DEFINE AVXSUP} // enables the evaluation of the avx asm codes by the compiler (instead of the db variants)
{$IFNDEF FPC}
  {$IF CompilerVersion<34}
  {$UNDEF AVXSUP}
  {$IFEND}
{$IFEND}

{$IFDEF FPC} {$ASMMODE intel} {$S-} {$DEFINE DELPHIAVX} {$ENDIF}

// ###########################################
// #### AVX Based encoding
// ###########################################

{$REGION 'AVX Encode'}

function AVXBase64Encode( dest : PByte; buf : PByte; len : integer; avxConst : PAVXEncodeConst ) : integer; assembler;
// x86: eax = dest, edx = buf, ecx = len; stack = avxConst
asm
   push esi;
   mov esi, avxConst;

   // ###########################################
   // #### prepare
   sub edx, 4;

   {$IFDEF AVXSUP}vmovdqa ymm4, [esi + TAVXEncodeConst.lut1];         {$ELSE}db $C5,$FD,$6F,$66,$40;{$ENDIF} 

   // first load is masked
   {$IFDEF AVXSUP}vmovdqa ymm5, [esi.TAVXEncodeConst.MaskMov];        {$ELSE}db $C5,$FD,$6F,$2E;{$ENDIF} 
   {$IFDEF AVXSUP}vmaskmovps ymm0, ymm5, [edx];                       {$ELSE}db $C4,$E2,$55,$2C,$02;{$ENDIF} 
   sub ecx, 32;

   @loop:
      // shuf
      {$IFDEF AVXSUP}vpshufb ymm1, ymm0, [esi + TAVXEncodeConst.Lut0];{$ELSE}db $C4,$E2,$7D,$00,$4E,$20;{$ENDIF} 
      {$IFDEF AVXSUP}vpand ymm2, ymm1, [esi + TAVXEncodeConst.Mask0]; {$ELSE}db $C5,$F5,$DB,$56,$60;{$ENDIF} 
      {$IFDEF AVXSUP}vpand ymm1, ymm1, [esi + TAVXEncodeConst.Mask2]; {$ELSE}db $C5,$F5,$DB,$8E,$A0,$00,$00,$00;{$ENDIF} 
      {$IFDEF AVXSUP}vpmulhuw ymm2, ymm2, [esi + TAVXEncodeConst.Mask1];{$ELSE}db $C5,$ED,$E4,$96,$80,$00,$00,$00;{$ENDIF} 
      {$IFDEF AVXSUP}vpmullw ymm1, ymm1, [esi + TAVXEncodeConst.Mask3];{$ELSE}db $C5,$F5,$D5,$8E,$C0,$00,$00,$00;{$ENDIF} 
      {$IFDEF AVXSUP}vpor ymm1, ymm1, ymm2;                           {$ELSE}db $C5,$F5,$EB,$CA;{$ENDIF} 

      {$IFDEF AVXSUP}vpsubusb ymm0, ymm1, [esi + TAVXEncodeConst.N51] ;{$ELSE}db $C5,$F5,$D8,$86,$E0,$00,$00,$00;{$ENDIF} // indices
      {$IFDEF AVXSUP}vpcmpgtb ymm2, ymm1, [esi + TAVXEncodeConst.N25];{$ELSE}db $C5,$F5,$64,$96,$00,$01,$00,$00;{$ENDIF} //, ymm0;

      {$IFDEF AVXSUP}vpsubb ymm0, ymm0, ymm2;                         {$ELSE}db $C5,$FD,$F8,$C2;{$ENDIF} 
      {$IFDEF AVXSUP}vpshufb ymm2, ymm4, ymm0;                        {$ELSE}db $C4,$E2,$5D,$00,$D0;{$ENDIF} 

      {$IFDEF AVXSUP}vpaddb ymm0, ymm2, ymm1;                         {$ELSE}db $C5,$ED,$FC,$C1;{$ENDIF} 
      {$IFDEF AVXSUP}vmovdqu [eax], ymm0;                             {$ELSE}db $C5,$FE,$7F,$00;{$ENDIF} 

      // adjust buffer
      add eax, 32;
      add edx, 24;

      sub ecx, 24;
      jl @loopEnd;

      // load next
      {$IFDEF AVXSUP}vmovdqu ymm0, [edx];                             {$ELSE}db $C5,$FE,$6F,$02;{$ENDIF} 

   // adjust len
   jmp @loop;

   @loopEnd:

   // build result -> the remaining bytes left
   mov eax, ecx;
   add eax, 32;

   {$IFDEF AVXSUP}vzeroupper;                                         {$ELSE}db $C5,$F8,$77;{$ENDIF} 

   pop esi;
end;

{$ENDREGION}

// ###########################################
// #### AVX Decode
// ###########################################

{$REGION 'AVX Decoding'}

// a compressed version from: https://github.com/lemire/fastbase64/blob/master/src/fastavxbase64.c
function AVXBase64Decode( output : PByte; src : PAnsiChar; srcLen : integer; avxConst : PAVXDecodeConst ) : boolean; assembler;
// 32bit: eax = output, edx = src, ecx = srcLen
asm
   push edi;
   push esi;
   mov esi, avxConst;

   sub ecx, 32;
   mov edi, eax;      // edi is the new output
   xor eax, eax;      // prepare result

   {$IFDEF AVXSUP}vmovdqa ymm7, [esi + TAVXDecodeConst.LutLo];        {$ELSE}db $C5,$FD,$6F,$3E;{$ENDIF} 
   {$IFDEF AVXSUP}vmovdqa ymm6, [esi + TAVXDecodeConst.LutHi];        {$ELSE}db $C5,$FD,$6F,$76,$20;{$ENDIF} 
   {$IFDEF AVXSUP}vmovdqa ymm5, [esi + TAVXDecodeConst.LutRoll];      {$ELSE}db $C5,$FD,$6F,$6E,$40;{$ENDIF} 

   @loop:
       // load 32 bytes -> convert ascii to bytes
       {$IFDEF AVXSUP}vmovupd ymm0, [edx];                            {$ELSE}db $C5,$FD,$10,$02;{$ENDIF} 

       {$IFDEF AVXSUP}vpsrld ymm1, ymm0, 4;                           {$ELSE}db $C5,$F5,$72,$D0,$04;{$ENDIF} 
       {$IFDEF AVXSUP}vpand ymm1, ymm1, [esi + TAVXDecodeConst.Mask2F];{$ELSE}db $C5,$F5,$DB,$4E,$60;{$ENDIF}
       {$IFDEF AVXSUP}vpshufb ymm2, ymm6, ymm1;                       {$ELSE}db $C4,$E2,$4D,$00,$D1;{$ENDIF} // hi
       {$IFDEF AVXSUP}vpcmpeqb ymm3, ymm0, [esi + TAVXDecodeConst.Mask2F];{$ELSE}db $C5,$FD,$74,$5E,$60;{$ENDIF} // eq2f
       {$IFDEF AVXSUP}vpaddb ymm3, ymm3, ymm1;                        {$ELSE}db $C5,$E5,$FC,$D9;{$ENDIF} // add epqf hi_nibbles
       {$IFDEF AVXSUP}vpshufb ymm3, ymm5, ymm3;                       {$ELSE}db $C4,$E2,$55,$00,$DB;{$ENDIF} // roll

       {$IFDEF AVXSUP}vpand ymm4, ymm0, [esi + TAVXDecodeConst.Mask2F];{$ELSE}db $C5,$FD,$DB,$66,$60;{$ENDIF} // lo_nibbles

       {$IFDEF AVXSUP}vpshufb ymm4, ymm7, ymm4;                       {$ELSE}db $C4,$E2,$45,$00,$E4;{$ENDIF} // lo

       // test for an incorrect character
       {$IFDEF AVXSUP}vptest ymm4, ymm2;                              {$ELSE}db $C4,$E2,$7D,$17,$E2;{$ENDIF} 
       jnz @wrongEncoding;

       {$IFDEF AVXSUP}vpaddb ymm0, ymm0, ymm3;                        {$ELSE}db $C5,$FD,$FC,$C3;{$ENDIF} 

       // ###########################################
       // #### Reshuffle from 32 bytes to 24
       {$IFDEF AVXSUP}vmovdqa ymm3, [esi + TAVXDecodeConst.PermOut];  {$ELSE}db $C5,$FD,$6F,$9E,$E0,$00,$00,$00;{$ENDIF} // would be great if we could evade this mov operation....
       {$IFDEF AVXSUP}vpmaddubsw ymm1, ymm0, [esi + TAVXDecodeConst.Merge];{$ELSE}db $C4,$E2,$7D,$04,$8E,$80,$00,$00,$00;{$ENDIF} 
       {$IFDEF AVXSUP}vpmaddwd ymm1, ymm1, [esi + TAVXDecodeConst.MergeAdd];{$ELSE}db $C5,$F5,$F5,$8E,$A0,$00,$00,$00;{$ENDIF} 
       {$IFDEF AVXSUP}vpshufb ymm1, ymm1, [esi + TAVXDecodeConst.ShufOut];{$ELSE}db $C4,$E2,$75,$00,$8E,$C0,$00,$00,$00;{$ENDIF} 
       {$IFDEF AVXSUP}vpermd ymm0, ymm3, ymm1;                        {$ELSE}db $C4,$E2,$65,$36,$C1;{$ENDIF} 

       {$IFDEF AVXSUP}vmovdqu [edi], ymm0;                            {$ELSE}db $C5,$FE,$7F,$07;{$ENDIF} 
       add edi, 24;
       add edx, 32;
   sub ecx, 32;
   jg @loop;

   add eax, 1; // true

   // ###########################################
   // #### Build result

   // return true
   @wrongEncoding:

   {$IFDEF AVXSUP}vzeroupper;                                         {$ELSE}db $C5,$F8,$77;{$ENDIF} 

   pop esi;
   pop edi;
end;

{$ENDREGION}

{$ENDIF}

end.
