unit AVXBase64_x64;

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

{$IFDEF x64}

uses FastBase64Const;

function AVXBase64Encode( dest : PByte; buf : PByte; len : integer; avxConst : PAVXEncodeConst ) : integer; assembler;
function AVXBase64Decode( output : PByte; src : PAnsiChar; srcLen : integer; avxConst : PAVXDecodeConst ) : boolean; assembler;

{$ENDIF}

implementation

{$IFDEF x64}

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
// x64: RCX = dest, RDX = buf, r8 = len, r9 = avxConst
asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
   {$ENDIF}

   // ###########################################
   // #### prepare
   sub rdx, 4;

   {$IFDEF AVXSUP}vmovdqa ymm4, [r9 + TAVXEncodeConst.Lut1];          {$ELSE}db $C4,$C1,$7D,$6F,$61,$40;{$ENDIF} 

   // first load is masked
   {$IFDEF AVXSUP}vmovdqa ymm5, [r9 + TAVXEncodeConst.MaskMov];       {$ELSE}db $C4,$C1,$7D,$6F,$29;{$ENDIF} 
   {$IFDEF AVXSUP}vmaskmovps ymm0, ymm5, [rdx];                       {$ELSE}db $C4,$E2,$55,$2C,$02;{$ENDIF} 
   sub r8, 32;

   @loop:
      // shuf
      {$IFDEF AVXSUP}vpshufb ymm1, ymm0, [r9 + TAVXEncodeConst.Lut0]; {$ELSE}db $C4,$C2,$7D,$00,$49,$20;{$ENDIF} 
      {$IFDEF AVXSUP}vpand ymm2, ymm1, [r9 + TAVXEncodeConst.Mask0];  {$ELSE}db $C4,$C1,$75,$DB,$51,$60;{$ENDIF} 
      {$IFDEF AVXSUP}vpand ymm1, ymm1, [r9 + TAVXEncodeConst.Mask2];  {$ELSE}db $C4,$C1,$75,$DB,$89,$A0,$00,$00,$00;{$ENDIF} 
      {$IFDEF AVXSUP}vpmulhuw ymm2, ymm2, [r9 + TAVXEncodeConst.Mask1];{$ELSE}db $C4,$C1,$6D,$E4,$91,$80,$00,$00,$00;{$ENDIF} 
      {$IFDEF AVXSUP}vpmullw ymm1, ymm1, [r9 + TAVXEncodeConst.Mask3];{$ELSE}db $C4,$C1,$75,$D5,$89,$C0,$00,$00,$00;{$ENDIF} 
      {$IFDEF AVXSUP}vpor ymm1, ymm1, ymm2;                           {$ELSE}db $C5,$F5,$EB,$CA;{$ENDIF} 

      {$IFDEF AVXSUP}vpsubusb ymm0, ymm1, [r9 + TAVXEncodeConst.N51]; {$ELSE}db $C4,$C1,$75,$D8,$81,$E0,$00,$00,$00;{$ENDIF} // indices
      {$IFDEF AVXSUP}vpcmpgtb ymm2, ymm1, [r9 + TAVXEncodeConst.N25]; {$ELSE}db $C4,$C1,$75,$64,$91,$00,$01,$00,$00;{$ENDIF} //, ymm0;

      {$IFDEF AVXSUP}vpsubb ymm0, ymm0, ymm2;                         {$ELSE}db $C5,$FD,$F8,$C2;{$ENDIF} 
      {$IFDEF AVXSUP}vpshufb ymm2, ymm4, ymm0;                        {$ELSE}db $C4,$E2,$5D,$00,$D0;{$ENDIF} 

      {$IFDEF AVXSUP}vpaddb ymm0, ymm2, ymm1;                         {$ELSE}db $C5,$ED,$FC,$C1;{$ENDIF} 
      // store
      {$IFDEF AVXSUP}vmovdqu [rcx], ymm0;                             {$ELSE}db $C5,$FE,$7F,$01;{$ENDIF} 

      // adjust buffer
      add rcx, 32;
      add rdx, 24;
      sub r8, 24;
      jl @loopEnd;

      // load next
      {$IFDEF AVXSUP}vmovdqu ymm0, [rdx];                             {$ELSE}db $C5,$FE,$6F,$02;{$ENDIF} 

   // adjust len
   jmp @loop;

   @loopEnd:

   // build result -> the remaining bytes left
   mov rax, r8;
   add rax, 32;
   {$IFDEF AVXSUP}vzeroupper;                                         {$ELSE}db $C5,$F8,$77;{$ENDIF} 
end;

{$ENDREGION}

// ###########################################
// #### AVX Decode
// ###########################################

{$REGION 'AVX Decoding'}

