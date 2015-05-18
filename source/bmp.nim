# Copyright (c) 2015 Andri Lim
#
# Distributed under the MIT license 
# (See accompanying file LICENSE.txt)
#
# this is a nim version of EasyBMP
# originally written by Paul Macklin
# http://easybmp.sourceforge.net

# support reading 1bit, 4bit, 8bit, 16bit, 24bit, and 32bit BMP
# this is a BMP reader, not a writer

import unsigned, streams, math

const
  #set to a default of 96 dpi 
  DefaultXPelsPerMeter=3780
  DefaultYPelsPerMeter=3780
  IsBigEndian = system.cpuEndian == bigEndian

type 
  BYTE = uint8
  WORD = uint16
  DWORD = uint32
  
  RGBApixel* {.pure,final.}= object
    Blue*, Green*, Red*, Alpha*: BYTE
  
  BMFH=object
    bfType:WORD
    bfSize:DWORD
    bfReserved1:WORD
    bfReserved2:WORD
    bfOffBits:DWORD
    
  BMIH=object
    biSize, biWidth, biHeight:DWORD
    biPlanes, biBitCount:WORD
    biCompression, biSizeImage, biXPelsPerMeter, biYPelsPerMeter, biClrUsed, biClrImportant : DWORD
    
  BMP* = object
    BitDepth*, Width*, Height*: int
    Pixels*:seq[seq[RGBApixel]]
    Colors:seq[RGBApixel]
    XPelsPerMeter, YPelsPerMeter: int
    MetaData1, MetaData2: seq[BYTE]
    SizeOfMetaData1, SizeOfMetaData2: int
 
template square(e:expr):expr=e*e

proc FlipWORD(val: WORD) : WORD {.inline.} = ( (val shr 8) or (val shl 8) )
proc FlipDWORD(val:DWORD) : DWORD {.inline.} = 
  (((val and 0xFF000000'u32) shr 24) or DWORD((val and 0x000000FF'u32) shl 24) or DWORD((val and 0x00FF0000'u32) shr 8 ) or DWORD((val and 0x0000FF00'u32) shl 8))

proc IntPow(base: int, exponent: int): int =
  result = 1
  for i in 1..exponent: result *= base
 
proc init(bm: var BMFH) =
  bm.bfType = 19778
  bm.bfReserved1 = 0
  bm.bfReserved2 = 0

proc SwitchEndianess(bm: var BMFH) =
  bm.bfType = FlipWORD(bm.bfType)
  bm.bfSize = FlipDWORD(bm.bfSize)
  bm.bfReserved1 = FlipWORD(bm.bfReserved1)
  bm.bfReserved2 = FlipWORD(bm.bfReserved2)
  bm.bfOffBits = FlipDWORD(bm.bfOffBits)
 
proc init(bm: var BMIH) =
  bm.biPlanes = 1
  bm.biCompression = 0
  bm.biXPelsPerMeter = DefaultXPelsPerMeter
  bm.biYPelsPerMeter = DefaultYPelsPerMeter
  bm.biClrUsed = 0
  bm.biClrImportant = 0

proc SwitchEndianess(bm: var BMIH) = 
  bm.biSize = FlipDWORD( bm.biSize )
  bm.biWidth = FlipDWORD( bm.biWidth )
  bm.biHeight = FlipDWORD( bm.biHeight )
  bm.biPlanes = FlipWORD( bm.biPlanes )
  bm.biBitCount = FlipWORD( bm.biBitCount )
  bm.biCompression = FlipDWORD( bm.biCompression )
  bm.biSizeImage = FlipDWORD( bm.biSizeImage )
  bm.biXPelsPerMeter = FlipDWORD( bm.biXPelsPerMeter )
  bm.biYPelsPerMeter = FlipDWORD( bm.biYPelsPerMeter )
  bm.biClrUsed = FlipDWORD( bm.biClrUsed )
  bm.biClrImportant = FlipDWORD( bm.biClrImportant )

proc display(bm: BMIH) =
  echo "biSize: ", $bm.biSize
  echo "biWidth: ", $bm.biWidth
  echo "biHeight: ", $bm.biHeight
  echo "biPlanes: ", $bm.biPlanes
  echo "biBitCount: ", $bm.biBitCount
  echo "biCompression: ", $bm.biCompression
  echo "biSizeImage: ", $bm.biSizeImage
  echo "biXPelsPerMeter: ", $bm.biXPelsPerMeter
  echo "biYPelsPerMeter: ", $bm.biYPelsPerMeter
  echo "biClrUsed: ", $bm.biClrUsed
  echo "biClrImportant: ", $bm.biClrImportant

