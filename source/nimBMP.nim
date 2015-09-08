# BMP Graphics Encoder and Decoder written in Nim
# part of nimPDF sister projects
#
# Copyright (c) 2015 Andri Lim
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
#-------------------------------------

import streams, endians, unsigned, tables, hashes
import strutils

const
  #set to a default of 96 dpi
  DefaultXPelsPerMeter = 3780
  DefaultYPelsPerMeter = 3780

  defaultPalette = [(7,192'u8,192'u8,192'u8),
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

  palMaker = [(1,1,1,128,128,128),
    (1,1,1,255,255,255),
    (3,7,7,32,32,64)]

  BMPSignature = "\x42\x4D"

type
  BYTE  = uint8
  WORD  = uint16
  DWORD = uint32
  LONG  = int32

  BMPCompression* = enum
    BC_NONE,
    BC_RLE8,
    BC_RLE4,
    BC_BITFIELDS

  BMPHeader = object
    fileSize: DWORD
    reserved1: WORD
    reserved2: WORD
    offset: DWORD

  BMPInfo = object
    size: DWORD
    width, height: LONG
    planes, bitsPerPixel: WORD
    compression, imageSize: DWORD
    horzResolution, vertResolution: LONG
    colorUsed, colorImportant: DWORD

  BMPRGBA* {.pure, final.} = object
    b*,g*,r*,a*: BYTE  #the order must be b,g,r,a!

  BMP* = ref object
    pixels*: seq[BMPRGBA]
    palette*: seq[BMPRGBA]
    inverted*: bool
    compression*: BMPCompression
    bitsPerPixel*: int
    width*: int
    height*: int

  BMPResult* = ref object
    data*: string
    width*, height*: int

  scanlineReader = proc(bmp: BMP, input: string, row: int)

const
  RLE_COMMAND     = 0
  RLE_ENDOFLINE   = 0
  RLE_ENDOFBITMAP = 1
  RLE_DELTA       = 2

proc toHex*(input: string) =
  var i = 0
  for x in 0..input.high:
    write(stdout, toHex(ord(input[x]), 2))
    inc i
    if i == 40:
      write(stdout, "\n")
      i = 0
  if i < 40:
    write(stdout, "\n")

proc show*[T](mode: T) =
  for k, v in fieldPairs(mode):
    echo k, " ", $v

proc BMPError(msg: string): ref Exception =
  new(result)
  result.msg = msg

proc readLE[T: WORD|DWORD|LONG](s: Stream, val: var T): bool =
  if s.atEnd(): return false
  var tmp: T
  if s.readData(addr(tmp), sizeof(T)) != sizeof(T): return false
  when T is WORD: littleEndian16(addr(val), addr(tmp))
  else: littleEndian32(addr(val), addr(tmp))
  result = true

proc readLE[T: BMPHeader|BMPInfo](s: Stream, val: var T) =
  for field in fields(val):
    if not s.readLE(field):
      raise BMPError("error when reading file")

proc readWORD(s: Stream): WORD =
  if not s.readLE(result): raise BMPError("error when reading word")

proc readDWORD(s: Stream): DWORD =
  if not s.readLE(result): raise BMPError("error when reading dword")

proc skip(s: Stream, nums: int) =
  var tmp: char
  for i in 0.. <nums: tmp = s.readChar()

proc pow(base: int, exponent: int): int =
  result = 1
  for i in 1..exponent: result *= base

proc numColors(bmp: BMP): int =
  if bmp.bitsPerPixel == 32: result = 2.pow(24)
  else: result = 2.pow(bmp.bitsPerPixel)

proc fillPalette[T](bmp: BMP, pm: T, idx: int): int =
  var i = idx
  for L in 0..pm[0]:
    for K in 0..pm[1]:
      for J in 0..pm[2]:
        bmp.palette[i].r = BYTE(J*pm[3])
        bmp.palette[i].g = BYTE(K*pm[4])
        bmp.palette[i].b = BYTE(L*pm[5])
        bmp.palette[i].a = 0
        inc i
  result = i

proc createStandardPalette(bmp: BMP) =
  assert bmp.bitsPerPixel in {1, 4, 8}

  if bmp.bitsPerPixel == 1:
    for i in 0..1:
      bmp.palette[i].r = BYTE(i*255)
      bmp.palette[i].g = BYTE(i*255)
      bmp.palette[i].b = BYTE(i*255)
      bmp.palette[i].a = 0
    return

  if bmp.bitsPerPixel == 4:
    var i = bmp.fillPalette(palMaker[0], 0)
    discard bmp.fillPalette(palMaker[1], i)

    i = 8
    bmp.palette[i].r = 192
    bmp.palette[i].g = 192
    bmp.palette[i].b = 192
    return

  if bmp.bitsPerPixel == 8:
    discard bmp.fillPalette(palMaker[2], 0)
    discard bmp.fillPalette(palMaker[0], 0)
    for x in defaultPalette:
      let i = x[0]
      bmp.palette[i].r = x[1]
      bmp.palette[i].g = x[2]
      bmp.palette[i].b = x[3]

proc read32bitRow(bmp: BMP, input: string, row: int) =
  for i in 0.. <bmp.width:
    let px = row * bmp.width + i
    let cx = i * 4
    bmp.pixels[px].b = BYTE(input[cx])
    bmp.pixels[px].g = BYTE(input[cx+1])
    bmp.pixels[px].r = BYTE(input[cx+2])
    bmp.pixels[px].a = BYTE(input[cx+4])

proc read24bitRow(bmp: BMP, input: string, row: int) =
  for i in 0.. <bmp.width:
    let px = row * bmp.width + i
    let cx = i * 3
    bmp.pixels[px].b = BYTE(input[cx])
    bmp.pixels[px].g = BYTE(input[cx+1])
    bmp.pixels[px].r = BYTE(input[cx+2])

proc read8bitRow(bmp: BMP, input: string, row: int) =
  for i in 0.. <bmp.width:    
    bmp.pixels[row * bmp.width + i] = bmp.palette[input[i].ord]

proc read4bitRow(bmp: BMP, input: string, row: int) =
  var i = 0
  var k = 0
  while i < bmp.width:
    var index = (input[k].ord shr 4) and 0x0F
    bmp.pixels[row * bmp.width + i] = bmp.palette[index]
    inc i
    if i < bmp.width: #odd width
      index = input[k].ord and 0x0F
      bmp.pixels[row * bmp.width + i] = bmp.palette[index]
      inc i
    inc k

proc read1bitRow(bmp: BMP, input: string, row: int) =
  var
    i = 0
    j = 0
    k = 0

  while i < bmp.width:
    j = 0
    while j < 8 and i < bmp.width:
      let index = (input[k].ord shr (7 - j)) and 0x01
      bmp.pixels[bmp.width * row + i] = bmp.palette[index]
      inc i
      inc j
    inc k

proc getScanlineReader(bmp: BMP): scanlineReader =
  case bmp.bitsPerPixel
  of 1:  result = read1bitRow
  of 4:  result = read4bitRow
  of 8:  result = read8bitRow
  of 24: result = read24bitRow
  of 32: result = read32bitRow
  else: raise BMPError("unavailable scanline reader")

proc readPixels(bmp: BMP, s: Stream) =
  let scanlineSize = 4 * ((bmp.width * bmp.bitsPerPixel + 31) div 32)
  var scanLine = newString(scanlineSize)
  let rowReader = bmp.getScanlineReader()

  if bmp.inverted:
    for row in countdown(bmp.height-1, 0):
      if s.readData(cstring(scanLine), scanlineSize) != scanlineSize:
        #raise BMPError("error reading bitmap scanline")
        break
      bmp.rowReader(scanLine, row)
  else:
    for row in countup(0, bmp.height-1):
      if s.readData(cstring(scanLine), scanlineSize) != scanlineSize:
        #raise BMPError("error reading bitmap scanline")
        break
      bmp.rowReader(scanLine, row)

proc makeShift(mask: WORD): WORD =
  result = 0
  var TempShift = mask
  while TempShift > WORD(31):
    TempShift = TempShift shr 1
    inc result

proc readPixels16(bmp: BMP, s: Stream, bytesToSkip: int) =
  let scanlineSize = bmp.width * 2
  let paddingBytes = (4 - scanlineSize mod 4) mod 4

  var BMask: WORD = 31
  var GMask: WORD = 992
  var RMask: WORD = 31744

  if bmp.compression != BC_NONE:
    var TMask: WORD
    try:
      RMask = s.readWORD()
      TMask = s.readWORD()
      GMask = s.readWORD()
      TMask = s.readWORD()
      BMask = s.readWORD()
      TMask = s.readWORD()
    except:
      #missing color mask
      return

  if bytesToSkip > 0: s.skip(bytesToSkip)

  let GShift = makeShift(GMask)
  let BShift = makeShift(BMask)
  let RShift = makeShift(RMask)

  template read16bitRow(): stmt =
    for i in 0.. <bmp.width:
      var val = s.readWORD()
      let px = row * bmp.width + i
      bmp.pixels[px].r = BYTE(WORD(8)*((RMask and val) shr RShift))
      bmp.pixels[px].g = BYTE(WORD(8)*((GMask and val) shr GShift))
      bmp.pixels[px].b = BYTE(WORD(8)*((BMask and val) shr BShift))
    s.skip(paddingBytes)

  #catch cropped image
  try:
    if bmp.inverted:
      for row in countdown(bmp.height-1, 0): read16bitRow()
    else:
      for row in countup(0, bmp.height-1): read16bitRow()
  except:
    discard

proc getScanLine(bmp: BMP, scanLine: int): int =
  if bmp.inverted: result = (bmp.height - 1 - scanLine) * bmp.width
  else: result = scanLine * bmp.width

proc readPixelsRLE4(bmp: BMP, s: Stream) =
  var
    bits = 0
    statusByte: int
    secondByte: int
    scanLine = 0

  while scanLine < bmp.height:
    if s.atEnd(): break
    statusByte = s.readChar.ord

    if statusByte != RLE_COMMAND:
      let count = min(statusByte, bmp.width - bits)
      let start = bmp.getScanLine(scanLine)
      #Encoded mode
      if s.atEnd(): break
      secondByte = s.readChar.ord

      for i in 0.. <count:
        if (i and 0x01) != 0: bmp.pixels[start + bits] = bmp.palette[secondByte and 0x0F]
        else: bmp.pixels[start + bits] = bmp.palette[(secondByte shr 4) and 0x0F]
        inc bits
    else:
      #Escape mode
      if s.atEnd(): break
      statusByte = s.readChar.ord

      case statusByte:
      of RLE_ENDOFLINE:
        bits = 0
        inc scanLine
      of RLE_ENDOFBITMAP:
        #End of bitmap
        return
      of RLE_DELTA:
        #read the delta values
        if s.atEnd(): break
        let deltaX = s.readChar.ord
        if s.atEnd(): break
        let deltaY = s.readChar.ord

        #apply them
        inc (bits, deltaX)
        inc (scanLine, deltaY)
      else:
        #Absolute mode
        let count = min(statusByte, bmp.width - bits)
        let start = bmp.getScanLine(scanLine)
        for i in 0.. <count:
          if(i and 0x01) == 0:
            if s.atEnd(): break
            secondByte = s.readChar.ord

          if (i and 0x01) != 0: bmp.pixels[start + bits] = bmp.palette[secondByte and 0x0F]
          else: bmp.pixels[start + bits] = bmp.palette[(secondByte shr 4) and 0x0F]
          inc bits

        #Read pad byte
        if((statusByte and 0x03) == 1) or ((statusByte and 0x03) == 2):
          if s.atEnd(): break
          discard s.readChar.ord

proc readPixelsRLE8(bmp: BMP, s: Stream) =
  var
    scanLine = 0
    bits = 0
    statusByte: int
    secondByte: int

  while scanLine < bmp.height:
    if s.atEnd(): return
    statusByte = s.readChar.ord

    if statusByte == RLE_COMMAND:
      if s.atEnd(): return
      statusByte = s.readChar.ord

      case statusByte
      of RLE_ENDOFLINE:
        bits = 0
        inc scanLine
      of RLE_ENDOFBITMAP:
        return
      of RLE_DELTA:
        #read the delta values
        if s.atEnd(): return
        let deltaX = s.readChar.ord
        if s.atEnd(): return
        let deltaY = s.readChar.ord

        #apply them
        inc (bits, deltaX)
        inc (scanLine, deltaY)
      else:
        if scanLine >= bmp.height: return
        let count = min(statusByte, bmp.width - bits)
        let start = bmp.getScanLine(scanLine)
        for i in 0.. <count:
          if s.atEnd(): return
          secondByte = s.readChar.ord
          bmp.pixels[start + bits] = bmp.palette[secondByte]
          inc bits

        #align run length to even number of bytes
        if (statusByte and 1) == 1:
          if s.atEnd(): return
          secondByte = s.readChar.ord
    else:
      if scanLine >= bmp.height: return
      let count = min(statusByte, bmp.width - bits)
      let start = bmp.getScanLine(scanLine)
      if s.atEnd(): return
      secondByte = s.readChar.ord
      for i in 0.. <count:
        bmp.pixels[start + bits] = bmp.palette[secondByte]
        inc bits

proc makeShift(mask: DWORD): DWORD =
  result = 0
  var pos: DWORD = 1
  while((pos and mask) == 0) and result < 31:
    pos = pos shl 1
    inc result

proc readPixels32(bmp: BMP, s: Stream, bytesToSkip: int) =
  var
    BMask = s.readDWORD()
    GMask = s.readDWORD()
    RMask = s.readDWORD()
  if bytesToSkip > 0: s.skip(bytesToSkip)

  let GShift = makeShift(GMask)
  let BShift = makeShift(BMask)
  let RShift = makeShift(RMask)

  let maxR = RMask shr RShift
  let maxG = GMask shr GShift
  let maxB = BMask shr BShift

  template read32bitMasked(): stmt =
    for i in 0.. <bmp.width:
      var val = s.readDWORD()
      let px = row * bmp.width + i
      let R = ((RMask and val) shr RShift).float / maxR.float
      let G = ((GMask and val) shr GShift).float / maxG.float
      let B = ((BMask and val) shr BShift).float / maxB.float

      bmp.pixels[px].r = BYTE(R * 255.float)
      bmp.pixels[px].g = BYTE(G * 255.float)
      bmp.pixels[px].b = BYTE(B * 255.float)

  #catch cropped image
  try:
    if bmp.inverted:
      for row in countdown(bmp.height-1, 0): read32bitMasked()
    else:
      for row in countup(0, bmp.height-1): read32bitMasked()
  except:
    discard

proc decodeBMP*(s: Stream): BMP =
  var bmp: BMP
  new(bmp)

  let signature = s. readStr(2)

  var header: BMPHeader
  var info: BMPInfo

  try:
    s.readLE(header)
  except:
    raise BMPError("error reading BMP header")

  try:
    s.readLE(info)
  except:
    raise BMPError("error reading BMP info")

  if signature != BMPSignature and info.size != 40:
    raise BMPError("signature mismatch") #perhaps only it's signature invalid?

  if info.size != 40:
    raise BMPError("wrong BMP version, only supported version 3.0")
  
  bmp.width = info.width
  bmp.height = info.height
  bmp.inverted = true
  if info.height < 0:
    bmp.inverted = false
    bmp.height = -1 * info.height

  bmp.bitsPerPixel = int(info.bitsPerPixel)
  if bmp.bitsPerPixel notin {1, 4, 8, 16, 24, 32}:
    raise BMPError("unsupported bitsPerPixel: " & $bmp.bitsPerPixel)

  if info.compression > 3.DWORD: info.compression = 0.DWORD #really bad compression
  bmp.compression = BMPCompression(info.compression)
  if bmp.compression notin {BC_NONE, BC_RLE4, BC_RLE8, BC_BITFIELDS}:
    raise BMPError("unsupported compression: " & $info.compression)

  if (bmp.compression == BC_BITFIELDS) and bmp.bitsPerPixel notin {16, 32}:
    raise BMPError("Bitfields Compression only for 16, 32 bits")

  if bmp.compression == BC_RLE8 and bmp.bitsPerPixel != 8:
    if bmp.bitsPerPixel == 4: bmp.compression = BC_RLE4 #try with this
    else: bmp.compression = BC_NONE
    #raise BMPError("RLE8 Compression only for 8 bits")

  if bmp.compression == BC_RLE4 and bmp.bitsPerPixel != 4:
    if bmp.bitsPerPixel == 8: bmp.compression = BC_RLE8 #try with this
    else: bmp.compression = BC_NONE
    #raise BMPError("RLE4 Compression only for 4 bits")

  #read palette
  if bmp.bitsPerPixel < 16:
    #54 = sizeof BMPInfo + sizeof BMPHeader + signature
    let paletteSize = min(int((header.offset - 54) div 4), 2.pow(bmp.bitsPerPixel))
    let numColors = bmp.numColors() #max paletteSize
    bmp.palette = newSeq[BMPRGBA](numColors)
    bmp.createStandardPalette()

    for n in 0.. <paletteSize:
      if s.readData(addr(bmp.palette[n]), 4) != 4:
        raise BMPError("error when reading palette")

    let BLACK = BMPRGBA(r: 0, g: 0, b: 0, a: 0)
    for n in paletteSize.. <numColors: bmp.palette[n] = BLACK

  var bytesToSkip = int(header.offset - 54)
  if bmp.bitsPerPixel < 16: bytesToSkip -= 4 * 2.pow(bmp.bitsPerPixel)
  if bmp.bitsPerPixel in {16, 32} and bmp.compression == BC_BITFIELDS: bytesToSkip -= 3 * 4
  if bytesToSkip < 0: bytesToSkip = 0
  if bytesToSkip > 0 and bmp.compression != BC_BITFIELDS: s.skip(bytesToSkip)

  if bmp.width < 0: bmp.width = -1 * bmp.width #another bad value
  bmp.pixels = newSeq[BMPRGBA](bmp.width * bmp.height)
  if bmp.bitsPerPixel == 16: bmp.readPixels16(s, bytesToSkip)
  else:
    if bmp.compression == BC_BITFIELDS: bmp.readPixels32(s, bytesToSkip)
    elif bmp.compression == BC_RLE4: bmp.readPixelsRLE4(s)
    elif bmp.compression == BC_RLE8: bmp.readPixelsRLE8(s)
    else: bmp.readPixels(s)

  s.close()
  result = bmp

proc loadBMP*(fileName: string): BMP =
  try:
    var s = newFileStream(fileName, fmRead)
    if s == nil: return nil
    result = s.decodeBMP()
    s.close()
  except:
    debugEcho getCurrentExceptionMsg()
    result = nil

proc convertTo32Bit*(bmp: BMP): BMPResult =
  new(result)
  result.data  = newString(bmp.width * bmp.height * 4)
  result.width = bmp.width
  result.height = bmp.height
  let numPixels = bmp.width * bmp.height
  for i in 0.. <numPixels:
    result.data[i * 4 + 0] = chr(bmp.pixels[i].r)
    result.data[i * 4 + 1] = chr(bmp.pixels[i].g)
    result.data[i * 4 + 2] = chr(bmp.pixels[i].b)
    result.data[i * 4 + 3] = chr(bmp.pixels[i].a)

proc convertTo24Bit*(bmp: BMP): BMPResult =
  new(result)
  result.data  = newString(bmp.width * bmp.height * 3)
  result.width = bmp.width
  result.height = bmp.height
  let numPixels = bmp.width * bmp.height
  for i in 0.. <numPixels:
    result.data[i * 3 + 0] = chr(bmp.pixels[i].r)
    result.data[i * 3 + 1] = chr(bmp.pixels[i].g)
    result.data[i * 3 + 2] = chr(bmp.pixels[i].b)
    
proc convert*(bmp: BMP, bitsPerPixel: int): BMPResult =
  assert bitsPerPixel in {24, 32}
  if bitsPerPixel == 24: result = bmp.convertTo24Bit()
  else: result = bmp.convertTo32Bit()
  
proc loadBMP32*(fileName: string): BMPResult =
  var bmp = loadBMP(fileName)
  if bmp != nil: result = bmp.convert(32)
    
proc loadBMP24*(fileName: string): BMPResult =
  var bmp = loadBMP(fileName)
  if bmp != nil: result = bmp.convert(24)

type
  BMPEncoder = object
    bitsPerPixel: int
    colors: OrderedTable[BMPRGBA, int]
    pixels: string
    cvt: proc(p: var BMPRGBA, input: string, px: int)

proc hash*(c: BMPRGBA): THash =
  var h: THash = 0
  h = h !& ord(c.r)
  h = h !& ord(c.g)
  h = h !& ord(c.b)
  h = h !& ord(c.a)

proc pixelFromRGB24(p: var BMPRGBA, input: string, px: int) =
  let y = px * 3
  p.r = input[y].ord
  p.g = input[y + 1].ord
  p.b = input[y + 2].ord

proc pixelFromRGB32(p: var BMPRGBA, input: string, px: int) =
  let y = px * 4
  p.r = input[y].ord
  p.g = input[y + 1].ord
  p.b = input[y + 2].ord
  p.a = input[y + 3].ord

proc countColors(input: string, w, h, bitsPerPixel: int, colors: var OrderedTable[BMPRGBA, int]): int =
  let numPixels = w * h
  assert bitsPerPixel in {24, 32}

  var
    p: BMPRGBA
    cvt = if bitsPerPixel == 32: pixelFromRGB32 else: pixelFromRGB24
    numColors = 0

  for px in 0.. <numPixels:
    cvt(p, input, px)
    if not colors.hasKey(p):
      if numColors < 256: 
        colors[p] = numColors
      inc numColors
    if numColors >= 257: break

  result = numColors

proc encode1Bit(bmp: var BMPEncoder, input: string, w, h: int) =
  let scanlineSize = 4 * ((w * bmp.bitsPerPixel + 31) div 32)
  let size = scanlineSize * h
  bmp.pixels = newString(size)

  var
    px = 0
    p: BMPRGBA

  for row in countdown(h - 1, 0):
    var x = 0
    var y = row * scanLineSize
    while x < w:
      var z = 0
      var t = 0
      while z < 8 and x < w:
        bmp.cvt(p, input, px)
        t = t or ((bmp.colors[p] and 0x01) shl (7 - z))
        inc px
        inc z
        inc x
      bmp.pixels[y] = t.chr
      inc y

proc encode4Bit(bmp: var BMPEncoder, input: string, w, h: int) =
  let scanlineSize = 4 * ((w * bmp.bitsPerPixel + 31) div 32)
  let size = scanlineSize * h
  bmp.pixels = newString(size)

  var
    px = 0
    p: BMPRGBA

  for row in countdown(h - 1, 0):
    let start = row * scanLineSize
    for x in 0.. <w:
      let y = start + (x div 2)
      bmp.cvt(p, input, px)
      inc px
      if (x mod 2) == 0:
        bmp.pixels[y] = chr((bmp.colors[p] and 0x0F) shl 4)
      else:
        bmp.pixels[y] = chr(bmp.pixels[y].ord or (bmp.colors[p] and 0x0F))

proc encode8Bit(bmp: var BMPEncoder, input: string, w, h: int) =
  let scanlineSize = 4 * ((w * bmp.bitsPerPixel + 31) div 32)
  let size = scanlineSize * h
  bmp.pixels = newString(size)

  var
    px = 0
    p: BMPRGBA

  for row in countdown(h - 1, 0):
    var y = row * scanLineSize
    for x in 0.. <w:
      bmp.cvt(p, input, px)
      bmp.pixels[row * scanLineSize + x] = bmp.colors[p].chr
      inc y
      inc px

proc encode24Bit(bmp: var BMPEncoder, input: string, w, h: int) =
  let scanlineSize = 4 * ((w * bmp.bitsPerPixel + 31) div 32)
  let size = scanlineSize * h
  bmp.pixels = newString(size)

  var
    px = 0
    p: BMPRGBA

  for row in countdown(h - 1, 0):
    let start = row * scanLineSize
    for x in 0.. <w:
      let y = start + x * 3
      bmp.cvt(p, input, px)
      bmp.pixels[y]     = chr(p.b)
      bmp.pixels[y + 1] = chr(p.g)
      bmp.pixels[y + 2] = chr(p.r)
      inc px

proc autoChooseColor(input: string, w, h, bitsPerPixel: int): BMPEncoder =
  var
    colors = initOrderedTable[BMPRGBA, int]()
    numColors = countColors(input, w, h, bitsPerPixel, colors)

  result.cvt = if bitsPerPixel == 32: pixelFromRGB32 else: pixelFromRGB24
  result.colors = colors

  if numColors <= 2:
    result.bitsPerPixel = 1
    result.encode1Bit(input, w, h)
  elif numColors <= 16:
    result.bitsPerPixel = 4
    result.encode4Bit(input, w, h)
  elif numColors <= 256:
    result.bitsPerPixel = 8
    result.encode8Bit(input, w, h)
  else:
    result.bitsPerPixel = 24
    result.encode24Bit(input, w, h)

proc writeLE[T: WORD|DWORD|LONG](s: Stream, val: T) =
  var 
    value: T
    tmp = val
  
  when T is WORD: littleEndian16(addr(value), addr(tmp))
  else: littleEndian32(addr(value), addr(tmp))
  s.writeData(addr(value), sizeof(T))  

proc writeLE[T: BMPHeader|BMPInfo](s: Stream, val: T) =
  for field in fields(val): s.writeLE(field)

proc writeWORD(s: Stream, val: int) =
  let tmp = val.WORD
  s.writeLE(tmp)
  
proc writeDWORD(s: Stream, val: int) =
  let tmp = val.DWORD
  s.writeLE(tmp)

proc encodeBMP*(s: Stream, input: string, w, h, bitsPerPixel: int) =
  let bmp = autoChooseColor(input, w, h, bitsPerPixel)
  let scanlineSize = 4 * ((w * bmp.bitsPerPixel + 31) div 32)
  let rowSize = (w * bmp.bitsPerPixel + 7) div 8
  let paddingSize = scanlineSize - rowSize
  let dataSize = scanlineSize * h
  let offset = 54 + bmp.colors.len * 4
 
  var header: BMPHeader
  header.fileSize  = DWORD(offset + dataSize)
  header.reserved1 = 0.WORD
  header.reserved2 = 0.WORD
  header.offset    = offset.DWORD

  var info: BMPInfo
  info.size   = 40
  info.width  = w.LONG
  info.height = h.LONG
  info.planes = 1
  info.bitsPerPixel = WORD(bmp.bitsPerPixel)
  info.compression  = BC_NONE.DWORD
  info.imageSize    = dataSize.DWORD
  info.horzResolution = DefaultXPelsPerMeter
  info.vertResolution = DefaultYPelsPerMeter
  info.colorUsed = DWORD(bmp.colors.len)
  info.colorImportant = 0
  
  s.write BMPSignature
  s.writeLE header
  s.writeLE info
  
  for k in keys(bmp.colors):
    var tmp = k
    s.writeData(addr(tmp), 4)
  
  s.write bmp.pixels
  
proc saveBMP32*(fileName, input: string, w, h: int) =
  var s = newFileStream(fileName, fmWrite)
  s.encodeBMP(input, w, h, 32)
  s.close()
  
proc saveBMP24*(fileName, input: string, w, h: int) =
  var s = newFileStream(fileName, fmWrite)
  s.encodeBMP(input, w, h, 24)
  s.close()