// a compressed version from: https://github.com/lemire/fastbase64/blob/master/src/fastavxbase64.c
function AVXBase64Decode( output : PByte; src : PAnsiChar; srcLen : integer; avxConst : PAVXDecodeConst ) : boolean; assembler;
// 64bit: rcx = output, rdx = src, r8 : srcLen, r9 : avxConst
var dXmm8, dXmm7, dXmm6 : TXMM;
asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
   {$ENDIF}

   {$IFDEF AVXSUP}vmovupd dXmm8, xmm8;                                {$ELSE}db $C5,$79,$11,$45,$EC;{$ENDIF} 
   {$IFDEF AVXSUP}vmovupd dXmm7, xmm7;                                {$ELSE}db $C5,$F9,$11,$7D,$DC;{$ENDIF} 
   {$IFDEF AVXSUP}vmovupd dXmm6, xmm6;                                {$ELSE}db $C5,$F9,$11,$75,$CC;{$ENDIF} 


   sub r8, 32;
   {$IFDEF AVXSUP}vmovdqa ymm8, [r9 + TAVXDecodeConst.PermOut];       {$ELSE}db $C4,$41,$7D,$6F,$81,$E0,$00,$00,$00;{$ENDIF} 

   {$IFDEF AVXSUP}vmovdqa ymm7, [r9 + TAVXDecodeConst.LutLo];         {$ELSE}db $C4,$C1,$7D,$6F,$39;{$ENDIF} 
   {$IFDEF AVXSUP}vmovdqa ymm6, [r9 + TAVXDecodeConst.LutHi];         {$ELSE}db $C4,$C1,$7D,$6F,$71,$20;{$ENDIF} 
   {$IFDEF AVXSUP}vmovdqa ymm5, [r9 + TAVXDecodeConst.LutRoll];       {$ELSE}db $C4,$C1,$7D,$6F,$69,$40;{$ENDIF} 

   xor eax, eax;

   @loop:
       // load 32 bytes -> convert ascii to bytes
       {$IFDEF AVXSUP}vmovupd ymm0, [rdx];                            {$ELSE}db $C5,$FD,$10,$02;{$ENDIF} 

       {$IFDEF AVXSUP}vpsrld ymm1, ymm0, 4;                           {$ELSE}db $C5,$F5,$72,$D0,$04;{$ENDIF} 
       {$IFDEF AVXSUP}vpand ymm1, ymm1, [r9 + TAVXDecodeConst.Mask2F];{$ELSE}db $C4,$C1,$75,$DB,$49,$60;{$ENDIF} // hi_nibbles
       {$IFDEF AVXSUP}vpshufb ymm2, ymm6, ymm1;                       {$ELSE}db $C4,$E2,$4D,$00,$D1;{$ENDIF} // hi
       {$IFDEF AVXSUP}vpcmpeqb ymm3, ymm0, [r9 + TAVXDecodeConst.Mask2F];{$ELSE}db $C4,$C1,$7D,$74,$59,$60;{$ENDIF} // eq2f
       {$IFDEF AVXSUP}vpaddb ymm3, ymm3, ymm1;                        {$ELSE}db $C5,$E5,$FC,$D9;{$ENDIF} // add epqf hi_nibbles
       {$IFDEF AVXSUP}vpshufb ymm3, ymm5, ymm3;                       {$ELSE}db $C4,$E2,$55,$00,$DB;{$ENDIF} // roll

       {$IFDEF AVXSUP}vpand ymm4, ymm0, [r9 + TAVXDecodeConst.Mask2F];{$ELSE}db $C4,$C1,$7D,$DB,$61,$60;{$ENDIF} // lo_nibbles
       {$IFDEF AVXSUP}vpshufb ymm4, ymm7, ymm4;                       {$ELSE}db $C4,$E2,$45,$00,$E4;{$ENDIF} // lo

       // test for an incorrect character
       {$IFDEF AVXSUP}vptest ymm4, ymm2;                              {$ELSE}db $C4,$E2,$7D,$17,$E2;{$ENDIF} 
       jnz @wrongEncoding;

       {$IFDEF AVXSUP}vpaddb ymm0, ymm0, ymm3;                        {$ELSE}db $C5,$FD,$FC,$C3;{$ENDIF} 

       // ###########################################
       // #### Reshuffle from 32 bytes to 24
       {$IFDEF AVXSUP}vpmaddubsw ymm1, ymm0, [r9 + TAVXDecodeConst.Merge];{$ELSE}db $C4,$C2,$7D,$04,$89,$80,$00,$00,$00;{$ENDIF} 
       {$IFDEF AVXSUP}vpmaddwd ymm1, ymm1, [r9 + TAVXDecodeConst.MergeAdd];{$ELSE}db $C4,$C1,$75,$F5,$89,$A0,$00,$00,$00;{$ENDIF} 
       {$IFDEF AVXSUP}vpshufb ymm1, ymm1, [r9 + TAVXDecodeConst.ShufOut];{$ELSE}db $C4,$C2,$75,$00,$89,$C0,$00,$00,$00;{$ENDIF} 
       {$IFDEF AVXSUP}vpermd ymm0, ymm8, ymm1;                        {$ELSE}db $C4,$E2,$3D,$36,$C1;{$ENDIF} 

       {$IFDEF AVXSUP}vmovdqu [rcx], ymm0;                            {$ELSE}db $C5,$FE,$7F,$01;{$ENDIF} 
       add rcx, 24;
       add rdx, 32;

   sub r8, 32;
   jg @loop;

   // ###########################################
   // #### Build result
   add eax, 1;    // set to true

   @wrongEncoding:

   {$IFDEF AVXSUP}vmovupd xmm8, dXmm8;                                {$ELSE}db $C5,$79,$10,$45,$EC;{$ENDIF} 
   {$IFDEF AVXSUP}vmovupd xmm7, dXMM7;                                {$ELSE}db $C5,$F9,$10,$7D,$DC;{$ENDIF} 
   {$IFDEF AVXSUP}vmovupd xmm6, dXMM6;                                {$ELSE}db $C5,$F9,$10,$75,$CC;{$ENDIF} 
   {$IFDEF AVXSUP}vzeroupper;                                         {$ELSE}db $C5,$F8,$77;{$ENDIF} 
end;

{$ENDREGION}

{$ENDIF}

end.