proc display(bm: BMFH) =
  echo "bfType: ", $bm.bfType
  echo "bfSize: ", $bm.bfSize
  echo "bfReserved1: ", $bm.bfReserved1
  echo "bfReserved2: ", $bm.bfReserved2
  echo "bfOffBits: ", $bm.bfOffBits

proc GetPixel(bm: BMP; i, j: int) : RGBAPixel = bm.Pixels[i][j]
proc SetPixel(bm: var BMP; i, j: int, NewPixel: RGBApixel) = bm.Pixels[i][j] = NewPixel

proc TellNumberOfColors(bm: BMP): int = 
  result = IntPow(2, bm.BitDepth)
  if bm.BitDepth == 32: result = IntPow(2, 24)
 
proc SetColor(bm: var BMP, ColorNumber: int, NewColor: RGBApixel): bool =  
  if bm.BitDepth != 1 and bm.BitDepth != 4 and bm.BitDepth != 8: return false
  if bm.Colors == nil: return false
  if ColorNumber >= bm.TellNumberOfColors(): return false
  bm.Colors[ColorNumber] = NewColor
  result = true

proc GetColor(bm: BMP, ColorNumber: int): RGBAPixel = 
  result.Red   = 255
  result.Green = 255
  result.Blue  = 255
  result.Alpha = 0
  
  if bm.BitDepth != 1 and bm.BitDepth != 4 and bm.BitDepth != 8: return result
  if bm.Colors == nil: return result
  if ColorNumber >= bm.TellNumberOfColors(): return result
  result = bm.Colors[ColorNumber]
 
proc init*(bm: var BMP) = 
  bm.Width = 1
  bm.Height = 1
  bm.BitDepth = 24
  newSeq(bm.Pixels, 1)
  newSeq(bm.Pixels[0], 1)
  bm.XPelsPerMeter = 0
  bm.YPelsPerMeter = 0
  bm.SizeOfMetaData1 = 0
  bm.SizeOfMetaData2 = 0
  
proc SafeFread[T](s:Stream, val: var T): bool = 
  if s.atEnd(): return false
  if readData(s, addr(val), sizeof(T)) != sizeof(T): return false
  result = true

proc CreateStandardColorTable(bm: var BMP): bool =
  if bm.BitDepth != 1 and bm.BitDepth != 4 and bm.BitDepth != 8:
    return false
  
  if bm.BitDepth == 1:
    for i in 0..1:
      bm.Colors[i].Red = BYTE(i*255)
      bm.Colors[i].Green = BYTE(i*255)
      bm.Colors[i].Blue = BYTE(i*255)
      bm.Colors[i].Alpha = 0
    return true
 
  if bm.BitDepth == 4:
    var i = 0
    for ell in 0..1:
      for k in 0..1:
        for j in 0..1:
          bm.Colors[i].Red = BYTE(j*128)
          bm.Colors[i].Green = BYTE(k*128)
          bm.Colors[i].Blue = BYTE(ell*128)
          i += 1
          
    for ell in 0..1:
      for k in 0..1:
        for j in 0..1:
          bm.Colors[i].Red = BYTE(j*255)
          bm.Colors[i].Green = BYTE(k*255)
          bm.Colors[i].Blue = BYTE(ell*255)
          i += 1
  
    i=8
    bm.Colors[i].Red = 192
    bm.Colors[i].Green = 192
    bm.Colors[i].Blue = 192
   
    for i in 0..15:
      bm.Colors[i].Alpha = 0
    return true
  
  if bm.BitDepth == 8:
    var i = 0
    for ell in 0..3:
      for k in 0..7:
        for j in 0..7:
          bm.Colors[i].Red = BYTE(j*32)
          bm.Colors[i].Green = BYTE(k*32)
          bm.Colors[i].Blue = BYTE(ell*64)
          bm.Colors[i].Alpha = 0
          i += 1
  
    i=0
    for ell in 0..1:
      for k in 0..1:
        for j in 0..1:
          bm.Colors[i].Red = BYTE(j*128)
          bm.Colors[i].Green = BYTE(k*128)
          bm.Colors[i].Blue = BYTE(ell*128)
          bm.Colors[i].Alpha = 0
          i += 1
   
    i=7
    bm.Colors[i].Red = 192
    bm.Colors[i].Green = 192
    bm.Colors[i].Blue = 192
    i=8
    bm.Colors[i].Red = 192
    bm.Colors[i].Green = 220
    bm.Colors[i].Blue = 192
    i=9
    bm.Colors[i].Red = 166
    bm.Colors[i].Green = 202
    bm.Colors[i].Blue = 240
    i=246
    bm.Colors[i].Red = 255
    bm.Colors[i].Green = 251
    bm.Colors[i].Blue = 240
    i=247
    bm.Colors[i].Red = 160
    bm.Colors[i].Green = 160
    bm.Colors[i].Blue = 164
    i=248
    bm.Colors[i].Red = 128
    bm.Colors[i].Green = 128
    bm.Colors[i].Blue = 128
    i=249
    bm.Colors[i].Red = 255
    bm.Colors[i].Green = 0
    bm.Colors[i].Blue = 0
    i=250
    bm.Colors[i].Red = 0
    bm.Colors[i].Green = 255
    bm.Colors[i].Blue = 0
    i=251
    bm.Colors[i].Red = 255
    bm.Colors[i].Green = 255
    bm.Colors[i].Blue = 0
    i=252
    bm.Colors[i].Red = 0
    bm.Colors[i].Green = 0
    bm.Colors[i].Blue = 255
    i=253
    bm.Colors[i].Red = 255
    bm.Colors[i].Green = 0
    bm.Colors[i].Blue = 255
    i=254
    bm.Colors[i].Red = 0
    bm.Colors[i].Green = 255
    bm.Colors[i].Blue = 255
    i=255
    bm.Colors[i].Red = 255
    bm.Colors[i].Green = 255
    bm.Colors[i].Blue = 255
    return true
  return true

