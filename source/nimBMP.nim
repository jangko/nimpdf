import streams, endians, unsigned
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
    planes, bitDepth: WORD
    compression, imageSize: DWORD
    horzResolution, vertResolution: LONG
    colorUsed, colorImportant: DWORD

  BMPRGBA* {.pure, final.} = object
    b*,g*,r*,a*: BYTE  #the order must be b,g,r,a!

  BMP* = ref object
    pixels*: seq[BMPRGBA]
    palette: seq[BMPRGBA]
    inverted: bool
    compression: BMPCompression
    bitDepth: int
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
  if bmp.bitDepth == 32: result = 2.pow(24)
  else: result = 2.pow(bmp.bitDepth)

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
  assert bmp.bitDepth in {1, 4, 8}

  if bmp.bitDepth == 1:
    for i in 0..1:
      bmp.palette[i].r = BYTE(i*255)
      bmp.palette[i].g = BYTE(i*255)
      bmp.palette[i].b = BYTE(i*255)
      bmp.palette[i].a = 0
    return

  if bmp.bitDepth == 4:
    var i = bmp.fillPalette(palMaker[0], 0)
    discard bmp.fillPalette(palMaker[1], i)

    i = 8
    bmp.palette[i].r = 192
    bmp.palette[i].g = 192
    bmp.palette[i].b = 192
    return

  if bmp.bitDepth == 8:
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
    var index = (input[k].ord and 0xF0) shr 4
    bmp.pixels[row * bmp.width + i] = bmp.palette[index]
    inc i
    if i < bmp.width: #odd width
      index = input[k].ord and 0x0F
      bmp.pixels[row * bmp.width + i] = bmp.palette[index]
      inc i
    inc k

proc read1bitRow(bmp: BMP, input: string, row: int) =
  const
    shifts = [  7, 6, 5, 4,3,2,1,0]
    masks  = [128,64,32,16,8,4,2,1]

  var
    i = 0
    j = 0
    k = 0

  while i < bmp.width:
    j = 0
    while j < 8 and i < bmp.width:
      let index = (input[k].ord and masks[j]) shr shifts[j]
      bmp.pixels[bmp.width * row + i] = bmp.palette[index]
      i += 1
      j += 1
    k += 1

proc getScanlineReader(bmp: BMP): scanlineReader =
  case bmp.bitDepth
  of 1:  result = read1bitRow
  of 4:  result = read4bitRow
  of 8:  result = read8bitRow
  of 24: result = read24bitRow
  of 32: result = read32bitRow
  else: raise BMPError("unavailable scanline reader")

proc readPixels(bmp: BMP, s: Stream) =
  let scanlineSize = 4 * ((bmp.width * bmp.bitDepth + 31) div 32)
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

proc parseBMP*(s: Stream): BMP =
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

  bmp.bitDepth = int(info.bitDepth)
  if bmp.bitDepth notin {1, 4, 8, 16, 24, 32}:
    raise BMPError("unsupported bitDepth: " & $bmp.bitDepth)

  if info.compression > 3.DWORD: info.compression = 0.DWORD #really bad compression
  bmp.compression = BMPCompression(info.compression)
  if bmp.compression notin {BC_NONE, BC_RLE4, BC_RLE8, BC_BITFIELDS}:
    raise BMPError("unsupported compression: " & $info.compression)

  if (bmp.compression == BC_BITFIELDS) and bmp.bitDepth notin {16, 32}:
    raise BMPError("Bitfields Compression only for 16, 32 bits")

  if bmp.compression == BC_RLE8 and bmp.bitDepth != 8:
    if bmp.bitDepth == 4: bmp.compression = BC_RLE4 #try with this
    else: bmp.compression = BC_NONE
    #raise BMPError("RLE8 Compression only for 8 bits")

  if bmp.compression == BC_RLE4 and bmp.bitDepth != 4:
    if bmp.bitDepth == 8: bmp.compression = BC_RLE8 #try with this
    else: bmp.compression = BC_NONE
    #raise BMPError("RLE4 Compression only for 4 bits")

  #read palette
  if bmp.bitDepth < 16:
    #54 = sizeof BMPInfo + sizeof BMPHeader + signature
    let paletteSize = min(int((header.offset - 54) div 4), 2.pow(bmp.bitDepth))
    let numColors = bmp.numColors() #max paletteSize
    bmp.palette = newSeq[BMPRGBA](numColors)
    bmp.createStandardPalette()

    for n in 0.. <paletteSize:
      if s.readData(addr(bmp.palette[n]), 4) != 4:
        raise BMPError("error when reading palette")

    let BLACK = BMPRGBA(r: 0, g: 0, b: 0, a: 0)
    for n in paletteSize.. <numColors: bmp.palette[n] = BLACK

  var bytesToSkip = int(header.offset - 54)
  if bmp.bitDepth < 16: bytesToSkip -= 4 * 2.pow(bmp.bitDepth)
  if bmp.bitDepth in {16, 32} and bmp.compression == BC_BITFIELDS: bytesToSkip -= 3 * 4
  if bytesToSkip < 0: bytesToSkip = 0
  if bytesToSkip > 0 and bmp.compression != BC_BITFIELDS: s.skip(bytesToSkip)

  if bmp.width < 0: bmp.width = -1 * bmp.width #another bad value
  bmp.pixels = newSeq[BMPRGBA](bmp.width * bmp.height)
  if bmp.bitDepth == 16: bmp.readPixels16(s, bytesToSkip)
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
    result = s.parseBMP()
    s.close()
  except:
    debugEcho getCurrentExceptionMsg()
    result = nil

proc loadBMP32*(fileName: string): BMPResult =
  var bmp = loadBMP(fileName)
  if bmp != nil:
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

proc loadBMP24*(fileName: string): BMPResult =
  var bmp = loadBMP(fileName)
  if bmp != nil:
    new(result)
    result.data  = newString(bmp.width * bmp.height * 3)
    result.width = bmp.width
    result.height = bmp.height
    let numPixels = bmp.width * bmp.height
    for i in 0.. <numPixels:
      result.data[i * 3 + 0] = chr(bmp.pixels[i].r)
      result.data[i * 3 + 1] = chr(bmp.pixels[i].g)
      result.data[i * 3 + 2] = chr(bmp.pixels[i].b)
