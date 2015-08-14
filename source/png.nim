import unsigned, streams, endians, tables, hashes, nimz

type
  PNGChunkType = distinct int32

  PNGColorType* = enum
    LCT_GREY = 0,       # greyscale: 1,2,4,8,16 bit
    LCT_RGB = 2,        # RGB: 8,16 bit
    LCT_PALETTE = 3,    # palette: 1,2,4,8 bit
    LCT_GREY_ALPHA = 4, # greyscale with alpha: 8,16 bit
    LCT_RGBA = 6        # RGB with alpha: 8,16 bit

  PNGFilter0 = enum
    FLT_NONE,
    FLT_SUB,
    FLT_UP,
    FLT_AVERAGE,
    FLT_PAETH

  PNGInterlace = enum
    IM_NONE = 0, IM_INTERLACED = 1

  PNGChunk = ref object of RootObj
    length: range[1..0x7FFFFFFF]
    chunkType: PNGChunkType
    crc: uint32
    data: string
    pos: int

  PNGHeader = ref object of PNGChunk
    width, height: range[1..0x7FFFFFFF]
    bitDepth: int
    colorType: PNGColorType
    compressionMethod: int
    filterMethod: int
    interlaceMethod: PNGInterlace

  RGBA8 = object
    r, g, b, a: char

  RGBA16 = object
    r, g, b, a: uint16

  ColorTree8 = Table[RGBA8, int]

  PNGPalette = ref object of PNGChunk
    palette: seq[RGBA8]

  PNGData = ref object of PNGChunk
    idat: string

  PNGTime = ref object of PNGChunk
    year: range[0..65535]
    month: range[1..12]
    day: range[1..31]
    hour: range[0..23]
    minute: range[0..59]
    second: range[0..60] #to allow for leap seconds

  PNGPhys = ref object of PNGChunk
    physX, physY: int
    unit: int

  PNGTrans = ref object of PNGChunk
    keyR, keyG, keyB: int

  PNGBackground = ref object of PNGChunk
    bkgdR, bkgdG, bkgdB: int

  PNGText = ref object of PNGChunk
    keyword: string
    text: string

  PNGZtxt = ref object of PNGChunk
    keyword: string
    text: string

  PNGItxt = ref object of PNGChunk
    keyword: string
    text: string
    languageTag: string
    translatedKeyword: string

  PNGGamma = ref object of PNGChunk
    gamma: int

  PNGChroma = ref object of PNGChunk
    whitePointX, whitePointY: int
    redX, redY: int
    greenX, greenY: int
    blueX, blueY: int

  PNGStandarRGB = ref object of PNGChunk
    renderingIntent: int

  PNGICCProfile = ref object of PNGChunk
    profileName: string
    profile: string

  PNGSPEntry = object
    red, green, blue, alpha, frequency: int

  PNGSPalette = ref object of PNGChunk
    paletteName: string
    sampleDepth: int
    palette: seq[PNGSPEntry]

  PNGHist = ref object of PNGChunk
    histogram: seq[int]

  PNGSbit = ref object of PNGChunk

  PNGPass = object
    w, h: array[0..6, int]
    filterStart, paddedStart, start: array[0..7, int]

  PNGColorMode = ref object
    colorType: PNGColorType
    bitDepth: int
    paletteSize: int
    palette: seq[RGBA8]
    keyDefined: bool
    keyR, keyG, keyB: int

  PNG = ref object
    chunks: seq[PNGChunk]
    pixels: string

  PNGResult* = ref object
    width*: int
    height*: int
    data*: string
    
proc signatureMaker(): string {. compiletime .} =
  const signatureBytes = [137, 80, 78, 71, 13, 10, 26, 10]
  result = ""
  for c in signatureBytes: result.add chr(c)

proc makeChunkType(val: string): PNGChunkType {. compiletime .} =
  assert (val.len == 4)
  result = PNGChunkType((ord(val[0]) shl 24) or (ord(val[1]) shl 16) or (ord(val[2]) shl 8) or ord(val[3]))

proc `$`*(tag: PNGChunkType): string =
  result = newString(4)
  let t = int(tag)
  result[0] = chr(toU32(t shr 24) and 0xFF)
  result[1] = chr(toU32(t shr 16) and 0xFF)
  result[2] = chr(toU32(t shr 8) and 0xFF)
  result[3] = chr(toU32(t) and 0xFF)

proc `==`(a, b: PNGChunkType): bool = int(a) == int(b)
proc isAncillary(a: PNGChunkType): bool = (int(a) and (32 shl 24)) != 0
proc isPrivate(a: PNGChunkType): bool = (int(a) and (32 shl 16)) != 0
proc isSafeToCopy(a: PNGChunkType): bool = (int(a) and 32) != 0