proc SetBitDepth(bm: var BMP, NewDepth: int): bool =
  if NewDepth notin {1,4,8,16,24,32}:
    return false
  bm.BitDepth = NewDepth
  if bm.BitDepth == 1 or bm.BitDepth == 4 or bm.BitDepth == 8:
    let NumberOfColors = IntPow(2, bm.BitDepth)
    newSeq(bm.Colors, NumberOfColors)
    discard bm.CreateStandardColorTable()
  result = true

proc SetSize(bm: var BMP, NewWidth: int, NewHeight: int) =
  newSeq(bm.Pixels, NewWidth)
  for i in 0..NewWidth-1:
    newSeq(bm.Pixels[i], NewHeight)
  bm.Width = NewWidth
  bm.Height = NewHeight
 
proc `&=`(a: var bool, b: bool) {.inline.} =
  a = a and b

proc Read32bitRow(bm: var BMP, Buffer: cstring, BufferSize: int, Row:int): bool =
  if bm.Width*4 > BufferSize:
    return false
 
  for i in 0..bm.Width-1:
    bm.Pixels[i][Row].Blue  = BYTE(Buffer[i*4])
    bm.Pixels[i][Row].Green = BYTE(Buffer[i*4+1])
    bm.Pixels[i][Row].Red   = BYTE(Buffer[i*4+2])
    bm.Pixels[i][Row].Alpha = BYTE(Buffer[i*4+4])
  result = true

proc Read24bitRow(bm: var BMP, Buffer: cstring, BufferSize: int, Row:int): bool =
  if bm.Width*3 > BufferSize:
    return false
 
  for i in 0..bm.Width-1:
    bm.Pixels[i][Row].Blue  = BYTE(Buffer[i*3])
    bm.Pixels[i][Row].Green = BYTE(Buffer[i*3+1])
    bm.Pixels[i][Row].Red   = BYTE(Buffer[i*3+2])    
  result = true

proc Read8bitRow(bm: var BMP, Buffer: cstring, BufferSize: int, Row:int): bool =
  if bm.Width > BufferSize:
    return false
 
  for i in 0..bm.Width-1: 
    bm.Pixels[i][Row] = bm.GetColor(int(Buffer[i]))
  result = true

proc Read4bitRow(bm: var BMP, Buffer: cstring, BufferSize: int, Row:int): bool =
  let Shifts = [4, 0]
  let Masks =  [240,15]
 
  if bm.Width > 2*BufferSize:
    return false
  
  var i=0
  var j=0
  var k=0
  while i < bm.Width:
    j=0
    while j < 2 and i < bm.Width:
      let index = (int(Buffer[k]) and Masks[j]) shr Shifts[j]
      bm.Pixels[i][Row] = bm.GetColor(index)
      i += 1
      j += 1
    k += 1
  result = true

