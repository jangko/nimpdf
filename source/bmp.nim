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

import unsigned, streams, math, endians

const
  #set to a default of 96 dpi
  DefaultXPelsPerMeter = 3780
  DefaultYPelsPerMeter = 3780

  DefaultPalette = [(7,192'u8,192'u8,192'u8),
    (8,192'u8,220'u8,192'u8),
    (9,166'u8,202'u8,240'u8),
    (246,255'u8,251'u8,240'u8),
    (247,160'u8,160'u8,164'u8),
    (248,128'u8,128'u8,128'u8),
    (249,255'u8,0'u8,0'u8),
    (250,0'u8,255'u8,0'u8),
    (251,255'u8,255'u8,0'u8),
    (252,0'u8,0'u8,255'u8),
    (253,255'u8,0'u8,255'u8),
    (254,0'u8,255'u8,255'u8),
    (255,255'u8,255'u8,255'u8)]

  PalMaker = [(1,1,1,128,128,128),
    (1,1,1,255,255,255),
    (3,7,7,32,32,64)]

when system.cpuEndian == littleEndian:
  const BMPSignature = 0x4D42
else:
  const BMPSignature = 0x424D
  
type
  BYTE = uint8
  WORD = uint16
  DWORD = uint32

  RGBApixel* {.pure,final.}= object
    Blue*, Green*, Red*, Alpha*: BYTE

  BMFH = object
    bfType: WORD
    bfSize: DWORD
    bfReserved1: WORD
    bfReserved2: WORD
    bfOffBits: DWORD

  BMIH = object
    biSize, biWidth, biHeight: DWORD
    biPlanes, biBitCount: WORD
    biCompression, biSizeImage, biXPelsPerMeter: DWORD
    biYPelsPerMeter, biClrUsed, biClrImportant : DWORD

  BMP* = object
    BitDepth*, Width*, Height*: int
    Pixels*: seq[RGBApixel]
    Colors: seq[RGBApixel]
    XPelsPerMeter, YPelsPerMeter: int
    MetaData1, MetaData2: seq[BYTE]
    SizeOfMetaData1, SizeOfMetaData2: int

proc BMPError(msg: string): ref Exception =
  new(result)
  result.msg = msg
  
proc pow(base: int, exponent: int): int =
  result = 1
  for i in 1..exponent: result *= base

proc readLE[T: WORD|DWORD](s: Stream, val: var T): bool =
  if s.atEnd(): return false
  var tmp: T
  if s.readData(addr(tmp), sizeof(T)) != sizeof(T): return false
  when T is WORD: littleEndian16(addr(val), addr(tmp))
  else: littleEndian32(addr(val), addr(tmp))
  result = true

proc readLE[T: object](s: Stream, val: var T) =
  for field in fields(val):
    if not s.readLE(field):
      raise BMPError("error when reading file")

proc readWORD(s: Stream): WORD = 
  if not s.readLE(result): raise BMPError("error when reading word")

proc skip(s: Stream, nums: int) =
  var tmp: char
  for i in 0..nums-1: tmp = s.readChar()
  
proc TellNumberOfColors(bm: BMP): int =
  result = 2.pow(bm.BitDepth)
  if bm.BitDepth == 32: result = 2.pow(24)

proc SetColor(bm: var BMP, ColorNumber: int, NewColor: RGBApixel): bool =
  if bm.BitDepth != 1 and bm.BitDepth != 4 and bm.BitDepth != 8: return false
  if bm.Colors == nil: return false
  if ColorNumber >= bm.TellNumberOfColors(): return false
  bm.Colors[ColorNumber] = NewColor
  result = true

proc GetColor(bm: BMP, ColorNumber: int): RGBAPixel =
  result = RGBAPixel(Red: 255, Green: 255, Blue: 255, Alpha: 0)

  if bm.BitDepth != 1 and bm.BitDepth != 4 and bm.BitDepth != 8: return result
  if bm.Colors == nil: return result
  if ColorNumber >= bm.TellNumberOfColors(): return result
  result = bm.Colors[ColorNumber]

proc init*(bm: var BMP) =
  bm.Width = 1
  bm.Height = 1
  bm.BitDepth = 24
  newSeq(bm.Pixels, 1)
  bm.XPelsPerMeter = 0
  bm.YPelsPerMeter = 0
  bm.SizeOfMetaData1 = 0
  bm.SizeOfMetaData2 = 0

proc fillColorTable[T](bm: var BMP, pm: T, idx: int): int =
  var i = idx
  for L in 0..pm[0]:
    for K in 0..pm[1]:
      for J in 0..pm[2]:
        bm.Colors[i].Red   = BYTE(J*pm[3])
        bm.Colors[i].Green = BYTE(K*pm[4])
        bm.Colors[i].Blue  = BYTE(L*pm[5])
        bm.Colors[i].Alpha = 0
        inc i
  result = i
  
proc CreateStandardColorTable(bm: var BMP): bool =
  if bm.BitDepth notin {1, 4, 8}:  return false

  if bm.BitDepth == 1:
    for i in 0..1:
      bm.Colors[i].Red = BYTE(i*255)
      bm.Colors[i].Green = BYTE(i*255)
      bm.Colors[i].Blue = BYTE(i*255)
      bm.Colors[i].Alpha = 0
    return true

  if bm.BitDepth == 4:
    var i = bm.fillColorTable(PalMaker[0], 0)
    discard bm.fillColorTable(PalMaker[1], i)

    i=8
    bm.Colors[i].Red   = 192
    bm.Colors[i].Green = 192
    bm.Colors[i].Blue  = 192
    return true

  if bm.BitDepth == 8:
    discard bm.fillColorTable(PalMaker[2], 0)
    discard bm.fillColorTable(PalMaker[0], 0)
    for x in DefaultPalette:
      let i = x[0] 
      bm.Colors[i].Red   = x[1]
      bm.Colors[i].Green = x[2]
      bm.Colors[i].Blue  = x[3]
    return true
  return true

proc SetBitDepth(bm: var BMP, NewDepth: int): bool =
  if NewDepth notin {1,4,8,16,24,32}: return false
  bm.BitDepth = NewDepth
  if bm.BitDepth == 1 or bm.BitDepth == 4 or bm.BitDepth == 8:
    let NumberOfColors = 2.pow(bm.BitDepth)
    newSeq(bm.Colors, NumberOfColors)
    discard bm.CreateStandardColorTable()
  result = true

proc SetSize(bm: var BMP, NewWidth: int, NewHeight: int) =
  newSeq(bm.Pixels, NewWidth * NewHeight)
  bm.Width = NewWidth
  bm.Height = NewHeight

proc Read32bitRow(bm: var BMP, Buffer: cstring, BufferSize: int, Row:int): bool =
  if bm.Width*4 > BufferSize: return false

  for i in 0..bm.Width-1:
    let px = Row * bm.Width + i
    let cx = i * 4
    bm.Pixels[px].Blue  = BYTE(Buffer[cx])
    bm.Pixels[px].Green = BYTE(Buffer[cx+1])
    bm.Pixels[px].Red   = BYTE(Buffer[cx+2])
    bm.Pixels[px].Alpha = BYTE(Buffer[cx+4])
  result = true

proc Read24bitRow(bm: var BMP, Buffer: cstring, BufferSize: int, Row:int): bool =
  if bm.Width*3 > BufferSize: return false

  for i in 0..bm.Width-1:
    let px = Row * bm.Width + i
    let cx = i * 3
    bm.Pixels[px].Blue  = BYTE(Buffer[cx])
    bm.Pixels[px].Green = BYTE(Buffer[cx+1])
    bm.Pixels[px].Red   = BYTE(Buffer[cx+2])
  result = true

proc Read8bitRow(bm: var BMP, Buffer: cstring, BufferSize: int, Row:int): bool =
  if bm.Width > BufferSize: return false

  for i in 0..bm.Width-1:
    bm.Pixels[Row * bm.Width + i] = bm.GetColor(int(Buffer[i]))
  result = true

proc Read4bitRow(bm: var BMP, Buffer: cstring, BufferSize: int, Row:int): bool =
  let Shifts = [4, 0]
  let Masks =  [240,15]

  if bm.Width > 2*BufferSize: return false

  var i=0
  var j=0
  var k=0
  while i < bm.Width:
    j=0
    while j < 2 and i < bm.Width:
      let index = (int(Buffer[k]) and Masks[j]) shr Shifts[j]
      bm.Pixels[Row * bm.Width + i] = bm.GetColor(index)
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

  if bm.Width > 8*BufferSize: return false

  while i < bm.Width:
    j=0;
    while j < 8 and i < bm.Width:
      let index = (int(Buffer[k]) and Masks[j]) shr Shifts[j]
      bm.Pixels[bm.Width*Row+i] = bm.GetColor(index)
      i += 1
      j += 1
    k += 1
  result = true

proc readHeader(bmp: var BMP, ih: var BMIH, fh: var BMFH, s: Stream): bool =
  s.readLE(fh)
  s.readLE(ih)
  bmp.XPelsPerMeter = int(ih.biXPelsPerMeter)
  bmp.YPelsPerMeter = int(ih.biYPelsPerMeter)

  if fh.bfType != BMPSignature: return false
  if ih.biCompression == 1 or ih.biCompression == 2: return false
  if ih.biCompression > DWORD(3): return false
  if ih.biCompression == 3 and ih.biBitCount != 16: return false
  if ih.biBitCount notin {1,4,8,16,24,32}: return false
  discard bmp.SetBitDepth(int(ih.biBitCount))
  if ih.biWidth <= 0 and ih.biHeight <= 0: return false
  bmp.SetSize( int(ih.biWidth), int(ih.biHeight) )
  
  if bmp.BitDepth < 16:
    var NumberOfColorsToRead = int((fh.bfOffBits - 54) div 4)
    if NumberOfColorsToRead > 2.pow(bmp.BitDepth):  NumberOfColorsToRead = 2.pow(bmp.BitDepth)

    for n in 0..NumberOfColorsToRead-1:
      if s.readData(addr(bmp.Colors[n]), 4) != 4: return false

    var WHITE = RGBApixel(Red: 255, Green: 255, Blue: 255, Alpha: 0)
    for n in NumberOfColorsToRead..bmp.TellNumberOfColors()-1:
      discard bmp.SetColor( n , WHITE )
      
  result = true

proc makeShift(mask: WORD): WORD =
  result = 0
  var TempShift = mask
  while TempShift > WORD(31):
    TempShift = TempShift shr 1
    inc result

proc ReadFromFile*(bmp: var BMP, fileName: string): bool =
  var ih: BMIH
  var fh: BMFH
  var s = newFileStream(fileName, fmRead)
  if s == nil: return false
  if not bmp.readHeader(ih, fh, s):
    s.close()
    return false
  
  var BytesToSkip = int(fh.bfOffBits - 54)
  if bmp.BitDepth < 16: BytesToSkip -= 4 * 2.pow(bmp.BitDepth)
  if bmp.BitDepth == 16 and ih.biCompression == 3: BytesToSkip -= 3 * 4
  if BytesToSkip < 0: BytesToSkip = 0
  if BytesToSkip > 0 and bmp.BitDepth != 16: s.skip(BytesToSkip)
      
  if bmp.BitDepth != 16:
    let BufferSize = 4 * ((bmp.Width * bmp.BitDepth + 31) div 32)

    var Buffer = newString(BufferSize)
    var j = bmp.Height-1
    while j > -1:
      if readData(s, cstring(Buffer), BufferSize) != BufferSize: break
      var Success = false
      case bmp.BitDepth
      of 1: Success = bmp.Read1bitRow(  Buffer, BufferSize, j )
      of 4: Success = bmp.Read4bitRow(  Buffer, BufferSize, j )
      of 8: Success = bmp.Read8bitRow(  Buffer, BufferSize, j )
      of 24: Success = bmp.Read24bitRow( Buffer, BufferSize, j )
      of 32: Success = bmp.Read32bitRow( Buffer, BufferSize, j )
      else: break
      if not Success: break
      dec j

  if bmp.BitDepth == 16:
    let DataBytes = bmp.Width * 2
    let PaddingBytes = (4 - DataBytes mod 4) mod 4

    var BlueMask: WORD = 31
    var GreenMask: WORD = 992
    var RedMask: WORD = 31744

    if ih.biCompression != 0:
      var TempMask: WORD
      RedMask   = s.readWORD()
      TempMask  = s.readWORD()
      GreenMask = s.readWORD()
      TempMask  = s.readWORD()
      BlueMask  = s.readWORD()
      TempMask  = s.readWORD()
      
    if BytesToSkip > 0: s.skip(BytesToSkip)
    
    var GreenShift = makeShift(GreenMask)
    var BlueShift = makeShift(BlueMask)
    var RedShift = makeShift(RedMask)
    
    for j in countdown(bmp.Height-1, 0):
      var i = 0
      var ReadNumber = 0
      while ReadNumber < DataBytes:
        var temp = s.readWORD()
        ReadNumber += 2

        let BlueBYTE  = BYTE(WORD(8)*((BlueMask and temp) shr BlueShift))
        let GreenBYTE = BYTE(WORD(8)*((GreenMask and temp) shr GreenShift))
        let RedBYTE   = BYTE(WORD(8)*((RedMask and temp) shr RedShift))

        let px = j * bmp.Width + i
        bmp.Pixels[px].Red = RedBYTE
        bmp.Pixels[px].Green = GreenBYTE
        bmp.Pixels[px].Blue = BlueBYTE

        i += 1

      s.skip(PaddingBytes)

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