proc crc32(crc: uint32, buf: string): uint32 =
  const kcrc32 = [ 0'u32, 0x1db71064, 0x3b6e20c8, 0x26d930ac, 0x76dc4190,
    0x6b6b51f4, 0x4db26158, 0x5005713c, 0xedb88320'u32, 0xf00f9344'u32, 0xd6d6a3e8'u32,
    0xcb61b38c'u32, 0x9b64c2b0'u32, 0x86d3d2d4'u32, 0xa00ae278'u32, 0xbdbdf21c'u32]

  var crcu32 = not crc
  for b in buf:
    crcu32 = (crcu32 shr 4) xor kcrc32[(crcu32 and 0xF) xor (ord(b) and 0xF)]
    crcu32 = (crcu32 shr 4) xor kcrc32[(crcu32 and 0xF) xor (ord(b) shr 4)]

  result = not crcu32

const
  PNGSignature = signatureMaker()
  IHDR = makeChunkType("IHDR")
  IEND = makeChunkType("IEND")
  PLTE = makeChunkType("PLTE")
  IDAT = makeChunkType("IDAT")
  tRNS = makeChunkType("tRNS")
  bKGD = makeChunkType("bKGD")
  pHYs = makeChunkType("pHYs")
  tIME = makeChunkType("tIME")
  iTXt = makeChunkType("iTXt")
  zTXt = makeChunkType("zTXt")
  tEXt = makeChunkType("tEXt")
  gAMA = makeChunkType("gAMA")
  cHRM = makeChunkType("cHRM")
  sRGB = makeChunkType("sRGB")
  iCCP = makeChunkType("iCCP")
  sBIT = makeChunkType("sBIT")
  sPLT = makeChunkType("sPLT")
  hIST = makeChunkType("hIST")

  # shared values used by multiple Adam7 related functions
  ADAM7_IX = [ 0, 4, 0, 2, 0, 1, 0 ] # x start values
  ADAM7_IY = [ 0, 0, 4, 0, 2, 0, 1 ] # y start values
  ADAM7_DX = [ 8, 8, 4, 4, 2, 2, 1 ] # x delta values
  ADAM7_DY = [ 8, 8, 8, 4, 4, 2, 2 ] # y delta values

proc PNGError(msg: string): ref Exception =
  new(result)
  result.msg = msg

proc newColorMode(): PNGColorMode =
  new(result)
  result.keyDefined = false
  result.keyR = 0
  result.keyG = 0
  result.keyB = 0
  result.colorType = LCT_RGBA
  result.bitDepth = 8
  result.paletteSize = 0

proc copyTo(src, dest: PNGColorMode) =
  if src.palette != nil:
    newSeq(dest.palette, src.paletteSize)
    for i in 0..src.palette.len-1: dest.palette[i] = src.palette[i]

proc `==`(a, b: PNGColorMode): bool =
  if a.colorType != b.colorType: return false
  if a.bitDepth != b.bitDepth: return false
  if a.keyDefined != b.keyDefined: return false
  if a.keyDefined:
    if a.keyR != b.keyR: return false
    if a.keyG != b.keyG: return false
    if a.keyB != b.keyB: return false
  if a.paletteSize != b.paletteSize: return false
  for i in 0..a.palette.len-1:
    if a.palette[i] != b.palette[i]: return false
  result = true

proc readInt32(s: PNGChunk): int =
  if s.pos + 4 > s.data.len: raise PNGError("index out of bound 4")
  result = ord(s.data[s.pos]) shl 8
  result = (result + ord(s.data[s.pos + 1])) shl 8
  result = (result + ord(s.data[s.pos + 2])) shl 8
  result = result + ord(s.data[s.pos + 3])
  inc(s.pos, 4)

proc readInt16(s: PNGChunk): int =
  if s.pos + 2 > s.data.len: raise PNGError("index out of bound 2")
  result = ord(s.data[s.pos]) shl 8
  result = result + ord(s.data[s.pos + 1])
  inc(s.pos, 2)

proc readInt32BE(s: Stream): int =
  var val = s.readInt32()
  bigEndian32(addr(result), addr(val))

proc readByte(s: PNGChunk): int =
  if s.pos + 1 > s.data.len: raise PNGError("index out of bound 1")
  result = ord(s.data[s.pos])
  inc s.pos

proc setPosition(s: PNGChunk, pos: int) =
  if pos < 0 or pos > s.data.len: raise PNGError("set position error")
  s.pos = pos

proc hasChunk(png: PNG, chunkType: PNGChunkType): bool =
  for c in png.chunks:
    if c.chunkType == chunkType: return true
  result = false

proc getChunk(png: PNG, chunkType: PNGChunkType): PNGChunk =
  for c in png.chunks:
    if c.chunkType == chunkType: return c

proc bitDepthAllowed(colorType: PNGColorType, bitDepth: int): bool =
  case colorType
  of LCT_GREY   : result = bitDepth in {1, 2, 4, 8, 16}
  of LCT_PALETTE: result = bitDepth in {1, 2, 4, 8}
  else: result = bitDepth in {8, 16}

method validateChunk(chunk: PNGChunk, png: PNG): bool = true
method parseChunk(chunk: PNGChunk, png: PNG): bool = true

method validateChunk(header: PNGHeader, png: PNG): bool =
  if header.width < 1 or header.width > 0x7FFFFFFF:
    raise PNGError("image width not allowed: " & $header.width)
  if header.height < 1 or header.height > 0x7FFFFFFF:
    raise PNGError("image width not allowed: " & $header.height)
  if header.colorType notin {LCT_GREY, LCT_RGB, LCT_PALETTE, LCT_GREY_ALPHA, LCT_RGBA}:
    raise PNGError("color type not allowed: " & $int(header.colorType))
  if not bitDepthAllowed(header.colorType, header.bitDepth):
    raise PNGError("bit depth not allowed: " & $header.bitDepth)
  if header.compressionMethod != 0:
    raise PNGError("unsupported compression method")
  if header.filterMethod != 0:
    raise PNGError("unsupported filter method")
  if header.interlaceMethod notin {IM_NONE, IM_INTERLACED}:
    raise PNGError("unsupported interlace method")
  result = true

method parseChunk(chunk: PNGHeader, png: PNG): bool =
  if chunk.length != 13: return false
  chunk.width = chunk.readInt32()
  chunk.height = chunk.readInt32()
  chunk.bitDepth = chunk.readByte()
  chunk.colorType = PNGColorType(chunk.readByte())
  chunk.compressionMethod = chunk.readByte()
  chunk.filterMethod = chunk.readByte()
  chunk.interlaceMethod = PNGInterlace(chunk.readByte())
  result = true

method parseChunk(chunk: PNGPalette, png: PNG): bool =
  let paletteSize = chunk.length div 3
  if paletteSize > 256: raise PNGError("palette size to big")
  newSeq(chunk.palette, paletteSize)
  for px in mitems(chunk.palette):
    px.r = chr(chunk.readByte())
    px.g = chr(chunk.readByte())
    px.b = chr(chunk.readByte())
    px.a = chr(255)
  result = true

proc numChannels(colorType: PNGColorType): int =
  case colorType
  of LCT_GREY: result = 1
  of LCT_RGB : result = 3
  of LCT_PALETTE: result = 1
  of LCT_GREY_ALPHA: result = 2
  of LCT_RGBA: result = 4

proc LCTBPP(colorType: PNGColorType, bitDepth: int): int =
  # bits per pixel is amount of channels * bits per channel
  result = numChannels(colorType) * bitDepth

proc getBPP(header: PNGHeader): int =
  # calculate bits per pixel out of colortype and bitDepth
  result = LCTBPP(header.colorType, header.bitDepth)

proc getBPP(color: PNGColorMode): int =
  # calculate bits per pixel out of colortype and bitDepth
  result = LCTBPP(color.colorType, color.bitDepth)

proc idatRawSize(w, h: int, header: PNGHeader): int =
  result = h * ((w * getBPP(header) + 7) div 8)

proc getRawSize(w, h: int, color: PNGColorMode): int =
  result = (w * h * getBPP(color) + 7) div 8

proc getRawSizeLct(w, h: int, colorType: PNGColorType, bitDepth: int): int =
  result = (w * h * LCTBPP(colorType, bitDepth) + 7) div 8

method validateChunk(chunk: PNGData, png: PNG): bool =
  var header = PNGHeader(png.getChunk(IHDR))

  var predict = 0
  if header.interlaceMethod == IM_NONE:
    # The extra header.height is added because this are the filter bytes every scanLine starts with
    predict = idatRawSize(header.width, header.height, header) + header.height
  else:
    # Adam-7 interlaced: predicted size is the sum of the 7 sub-images sizes
    let w = header.width
    let h = header.height
    predict += idatRawSize((w + 7) div 8, (h + 7) div 8, header) + (h + 7) div 8
    if w > 4: predict += idatRawSize((w + 3) div 8, (h + 7) div 8, header) + (h + 7) div 8
    predict += idatRawSize((w + 3) div 4, (h + 3) div 8, header) + (h + 3) div 8
    if w > 2: predict += idatRawSize((w + 1) div 4, (h + 3) div 4, header) + (h + 3) div 4
    predict += idatRawSize((w + 1) div 2, (h + 1) div 4, header) + (h + 1) div 4
    if w > 1: predict += idatRawSize((w + 0) div 2, (h + 1) div 2, header) + (h + 1) div 2
    predict += idatRawSize((w + 0) div 1, (h + 0) div 2, header) + (h + 0) div 2

  if chunk.idat.len != predict: raise PNGError("Decompress size doesn't match predict")
  result = true

method parseChunk(chunk: PNGData, png: PNG): bool =
  var nz = nzInflateInit(chunk.data)
  chunk.idat = zlib_decompress(nz)
  result = true

method parseChunk(chunk: PNGTrans, png: PNG): bool =
  var header = PNGHeader(png.getChunk(IHDR))

  if header.colorType == LCT_PALETTE:
    var plte = PNGPalette(png.getChunk(PLTE))
    # error: more alpha values given than there are palette entries
    if chunk.length > plte.palette.len:
      raise PNGError("more alpha value than palette entries")
    #can contain fewer values than palette entries
    for i in 0..chunk.length-1: plte.palette[i].a = chr(chunk.readByte())
  elif header.colorType == LCT_GREY:
    # error: this chunk must be 2 bytes for greyscale image
    if chunk.length != 2: raise PNGError("tRNS must be 2 bytes")
    chunk.keyR = chunk.readInt16()
    chunk.keyG = chunk.keyR
    chunk.keyB = chunk.keyR
  elif header.colorType == LCT_RGB:
    # error: this chunk must be 6 bytes for RGB image
    if chunk.length != 6: raise PNGError("tRNS must be 6 bytes")
    chunk.keyR = chunk.readInt16()
    chunk.keyG = chunk.readInt16()
    chunk.keyB = chunk.readInt16()
  else:
    raise PNGError("tRNS chunk not allowed for other color models")

  result = true

method parseChunk(chunk: PNGBackground, png: PNG): bool =
  var header = PNGHeader(png.getChunk(IHDR))
  if header.colorType == LCT_PALETTE:
    # error: this chunk must be 1 byte for indexed color image
    if chunk.length != 1: raise PNGError("bkgd must be 1 byte")
    chunk.bkgdR = chunk.readByte()
    chunk.bkgdG = chunk.bkgdR
    chunk.bkgdB = chunk.bkgdR
  elif header.colorType in {LCT_GREY, LCT_GREY_ALPHA}:
    # error: this chunk must be 2 bytes for greyscale image
    if chunk.length != 2: raise PNGError("bkgd must be 2 byte")
    chunk.bkgdR = chunk.readInt16()
    chunk.bkgdG = chunk.bkgdR
    chunk.bkgdB = chunk.bkgdR
  elif header.colorType in {LCT_RGB, LCT_RGBA}:
    # error: this chunk must be 6 bytes for greyscale image
    if chunk.length != 6: raise PNGError("bkgd must be 6 byte")
    chunk.bkgdR = chunk.readInt16()
    chunk.bkgdG = chunk.readInt16()
    chunk.bkgdB = chunk.readInt16()
  result = true

proc initChunk(chunk: PNGChunk, chunkType: PNGChunkType, data: string, crc: uint32) =
  chunk.length = data.len
  chunk.crc = crc
  chunk.chunkType = chunkType
  chunk.data = data
  chunk.pos = 0

method parseChunk(chunk: PNGTime, png: PNG): bool =
  if chunk.length != 7: raise PNGError("tIME must be 7 bytes")
  chunk.year   = chunk.readInt16()
  chunk.month  = chunk.readByte()
  chunk.day    = chunk.readByte()
  chunk.hour   = chunk.readByte()
  chunk.minute = chunk.readByte()
  chunk.second = chunk.readByte()
  result = true

method parseChunk(chunk: PNGPhys, png: PNG): bool =
  if chunk.length != 9: raise PNGError("pHYs must be 9 bytes")
  chunk.physX = chunk.readInt32()
  chunk.physY = chunk.readInt32()
  chunk.physX = chunk.readByte()
  result = true

method parseChunk(chunk: PNGText, png: PNG): bool =
  var len = 0
  while(len < chunk.length) and (chunk.data[len] != chr(0)): inc len
  if(len < 1) or (len > 79): raise PNGError("keyword too short or too long")
  chunk.keyword = chunk.data.substr(0, len)

  var textBegin = len + 1 # skip keyword null terminator
  chunk.text = chunk.data.substr(textBegin)
  result = true

method parseChunk(chunk: PNGZtxt, png: PNG): bool =
  var len = 0
  while(len < chunk.length) and (chunk.data[len] != chr(0)): inc len
  if(len < 1) or (len > 79): raise PNGError("keyword too short or too long")
  chunk.keyword = chunk.data.substr(0, len)

  var compMethod = ord(chunk.data[len + 1]) # skip keyword null terminator
  if compMethod != 0: raise PNGError("unsupported comp method")

  var nz = nzInflateInit(chunk.data.substr(len + 2))
  chunk.text = zlib_decompress(nz)

  result = true

method parseChunk(chunk: PNGItxt, png: PNG): bool =
  if chunk.length < 5: raise PNGError("iTXt len too short")

  var len = 0
  while(len < chunk.length) and (chunk.data[len] != chr(0)): inc len

  if(len + 3) >= chunk.length: raise PNGError("no null termination char, corrupt?")
  if(len < 1) or (len > 79): raise PNGError("keyword too short or too long")
  chunk.keyword = chunk.data.substr(0, len)

  var compressed = ord(chunk.data[len + 1]) == 1 # skip keyword null terminator
  var compMethod = ord(chunk.data[len + 2])
  if compMethod != 0: raise PNGError("unsupported comp method")

  len = 0
  var i = len + 3
  while(i < chunk.length) and (chunk.data[i] != chr(0)):
    inc len
    inc i

  chunk.languageTag = chunk.data.substr(i, i + len)

  len = 0
  i += len + 1
  while(i < chunk.length) and (chunk.data[i] != chr(0)):
    inc len
    inc i

  chunk.translatedKeyword = chunk.data.substr(i, i + len)

  let textBegin = i + len + 1
  if compressed:
    var nz = nzInflateInit(chunk.data.substr(textBegin))
    chunk.text = zlib_decompress(nz)
  else:
    chunk.text = chunk.data.substr(textBegin)
  result = true

method parseChunk(chunk: PNGGamma, png: PNG): bool =
  if chunk.length != 4: raise PNGError("invalid gAMA length")
  chunk.gamma = chunk.readInt32()
  result = true

method parseChunk(chunk: PNGChroma, png: PNG): bool =
  if chunk.length != 32: raise PNGError("invalid Chroma length")
  chunk.whitePointX = chunk.readInt32()
  chunk.whitePointY = chunk.readInt32()
  chunk.redX = chunk.readInt32()
  chunk.redY = chunk.readInt32()
  chunk.greenX = chunk.readInt32()
  chunk.greenY = chunk.readInt32()
  chunk.blueX = chunk.readInt32()
  chunk.blueY = chunk.readInt32()
  result = true

method parseChunk(chunk: PNGStandarRGB, png: PNG): bool =
  if chunk.length != 1: raise PNGError("invalid sRGB length")
  chunk.renderingIntent = chunk.readByte()
  result = true

method parseChunk(chunk: PNGICCProfile, png: PNG): bool =
  var len = 0
  while(len < chunk.length) and (chunk.data[len] != chr(0)): inc len
  if(len < 1) or (len > 79): raise PNGError("keyword too short or too long")
  chunk.profileName = chunk.data.substr(0, len)

  var compMethod = ord(chunk.data[len + 1]) # skip keyword null terminator
  if compMethod != 0: raise PNGError("unsupported comp method")

  var nz = nzInflateInit(chunk.data.substr(len + 2))
  chunk.profile = zlib_decompress(nz)
  result = true

method parseChunk(chunk: PNGSPalette, png: PNG): bool =
  var len = 0
  while(len < chunk.length) and (chunk.data[len] != chr(0)): inc len
  if(len < 1) or (len > 79): raise PNGError("keyword too short or too long")
  chunk.paletteName = chunk.data.substr(0, len)
  chunk.setPosition(len + 1)
  chunk.sampleDepth = chunk.readByte()
  if chunk.sampleDepth notin {8, 16}: raise PNGError("palette sample depth error")

  let remainingLength = (chunk.length - (len + 2))
  if chunk.sampleDepth == 8:
    if (remainingLength mod 6) != 0: raise PNGError("palette length not divisible by 6")
    let numSamples = remainingLength div 6
    newSeq(chunk.palette, numSamples)
    for p in mitems(chunk.palette):
      p.red   = chunk.readByte()
      p.green = chunk.readByte()
      p.blue  = chunk.readByte()
      p.alpha = chunk.readByte()
      p.frequency = chunk.readInt16()
  else: # chunk.sampleDepth == 16:
    if (remainingLength mod 10) != 0: raise PNGError("palette length not divisible by 10")
    let numSamples = remainingLength div 10
    newSeq(chunk.palette, numSamples)
    for p in mitems(chunk.palette):
      p.red   = chunk.readInt16()
      p.green = chunk.readInt16()
      p.blue  = chunk.readInt16()
      p.alpha = chunk.readInt16()
      p.frequency = chunk.readInt16()

  result = true

method parseChunk(chunk: PNGHist, png: PNG): bool =
  if not png.hasChunk(PLTE): raise PNGError("Histogram need PLTE")
  var plte = PNGPalette(png.getChunk(PLTE))
  if plte.palette.len != (chunk.length div 2): raise PNGError("invalid histogram length")
  newSeq(chunk.histogram, plte.palette.len)
  for i in 0..chunk.histogram.high:
    chunk.histogram[i] = chunk.readInt16()
  result = true

method parseChunk(chunk: PNGSbit, png: PNG): bool =
  let header = PNGHEader(png.getChunk(IHDR))
  var expectedLen = 0

  case header.colorType
  of LCT_GREY: expectedLen = 1
  of LCT_RGB: expectedLen = 3
  of LCT_PALETTE: expectedLen = 3
  of LCT_GREY_ALPHA: expectedLen = 2
  of LCT_RGBA: expectedLen = 4
  if chunk.length != expectedLen: raise PNGError("invalid sBIT length")
  var expectedDepth = 8 #LCT_PALETTE
  if header.colorType != LCT_PALETTE: expectedDepth = header.bitDepth
  for c in chunk.data:
    if (ord(c) == 0) or (ord(c) > expectedDepth): raise PNGError("invalid sBIT value")

  result = true

proc makeIHDR(): PNGHeader = new(result)
proc makePLTE(): PNGPalette = new(result)
proc makeIDAT(): PNGData = new(result)
proc maketRNS(): PNGTrans = new(result)
proc makebKGD(): PNGBackground = new(result)
proc maketIME(): PNGTime = new(result)
proc makepHYs(): PNGPhys = new(result)
proc maketEXt(): PNGText = new(result)
proc makezTXt(): PNGZtxt = new(result)
proc makeiTXt(): PNGItxt = new(result)
proc makegAMA(): PNGGamma = new(result)
proc makecHRM(): PNGChroma = new(result)
proc makesRGB(): PNGStandarRGB = new(result)
proc makeiCCP(): PNGICCProfile = new(result)
proc makesPLT(): PNGSPalette = new(result)
proc makehIST(): PNGHist = new(result)
proc makesBIT(): PNGSbit = new(result)

proc createChunk(png: PNG, chunkType: PNGChunkType, data: string, crc: uint32): PNGChunk =
  if chunkType == IHDR: result = makeIHDR()
  elif chunkType == PLTE: result = makePLTE()
  elif chunkType == IDAT:
    if not png.hasChunk(IDAT): result = makeIDAT()
    else:
      var idat = PNGData(png.getChunk(IDAT))
      idat.data.add data
      return idat
  elif chunkType == tRNS: result = maketRNS()
  elif chunkType == bKGD: result = makebKGD()
  elif chunkType == tIME: result = maketIME()
  elif chunkType == pHYs: result = makepHYs()
  elif chunkType == tEXt: result = maketEXt()
  elif chunkType == zTXt: result = makezTXt()
  elif chunkType == iTXt: result = makeiTXt()
  elif chunkType == gAMA: result = makegAMA()
  elif chunkType == cHRM: result = makecHRM()
  elif chunkType == iCCP: result = makeiCCP()
  elif chunkType == sRGB: result = makesRGB()
  elif chunkType == sPLT: result = makesPLT()
  elif chunkType == hIST: result = makehIST()
  elif chunkType == sBIT: result = makesBIT()
  else: new(result)
  result.initChunk(chunkType, data, crc)

proc parsePNG(s: Stream): PNG =
  var png: PNG
  new(png)
  png.chunks = @[]
  let signature = s.readStr(8)
  if signature != PNGSignature: raise PNGError("signature mismatch")

  while not s.atEnd():
    let length = s.readInt32BE()
    let chunkType = PNGChunkType(s.readInt32BE())
    if chunkType == IEND: break

    let data = s.readStr(length)
    let crc = cast[uint32](s.readInt32BE())
    let calculatedCRC = crc32(crc32(0, $chunkType), data)
    if calculatedCRC != crc: raise PNGError("wrong crc for: " & $chunkType)
    var chunk = png.createChunk(chunkType, data, crc)

    if chunkType != IDAT:
      if chunk == nil: raise PNGError("error creating chunk: " & $chunkType)
      if not chunk.parseChunk(png): raise PNGError("error parse chunk: " & $chunkType)
      if not chunk.validateChunk(png): raise PNGError("invalid chunk: " & $chunkType)
    png.chunks.add chunk

  if not png.hasChunk(IHDR): raise PNGError("no IHDR found")
  if not png.hasChunk(IDAT): raise PNGError("no IDAT found")
  var header = PNGHeader(png.getChunk(IHDR))
  if header.colorType == LCT_PALETTE and not png.hasChunk(PLTE):
    raise PNGError("expected PLTE not found")

  # IDAT get special treatment because it can appear in multiple chunk
  var idat = PNGData(png.getChunk(IDAT))
  if not idat.parseChunk(png): raise PNGError("IDAT parse error")
  if not idat.validateChunk(png): raise PNGError("bad IDAT")
  result = png

# Paeth predicter, used by PNG filter type 4
proc paethPredictor(a, b, c: int): int =
  let pa = abs(b - c)
  let pb = abs(a - c)
  let pc = abs(a + b - c - c)

  if(pc < pa) and (pc < pb): return c
  elif pb < pa: return b
  result = a

proc readBitFromReversedStream(bitptr: var int, bitstream: cstring): int =
  result = ((ord(bitstream[bitptr shr 3]) shr (7 - (bitptr and 0x7))) and 1)
  inc bitptr

proc readBitsFromReversedStream(bitptr: var int, bitstream: cstring, nbits: int): int =
  result = 0
  var i = nbits - 1
  while i > -1:
    result += readBitFromReversedStream(bitptr, bitstream) shl i
    dec i

proc `&=`(a: var char, b: char) =
  a = chr(ord(a) and ord(b))

proc `|=`(a: var char, b: char) =
  a = chr(ord(a) or ord(b))

proc setBitOfReversedStream0(bitptr: var int, bitstream: var cstring, bit: int) =
  # the current bit in bitstream must be 0 for this to work
  if bit != 0:
    # earlier bit of huffman code is in a lesser significant bit of an earlier byte
    bitstream[bitptr shr 3] |= cast[char](bit shl (7 - (bitptr and 0x7)))
  inc bitptr

proc setBitOfReversedStream(bitptr: var int, bitstream: var cstring, bit: int) =
  #the current bit in bitstream may be 0 or 1 for this to work
  if bit == 0: bitstream[bitptr shr 3] &= cast[char](not (1 shl (7 - (bitptr and 0x7))))
  else: bitstream[bitptr shr 3] |= cast[char](1 shl (7 - (bitptr and 0x7)))
  inc bitptr

# index: bitgroup index, bits: bitgroup size(1, 2 or 4), in: bitgroup value, out: octet array to add bits to
proc addColorBits(output: var cstring, index, bits, input: int) =
  var m = 1
  if bits == 1: m = 7
  elif bits == 2: m = 3
  # p = the partial index in the byte, e.g. with 4 palettebits it is 0 for first half or 1 for second half
  let p = index and m

  var val = input and ((1 shl bits) - 1) #filter out any other bits of the input value
  val = val shl (bits * (m - p))
  let idx = index * bits div 8
  if p == 0: output[idx] = chr(val)
  else: output[idx] = chr(ord(output[idx]) or val)

proc unfilterScanline(recon: var cstring, scanLine, precon: cstring, byteWidth, len: int, filterType: PNGFilter0) =
  # For PNG filter method 0
  # unfilter a PNG image scanLine by scanLine. when the pixels are smaller than 1 byte,
  # the filter works byte per byte (bytewidth = 1)
  # precon is the previous unfiltered scanLine, recon the result, scanLine the current one
  # the incoming scanLines do NOT include the filtertype byte, that one is given in the parameter filterType instead
  # recon and scanLine MAY be the same memory address! precon must be disjoint.

  case filterType
  of FLT_NONE:
    for i in 0..len-1: recon[i] = scanLine[i]
  of FLT_SUB:
    for i in 0..byteWidth-1: recon[i] = scanLine[i]
    for i in byteWidth..len-1: recon[i] = chr((ord(scanLine[i]) + ord(recon[i - byteWidth])) mod 256)
  of FLT_UP:
    if precon != nil:
      for i in 0..len-1: recon[i] = chr((ord(scanLine[i]) + ord(precon[i])) mod 256)
    else:
      for i in 0..len-1: recon[i] = scanLine[i]
  of FLT_AVERAGE:
    if precon != nil:
      for i in 0..byteWidth-1:
        recon[i] = chr((ord(scanLine[i]) + ord(precon[i]) div 2) mod 256)
      for i in byteWidth..len-1:
        recon[i] = chr((ord(scanLine[i]) + ((ord(recon[i - bytewidth]) + ord(precon[i])) div 2)) mod 256)
    else:
      for i in 0..byteWidth-1: recon[i] = scanLine[i]
      for i in byteWidth..len-1:
        recon[i] = chr((ord(scanLine[i]) + ord(recon[i - bytewidth]) div 2) mod 256)
  of FLT_PAETH:
    if precon != nil:
      for i in 0..byteWidth-1:
        recon[i] = chr((ord(scanLine[i]) + ord(precon[i])) mod 256) #paethPredictor(0, precon[i], 0) is always precon[i]
      for i in byteWidth..len-1:
        recon[i] = chr((ord(scanLine[i]) + paethPredictor(ord(recon[i - bytewidth]), ord(precon[i]), ord(precon[i - bytewidth]))) mod 256)
    else:
      for i in 0..byteWidth-1: recon[i] = scanLine[i]
      for i in byteWidth..len-1:
        # paethPredictor(recon[i - bytewidth], 0, 0) is always recon[i - bytewidth]
        recon[i] = chr((ord(scanLine[i]) + ord(recon[i - bytewidth])) mod 256)

proc unfilter(output: var cstring, input: cstring, w, h, bpp: int) =
  # For PNG filter method 0
  # this function unfilters a single image (e.g. without interlacing this is called once, with Adam7 seven times)
  # output must have enough bytes allocated already, input must have the scanLines + 1 filtertype byte per scanLine
  # w and h are image dimensions or dimensions of reduced image, bpp is bits per pixel
  # input and output are allowed to be the same memory address (but aren't the same size since in has the extra filter bytes)

  var prevLine = cstring(nil)
  var inp = input

  # bytewidth is used for filtering, is 1 when bpp < 8, number of bytes per pixel otherwise
  let byteWidth = (bpp + 7) div 8
  let lineBytes = (w * bpp + 7) div 8

  for y in 0..h-1:
    let outIndex = lineBytes * y
    let inIndex = (1 + lineBytes) * y # the extra filterbyte added to each row
    let filterType = PNGFilter0(input[inindex])
    let scanLine: cstring = addr(inp[inIndex + 1])
    var outp: cstring = addr(output[outIndex])
    unfilterScanline(outp, scanLine, prevLine, byteWidth, lineBytes, filterType)
    prevLine = addr(output[outIndex])

proc removePaddingBits(output: var cstring, input: cstring, olinebits, ilinebits, h: int) =
  # After filtering there are still padding bits if scanlines have non multiple of 8 bit amounts. They need
  # to be removed (except at last scanline of (Adam7-reduced) image) before working with pure image buffers
  # for the Adam7 code, the color convert code and the output to the user.
  # in and out are allowed to be the same buffer, in may also be higher but still overlapping; in must
  # have >= ilinebits*h bits, out must have >= olinebits*h bits, olinebits must be <= ilinebits
  # also used to move bits after earlier such operations happened, e.g. in a sequence of reduced images from Adam7
  # only useful if (ilinebits - olinebits) is a value in the range 1..7

  let diff = ilinebits - olinebits
  var
    ibp = 0
    obp = 0 # input and output bit pointers
  for y in 0..h-1:
    for x in 0..olinebits-1:
      var bit = readBitFromReversedStream(ibp, input)
      setBitOfReversedStream(obp, output, bit)
    inc(ibp, diff)

# Outputs various dimensions and positions in the image related to the Adam7 reduced images.
# passw: output containing the width of the 7 passes
# passh: output containing the height of the 7 passes
# filter_passstart: output containing the index of the start and end of each
# reduced image with filter bytes
# padded_passstart output containing the index of the start and end of each
# reduced image when without filter bytes but with padded scanlines
# passstart: output containing the index of the start and end of each reduced
# image without padding between scanlines, but still padding between the images
# w, h: width and height of non-interlaced image
# bpp: bits per pixel
# "padded" is only relevant if bpp is less than 8 and a scanline or image does not
# end at a full byte
proc Adam7PassValues(pass: var PNGPass, w, h, bpp: int) =
  #the passstart values have 8 values:
  # the 8th one indicates the byte after the end of the 7th (= last) pass

  # calculate width and height in pixels of each pass
  for i in 0..6:
    pass.w[i] = (w + ADAM7_DX[i] - ADAM7_IX[i] - 1) div ADAM7_DX[i]
    pass.h[i] = (h + ADAM7_DY[i] - ADAM7_IY[i] - 1) div ADAM7_DY[i]
    if pass.w[i] == 0: pass.h[i] = 0
    if pass.h[i] == 0: pass.w[i] = 0

  pass.filterStart[0] = 0
  pass.paddedStart[0] = 0
  pass.start[0] = 0
  for i in 0..6:
    # if passw[i] is 0, it's 0 bytes, not 1 (no filtertype-byte)
    pass.filterStart[i + 1] = pass.filterStart[i]
    if (pass.w[i] != 0) and (pass.h[i] != 0):
      pass.filterStart[i + 1] += pass.h[i] * (1 + (pass.w[i] * bpp + 7) div 8)
    # bits padded if needed to fill full byte at end of each scanline
    pass.paddedStart[i + 1] = pass.paddedStart[i] + pass.h[i] * ((pass.w[i] * bpp + 7) div 8)
    # only padded at end of reduced image
    pass.start[i + 1] = pass.start[i] + (pass.h[i] * pass.w[i] * bpp + 7) div 8

# input: Adam7 interlaced image, with no padding bits between scanlines, but between
# reduced images so that each reduced image starts at a byte.
# output: the same pixels, but re-ordered so that they're now a non-interlaced image with size w*h
# bpp: bits per pixel
# output has the following size in bits: w * h * bpp.
# input is possibly bigger due to padding bits between reduced images.
# output must be big enough AND must be 0 everywhere if bpp < 8 in the current implementation
# (because that's likely a little bit faster)
# NOTE: comments about padding bits are only relevant if bpp < 8

proc Adam7Deinterlace(output: var cstring, input: cstring, w, h, bpp: int) =
  var pass: PNGPass
  Adam7PassValues(pass, w, h, bpp)

  if bpp >= 8:
    for i in 0..6:
      var bytewidth = bpp div 8
      for y in 0..pass.h[i]-1:
        for x in 0..pass.w[i]-1:
          var pixelinstart  = pass.start[i] + (y * pass.w[i] + x) * bytewidth
          var pixeloutstart = ((ADAM7_IY[i] + y * ADAM7_DY[i]) * w + ADAM7_IX[i] + x * ADAM7_DX[i]) * bytewidth
          for b in 0..bytewidth-1:
            output[pixeloutstart + b] = input[pixelinstart + b]
  else: # bpp < 8: Adam7 with pixels < 8 bit is a bit trickier: with bit pointers
    for i in 0..6:
      var ilinebits = bpp * pass.w[i]
      var olinebits = bpp * w
      for y in 0..pass.h[i]-1:
        for x in 0..pass.w[i]-1:
          var ibp = (8 * pass.start[i]) + (y * ilinebits + x * bpp)
          var obp = (ADAM7_IY[i] + y * ADAM7_DY[i]) * olinebits + (ADAM7_IX[i] + x * ADAM7_DX[i]) * bpp
          for b in 0..bpp-1:
            var bit = readBitFromReversedStream(ibp, input)
            # note that this function assumes the out buffer is completely 0, use setBitOfReversedStream otherwise
            setBitOfReversedStream0(obp, output, bit)

proc postProcessscanLines(png: PNG) =
  # This function converts the filtered-padded-interlaced data
  # into pure 2D image buffer with the PNG's colortype.
  # Steps:
  # *) if no Adam7: 1) unfilter 2) remove padding bits (= posible extra bits per scanLine if bpp < 8)
  # *) if adam7: 1) 7x unfilter 2) 7x remove padding bits 3) Adam7_deinterlace
  # NOTE: the input buffer will be overwritten with intermediate data!

  var header = PNGHeader(png.getChunk(IHDR))
  let bpp = header.getBPP()
  let w = header.width
  let h = header.height
  let bitsPerLine = w * bpp
  let bitsPerPaddedLine = ((w * bpp + 7) div 8) * 8
  var idat = PNGData(png.getChunk(IDAT))
  png.pixels = newString(idatRawSize(header.width, header.height, header))
  var input = cstring(idat.idat)
  var output = cstring(png.pixels)
  zeroMem(output, png.pixels.len)

  if header.interlaceMethod == IM_NONE:
    if(bpp < 8) and (bitsPerLine != bitsPerPaddedLine):
      unfilter(input, input, w, h, bpp)
      removePaddingBits(output, input, bitsPerLine, bitsPerPaddedLine, h)
    # we can immediatly filter into the out buffer, no other steps needed
    else: unfilter(output, input, w, h, bpp)
  else: # interlace_method is 1 (Adam7)
    var pass: PNGPass
    Adam7PassValues(pass, w, h, bpp)

    for i in 0..6:
      var outp: cstring = addr(input[pass.paddedStart[i]])
      var inp: cstring = addr(input[pass.filterStart[i]])
      unfilter(outp, inp, pass.w[i], pass.h[i], bpp)

      # TODO: possible efficiency improvement:
      # if in this reduced image the bits fit nicely in 1 scanLine,
      # move bytes instead of bits or move not at all
      if bpp < 8:
        # remove padding bits in scanLines; after this there still may be padding
        # bits between the different reduced images: each reduced image still starts nicely at a byte
        outp = addr(input[pass.start[i]])
        inp = addr(input[pass.paddedStart[i]])
        removePaddingBits(outp, inp, pass.w[i] * bpp, ((pass.w[i] * bpp + 7) div 8) * 8, pass.h[i])

    Adam7Deinterlace(output, input, w, h, bpp)

proc getColorMode(png: PNG): PNGColorMode =
  var cm = newColorMode()
  var header = PNGHeader(png.getChunk(IHDR))
  cm.colorType = header.colorType
  cm.bitDepth = header.bitDepth
  var plte = PNGPalette(png.getChunk(PLTE))
  if plte != nil:
    cm.paletteSize = plte.palette.len
    newSeq(cm.palette, cm.paletteSize)
    for i in 0..cm.paletteSize-1: cm.palette[i] = plte.palette[i]
  var trans = PNGTrans(png.getChunk(tRNS))
  if trans != nil:
    if cm.colorType in {LCT_GREY, LCT_RGB}:
      cm.keyDefined = true
      cm.keyR = trans.keyR
      cm.keyG = trans.keyG
      cm.keyB = trans.keyB
  result = cm

proc RGBFromGrey8(output: var cstring, input: cstring, numPixels: int, mode: PNGColorMode) =
  for i in 0..numPixels-1:
    let x = i * 3
    output[x]   = input[i]
    output[x+1] = input[i]
    output[x+2] = input[i]

proc RGBFromGrey16(output: var cstring, input: cstring, numPixels: int, mode: PNGColorMode) =
  for i in 0..numPixels-1:
    let x = i * 3
    let y = i * 2
    output[x]   = input[y]
    output[x+1] = input[y]
    output[x+2] = input[y]

proc RGBFromGrey124(output: var cstring, input: cstring, numPixels: int, mode: PNGColorMode) =
  var highest = ((1 shl mode.bitDepth) - 1) #highest possible value for this bit depth
  var obp = 0
  for i in 0..numPixels-1:
    let val = chr((readBitsFromReversedStream(obp, input, mode.bitDepth) * 255) div highest)
    let x = i * 3
    output[x]   = val
    output[x+1] = val
    output[x+2] = val

proc RGBFromRGB8(output: var cstring, input: cstring, numPixels: int, mode: PNGColorMode) =
  for i in 0..numPixels-1:
    let x = i * 3
    output[x]   = input[x]
    output[x+1] = input[x+1]
    output[x+2] = input[x+2]

proc RGBFromRGB16(output: var cstring, input: cstring, numPixels: int, mode: PNGColorMode) =
  for i in 0..numPixels-1:
    let x = i * 3
    let y = i * 6
    output[x]   = input[y]
    output[x+1] = input[y+2]
    output[x+2] = input[y+4]

proc RGBFromPalette8(output: var cstring, input: cstring, numPixels: int, mode: PNGColorMode) =
  for i in 0..numPixels-1:
    let x = i * 3
    let index = ord(input[i])
    if index >= mode.paletteSize:
      # This is an error according to the PNG spec, but most PNG decoders make it black instead.
      # Done here too, slightly faster due to no error handling needed.
      output[x]   = chr(0)
      output[x+1] = chr(0)
      output[x+2] = chr(0)
    else:
      output[x]   = mode.palette[index].r
      output[x+1] = mode.palette[index].g
      output[x+2] = mode.palette[index].b

proc RGBFromPalette124(output: var cstring, input: cstring, numPixels: int, mode: PNGColorMode) =
  var obp = 0
  for i in 0..numPixels-1:
    let x = i * 3
    let index = readBitsFromReversedStream(obp, input, mode.bitDepth)
    if index >= mode.paletteSize:
      # This is an error according to the PNG spec, but most PNG decoders make it black instead.
      # Done here too, slightly faster due to no error handling needed.
      output[x]   = chr(0)
      output[x+1] = chr(0)
      output[x+2] = chr(0)
    else:
      output[x]   = mode.palette[index].r
      output[x+1] = mode.palette[index].g
      output[x+2] = mode.palette[index].b

proc RGBFromGreyAlpha8(output: var cstring, input: cstring, numPixels: int, mode: PNGColorMode) =
  for i in 0..numPixels-1:
    let x = i * 3
    let val = input[i * 2]
    output[x] = val
    output[x+1] = val
    output[x+2] = val

proc RGBFromGreyAlpha16(output: var cstring, input: cstring, numPixels: int, mode: PNGColorMode) =
  for i in 0..numPixels-1:
    let x = i * 3
    let val = input[i * 4]
    output[x] = val
    output[x+1] = val
    output[x+2] = val

proc RGBFromRGBA8(output: var cstring, input: cstring, numPixels: int, mode: PNGColorMode) =
  for i in 0..numPixels-1:
    let x = i * 3
    let y = i * 4
    output[x]   = input[y]
    output[x+1] = input[y+1]
    output[x+2] = input[y+2]

proc RGBFromRGBA16(output: var cstring, input: cstring, numPixels: int, mode: PNGColorMode) =
  for i in 0..numPixels-1:
    let x = i * 3
    let y = i * 8
    output[x]   = input[y]
    output[x+1] = input[y+2]
    output[x+2] = input[y+4]

proc RGBAFromGrey8(output: var cstring, input: cstring, numPixels: int, mode: PNGColorMode) =
  for i in 0..numPixels-1:
    let x = i * 4
    output[x]   = input[i]
    output[x+1] = input[i]
    output[x+2] = input[i]
    if mode.keyDefined and (ord(input[i]) == mode.keyR): output[x+3] = chr(0)
    else: output[x+3] = chr(255)

proc RGBAFromGrey16(output: var cstring, input: cstring, numPixels: int, mode: PNGColorMode) =
  for i in 0..numPixels-1:
    let x = i * 4
    let y = i * 2
    output[x]   = input[y]
    output[x+1] = input[y]
    output[x+2] = input[y]
    let keyR = 256 * ord(input[y + 0]) + ord(input[y + 1])
    if mode.keyDefined and (keyR == mode.keyR): output[x+3] = chr(0)
    else: output[x+3] = chr(255)

proc RGBAFromGrey124(output: var cstring, input: cstring, numPixels: int, mode: PNGColorMode) =
  var highest = ((1 shl mode.bitDepth) - 1) #highest possible value for this bit depth
  var obp = 0
  for i in 0..numPixels-1:
    let val = chr((readBitsFromReversedStream(obp, input, mode.bitDepth) * 255) div highest)
    let x = i * 4
    output[x]   = val
    output[x+1] = val
    output[x+2] = val
    if mode.keyDefined and (ord(val) == mode.keyR): output[x+3] = chr(0)
    else: output[x+3] = chr(255)

proc RGBAFromRGB8(output: var cstring, input: cstring, numPixels: int, mode: PNGColorMode) =
  for i in 0..numPixels-1:
    let x = i * 4
    output[x]   = input[x]
    output[x+1] = input[x+1]
    output[x+2] = input[x+2]
    if mode.keyDefined and (mode.keyR == ord(input[x])) and
      (mode.keyG == ord(input[x+1])) and (mode.keyB == ord(input[x+2])): output[x+3] = chr(0)
    else: output[x+3] = chr(255)

proc RGBAFromRGB16(output: var cstring, input: cstring, numPixels: int, mode: PNGColorMode) =
  for i in 0..numPixels-1:
    let x = i * 4
    let y = i * 6
    output[x]   = input[y]
    output[x+1] = input[y+2]
    output[x+2] = input[y+4]
    let keyR = 256 * ord(input[y]) + ord(input[y+1])
    let keyG = 256 * ord(input[y+2]) + ord(input[y+3])
    let keyB = 256 * ord(input[y+4]) + ord(input[y+5])
    if mode.keyDefined and (mode.keyR == keyR) and
      (mode.keyG == keyG) and (mode.keyB == keyB): output[x+3] = chr(0)
    else: output[x+3] = chr(255)

proc RGBAFromPalette8(output: var cstring, input: cstring, numPixels: int, mode: PNGColorMode) =
  for i in 0..numPixels-1:
    let x = i * 4
    let index = ord(input[i])
    if index >= mode.paletteSize:
      # This is an error according to the PNG spec, but most PNG decoders make it black instead.
      # Done here too, slightly faster due to no error handling needed.
      output[x]   = chr(0)
      output[x+1] = chr(0)
      output[x+2] = chr(0)
      output[x+3] = chr(0)
    else:
      output[x]   = mode.palette[index].r
      output[x+1] = mode.palette[index].g
      output[x+2] = mode.palette[index].b
      output[x+3] = mode.palette[index].a

proc RGBAFromPalette124(output: var cstring, input: cstring, numPixels: int, mode: PNGColorMode) =
  var obp = 0
  for i in 0..numPixels-1:
    let x = i * 4
    let index = readBitsFromReversedStream(obp, input, mode.bitDepth)
    if index >= mode.paletteSize:
      # This is an error according to the PNG spec, but most PNG decoders make it black instead.
      # Done here too, slightly faster due to no error handling needed.
      output[x]   = chr(0)
      output[x+1] = chr(0)
      output[x+2] = chr(0)
      output[x+3] = chr(0)
    else:
      output[x]   = mode.palette[index].r
      output[x+1] = mode.palette[index].g
      output[x+2] = mode.palette[index].b
      output[x+3] = mode.palette[index].a

proc RGBAFromGreyAlpha8(output: var cstring, input: cstring, numPixels: int, mode: PNGColorMode) =
  for i in 0..numPixels-1:
    let x = i * 4
    let val = input[i * 2]
    output[x] = val
    output[x+1] = val
    output[x+2] = val
    output[x+3] = input[i * 2 + 1]

proc RGBAFromGreyAlpha16(output: var cstring, input: cstring, numPixels: int, mode: PNGColorMode) =
  for i in 0..numPixels-1:
    let x = i * 4
    let val = input[i * 4]
    output[x] = val
    output[x+1] = val
    output[x+2] = val
    output[x+3] = input[i * 4 + 2]

proc RGBAFromRGBA8(output: var cstring, input: cstring, numPixels: int, mode: PNGColorMode) =
  for i in 0..numPixels-1:
    let x = i * 4
    let y = i * 4
    output[x]   = input[y]
    output[x+1] = input[y+1]
    output[x+2] = input[y+2]
    output[x+3] = input[y+3]

proc RGBAFromRGBA16(output: var cstring, input: cstring, numPixels: int, mode: PNGColorMode) =
  for i in 0..numPixels-1:
    let x = i * 4
    let y = i * 8
    output[x]   = input[y]
    output[x+1] = input[y+2]
    output[x+2] = input[y+4]
    output[x+3] = input[y+6]

type
  convertRGBA    = proc(output: var cstring, input: cstring, numPixels: int, mode: PNGColorMode)
  convertRGBA8   = proc(p: var RGBA8, input: cstring, px: int, mode: PNGColorMode)
  convertRGBA16  = proc(p: var RGBA16, input: cstring, px: int, mode: PNGColorMode)
  pixelRGBA8     = proc(p: RGBA8, output: var cstring, px: int, mode: PNGColorMode, ct: ColorTree8)
  pixelRGBA16    = proc(p: RGBA16, output: var cstring, px: int, mode: PNGColorMode)

proc hash*(c: RGBA8): THash =
  var h: THash = 0
  h = h !& ord(c.r)
  h = h !& ord(c.g)
  h = h !& ord(c.b)
  h = h !& ord(c.a)

proc RGBA8FromGrey8(p: var RGBA8, input: cstring, px: int, mode: PNGColorMode) =
  p.r = input[px]
  p.g = input[px]
  p.b = input[px]
  if mode.keyDefined and (ord(p.r) == mode.keyR): p.a = chr(0)
  else: p.a = chr(255)

proc RGBA8FromGrey16(p: var RGBA8, input: cstring, px: int, mode: PNGColorMode) =
  let i = px * 2
  let keyR = 256 * ord(input[i]) + ord(input[i + 1])
  p.r = input[i]
  p.g = input[i]
  p.b = input[i]
  if mode.keyDefined and (keyR == mode.keyR): p.a = chr(0)
  else: p.a = chr(255)

proc RGBA8FromGrey124(p: var RGBA8, input: cstring, px: int, mode: PNGColorMode) =
  let highest = ((1 shl mode.bitDepth) - 1) #highest possible value for this bit depth
  var obp = px * mode.bitDepth
  let val = chr((readBitsFromReversedStream(obp, input, mode.bitDepth) * 255) div highest)
  p.r = val
  p.g = val
  p.b = val
  if mode.keyDefined and (ord(val) == mode.keyR): p.a = chr(0)
  else: p.a = chr(255)

proc RGBA8FromRGB8(p: var RGBA8, input: cstring, px: int, mode: PNGColorMode) =
  let y = px * 3
  p.r = input[y]
  p.g = input[y+1]
  p.b = input[y+2]
  if mode.keyDefined and (mode.keyR == ord(input[y])) and
    (mode.keyG == ord(input[y+1])) and (mode.keyB == ord(input[y+2])): p.a = chr(0)
  else: p.a = chr(255)

proc RGBA8FromRGB16(p: var RGBA8, input: cstring, px: int, mode: PNGColorMode) =
  let y = px * 6
  p.r = input[y]
  p.g = input[y+2]
  p.b = input[y+4]
  let keyR = 256 * ord(input[y]) + ord(input[y+1])
  let keyG = 256 * ord(input[y+2]) + ord(input[y+3])
  let keyB = 256 * ord(input[y+4]) + ord(input[y+5])
  if mode.keyDefined and (mode.keyR == keyR) and
    (mode.keyG == keyG) and (mode.keyB == keyB): p.a = chr(0)
  else: p.a = chr(255)

proc RGBA8FromPalette8(p: var RGBA8, input: cstring, px: int, mode: PNGColorMode) =
  let index = ord(input[px])
  if index >= mode.paletteSize:
    # This is an error according to the PNG spec,
    # but common PNG decoders make it black instead.
    # Done here too, slightly faster due to no error handling needed.
    p.r = chr(0)
    p.g = chr(0)
    p.b = chr(0)
    p.a = chr(255)
  else:
    p.r = mode.palette[index].r
    p.g = mode.palette[index].g
    p.b = mode.palette[index].b
    p.a = mode.palette[index].a

proc RGBA8FromPalette124(p: var RGBA8, input: cstring, px: int, mode: PNGColorMode) =
  var obp = px * mode.bitDepth
  let index = readBitsFromReversedStream(obp, input, mode.bitDepth)
  if index >= mode.paletteSize:
    # This is an error according to the PNG spec,
    # but common PNG decoders make it black instead.
    # Done here too, slightly faster due to no error handling needed.
    p.r = chr(0)
    p.g = chr(0)
    p.b = chr(0)
    p.a = chr(255)
  else:
    p.r = mode.palette[index].r
    p.g = mode.palette[index].g
    p.b = mode.palette[index].b
    p.a = mode.palette[index].a

proc RGBA8FromGreyAlpha8(p: var RGBA8, input: cstring, px: int, mode: PNGColorMode) =
  let i = px * 2
  let val = input[i]
  p.r = val
  p.g = val
  p.b = val
  p.a = input[i+1]

proc RGBA8FromGreyAlpha16(p: var RGBA8, input: cstring, px: int, mode: PNGColorMode) =
  let i = px * 4
  let val = input[i]
  p.r = val
  p.g = val
  p.b = val
  p.a = input[i+2]

proc RGBA8FromRGBA8(p: var RGBA8, input: cstring, px: int, mode: PNGColorMode) =
  let i = px * 4
  p.r = input[i]
  p.g = input[i+1]
  p.b = input[i+2]
  p.a = input[i+3]

proc RGBA8FromRGBA16(p: var RGBA8, input: cstring, px: int, mode: PNGColorMode) =
  let i = px * 8
  p.r = input[i]
  p.g = input[i+2]
  p.b = input[i+4]
  p.a = input[i+6]

proc RGBA16FromGrey(p: var RGBA16, input: cstring, px: int, mode: PNGColorMode) =
  let i = px * 2
  let val = 256 * ord(input[i]) + ord(input[i + 1])
  p.r = val
  p.g = val
  p.b = val
  if mode.keyDefined and (val == mode.keyR): p.a = 0
  else: p.a = 65535

proc RGBA16FromRGB(p: var RGBA16, input: cstring, px: int, mode: PNGColorMode) =
  let i = px * 6
  p.r = 256 * ord(input[i]) + ord(input[i+1])
  p.g = 256 * ord(input[i+2]) + ord(input[i+3])
  p.b = 256 * ord(input[i+4]) + ord(input[i+5])
  if mode.keyDefined and (int(p.r) == mode.keyR) and
    (int(p.g) == mode.keyG) and (int(p.b) == mode.keyB): p.a = 0
  else: p.a = 65535

proc RGBA16FromGreyAlpha(p: var RGBA16, input: cstring, px: int, mode: PNGColorMode) =
  let i = px * 4
  let val = 256 * ord(input[i]) + ord(input[i + 1])
  p.r = val
  p.g = val
  p.b = val
  p.a = 256 * ord(input[px + 2]) + ord(input[px + 3])

proc RGBA16FromRGBA(p: var RGBA16, input: cstring, px: int, mode: PNGColorMode) =
  let i = px * 8
  p.r = 256 * ord(input[i]) + ord(input[i+1])
  p.g = 256 * ord(input[i+2]) + ord(input[i+3])
  p.b = 256 * ord(input[i+4]) + ord(input[i+5])
  p.a = 256 * ord(input[i+6]) + ord(input[i+7])

proc RGBA8ToGrey8(p: RGBA8, output: var cstring, px: int, mode: PNGColorMode, ct: ColorTree8) =
  output[px] = p.r

proc RGBA8ToGrey16(p: RGBA8, output: var cstring, px: int, mode: PNGColorMode, ct: ColorTree8) =
  let i = px * 2
  output[i] = p.r
  output[i+1] = p.r

proc RGBA8ToGrey124(p: RGBA8, output: var cstring, px: int, mode: PNGColorMode, ct: ColorTree8) =
  # take the most significant bits of grey
  let grey = (ord(p.r) shr (8 - mode.bitDepth)) and ((1 shl mode.bitDepth) - 1)
  addColorBits(output, px, mode.bitDepth, grey)

proc RGBA8ToRGB8(p: RGBA8, output: var cstring, px: int, mode: PNGColorMode, ct: ColorTree8) =
  let i = px * 3
  output[i]   = p.r
  output[i+1] = p.g
  output[i+2] = p.b

proc RGBA8ToRGB16(p: RGBA8, output: var cstring, px: int, mode: PNGColorMode, ct: ColorTree8) =
  let i = px * 6
  output[i]   = p.r
  output[i+2] = p.g
  output[i+4] = p.b
  output[i+1] = p.r
  output[i+3] = p.g
  output[i+5] = p.b

proc RGBA8ToPalette8(p: RGBA8, output: var cstring, px: int, mode: PNGColorMode, ct: ColorTree8) =
  output[px] = chr(ct[p])

proc RGBA8ToPalette124(p: RGBA8, output: var cstring, px: int, mode: PNGColorMode, ct: ColorTree8) =
  addColorBits(output, px, mode.bitDepth, ct[p])

proc RGBA8ToGreyAlpha8(p: RGBA8, output: var cstring, px: int, mode: PNGColorMode, ct: ColorTree8) =
  let i = px * 2
  output[i] = p.r
  output[i+1] = p.a

proc RGBA8ToGreyAlpha16(p: RGBA8, output: var cstring, px: int, mode: PNGColorMode, ct: ColorTree8) =
  let i = px * 4
  output[i] = p.r
  output[i+1] = p.r
  output[i+2] = p.a
  output[i+3] = p.a

proc RGBA8ToRGBA8(p: RGBA8, output: var cstring, px: int, mode: PNGColorMode, ct: ColorTree8) =
  let i = px * 4
  output[i] = p.r
  output[i+1] = p.g
  output[i+2] = p.b
  output[i+3] = p.a

proc RGBA8ToRGBA16(p: RGBA8, output: var cstring, px: int, mode: PNGColorMode, ct: ColorTree8) =
  let i = px * 8
  output[i] = p.r
  output[i+2] = p.g
  output[i+4] = p.b
  output[i+6] = p.a
  output[i+1] = p.r
  output[i+3] = p.g
  output[i+5] = p.b
  output[i+7] = p.a

proc RGBA16ToGrey(p: RGBA16, output: var cstring, px: int, mode: PNGColorMode) =
  let i = px * 2
  output[i] = chr((ord(p.r) shr 8) and 255)
  output[i+1] = chr(ord(p.r) and 255)

proc RGBA16ToRGB(p: RGBA16, output: var cstring, px: int, mode: PNGColorMode) =
  let i = px * 6
  output[i]   = chr((ord(p.r) shr 8) and 255)
  output[i+1] = chr(ord(p.r) and 255)
  output[i+2] = chr((ord(p.g) shr 8) and 255)
  output[i+3] = chr(ord(p.g) and 255)
  output[i+4] = chr((ord(p.b) shr 8) and 255)
  output[i+5] = chr(ord(p.b) and 255)

proc RGBA16ToGreyAlpha(p: RGBA16, output: var cstring, px: int, mode: PNGColorMode) =
  let i = px * 4
  output[i]   = chr((ord(p.r) shr 8) and 255)
  output[i+1] = chr(ord(p.r) and 255)
  output[i+2] = chr((ord(p.a) shr 8) and 255)
  output[i+3] = chr(ord(p.a) and 255)

proc RGBA16ToRGBA(p: RGBA16, output: var cstring, px: int, mode: PNGColorMode) =
  let i = px * 8
  output[i]   = chr((ord(p.r) shr 8) and 255)
  output[i+1] = chr(ord(p.r) and 255)
  output[i+2] = chr((ord(p.g) shr 8) and 255)
  output[i+3] = chr(ord(p.g) and 255)
  output[i+4] = chr((ord(p.b) shr 8) and 255)
  output[i+5] = chr(ord(p.b) and 255)
  output[i+6] = chr((ord(p.a) shr 8) and 255)
  output[i+7] = chr(ord(p.a) and 255)

proc getColorRGBA16(mode: PNGColorMode): convertRGBA16 =
  if mode.colorType == LCT_GREY: return RGBA16FromGrey
  elif mode.colorType == LCT_RGB: return RGBA16FromRGB
  elif mode.colorType == LCT_GREY_ALPHA: return RGBA16FromGreyAlpha
  elif mode.colorType == LCT_RGBA: return RGBA16FromRGBA
  else: raise PNGError("unsupported converter16")

proc getPixelRGBA16(mode: PNGColorMode): pixelRGBA16 =
  if mode.colorType == LCT_GREY: return RGBA16ToGrey
  elif mode.colorType == LCT_RGB: return RGBA16ToRGB
  elif mode.colorType == LCT_GREY_ALPHA: return RGBA16ToGreyAlpha
  elif mode.colorType == LCT_RGBA: return RGBA16ToRGBA
  else: raise PNGError("unsupported pixel16 converter")

proc getColorRGBA8(mode: PNGColorMode): convertRGBA8 =
  if mode.colorType == LCT_GREY:
    if mode.bitDepth == 8: return RGBA8FromGrey8
    elif mode.bitDepth == 16: return RGBA8FromGrey16
    else: return RGBA8FromGrey124
  elif mode.colorType == LCT_RGB:
    if mode.bitDepth == 8: return RGBA8FromRGB8
    else: return RGBA8FromRGB16
  elif mode.colorType == LCT_PALETTE:
    if mode.bitDepth == 8: return RGBA8FromPalette8
    else: return RGBA8FromPalette124
  elif mode.colorType == LCT_GREY_ALPHA:
    if mode.bitDepth == 8: return RGBA8FromGreyAlpha8
    else: return RGBA8FromGreyAlpha16
  elif mode.colorType == LCT_RGBA:
    if mode.bitDepth == 8: return RGBA8FromRGBA8
    else: return RGBA8FromRGBA16
  else: raise PNGError("unsupported converter8")

proc getPixelRGBA8(mode: PNGColorMode): pixelRGBA8 =
  if mode.colorType == LCT_GREY:
    if mode.bitDepth == 8: return RGBA8ToGrey8
    elif mode.bitDepth == 16: return RGBA8ToGrey16
    else: return RGBA8ToGrey124
  elif mode.colorType == LCT_RGB:
    if mode.bitDepth == 8: return RGBA8ToRGB8
    else: return RGBA8ToRGB16
  elif mode.colorType == LCT_PALETTE:
    if mode.bitDepth == 8: return RGBA8ToPalette8
    else: return RGBA8ToPalette124
  elif mode.colorType == LCT_GREY_ALPHA:
    if mode.bitDepth == 8: return RGBA8ToGreyAlpha8
    else: return RGBA8ToGreyAlpha16
  elif mode.colorType == LCT_RGBA:
    if mode.bitDepth == 8: return RGBA8ToRGBA8
    else: return RGBA8ToRGBA16
  else: raise PNGError("unsupported pixel8 converter")

proc getConverterRGB(mode: PNGColorMode): convertRGBA =
  if mode.colorType == LCT_GREY:
    if mode.bitDepth == 8: return RGBFromGrey8
    elif mode.bitDepth == 16: return RGBFromGrey16
    else: return RGBFromGrey124
  elif mode.colorType == LCT_RGB:
    if mode.bitDepth == 8: return RGBFromRGB8
    else: return RGBFromRGB16
  elif mode.colorType == LCT_PALETTE:
    if mode.bitDepth == 8: return RGBFromPalette8
    else: return RGBFromPalette124
  elif mode.colorType == LCT_GREY_ALPHA:
    if mode.bitDepth == 8: return RGBFromGreyAlpha8
    else: return RGBFromGreyAlpha16
  elif mode.colorType == LCT_RGBA:
    if mode.bitDepth == 8: return RGBFromRGBA8
    else: return RGBFromRGBA16
  else: raise PNGError("unsupported RGB converter")

proc getConverterRGBA(mode: PNGColorMode): convertRGBA =
  if mode.colorType == LCT_GREY:
    if mode.bitDepth == 8: return RGBAFromGrey8
    elif mode.bitDepth == 16: return RGBAFromGrey16
    else: return RGBAFromGrey124
  elif mode.colorType == LCT_RGB:
    if mode.bitDepth == 8: return RGBAFromRGB8
    else: return RGBAFromRGB16
  elif mode.colorType == LCT_PALETTE:
    if mode.bitDepth == 8: return RGBAFromPalette8
    else: return RGBAFromPalette124
  elif mode.colorType == LCT_GREY_ALPHA:
    if mode.bitDepth == 8: return RGBAFromGreyAlpha8
    else: return RGBAFromGreyAlpha16
  elif mode.colorType == LCT_RGBA:
    if mode.bitDepth == 8: return RGBAFromRGBA8
    else: return RGBAFromRGBA16
  else: raise PNGError("unsupported RGBA converter")

proc convert(png: PNG, colorType: PNGColorType, bitDepth: int): PNGResult =
  #TODO: check if this works according to the statement in the documentation: "The converter can convert
  # from greyscale input color type, to 8-bit greyscale or greyscale with alpha"
  if(colorType notin {LCT_RGB, LCT_RGBA}) and (bitDepth != 8):
    raise PNGError("unsupported color mode conversion")

  let header = PNGHeader(png.getChunk(IHDR))
  let modeIn = png.getColorMode()
  let modeOut = newColorMode()
  modeOut.colorType = colorType
  modeOut.bitDepth = bitDepth
  let size = getRawSize(header.width, header.height, modeOut)
  let numPixels = header.width * header.height
  let input = cstring(png.pixels)
  
  new(result)
  result.width  = header.width
  result.height = header.height
  result.data   = newString(size)
  var output = cstring(result.data)
  
  if modeOut == modeIn:
    copyMem(output, input, size)
    return result

  var tree: ColorTree8
  if modeOut.colorType == LCT_PALETTE:
    let palSize = min(1 shl modeOut.bitDepth, modeOut.paletteSize)
    tree = initTable[RGBA8, int]()
    for i in 0..palSize-1:
      tree[modeOut.palette[i]] = i

  if(modeIn.bitDepth == 16) and (modeOut.bitDepth == 16):
    let cvt = getColorRGBA16(modeIn)
    let pxl = getPixelRGBA16(modeOut)
    for px in 0..numPixels-1:
      var p = RGBA16(r:0, g:0, b:0, a:0)
      cvt(p, input, px, modeIn)
      pxl(p, output, px, modeOut)
  elif(modeOut.bitDepth == 8) and (modeOut.colortype == LCT_RGBA):
    let cvt = getConverterRGBA(modeIn)
    cvt(output, input, numPixels, modeIn)
  elif(modeOut.bitDepth == 8) and (modeOut.colortype == LCT_RGB):
    let cvt = getConverterRGB(modeIn)
    cvt(output, input, numPixels, modeIn)
  else:
    var p = RGBA16(r:0, g:0, b:0, a:0)
    let cvt = getColorRGBA8(modeIn)
    let pxl = getPixelRGBA8(modeOut)
    for px in 0..numPixels-1:
      var p = RGBA8(r:chr(0), g:chr(0), b:chr(0), a:chr(0))
      cvt(p, input, px, modeIn)
      pxl(p, output, px, modeOut, tree)

proc loadPNG*(fileName: string, colorType: PNGColorType, bitDepth: int): PNGResult =
  try:
    if not bitDepthAllowed(colorType, bitDepth):
      raise PNGError("colorType and bitDepth combination not allowed")
    var s = newFileStream(fileName, fmRead)
    if s == nil: return nil
    var png = s.parsePNG()
    png.postProcessscanLines()
    result = png.convert(colorType, bitDepth)
  except:
    echo getCurrentExceptionMsg()
    result = nil

proc loadPNG32*(fileName: string): PNGResult =
  result = loadPNG(fileName, LCT_RGBA, 8)

proc loadPNG24*(fileName: string): PNGResult =
  result = loadPNG(fileName, LCT_RGB, 8)
  
proc pngDecode32*(input: string): PNGResult =
  try:
    var s = newStringStream(input)
    if s == nil: return nil
    var png = s.parsePNG()
    png.postProcessscanLines()
    result = png.convert(LCT_RGBA, 8)
  except:
    echo getCurrentExceptionMsg()
    result = nil

proc pngDecode24*(input: string): PNGResult =
  try:
    var s = newStringStream(input)
    if s == nil: return nil
    var png = s.parsePNG()
    png.postProcessscanLines()
    result = png.convert(LCT_RGB, 8)
  except:
    echo getCurrentExceptionMsg()
    result = nil