proc Read1bitRow(bm: var BMP, Buffer: cstring, BufferSize: int, Row:int): bool =
  let Shifts = [7, 6 ,5 ,4 ,3,2,1,0]
  let Masks  = [128,64,32,16,8,4,2,1]
 
  var i=0
  var j=0
  var k=0
 
  if bm.Width > 8*BufferSize:
    return false
    
  while i < bm.Width:
    j=0;
    while j < 8 and i < bm.Width:
      let index = (int(Buffer[k]) and Masks[j]) shr Shifts[j]
      bm.Pixels[i][Row] = bm.GetColor(index)
      i += 1
      j += 1
    k += 1
  result = true

proc ReadFromFile*(bmp: var BMP, fileName: string): bool =
  var fh:BMFH
  var ih:BMIH
  var NotCorrupted = true
  var IsBitmap = false
  var s = newFileStream(fileName, fmRead)
  
  NotCorrupted &= s.SafeFread(fh.bfType)
  if IsBigEndian and fh.bfType == 16973: IsBitmap = true
  if not IsBigEndian and fh.bfType == 19778: IsBitmap = true
  
  if not IsBitmap:
    s.close()
    return false
  
  NotCorrupted &= s.SafeFread(fh.bfSize)
  NotCorrupted &= s.SafeFread(fh.bfReserved1)
  NotCorrupted &= s.SafeFread(fh.bfReserved2)
  NotCorrupted &= s.SafeFread(fh.bfOffBits)
 
  if IsBigEndian: fh.SwitchEndianess()
 
  NotCorrupted &= s.SafeFread(ih.biSize)
  NotCorrupted &= s.SafeFread(ih.biWidth)
  NotCorrupted &= s.SafeFread(ih.biHeight)
  NotCorrupted &= s.SafeFread(ih.biPlanes)
  NotCorrupted &= s.SafeFread(ih.biBitCount)
          
  NotCorrupted &= s.SafeFread(ih.biCompression)
  NotCorrupted &= s.SafeFread(ih.biSizeImage)
  NotCorrupted &= s.SafeFread(ih.biXPelsPerMeter)
  NotCorrupted &= s.SafeFread(ih.biYPelsPerMeter)
  NotCorrupted &= s.SafeFread(ih.biClrUsed)
  NotCorrupted &= s.SafeFread(ih.biClrImportant)
 
  if IsBigEndian: ih.SwitchEndianess()
  if not NotCorrupted:
    s.close()
    return false
  
  bmp.XPelsPerMeter = int(ih.biXPelsPerMeter)
  bmp.YPelsPerMeter = int(ih.biYPelsPerMeter)
 
  if ih.biCompression == 1 or ih.biCompression == 2:
    s.close()
    return false
  
  if ih.biCompression > DWORD(3):
    s.close()
    return false
 
  if ih.biCompression == 3 and ih.biBitCount != 16:
    s.close()
    return false
  
  
  if ih.biBitCount notin {1,4,8,16,24,32}:
    s.close()
    return false
  
  discard bmp.SetBitDepth(int(ih.biBitCount))
 
  if ih.biWidth <= 0 and ih.biHeight <= 0:
    s.close()
    return false
 
  bmp.SetSize( int(ih.biWidth), int(ih.biHeight) )
  #ih.display()
  #fh.display()
  
  let dBytesPerPixel = float64(bmp.BitDepth) / 8.0
  let dBytesPerRow   = math.ceil(dBytesPerPixel * float64(bmp.Width))
    
  var BytePaddingPerRow = 4 - int(dBytesPerRow) mod 4
  if BytePaddingPerRow == 4: BytePaddingPerRow = 0
  
  if bmp.BitDepth < 16:
    var NumberOfColorsToRead = int((fh.bfOffBits - 54) div 4)
    if NumberOfColorsToRead > IntPow(2,bmp.BitDepth):  NumberOfColorsToRead = IntPow(2,bmp.BitDepth)
 
    for n in 0..NumberOfColorsToRead-1:
      discard s.SafeFread(bmp.Colors[n])   
  
    var WHITE: RGBApixel
    WHITE.Red = 255
    WHITE.Green = 255
    WHITE.Blue = 255
    WHITE.Alpha = 0
  
    for n in NumberOfColorsToRead..bmp.TellNumberOfColors()-1:
      discard bmp.SetColor( n , WHITE )
  
  var BytesToSkip = int(fh.bfOffBits - 54)
  if bmp.BitDepth < 16:
    BytesToSkip -= 4*IntPow(2,bmp.BitDepth)
  if bmp.BitDepth == 16 and ih.biCompression == 3:
    BytesToSkip -= 3*4
  if BytesToSkip < 0:
    BytesToSkip = 0
  if BytesToSkip > 0 and bmp.BitDepth != 16:
    var skip:BYTE
    for i in 1..BytesToSkip:
      discard s.SafeFread(skip)
   
  if bmp.BitDepth != 16:
    var BufferSize = int( (bmp.Width*bmp.BitDepth) / 8)
    while 8*BufferSize < bmp.Width*bmp.BitDepth:
      BufferSize += 1
    while (BufferSize mod 4) > 0:
      BufferSize += 1
  
    var Buffer: string = newString(BufferSize)
    var j = bmp.Height-1
    while j > -1:
      let BytesRead = readData(s, cstring(Buffer), BufferSize)
      if BytesRead < BufferSize: break
      else:
        var Success = false
        case bmp.BitDepth
        of 1: Success = bmp.Read1bitRow(  Buffer, BufferSize, j )
        of 4: Success = bmp.Read4bitRow(  Buffer, BufferSize, j )
        of 8: Success = bmp.Read8bitRow(  Buffer, BufferSize, j )
        of 24: Success = bmp.Read24bitRow( Buffer, BufferSize, j )
        of 32: Success = bmp.Read32bitRow( Buffer, BufferSize, j )
        else: break
        if not Success: break
      j -= 1
    
  if bmp.BitDepth == 16:
    let DataBytes = bmp.Width*2
    let PaddingBytes = ( 4 - DataBytes mod 4 ) mod 4
    
    var BlueMask : WORD = 31
    var GreenMask : WORD = 992
    var RedMask : WORD = 31744

    if ih.biCompression != 0:
      var TempMask: WORD
      discard s.SafeFread(RedMask)
      if IsBigEndian: RedMask = FlipWORD(RedMask)
      discard s.SafeFread(TempMask)
      discard s.SafeFread(GreenMask)
      if IsBigEndian: GreenMask = FlipWORD(GreenMask)
      discard s.SafeFread(TempMask)
      discard s.SafeFread(BlueMask)
      if IsBigEndian: BlueMask = FlipWORD(BlueMask)
      discard s.SafeFread(TempMask)
    
    if BytesToSkip > 0:
      var skip:BYTE
      for i in 1..BytesToSkip:
        discard s.SafeFread(skip)
  
    var GreenShift: WORD = 0
    var TempShift:WORD = GreenMask
    while TempShift > WORD(31): 
      TempShift = TempShift shr 1
      GreenShift += 1
      
    var BlueShift:WORD = 0
    TempShift = BlueMask
    while TempShift > WORD(31):
      TempShift = TempShift shr 1
      BlueShift += 1
      
    var RedShift:WORD = 0 
    TempShift = RedMask
    while TempShift > WORD(31):
      TempShift = TempShift shr 1
      RedShift += 1
  
    for j in countdown(bmp.Height-1, 0):
      var i = 0
      var ReadNumber = 0
      while ReadNumber < DataBytes:
        var temp: WORD
        discard s.SafeFread(temp)
        if IsBigEndian: temp = FlipWORD(temp)
        ReadNumber += 2
          
        let BlueBYTE  = BYTE(WORD(8)*((BlueMask and temp) shr BlueShift))
        let GreenBYTE = BYTE(WORD(8)*((GreenMask and temp) shr GreenShift))
        let RedBYTE   = BYTE(WORD(8)*((RedMask and temp) shr RedShift))

        bmp.Pixels[i][j].Red = RedBYTE
        bmp.Pixels[i][j].Green = GreenBYTE
        bmp.Pixels[i][j].Blue = BlueBYTE

        i += 1

      ReadNumber = 0
      while ReadNumber < PaddingBytes:
        var temp : BYTE
        discard s.SafeFread(temp)
        ReadNumber += 1
  
  s.close()
  result = true

when isMainModule:
  var bmp: BMP
  bmp.init()
  discard bmp.ReadFromFile("1bit.bmp")
  discard bmp.ReadFromFile("4bit.bmp")
  discard bmp.ReadFromFile("8bit.bmp")
  discard bmp.ReadFromFile("16bit.bmp")
  discard bmp.ReadFromFile("24bit.bmp")
  discard bmp.ReadFromFile("32bit.bmp")
