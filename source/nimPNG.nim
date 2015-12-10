# Portable Network Graphics Encoder and Decoder written in Nim
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
# this is a rewrite of LodePNG(www.lodev.org/lodepng)
# to be as idiomatic Nim as possible
# part of nimPDF sister projects
#-------------------------------------

import streams, endians, tables, hashes, math, nimz

const
  NIM_PNG_VERSION = "0.1.5"

type
  PNGChunkType = distinct int32

  PNGcolorType* = enum
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

  PNGSettings = ref object of RootObj

  PNGDecoder* = ref object of PNGSettings
    colorConvert*: bool

    #if false but rememberUnknownChunks is true, they're stored in the unknown chunks
    #(off by default, useful for a png editor)

    readTextChunks*: bool
    rememberUnknownChunks*: bool
    ignoreCRC*: bool

  PNGInterlace* = enum
    IM_NONE = 0, IM_INTERLACED = 1

  PNGChunk = ref object of RootObj
    length: int #range[0..0x7FFFFFFF]
    chunkType: PNGChunkType
    crc: uint32
    data: string
    pos: int

  PNGHeader = ref object of PNGChunk
    width, height: int #range[1..0x7FFFFFFF]
    bitDepth: int
    colorType: PNGcolorType
    compressionMethod: int
    filterMethod: int
    interlaceMethod: PNGInterlace

  RGBA8* = object
    r*, g*, b*, a*: char

  RGBA16* = object
    r*, g*, b*, a*: uint16

  ColorTree8 = Table[RGBA8, int]

  PNGPalette = ref object of PNGChunk
    palette: seq[RGBA8]

  PNGData = ref object of PNGChunk
    idat: string

  PNGTime = ref object of PNGChunk
    year: int #range[0..65535]
    month: int #range[1..12]
    day: int #range[1..31]
    hour: int #range[0..23]
    minute: int #range[0..59]
    second: int #range[0..60] #to allow for leap seconds

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

  PNGColorMode* = ref object
    colorType*: PNGcolorType
    bitDepth*: int
    paletteSize*: int
    palette*: seq[RGBA8]
    keyDefined*: bool
    keyR*, keyG*, keyB*: int

  PNGInfo* = ref object
    width*: int
    height*: int
    mode*: PNGColorMode
    backgroundDefined*: bool
    backgroundR*, backgroundG*, backgroundB*: int

    physDefined*: bool
    physX*, physY*, physUnit*: int

    timeDefined*: bool
    year*: int #range[0..65535]
    month*: int #range[1..12]
    day*: int #range[1..31]
    hour*: int #range[0..23]
    minute*: int #range[0..59]
    second*: int #range[0..60] #to allow for leap seconds

  PNG* = ref object
    settings*: PNGSettings
    chunks*: seq[PNGChunk]
    pixels*: string

  PNGResult* = ref object
    width*: int
    height*: int
    data*: string

proc makePNGDecoder*(): PNGDecoder =
  var s: PNGDecoder
  new(s)
  s.colorConvert = true
  s.readTextChunks = false
  s.rememberUnknownChunks = false
  s.ignoreCRC = false
  result = s

proc signatureMaker(): string {. compiletime .} =
  const signatureBytes = [137, 80, 78, 71, 13, 10, 26, 10]
  result = ""
  for c in signatureBytes: result.add chr(c)

proc makeChunkType*(val: string): PNGChunkType =
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
#proc isAncillary(a: PNGChunkType): bool = (int(a) and (32 shl 24)) != 0
#proc isPrivate(a: PNGChunkType): bool = (int(a) and (32 shl 16)) != 0
#proc isSafeToCopy(a: PNGChunkType): bool = (int(a) and 32) != 0

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

proc newColorMode*(colorType=LCT_RGBA, bitDepth=8): PNGColorMode =
  new(result)
  result.keyDefined = false
  result.keyR = 0
  result.keyG = 0
  result.keyB = 0
  result.colorType = colorType
  result.bitDepth = bitDepth
  result.paletteSize = 0

proc copyTo*(src, dest: PNGColorMode) =
  dest.keyDefined = src.keyDefined
  dest.keyR = src.keyR
  dest.keyG = src.keyG
  dest.keyB = src.keyB
  dest.colorType = src.colorType
  dest.bitDepth = src.bitDepth
  dest.paletteSize = src.paletteSize
  if src.palette != nil:
    newSeq(dest.palette, src.paletteSize)
    for i in 0..src.palette.len-1: dest.palette[i] = src.palette[i]

proc newColorMode*(mode: PNGColorMode): PNGColorMode =
  new(result)
  mode.copyTo(result)

proc addPalette*(mode: PNGColorMode, r, g, b, a: int) =
  if mode.palette == nil: mode.palette = @[]
  mode.palette.add RGBA8(r: chr(r), g: chr(g), b: chr(b), a: chr(a))
  mode.paletteSize = mode.palette.len

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

proc `!=`(a, b: PNGColorMode): bool = not (a == b)

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

proc hasChunk*(png: PNG, chunkType: PNGChunkType): bool =
  for c in png.chunks:
    if c.chunkType == chunkType: return true
  result = false

proc getChunk*(png: PNG, chunkType: PNGChunkType): PNGChunk =
  for c in png.chunks:
    if c.chunkType == chunkType: return c

proc bitDepthAllowed(colorType: PNGcolorType, bitDepth: int): bool =
  case colorType
  of LCT_GREY   : result = bitDepth in {1, 2, 4, 8, 16}
  of LCT_PALETTE: result = bitDepth in {1, 2, 4, 8}
  else: result = bitDepth in {8, 16}

method validateChunk(chunk: PNGChunk, png: PNG): bool {.base.} = true
method parseChunk(chunk: PNGChunk, png: PNG): bool {.base.} = true

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
  chunk.colorType = PNGcolorType(chunk.readByte())
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

proc numChannels(colorType: PNGcolorType): int =
  case colorType
  of LCT_GREY: result = 1
  of LCT_RGB : result = 3
  of LCT_PALETTE: result = 1
  of LCT_GREY_ALPHA: result = 2
  of LCT_RGBA: result = 4

proc LCTBPP(colorType: PNGcolorType, bitDepth: int): int =
  # bits per pixel is amount of channels * bits per channel
  result = numChannels(colorType) * bitDepth

proc getBPP(header: PNGHeader): int =
  # calculate bits per pixel out of colorType and bitDepth
  result = LCTBPP(header.colorType, header.bitDepth)

proc getBPP(color: PNGColorMode): int =
  # calculate bits per pixel out of colorType and bitDepth
  result = LCTBPP(color.colorType, color.bitDepth)

proc idatRawSize(w, h: int, header: PNGHeader): int =
  result = h * ((w * getBPP(header) + 7) div 8)

proc getRawSize(w, h: int, color: PNGColorMode): int =
  result = (w * h * getBPP(color) + 7) div 8

#proc getRawSizeLct(w, h: int, colorType: PNGcolorType, bitDepth: int): int =
#  result = (w * h * LCTBPP(colorType, bitDepth) + 7) div 8

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
  if header == nil: return false

  if header.colorType == LCT_PALETTE:
    var plte = PNGPalette(png.getChunk(PLTE))
    if plte == nil: return false
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

method validateChunk(chunk: PNGTime, png: PNG): bool =
  if chunk.year < 0 or chunk.year > 65535: raise PNGError("invalid year range[0..65535]")
  if chunk.month < 1 or chunk.month > 12: raise PNGError("invalid month range[1..12]")
  if chunk.day < 1 or chunk.day > 31: raise PNGError("invalid day range[1..32]")
  if chunk.hour < 0 or chunk.hour > 23: raise PNGError("invalid hour range[0..23]")
  if chunk.minute < 0 or chunk.minute > 59: raise PNGError("invalid minute range[0..59]")
  #to allow for leap seconds
  if chunk.second < 0 or chunk.second > 60: raise PNGError("invalid second range[0..60]")
  result = true

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
  chunk.unit  = chunk.readByte()
  result = true

method validateChunk(chunk: PNGText, png: PNG): bool =
  if(chunk.keyword.len < 1) or (chunk.keyword.len > 79):
    raise PNGError("keyword too short or too long")
  result = true

method parseChunk(chunk: PNGText, png: PNG): bool =
  var len = 0
  while(len < chunk.length) and (chunk.data[len] != chr(0)): inc len
  if(len < 1) or (len > 79): raise PNGError("keyword too short or too long")
  chunk.keyword = chunk.data.substr(0, len)

  var textBegin = len + 1 # skip keyword null terminator
  chunk.text = chunk.data.substr(textBegin)
  result = true

method validateChunk(chunk: PNGZtxt, png: PNG): bool =
  if(chunk.keyword.len < 1) or (chunk.keyword.len > 79):
    raise PNGError("keyword too short or too long")
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

method validateChunk(chunk: PNGItxt, png: PNG): bool =
  if(chunk.keyword.len < 1) or (chunk.keyword.len > 79):
    raise PNGError("keyword too short or too long")
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

method validateChunk(chunk: PNGICCProfile, png: PNG): bool =
  if(chunk.profileName.len < 1) or (chunk.profileName.len > 79):
    raise PNGError("keyword too short or too long")
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

proc make[T](): T = new(result)

proc createChunk(png: PNG, chunkType: PNGChunkType, data: string, crc: uint32): PNGChunk =
  var settings = PNGDecoder(png.settings)
  result = nil

  if chunkType == IHDR: result = make[PNGHeader]()
  elif chunkType == PLTE: result = make[PNGPalette]()
  elif chunkType == IDAT:
    if not png.hasChunk(IDAT): result = make[PNGData]()
    else:
      var idat = PNGData(png.getChunk(IDAT))
      idat.data.add data
      return idat
  elif chunkType == tRNS: result = make[PNGTrans]()
  elif chunkType == bKGD: result = make[PNGBackground]()
  elif chunkType == tIME: result = make[PNGTime]()
  elif chunkType == pHYs: result = make[PNGPhys]()
  elif chunkType == tEXt:
    if settings.readTextChunks: result = make[PNGTExt]()
    else:
      if settings.rememberUnknownChunks: new(result)
  elif chunkType == zTXt:
    if settings.readTextChunks: result = make[PNGZtxt]()
    else:
      if settings.rememberUnknownChunks: new(result)
  elif chunkType == iTXt:
    if settings.readTextChunks: result = make[PNGItxt]()
    else:
      if settings.rememberUnknownChunks: new(result)
  elif chunkType == gAMA: result = make[PNGGamma]()
  elif chunkType == cHRM: result = make[PNGChroma]()
  elif chunkType == iCCP: result = make[PNGICCProfile]()
  elif chunkType == sRGB: result = make[PNGStandarRGB]()
  elif chunkType == sPLT: result = make[PNGSPalette]()
  elif chunkType == hIST: result = make[PNGHist]()
  elif chunkType == sBIT: result = make[PNGSbit]()
  else:
    if settings.rememberUnknownChunks: new(result)

  if result != nil:
    result.initChunk(chunkType, data, crc)

proc parsePNG(s: Stream, settings: PNGDecoder): PNG =
  var png: PNG
  new(png)
  png.chunks = @[]
  if settings == nil: png.settings = makePNGDecoder()
  else: png.settings = settings

  let signature = s.readStr(8)
  if signature != PNGSignature:
    raise PNGError("signature mismatch")

  while not s.atEnd():
    let length = s.readInt32BE()
    let chunkType = PNGChunkType(s.readInt32BE())

    let data = s.readStr(length)
    let crc = cast[uint32](s.readInt32BE())
    let calculatedCRC = crc32(crc32(0, $chunkType), data)
    if calculatedCRC != crc and not PNGDecoder(png.settings).ignoreCRC:
      raise PNGError("wrong crc for: " & $chunkType)
    var chunk = png.createChunk(chunkType, data, crc)

    if chunkType != IDAT and chunk != nil:
      if not chunk.parseChunk(png): raise PNGError("error parse chunk: " & $chunkType)
      if not chunk.validateChunk(png): raise PNGError("invalid chunk: " & $chunkType)
    if chunk != nil: png.chunks.add chunk
    if chunkType == IEND: break

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

proc unfilterScanLine(recon: var cstring, scanLine, precon: cstring, byteWidth, len: int, filterType: PNGFilter0) =
  # For PNG filter method 0
  # unfilter a PNG image scanLine by scanLine. when the pixels are smaller than 1 byte,
  # the filter works byte per byte (byteWidth = 1)
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
        recon[i] = chr((ord(scanLine[i]) + ((ord(recon[i - byteWidth]) + ord(precon[i])) div 2)) mod 256)
    else:
      for i in 0..byteWidth-1: recon[i] = scanLine[i]
      for i in byteWidth..len-1:
        recon[i] = chr((ord(scanLine[i]) + ord(recon[i - byteWidth]) div 2) mod 256)
  of FLT_PAETH:
    if precon != nil:
      for i in 0..byteWidth-1:
        recon[i] = chr((ord(scanLine[i]) + ord(precon[i])) mod 256) #paethPredictor(0, precon[i], 0) is always precon[i]
      for i in byteWidth..len-1:
        recon[i] = chr((ord(scanLine[i]) + paethPredictor(ord(recon[i - byteWidth]), ord(precon[i]), ord(precon[i - byteWidth]))) mod 256)
    else:
      for i in 0..byteWidth-1: recon[i] = scanLine[i]
      for i in byteWidth..len-1:
        # paethPredictor(recon[i - byteWidth], 0, 0) is always recon[i - byteWidth]
        recon[i] = chr((ord(scanLine[i]) + ord(recon[i - byteWidth])) mod 256)

proc unfilter(output: var cstring, input: cstring, w, h, bpp: int) =
  # For PNG filter method 0
  # this function unfilters a single image (e.g. without interlacing this is called once, with Adam7 seven times)
  # output must have enough bytes allocated already, input must have the scanLines + 1 filtertype byte per scanLine
  # w and h are image dimensions or dimensions of reduced image, bpp is bits per pixel
  # input and output are allowed to be the same memory address (but aren't the same size since in has the extra filter bytes)

  var prevLine = cstring(nil)
  var inp = input

  # byteWidth is used for filtering, is 1 when bpp < 8, number of bytes per pixel otherwise
  let byteWidth = (bpp + 7) div 8
  let lineBytes = (w * bpp + 7) div 8

  for y in 0..h-1:
    let outIndex = lineBytes * y
    let inIndex = (1 + lineBytes) * y # the extra filterbyte added to each row
    let filterType = PNGFilter0(input[inindex])
    let scanLine: cstring = addr(inp[inIndex + 1])
    var outp: cstring = addr(output[outIndex])
    unfilterScanLine(outp, scanLine, prevLine, byteWidth, lineBytes, filterType)
    prevLine = addr(output[outIndex])

proc removePaddingBits(output: var cstring, input: cstring, olinebits, ilinebits, h: int) =
  # After filtering there are still padding bits if scanLines have non multiple of 8 bit amounts. They need
  # to be removed (except at last scanLine of (Adam7-reduced) image) before working with pure image buffers
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
# reduced image when without filter bytes but with padded scanLines
# passstart: output containing the index of the start and end of each reduced
# image without padding between scanLines, but still padding between the images
# w, h: width and height of non-interlaced image
# bpp: bits per pixel
# "padded" is only relevant if bpp is less than 8 and a scanLine or image does not
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
    # bits padded if needed to fill full byte at end of each scanLine
    pass.paddedStart[i + 1] = pass.paddedStart[i] + pass.h[i] * ((pass.w[i] * bpp + 7) div 8)
    # only padded at end of reduced image
    pass.start[i + 1] = pass.start[i] + (pass.h[i] * pass.w[i] * bpp + 7) div 8

# input: Adam7 interlaced image, with no padding bits between scanLines, but between
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
      var byteWidth = bpp div 8
      for y in 0..pass.h[i]-1:
        for x in 0..pass.w[i]-1:
          var inStart  = pass.start[i] + (y * pass.w[i] + x) * byteWidth
          var outStart = ((ADAM7_IY[i] + y * ADAM7_DY[i]) * w + ADAM7_IX[i] + x * ADAM7_DX[i]) * byteWidth
          for b in 0..byteWidth-1:
            output[outStart + b] = input[inStart + b]
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
  # into pure 2D image buffer with the PNG's colorType.
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
  var header = PNGHeader(png.getChunk(IHDR))
  var cm = newColorMode(header.colorType, header.bitDepth)
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

proc getInfo*(png: PNG): PNGInfo =
  result = new(PNGInfo)
  result.mode = png.getColorMode()
  var header = PNGHeader(png.getChunk(IHDR))
  result.width = header.width
  result.height = header.height
  var bkgd = PNGBackground(png.getChunk(bKGD))
  if bkgd == nil: result.backgroundDefined = false
  else:
    result.backgroundDefined = true
    result.backgroundR = bkgd.bkgdR
    result.backgroundG = bkgd.bkgdG
    result.backgroundB = bkgd.bkgdB

  var phys = PNGPhys(png.getChunk(pHYs))
  if phys == nil: result.physDefined = false
  else:
    result.physDefined = true
    result.physX = phys.physX
    result.physY = phys.physY
    result.physUnit = phys.unit

  var time = PNGTime(png.getChunk(tIME))
  if time == nil: result.timeDefined = false
  else:
    result.timeDefined = true
    result.year = time.year
    result.month = time.month
    result.day = time.day
    result.hour = time.hour
    result.minute = time.minute
    result.second = time.second

proc getChunkNames*(png: PNG): string =
  result = ""
  var i = 0
  for c in png.chunks:
    result.add ($c.chunkType)
    if i < png.chunks.high: result.add ' '
    inc i

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
    let val = readBitsFromReversedStream(obp, input, mode.bitDepth)
    let value = chr((val * 255) div highest)
    let x = i * 4
    output[x]   = value
    output[x+1] = value
    output[x+2] = value
    if mode.keyDefined and (ord(val) == mode.keyR): output[x+3] = chr(0)
    else: output[x+3] = chr(255)

proc RGBAFromRGB8(output: var cstring, input: cstring, numPixels: int, mode: PNGColorMode) =
  for i in 0..numPixels-1:
    let x = i * 4
    let y = i * 3
    output[x]   = input[y]
    output[x+1] = input[y+1]
    output[x+2] = input[y+2]
    if mode.keyDefined and (mode.keyR == ord(input[y])) and
      (mode.keyG == ord(input[y+1])) and (mode.keyB == ord(input[y+2])): output[x+3] = chr(0)
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

proc hash*(c: RGBA8): Hash =
  var h: Hash = 0
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
  let val = readBitsFromReversedStream(obp, input, mode.bitDepth)
  let value = chr((val * 255) div highest)
  p.r = value
  p.g = value
  p.b = value
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
  p.a = 256 * ord(input[i + 2]) + ord(input[i + 3])

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

proc convert*(output: var cstring, input: cstring, modeOut, modeIn: PNGColorMode, numPixels: int) =
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
  elif(modeOut.bitDepth == 8) and (modeOut.colorType == LCT_RGBA):
    let cvt = getConverterRGBA(modeIn)
    cvt(output, input, numPixels, modeIn)
  elif(modeOut.bitDepth == 8) and (modeOut.colorType == LCT_RGB):
    let cvt = getConverterRGB(modeIn)
    cvt(output, input, numPixels, modeIn)
  else:
    let cvt = getColorRGBA8(modeIn)
    let pxl = getPixelRGBA8(modeOut)
    for px in 0..numPixels-1:
      var p = RGBA8(r:chr(0), g:chr(0), b:chr(0), a:chr(0))
      cvt(p, input, px, modeIn)
      pxl(p, output, px, modeOut, tree)

proc convert*(png: PNG, colorType: PNGcolorType, bitDepth: int): PNGResult =
  #TODO: check if this works according to the statement in the documentation: "The converter can convert
  # from greyscale input color type, to 8-bit greyscale or greyscale with alpha"
  #if(colorType notin {LCT_RGB, LCT_RGBA}) and (bitDepth != 8):
    #raise PNGError("unsupported color mode conversion")

  let header = PNGHeader(png.getChunk(IHDR))
  let modeIn = png.getColorMode()
  let modeOut = newColorMode(colorType, bitDepth)
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

  convert(output, input, modeOut, modeIn, numPixels)

proc decodePNG*(s: Stream, colorType: PNGcolorType, bitDepth: int, settings = PNGDecoder(nil)): PNGResult =
  if not bitDepthAllowed(colorType, bitDepth):
      raise PNGError("colorType and bitDepth combination not allowed")
  var png = s.parsePNG(settings)
  png.postProcessscanLines()

  if PNGDecoder(png.settings).colorConvert:
    result = png.convert(colorType, bitDepth)
  else:
    let header = PNGHeader(png.getChunk(IHDR))
    new(result)
    result.width  = header.width
    result.height = header.height
    result.data   = png.pixels

proc decodePNG*(s: Stream, settings = PNGDecoder(nil)): PNG =
  var png = s.parsePNG(settings)
  png.postProcessscanLines()
  result = png

proc loadPNG*(fileName: string, colorType: PNGcolorType, bitDepth: int, settings: PNGDecoder): PNGResult =
  try:
    var s = newFileStream(fileName, fmRead)
    if s == nil: return nil
    result = s.decodePNG(colorType, bitDepth, settings)
    s.close()
  except:
    debugEcho getCurrentExceptionMsg()
    result = nil

proc loadPNG32*(fileName: string, settings = PNGDecoder(nil)): PNGResult =
  result = loadPNG(fileName, LCT_RGBA, 8, settings)

proc loadPNG24*(fileName: string, settings = PNGDecoder(nil)): PNGResult =
  result = loadPNG(fileName, LCT_RGB, 8, settings)

proc decodePNG32*(input: string, settings = PNGDecoder(nil)): PNGResult =
  try:
    var s = newStringStream(input)
    if s == nil: return nil
    result = s.decodePNG(LCT_RGBA, 8, settings)
  except:
    debugEcho getCurrentExceptionMsg()
    result = nil

proc decodePNG24*(input: string, settings = PNGDecoder(nil)): PNGResult =
  try:
    var s = newStringStream(input)
    if s == nil: return nil
    result = s.decodePNG(LCT_RGB, 8, settings)
  except:
    debugEcho getCurrentExceptionMsg()
    result = nil

#Encoder/Decoder demarcation line-----------------------------

type
  PNGFilterStrategy* = enum
    #every filter at zero
    LFS_ZERO,
    #Use filter that gives minimum sum, as described in the official PNG filter heuristic.
    LFS_MINSUM,
    #Use the filter type that gives smallest Shannon entropy for this scanLine. Depending
    #on the image, this is better or worse than minsum.
    LFS_ENTROPY,
    #Brute-force-search PNG filters by compressing each filter for each scanLine.
    #Experimental, very slow, and only rarely gives better compression than MINSUM.
    LFS_BRUTE_FORCE,
    #use predefined_filters buffer: you specify the filter type for each scanLine
    LFS_PREDEFINED

  PNGKeyText = object
    keyword, text: string

  PNGIText = object
    keyword: string
    text: string
    languageTag: string
    translatedKeyword: string

  PNGUnknown = ref object of PNGChunk
  PNGEnd = ref object of PNGChunk

  PNGEncoder* = ref object of PNGSettings
    #automatically choose output PNG color type. Default: true
    autoConvert*: bool
    modeIn*: PNGColorMode
    modeOut*: PNGColorMode

    #If true, follows the official PNG heuristic: if the PNG uses a palette or lower than
    #8 bit depth, set all filters to zero. Otherwise use the filter_strategy. Note that to
    #completely follow the official PNG heuristic, filter_palette_zero must be true and
    #filter_strategy must be LFS_MINSUM
    filterPaletteZero*: bool

    #Which filter strategy to use when not using zeroes due to filter_palette_zero.
    #Set filter_palette_zero to 0 to ensure always using your chosen strategy. Default: LFS_MINSUM
    filterStrategy*: PNGFilterStrategy

    #used if filter_strategy is LFS_PREDEFINED. In that case, this must point to a buffer with
    #the same length as the amount of scanLines in the image, and each value must <= 5.
    #Don't forget that filter_palette_zero must be set to false to ensure this is also used on palette or low bitdepth images.
    predefinedFilters*: string

    #force creating a PLTE chunk if colorType is 2 or 6 (= a suggested palette).
    #If colorType is 3, PLTE is _always_ created.
    forcePalette*: bool

    #add nimPNG identifier and version as a text chunk, for debugging
    addID*: bool
    #encode text chunks as zTXt chunks instead of tEXt chunks, and use compression in iTXt chunks
    textCompression*: bool
    textList*: seq[PNGKeyText]
    itextList*: seq[PNGIText]

    interlaceMethod*: PNGInterlace

    backgroundDefined*: bool
    backgroundR*, backgroundG*, backgroundB*: int

    physDefined*: bool
    physX*, physY*, physUnit*: int

    timeDefined*: bool
    year*: int   #range[0..65535]
    month*: int  #range[1..12]
    day*: int    #range[1..31]
    hour*: int   #range[0..23]
    minute*: int #range[0..59]
    second*: int #range[0..60] #to allow for leap seconds

    unknown*: seq[PNGUnknown]

  PNGColorProfile = ref object
    colored: bool #not greyscale
    key: bool #if true, image is not opaque. Only if true and alpha is false, color key is possible.
    keyR, keyG, keyB: int #these values are always in 16-bit bitdepth in the profile
    alpha: bool #alpha channel or alpha palette required
    numColors: int #amount of colors, up to 257. Not valid if bits == 16.
    palette: seq[RGBA8] #Remembers up to the first 256 RGBA colors, in no particular order
    bits: int #bits per channel (not for palette). 1,2 or 4 for greyscale only. 16 if 16-bit per channel required.

proc makePNGEncoder*(): PNGEncoder =
  var s: PNGEncoder
  s = new(PNGEncoder)
  s.filterPaletteZero = true
  s.filterStrategy = LFS_MINSUM
  s.autoConvert = true
  s.modeIn = newColorMode()
  s.modeOut = newColorMode()
  s.forcePalette = false
  s.predefinedFilters = nil
  s.addID = false
  s.textCompression = true
  s.interlaceMethod = IM_NONE
  s.backgroundDefined = false
  s.backgroundR = 0
  s.backgroundG = 0
  s.backgroundB = 0
  s.physDefined = false
  s.physX = 0
  s.physY = 0
  s.physUnit = 0
  s.timeDefined = false
  s.textList = @[]
  s.itextList = @[]
  s.unknown = @[]
  result = s

proc addText*(state: PNGEncoder, keyword, text: string) =
  state.textList.add PNGKeyText(keyword: keyword, text: text)

proc addIText*(state: PNGEncoder, keyword, langtag, transkey, text: string) =
  var itext: PNGIText
  itext.keyword = keyword
  itext.text = text
  itext.languageTag = langtag
  itext.translatedKeyword = transkey
  state.itextList.add itext

proc make[T](chunkType: PNGChunkType, estimateSize: int): T =
  result = new(T)
  result.chunkType = chunkType
  if estimateSize > 0: result.data = newStringOfCap(estimateSize)
  else: result.data = ""

proc addUnknownChunk*(state: PNGEncoder, chunkType, data: string) =
  assert chunkType.len == 4
  var chunk = make[PNGUnknown](makeChunkType(chunkType), 0)
  chunk.data = data
  state.unknown.add chunk

proc makeColorProfile(): PNGColorProfile =
  new(result)
  result.colored = false
  result.key = false
  result.alpha = false
  result.keyR = 0
  result.keyG = 0
  result.keyB = 0
  result.numcolors = 0
  result.bits = 1
  result.palette = @[]

proc writeByte(s: PNGChunk, val: int) = s.data.add chr(val)
proc writeString(s: PNGChunk, val: string) = s.data.add val

proc writeInt32(s: PNGChunk, val: int) =
  s.writeByte((val shr 24) and 0xff)
  s.writeByte((val shr 16) and 0xff)
  s.writeByte((val shr 8) and 0xff)
  s.writeByte(val and 0xff)

proc writeInt16(s: PNGChunk, val: int) =
  s.writeByte((val shr 8) and 0xff)
  s.writeByte(val and 0xff)

proc writeInt32BE(s: Stream, value: int) =
  var val = cast[int32](value)
  var tmp: int32
  bigEndian32(addr(tmp), addr(val))
  s.write(tmp)

method writeChunk(chunk: PNGChunk, png: PNG): bool {.base.} = true

method writeChunk(chunk: PNGHeader, png: PNG): bool =
  #estimate 13 bytes
  chunk.writeInt32(chunk.width)
  chunk.writeInt32(chunk.height)
  chunk.writeByte(chunk.bitDepth)
  chunk.writeByte(int(chunk.colorType))
  chunk.writeByte(chunk.compressionMethod)
  chunk.writeByte(chunk.filterMethod)
  chunk.writeByte(int(chunk.interlaceMethod))
  result = true

method writeChunk(chunk: PNGPalette, png: PNG): bool =
  #estimate 3 * palette.len
  for px in chunk.palette:
    chunk.writeByte(int(px.r))
    chunk.writeByte(int(px.g))
    chunk.writeByte(int(px.b))
  result = true

method writeChunk(chunk: PNGTrans, png: PNG): bool =
  var header = PNGHeader(png.getChunk(IHDR))

  if header.colorType == LCT_PALETTE:
    #estimate plte.palette.len
    var plte = PNGPalette(png.getChunk(PLTE))
    #the tail of palette values that all have 255 as alpha, does not have to be encoded
    var amount = plte.palette.len
    for i in countdown(amount-1, 0):
      if plte.palette[i].a == chr(255): dec amount
      else: break
    for i in 0..amount-1: chunk.writeByte(int(plte.palette[i].a))
  elif header.colorType == LCT_GREY:
    #estimate 2 bytes
    if chunk.keyR != -1: chunk.writeInt16(chunk.keyR)
  elif header.colorType == LCT_RGB:
    #estimate 6 bytes
    if chunk.keyR != -1:
      chunk.writeInt16(chunk.keyR)
      chunk.writeInt16(chunk.keyG)
      chunk.writeInt16(chunk.keyB)
  else:
    raise PNGError("tRNS chunk not allowed for other color models")
  result = true

method writeChunk(chunk: PNGBackground, png: PNG): bool =
  var header = PNGHeader(png.getChunk(IHDR))
  if header.colorType == LCT_PALETTE:
    #estimate 1 bytes
    chunk.writeByte(chunk.bkgdR)
  if header.colorType in {LCT_GREY, LCT_GREY_ALPHA}:
    #estimate 2 bytes
    chunk.writeInt16(chunk.bkgdR)
  elif header.colorType in {LCT_RGB, LCT_RGBA}:
    #estimate 6 bytes
    chunk.writeInt16(chunk.bkgdR)
    chunk.writeInt16(chunk.bkgdG)
    chunk.writeInt16(chunk.bkgdB)
  result = true

method writeChunk(chunk: PNGTime, png: PNG): bool =
  #estimate 7 bytes
  chunk.writeInt16(chunk.year)
  chunk.writeByte(chunk.month)
  chunk.writeByte(chunk.day)
  chunk.writeByte(chunk.hour)
  chunk.writeByte(chunk.minute)
  chunk.writeByte(chunk.second)
  result = true

method writeChunk(chunk: PNGPhys, png: PNG): bool =
  #estimate 9 bytes
  chunk.writeInt32(chunk.physX)
  chunk.writeInt32(chunk.physY)
  chunk.writeByte(chunk.unit)
  result = true

method writeChunk(chunk: PNGText, png: PNG): bool =
  #estimate chunk.keyword.len + chunk.text.len + 1
  chunk.writeString chunk.keyword
  chunk.writeByte 0 #null separator
  chunk.writeString chunk.text
  result = true

method writeChunk(chunk: PNGGamma, png: PNG): bool =
  #estimate 4 bytes
  chunk.writeInt32(chunk.gamma)
  result = true

method writeChunk(chunk: PNGChroma, png: PNG): bool =
  #estimate 8 * 4 bytes
  chunk.writeInt32(chunk.whitePointX)
  chunk.writeInt32(chunk.whitePointY)
  chunk.writeInt32(chunk.redX)
  chunk.writeInt32(chunk.redY)
  chunk.writeInt32(chunk.greenX)
  chunk.writeInt32(chunk.greenY)
  chunk.writeInt32(chunk.blueX)
  chunk.writeInt32(chunk.blueY)
  result = true

method writeChunk(chunk: PNGStandarRGB, png: PNG): bool =
  #estimate 1 byte
  chunk.writeByte(chunk.renderingIntent)
  result = true

method writeChunk(chunk: PNGSPalette, png: PNG): bool =
  #estimate chunk.paletteName.len + 2
  #if sampleDepth == 8: estimate += chunk.palette.len * 6
  #else: estimate += chunk.palette.len * 10
  chunk.writeString chunk.paletteName
  chunk.writeByte 0 #null separator
  if chunk.sampleDepth notin {8, 16}: raise PNGError("palette sample depth error")
  chunk.writeByte chunk.sampleDepth

  if chunk.sampleDepth == 8:
    for p in chunk.palette:
      chunk.writeByte(p.red)
      chunk.writeByte(p.green)
      chunk.writeByte(p.blue)
      chunk.writeByte(p.alpha)
      chunk.writeInt16(p.frequency)
  else: # chunk.sampleDepth == 16:
    for p in chunk.palette:
      chunk.writeInt16(p.red)
      chunk.writeInt16(p.green)
      chunk.writeInt16(p.blue)
      chunk.writeInt16(p.alpha)
      chunk.writeInt16(p.frequency)
  result = true
  
method writeChunk(chunk: PNGHist, png: PNG): bool =
  #estimate chunk.histogram.len * 2
  for c in chunk.histogram:
    chunk.writeInt16 c
  result = true

method writeChunk(chunk: PNGData, png: PNG): bool =
  var nz = nzDeflateInit(chunk.idat)
  chunk.data = zlib_compress(nz)
  result = true

method writeChunk(chunk: PNGZtxt, png: PNG): bool =
  #estimate chunk.keyword.len + 2
  chunk.writeString chunk.keyword
  chunk.writeByte 0 #null separator
  chunk.writeByte 0 #compression method(0: deflate)
  var nz = nzDeflateInit(chunk.text)
  chunk.writeString zlib_compress(nz)
  result = true

method writeChunk(chunk: PNGItxt, png: PNG): bool =
  #estimate chunk.keyword.len + 2
  # + chunk.languageTag.len + chunk.translatedKeyword.len
  let state = PNGEncoder(png.settings)
  var compressed: int
  var text: string
  if state.textCompression:
    var nz = nzDeflateInit(chunk.text)
    var zz = zlib_compress(nz)
    if zz.len >= chunk.text.len:
      compressed = 0
      text = chunk.text
    else:
      compressed = 1
      text = zz
  else:
    compressed = 0
    text = chunk.text

  chunk.writeString chunk.keyword
  chunk.writeByte 0 #null separator
  chunk.writeByte compressed #compression flag(0: uncompressed, 1: compressed)
  chunk.writeByte 0 #compression method(0: deflate)
  chunk.writeString chunk.languageTag
  chunk.writeByte 0 #null separator
  chunk.writeString chunk.translatedKeyword
  chunk.writeByte 0 #null separator
  chunk.writeString text
  result = true

method writeChunk(chunk: PNGICCProfile, png: PNG): bool =
  #estimate chunk.profileName.len + 2
  chunk.writeString chunk.profileName
  chunk.writeByte 0 #null separator
  chunk.writeByte 0 #compression method(0: deflate)
  var nz = nzDeflateInit(chunk.profile)
  chunk.writeString zlib_compress(nz)
  result = true
  
proc isGreyscaleType(mode: PNGColorMode): bool =
  result = mode.colorType in {LCT_GREY, LCT_GREY_ALPHA}

proc isAlphaType(mode: PNGColorMode): bool =
  result = mode.colorType in {LCT_RGBA, LCT_GREY_ALPHA}

#proc isPaletteType(mode: PNGColorMode): bool =
#  result = mode.colorType == LCT_PALETTE

proc hasPaletteAlpha(mode: PNGColorMode): bool =
  for p in mode.palette:
    if ord(p.a) < 255: return true
  result = false

proc canHaveAlpha(mode: PNGColorMode): bool =
  result = mode.keyDefined or isAlphaType(mode) or hasPaletteAlpha(mode)

#Returns how many bits needed to represent given value (max 8 bit)*/
proc getValueRequiredBits(value: int): int =
  if(value == 0) or (value == 255): return 1
  #The scaling of 2-bit and 4-bit values uses multiples of 85 and 17
  if(value mod 17) == 0:
    if (value mod 85) == 0: return 2
    else: return 4
  result = 8

proc differ(p: RGBA16): bool =
  # first and second byte differ
  if (p.r and 255) != ((p.r shr 8) and 255): return true
  if (p.g and 255) != ((p.g shr 8) and 255): return true
  if (p.b and 255) != ((p.b shr 8) and 255): return true
  if (p.a and 255) != ((p.a shr 8) and 255): return true
  result = false

proc getColorProfile(input: string, w, h: int, mode: PNGColorMode): PNGColorProfile =
  var prof = makeColorProfile()
  let
    numPixels = w * h
    bpp = getBPP(mode)

  var
    coloredDone = isGreyscaleType(mode)
    alphaDone   = not canHaveAlpha(mode)
    bitsDone = bpp == 1
    numColorsDone = false
    sixteen = false
    maxNumColors = 257
    tree = initTable[RGBA8, int]()

  if bpp <= 8:
    case bpp
    of 1: maxNumColors = 2
    of 2: maxNumColors = 4
    of 4: maxNumColors = 16
    else: maxNumColors = 256

  #Check if the 16-bit input is truly 16-bit
  if mode.bitDepth == 16:
    let cvt = getColorRGBA16(mode)
    var p = RGBA16(r:0, g:0, b:0, a:0)

    for px in 0..numPixels-1:
      cvt(p, cstring(input), px, mode)
      if p.differ():
        sixteen = true
        break

  if sixteen:
    let cvt = getColorRGBA16(mode)
    var p = RGBA16(r:0, g:0, b:0, a:0)
    prof.bits = 16
    #counting colors no longer useful, palette doesn't support 16-bit
    bitsDone = true
    numColorsDone = true

    for px in 0..numPixels-1:
      cvt(p, cstring(input), px, mode)
      if not coloredDone and ((p.r != p.g) or (p.r != p.b)):
        prof.colored = true
        coloredDone = true

      if not alphaDone:
        let matchKey = (int(p.r) == prof.keyR and
          int(p.g) == prof.keyG and int(p.b) == prof.keyB)

        if(p.a != 65535) and (p.a != 0 or (prof.key and not matchKey)):
          prof.alpha = true
          alphaDone = true
          if prof.bits < 8: prof.bits = 8 #PNG has no alphachannel modes with less than 8-bit per channel
        elif(p.a == 0) and not prof.alpha and not prof.key:
          prof.key = true
          prof.keyR = int(p.r)
          prof.keyG = int(p.g)
          prof.keyB = int(p.b)
        elif(p.a == 65535) and prof.key and matchKey:
          # Color key cannot be used if an opaque pixel also has that RGB color.
          prof.alpha = true
          alphaDone = true

      if alphaDone and numColorsDone and coloredDone and bitsDone: break
  else: # < 16-bit
    let cvt = getColorRGBA8(mode)
    for px in 0..numPixels-1:
      var p = RGBA8(r:chr(0), g:chr(0), b:chr(0), a:chr(0))
      cvt(p, cstring(input), px, mode)
      if (not bitsDone) and (prof.bits < 8):
        #only r is checked, < 8 bits is only relevant for greyscale
        let bits = getValueRequiredBits(int(p.r))
        if bits > prof.bits: prof.bits = bits
      bitsDone = prof.bits >= bpp

      if (not coloredDone) and ((p.r != p.g) or (p.r != p.b)):
        prof.colored = true
        coloredDone = true
        if prof.bits < 8: prof.bits = 8 #PNG has no colored modes with less than 8-bit per channel

      if not alphaDone:
        let matchKey = ((int(p.r) == prof.keyR) and
          (int(p.g) == prof.keyG) and (int(p.b) == prof.keyB))

        if(p.a != chr(255)) and (p.a != chr(0) or (prof.key and (not matchKey))):
          prof.alpha = true
          alphaDone = true
          if prof.bits < 8: prof.bits = 8 #PNG has no alphachannel modes with less than 8-bit per channel
        elif(p.a == chr(0)) and not prof.alpha and not prof.key:
          prof.key = true
          prof.keyR = int(p.r)
          prof.keyG = int(p.g)
          prof.keyB = int(p.b)
        elif(p.a == chr(255)) and prof.key and matchKey:
          #Color key cannot be used if an opaque pixel also has that RGB color.
          prof.alpha = true
          alphaDone = true
          if prof.bits < 8: prof.bits = 8 #PNG has no alphachannel modes with less than 8-bit per channel

      if not numColorsDone:
        if not tree.hasKey(p):
          tree[p] = prof.numColors
          if prof.numColors < 256: prof.palette.add p
          inc prof.numColors
          numColorsDone = prof.numColors >= maxNumColors
      if alphaDone and numColorsDone and coloredDone and bitsDone: break

    # make the profile's key always 16-bit for consistency - repeat each byte twice
    prof.keyR += prof.keyR shl 8
    prof.keyG += prof.keyG shl 8
    prof.keyB += prof.keyB shl 8
  result = prof

#Automatically chooses color type that gives smallest amount of bits in the
#output image, e.g. grey if there are only greyscale pixels, palette if there
#are less than 256 colors, ...
#Updates values of mode with a potentially smaller color model. mode_out should
#contain the user chosen color model, but will be overwritten with the new chosen one.
proc autoChooseColor(modeOut: PNGColorMode, input: string, w, h: int, modeIn: PNGColorMode) =
  var prof = getColorProfile(input, w, h, modeIn)
  modeOut.keyDefined = false

  if prof.key and ((w * h) <= 16):
    prof.alpha = true #too few pixels to justify tRNS chunk overhead
    if prof.bits < 8: prof.bits = 8 #PNG has no alphachannel modes with less than 8-bit per channel

  #grey without alpha, with potentially low bits
  let greyOk = not prof.colored and  not prof.alpha
  let n = prof.numColors

  var paletteBits = 0
  if n <= 2: paletteBits = 1
  elif n <= 4: paletteBits = 2
  elif n <= 16: paletteBits = 4
  else: paletteBits = 8
  var paletteOk = (n <= 256) and ((n * 2) < (w * h)) and prof.bits <= 8
  #don't add palette overhead if image has only a few pixels
  if (w * h) < (n * 2): paletteOk = false
  #grey is less overhead
  if greyOk and (prof.bits <= palettebits): paletteOk = false

  if paletteOk:
    modeOut.paletteSize = prof.palette.len
    modeOut.palette   = prof.palette
    modeOut.colorType = LCT_PALETTE
    modeOut.bitDepth  = paletteBits

    if(modeIn.colorType == LCT_PALETTE) and (modeIn.palettesize >= modeOut.palettesize) and
      (modeIn.bitdepth == modeOut.bitdepth):
      #If input should have same palette colors, keep original to preserve its order and prevent conversion
      modeIn.copyTo(modeOut)
  else: #8-bit or 16-bit per channel
    modeOut.bitDepth = prof.bits
    if prof.alpha:
      if prof.colored: modeOut.colorType = LCT_RGBA
      else: modeOut.colorType = LCT_GREY_ALPHA
    else:
      if prof.colored: modeOut.colorType = LCT_RGB
      else: modeOut.colorType = LCT_GREY

    if prof.key and not prof.alpha:
      #profile always uses 16-bit, mask converts it
      let mask = (1 shl modeOut.bitDepth) - 1
      modeOut.keyR = prof.keyR and mask
      modeOut.keyG = prof.keyG and mask
      modeOut.keyB = prof.keyB and mask
      modeOut.keyDefined = true

proc addPaddingBits(output: var cstring, input: cstring, olinebits, ilinebits, h: int) =
  #The opposite of the removePaddingBits function
  #olinebits must be >= ilinebits

  let diff = olinebits - ilinebits
  var
    obp = 0
    ibp = 0 #bit pointers

  for y in 0..h-1:
    for x in 0..ilinebits-1:
      let bit = readBitFromReversedStream(ibp, input)
      setBitOfReversedStream(obp, output, bit)
    for x in 0..diff-1: setBitOfReversedStream(obp, output, 0)

proc filterScanLine(output: var cstring, scanLine, prevLine: cstring, len, byteWidth: int, filterType: PNGFilter0) =

  case filterType
  of FLT_NONE:
    for i in 0..len-1: output[i] = scanLine[i]
  of FLT_SUB:
    for i in 0..byteWidth-1: output[i] = scanLine[i]
    for i in byteWidth..len-1:
      output[i] = chr(scanLine[i].uint8 - scanLine[i - byteWidth].uint8)
  of FLT_UP:
    if prevLine != nil:
      for i in 0..len-1:
        output[i] = chr(scanLine[i].uint8 - prevLine[i].uint8)
    else:
      for i in 0..len-1: output[i] = scanLine[i]
  of FLT_AVERAGE:
    if prevLine != nil:
      for i in 0..byteWidth-1:
        output[i] = chr(scanLine[i].uint8 - (prevLine[i].uint8 div 2))
      for i in byteWidth..len-1:
        output[i] = chr(scanLine[i].uint8 - ((scanLine[i - byteWidth].uint8 + prevLine[i].uint8) div 2))
    else:
      for i in 0..byteWidth-1: output[i] = scanLine[i]
      for i in byteWidth..len-1:
        output[i] = chr(scanLine[i].uint8 - (scanLine[i - byteWidth].uint8 div 2))
  of FLT_PAETH:
    if prevLine != nil:
      #paethPredictor(0, prevLine[i], 0) is always prevLine[i]
      for i in 0..byteWidth-1:
        output[i] = chr(scanLine[i].uint8 - prevLine[i].uint8)
      for i in byteWidth..len-1:
        output[i] = chr(scanLine[i].uint8 - paethPredictor(ord(scanLine[i - byteWidth]), ord(prevLine[i]), ord(prevLine[i - byteWidth])).uint8)
    else:
      for i in 0..byteWidth-1: output[i] = scanLine[i]
      #paethPredictor(scanLine[i - byteWidth], 0, 0) is always scanLine[i - byteWidth]
      for i in byteWidth..len-1:
        output[i] = chr(scanLine[i].uint8 - scanLine[i - byteWidth].uint8)
  else:
    raise PNGError("unsupported fitler type")

proc filterZero(output: var cstring, input: cstring, w, h, bpp: int) =
  #the width of a scanline in bytes, not including the filter type
  let lineBytes = (w * bpp + 7) div 8
  #byteWidth is used for filtering, is 1 when bpp < 8, number of bytes per pixel otherwise
  let byteWidth = (bpp + 7) div 8
  var prevLine: cstring = nil
  var inp = input

  for y in 0..h-1:
    let outindex = (1 + lineBytes) * y #the extra filterbyte added to each row
    let inindex = lineBytes * y
    output[outindex] = chr(int(FLT_NONE)) #filter type byte
    var outp: cstring = addr(output[outindex + 1])
    let scanLine: cstring = addr(inp[inindex])
    filterScanLine(outp, scanLine, prevLine, lineBytes, byteWidth, FLT_NONE)
    prevLine = addr(inp[inindex])

proc filterMinsum(output: var cstring, input: cstring, w, h, bpp: int) =
  let lineBytes = (w * bpp + 7) div 8
  let byteWidth = (bpp + 7) div 8

  #adaptive filtering
  var sum = [0, 0, 0, 0, 0]
  var smallest = 0

  #five filtering attempts, one for each filter type
  var attempt: array[0..4, string]
  var bestType = 0
  var inp = input
  var prevLine: cstring = nil

  for i in 0..attempt.high:
    attempt[i] = newString(lineBytes)

  for y in 0..h-1:
    #try the 5 filter types
    for fType in 0..4:
      var outp = cstring(attempt[fType])
      filterScanLine(outp, addr(inp[y * lineBytes]), prevLine, lineBytes, byteWidth, PNGFilter0(fType))
      #calculate the sum of the result
      sum[fType] = 0
      if fType == 0:
        for x in 0..lineBytes-1:
          sum[fType] += ord(attempt[fType][x])
      else:
        for x in 0..lineBytes-1:
          #For differences, each byte should be treated as signed, values above 127 are negative
          #(converted to signed char). Filtertype 0 isn't a difference though, so use unsigned there.
          #This means filtertype 0 is almost never chosen, but that is justified.
          let s = ord(attempt[fType][x])
          if s < 128: sum[fType] += s
          else: sum[fType] += (255 - s)

      #check if this is smallest sum (or if type == 0 it's the first case so always store the values)*/
      if(fType == 0) or (sum[fType] < smallest):
        bestType = fType
        smallest = sum[fType]

    prevLine = addr(inp[y * lineBytes])
    #now fill the out values
    #the first byte of a scanline will be the filter type
    output[y * (lineBytes + 1)] = chr(bestType)
    for x in 0..lineBytes-1:
      output[y * (lineBytes + 1) + 1 + x] = attempt[bestType][x]

proc filterEntropy(output: var cstring, input: cstring, w, h, bpp: int) =
  let lineBytes = (w * bpp + 7) div 8
  let byteWidth = (bpp + 7) div 8
  var inp = input
  var prevLine: cstring = nil

  var sum: array[0..4, float]
  var smallest = 0.0
  var bestType = 0
  var attempt: array[0..4, string]
  var count: array[0..255, int]

  for i in 0..attempt.high:
    attempt[i] = newString(lineBytes)

  for y in 0..h-1:
    #try the 5 filter types
    for fType in 0..4:
      var outp = cstring(attempt[fType])
      filterScanLine(outp, addr(inp[y * lineBytes]), prevLine, lineBytes, byteWidth, PNGFilter0(fType))
      for x in 0..255: count[x] = 0
      for x in 0..lineBytes-1:
        inc count[ord(attempt[fType][x])]
      inc count[fType] #the filter type itself is part of the scanline
      sum[fType] = 0
      for x in 0..255:
        let p = float(count[x]) / float(lineBytes + 1)
        if count[x] != 0: sum[fType] += log2(1 / p) * p

      #check if this is smallest sum (or if type == 0 it's the first case so always store the values)
      if (fType == 0) or (sum[fType] < smallest):
        bestType = fType
        smallest = sum[fType]

    prevLine = addr(inp[y * lineBytes])
    #now fill the out values*/
    #the first byte of a scanline will be the filter type
    output[y * (lineBytes + 1)] = chr(bestType)
    for x in 0..lineBytes-1:
      output[y * (lineBytes + 1) + 1 + x] = attempt[bestType][x]

proc filterPredefined(output: var cstring, input: cstring, w, h, bpp: int, state: PNGEncoder) =
  let lineBytes = (w * bpp + 7) div 8
  let byteWidth = (bpp + 7) div 8
  var inp = input
  var prevLine: cstring = nil

  for y in 0..h-1:
    let outindex = (1 + lineBytes) * y #the extra filterbyte added to each row
    let inindex = lineBytes * y
    let fType = ord(state.predefinedFilters[y])
    output[outindex] = chr(fType) #filter type byte
    var outp: cstring = addr(output[outindex + 1])
    filterScanLine(outp, addr(inp[inindex]), prevLine, lineBytes, byteWidth, PNGFilter0(fType))
    prevLine = addr(inp[inindex])

proc filterBruteForce(output: var cstring, input: cstring, w, h, bpp: int) =
  let lineBytes = (w * bpp + 7) div 8
  let byteWidth = (bpp + 7) div 8
  var inp = input
  var prevLine: cstring = nil

  #brute force filter chooser.
  #deflate the scanline after every filter attempt to see which one deflates best.
  #This is very slow and gives only slightly smaller, sometimes even larger, result*/

  var size: array[0..4, int]
  var attempt: array[0..4, string] #five filtering attempts, one for each filter type
  var smallest = 0
  var bestType = 0

  #use fixed tree on the attempts so that the tree is not adapted to the filtertype on purpose,
  #to simulate the true case where the tree is the same for the whole image. Sometimes it gives
  #better result with dynamic tree anyway. Using the fixed tree sometimes gives worse, but in rare
  #cases better compression. It does make this a bit less slow, so it's worth doing this.

  for i in 0..attempt.high:
    attempt[i] = newString(lineBytes)

  for y in 0..h-1:
    #try the 5 filter types
    for fType in 0..4:
      #let testSize = attempt[fType].len
      var outp = cstring(attempt[fType])
      filterScanline(outp, addr(inp[y * lineBytes]), prevLine, lineBytes, byteWidth, PNGFilter0(fType))
      size[fType] = 0

      var nz = nzDeflateInit(attempt[fType])
      let data = zlib_compress(nz)
      size[fType] = data.len

      #check if this is smallest size (or if type == 0 it's the first case so always store the values)
      if(fType == 0) or (size[fType] < smallest):
        bestType = fType
        smallest = size[fType]

    prevLine = addr(inp[y * lineBytes])
    output[y * (lineBytes + 1)] = chr(bestType) #the first byte of a scanline will be the filter type
    for x in 0..lineBytes-1:
      output[y * (lineBytes + 1) + 1 + x] = attempt[bestType][x]

proc filter(output: var cstring, input: cstring, w, h: int, modeOut: PNGColorMode, state: PNGEncoder) =
  #For PNG filter method 0
  #out must be a buffer with as size: h + (w * h * bpp + 7) / 8, because there are
  #the scanlines with 1 extra byte per scanline

  let bpp = getBPP(modeOut)
  var strategy = state.filterStrategy

  #There is a heuristic called the minimum sum of absolute differences heuristic, suggested by the PNG standard:
  # *  If the image type is Palette, or the bit depth is smaller than 8, then do not filter the image (i.e.
  #    use fixed filtering, with the filter None).
  # * (The other case) If the image type is Grayscale or RGB (with or without Alpha), and the bit depth is
  #   not smaller than 8, then use adaptive filtering heuristic as follows: independently for each row, apply
  #   all five filters and select the filter that produces the smallest sum of absolute values per row.
  #This heuristic is used if filter strategy is LFS_MINSUM and filter_palette_zero is true.

  #If filter_palette_zero is true and filter_strategy is not LFS_MINSUM, the above heuristic is followed,
  #but for "the other case", whatever strategy filter_strategy is set to instead of the minimum sum
  #heuristic is used.
  if state.filterPaletteZero and
    (modeOut.colorType == LCT_PALETTE or modeOut.bitDepth < 8): strategy = LFS_ZERO

  if bpp == 0:
    raise PNGError("invalid color type")

  case strategy
  of LFS_ZERO: filterZero(output, input, w, h, bpp)
  of LFS_MINSUM: filterMinsum(output, input, w, h, bpp)
  of LFS_ENTROPY: filterEntropy(output, input, w, h, bpp)
  of LFS_BRUTE_FORCE: filterBruteForce(output, input, w, h, bpp)
  of LFS_PREDEFINED: filterPredefined(output, input, w, h, bpp, state)

#input: non-interlaced image with size w*h
#output: the same pixels, but re-ordered according to PNG's Adam7 interlacing, with
# no padding bits between scanlines, but between reduced images so that each
# reduced image starts at a byte.
#bpp: bits per pixel
#there are no padding bits, not between scanlines, not between reduced images
#in has the following size in bits: w * h * bpp.
#output is possibly bigger due to padding bits between reduced images
#NOTE: comments about padding bits are only relevant if bpp < 8
proc Adam7Interlace(output: var cstring, input: cstring, w, h, bpp: int) =
  var pass: PNGPass
  Adam7PassValues(pass, w, h, bpp)

  if bpp >= 8:
    for i in 0..6:
      let byteWidth = bpp div 8
      for y in 0..pass.h[i]-1:
        for x in 0..pass.w[i]-1:
          let inStart = ((ADAM7_IY[i] + y * ADAM7_DY[i]) * w + ADAM7_IX[i] + x * ADAM7_DX[i]) * byteWidth
          let outStart = pass.start[i] + (y * pass.w[i] + x) * byteWidth
          for b in 0..byteWidth-1:
            output[outStart + b] = input[inStart + b]
  else: #bpp < 8: Adam7 with pixels < 8 bit is a bit trickier: with bit pointers
    for i in 0..6:
      let ilinebits = bpp * pass.w[i]
      let olinebits = bpp * w
      var obp, ibp: int #bit pointers (for out and in buffer)
      for y in 0..pass.h[i]-1:
        for x in 0..pass.w[i]-1:
          ibp = (ADAM7_IY[i] + y * ADAM7_DY[i]) * olinebits + (ADAM7_IX[i] + x * ADAM7_DX[i]) * bpp
          obp = (8 * pass.start[i]) + (y * ilinebits + x * bpp)
          for b in 0..bpp-1:
            let bit = readBitFromReversedStream(ibp, input)
            setBitOfReversedStream(obp, output, bit)

proc preProcessScanLines(png: PNG, input: cstring, w, h: int, modeOut: PNGColorMode, state: PNGEncoder) =
  #This function converts the pure 2D image with the PNG's colorType, into filtered-padded-interlaced data. Steps:
  # if no Adam7: 1) add padding bits (= posible extra bits per scanLine if bpp < 8) 2) filter
  # if adam7: 1) Adam7_interlace 2) 7x add padding bits 3) 7x filter
  let bpp = getBPP(modeOut)

  if state.interlaceMethod == IM_NONE:
    #image size plus an extra byte per scanLine + possible padding bits
    let scanLen = (w * bpp + 7) div 8
    let outSize = h + (h * scanLen)
    png.pixels = newString(outSize)
    var output = cstring(png.pixels)
    #non multiple of 8 bits per scanLine, padding bits needed per scanLine
    if(bpp < 8) and ((w * bpp) != (scanLen * 8)):
      var padded = newString(h * scanLen)
      var padding = cstring(padded)
      addPaddingBits(padding, input, scanLen * 8, w * bpp, h)

      filter(output, padding, w, h, modeOut, state)
    else:
      #we can immediatly filter into the out buffer, no other steps needed
      filter(output, input, w, h, modeOut, state)

  else: #interlaceMethod is 1 (Adam7)
    var pass: PNGPass
    Adam7PassValues(pass, w, h, bpp)
    let outSize = pass.filterStart[7]
    png.pixels = newString(outSize)
    var adam7buf = newString(pass.start[7])
    var adam7 = cstring(adam7buf)
    var output = cstring(png.pixels)

    Adam7Interlace(adam7, input, w, h, bpp)
    for i in 0..6:
      if bpp < 8:
        var padded = newString(pass.paddedStart[i + 1] - pass.paddedStart[i])
        var padding = cstring(padded)
        addPaddingBits(padding, addr(adam7[pass.start[i]]), ((pass.w[i] * bpp + 7) div 8) * 8, pass.w[i] * bpp, pass.h[i])
        var outp:cstring = addr(output[pass.filterStart[i]])
        filter(outp, padding, pass.w[i], pass.h[i], modeOut, state)
      else:
        var outp:cstring = addr(output[pass.filterStart[i]])
        filter(outp, addr(adam7[pass.paddedStart[i]]), pass.w[i], pass.h[i], modeOut, state)

#palette must have 4 * palettesize bytes allocated, and given in format RGBARGBARGBARGBA...
#returns 0 if the palette is opaque,
#returns 1 if the palette has a single color with alpha 0 ==> color key
#returns 2 if the palette is semi-translucent.
proc getPaletteTranslucency(modeOut: PNGColorMode): int =
  var key = 0
  #the value of the color with alpha 0, so long as color keying is possible
  var p: RGBA8
  var i = 0
  while i < modeOut.paletteSize:
    let x = modeOut.palette[i]
    if (key == 0) and (x.a == chr(0)):
      p = x
      key = 1
      i = -1 #restart from beginning, to detect earlier opaque colors with key's value
    elif x.a != chr(255): return 2
    #when key, no opaque RGB may have key's RGB*/
    elif(key != 0) and (p.r == x.r) and (p.g == x.g) and (p.b == x.g): return 2
    inc i

  result = key

proc addChunkIHDR(png: PNG, w,h: int, modeOut: PNGColorMode, state: PNGEncoder) =
  var chunk = make[PNGHeader](IHDR, 13)
  chunk.width = w
  chunk.height = h
  chunk.bitDepth = modeOut.bitDepth
  chunk.colorType = modeOut.colorType
  chunk.compressionMethod = 0
  chunk.filterMethod = 0
  chunk.interlaceMethod = state.interlaceMethod
  png.chunks.add chunk

proc addChunkPLTE(png: PNG, modeOut: PNGColorMode) =
  if modeOut.paletteSize == 0: return
  var chunk = make[PNGPalette](PLTE, 3 * modeOut.paletteSize)
  chunk.palette = modeOut.palette
  png.chunks.add chunk

proc addChunktRNS(png: PNG, modeOut: PNGColorMode) =
  var chunk = make[PNGTrans](tRNS, 2)

  if modeOut.colorType == LCT_PALETTE:
    var plte = png.getChunk(PLTE)
    doAssert plte != nil
  elif modeOut.colorType == LCT_GREY:
    if modeOut.keyDefined:
      chunk.keyR = modeOut.keyR
    else:
      chunk.keyR = -1
  elif modeOut.colorType == LCT_RGB:
    if modeOut.keyDefined:
      chunk.keyR = modeOut.keyR
      chunk.keyG = modeOut.keyG
      chunk.keyB = modeOut.keyB
    else:
      chunk.keyR = -1
  png.chunks.add chunk

proc addChunkbKGD(png: PNG, modeOut: PNGColorMode, state: PNGEncoder) =
  var chunk = make[PNGBackground](bKGD, 6)
  if modeOut.colorType == LCT_PALETTE:
    #estimate 1 bytes
    chunk.bkgdR = state.backgroundR
  if modeOut.colorType in {LCT_GREY, LCT_GREY_ALPHA}:
    #estimate 2 bytes
    chunk.bkgdR = state.backgroundR
  elif modeOut.colorType in {LCT_RGB, LCT_RGBA}:
    #estimate 6 bytes
    chunk.bkgdR = state.backgroundR
    chunk.bkgdG = state.backgroundG
    chunk.bkgdB = state.backgroundB
  png.chunks.add chunk

proc addChunkpHYs(png: PNG, state: PNGEncoder) =
  var chunk = make[PNGPhys](pHYs, 9)
  chunk.physX = state.physX
  chunk.physY = state.physY
  chunk.unit  = state.physUnit
  png.chunks.add chunk

proc addChunkIDAT(png: PNG, state: PNGEncoder) =
  var chunk = make[PNGData](IDAT, 0)
  chunk.idat = png.pixels
  png.chunks.add chunk

proc addChunktIME(png: PNG, state: PNGEncoder) =
  var chunk = make[PNGTime](tIME, 0)
  chunk.year   = state.year
  chunk.month  = state.month
  chunk.day    = state.day
  chunk.hour   = state.hour
  chunk.minute = state.minute
  chunk.second = state.second
  png.chunks.add chunk

proc addChunktEXt(png: PNG, txt: PNGKeyText) =
  var chunk = make[PNGText](tEXt, txt.keyword.len + txt.text.len + 1)
  chunk.keyword = txt.keyword
  chunk.text = txt.text
  png.chunks.add chunk

proc addChunkzTXt(png: PNG, txt: PNGKeyText) =
  var chunk = make[PNGZtxt](zTXt, txt.keyword.len + txt.text.len + 1)
  chunk.keyword = txt.keyword
  chunk.text = txt.text
  png.chunks.add chunk

proc addChunkiTXt(png: PNG, txt: PNGIText) =
  var chunk = make[PNGItxt](iTXt, txt.keyword.len + txt.text.len + 1)
  chunk.keyword = txt.keyword
  chunk.translatedKeyword = txt.translatedKeyword
  chunk.languageTag = txt.languageTag
  chunk.text = txt.text
  png.chunks.add chunk

proc addChunkIEND(png: PNG) =
  var chunk = make[PNGEnd](IEND, 0)
  png.chunks.add chunk

proc encodePNG*(input: string, w, h: int, settings = PNGEncoder(nil)): PNG =
  var png: PNG
  new(png)
  png.chunks = @[]

  if settings == nil: png.settings = makePNGEncoder()
  else: png.settings = settings

  let state = PNGEncoder(png.settings)
  var modeIn = newColorMode(state.modeIn)
  var modeOut = newColorMode(state.modeOut)

  if not bitDepthAllowed(modeIn.colorType, modeIn.bitDepth):
    raise PNGError("modeIn colorType and bitDepth combination not allowed")

  if not bitDepthAllowed(modeOut.colorType, modeOut.bitDepth):
    raise PNGError("modeOut colorType and bitDepth combination not allowed")

  if(modeOut.colorType == LCT_PALETTE or state.forcePalette) and
    (modeOut.paletteSize == 0 or modeOut.paletteSize > 256):
    raise PNGError("invalid palette size, it is only allowed to be 1-256")

  let inputSize = getRawSize(w, h, modeIn)
  if input.len < inputSize:
    raise PNGError("not enough input to encode")

  if state.autoConvert:
    autoChooseColor(modeOut, input, w, h, modeIn)

  if state.interlaceMethod notin {IM_NONE, IM_INTERLACED}:
    raise PNGError("unexisting interlace mode")

  if not bitDepthAllowed(modeOut.colorType, modeOut.bitDepth):
      raise PNGError("colorType and bitDepth combination not allowed")

  if modeIn != modeOut:
    let size = (w * h * getBPP(modeOut) + 7) div 8
    let numPixels = w * h

    var converted = newString(size)
    var output = cstring(converted)
    convert(output, cstring(input), modeOut, modeIn, numPixels)
    preProcessScanLines(png, cstring(converted), w, h, modeOut, state)
  else:
    preProcessScanLines(png, cstring(input), w, h, modeOut, state)

  png.addChunkIHDR(w, h, modeOut, state)
  #unknown chunks between IHDR and PLTE
  if state.unknown.len > 0:
    png.chunks.add state.unknown[0]

  if modeOut.colorType == LCT_PALETTE: png.addChunkPLTE(modeOut)
  if state.forcePalette and modeOut.colorType in {LCT_RGB, LCT_RGBA}: png.addChunkPLTE(modeOut)

  if(modeOut.colorType == LCT_PALETTE) and (getPaletteTranslucency(modeOut) != 0):
    png.addChunktRNS(modeOut)

  if modeOut.colorType in {LCT_GREY, LCT_RGB} and modeOut.keyDefined:
    png.addChunktRNS(modeOut)

  #bKGD (must come between PLTE and the IDAt chunks
  if state.backgroundDefined: png.addChunkbKGD(modeOut, state)

  #pHYs (must come before the IDAT chunks)
  if state.physDefined: png.addChunkpHYs(state)

  #unknown chunks between PLTE and IDAT
  if state.unknown.len > 1:
    png.chunks.add state.unknown[1]

  #IDAT (multiple IDAT chunks must be consecutive)
  png.addChunkIDAT(state)

  if state.timeDefined: png.addChunktIME(state)

  for txt in state.textList:
    if state.textCompression: png.addChunkzTXt(txt)
    else: png.addChunktEXt(txt)

  if state.addID:
    var txt = PNGKeyText(keyword: "nimPNG", text: NIM_PNG_VERSION)
    png.addChunktEXt(txt)

  for txt in state.itextList:
    png.addChunkiTXt(txt)

  #unknown chunks between IDAT and IEND
  if state.unknown.len > 2:
    png.chunks.add state.unknown[2]

  png.addChunkIEND()
  result = png

proc encodePNG*(input: string, colorType: PNGcolorType, bitDepth, w, h: int, settings = PNGEncoder(nil)): PNG =
  if not bitDepthAllowed(colorType, bitDepth):
      raise PNGError("colorType and bitDepth combination not allowed")

  var state: PNGEncoder
  if settings == nil: state = makePNGEncoder()
  else: state = settings

  state.modeIn.colorType = colorType
  state.modeIn.bitDepth = bitDepth
  result = encodePNG(input, w, h, state)

proc encodePNG32*(input: string, w, h: int): PNG =
  result = encodePNG(input, LCT_RGBA, 8, w, h)

proc encodePNG24*(input: string, w, h: int): PNG =
  result = encodePNG(input, LCT_RGB, 8, w, h)

proc writeChunks*(png: PNG, s: Stream) =
  s.write PNGSignature

  for chunk in png.chunks:
    if not chunk.validateChunk(png): raise PNGError("combine chunk validation error")
    if not chunk.writeChunk(png): raise PNGError("combine chunk write error")
    chunk.length = chunk.data.len
    chunk.crc = crc32(crc32(0, $chunk.chunkType), chunk.data)

    s.writeInt32BE chunk.length
    s.writeInt32BE int(chunk.chunkType)
    s.write chunk.data
    s.writeInt32BE cast[int](chunk.crc)

proc savePNG*(fileName, input: string, colorType: PNGcolorType, bitDepth, w, h: int): bool =
  try:
    var png = encodePNG(input, colorType, bitDepth, w, h)
    var s = newFileStream(fileName, fmWrite)
    png.writeChunks s
    s.close()
    result = true
  except:
    debugEcho getCurrentExceptionMsg()
    result = false
    
proc savePNG32*(fileName, input: string, w, h: int): bool =
  result = savePNG(fileName, input, LCT_RGBA, 8, w, h)
  
proc savePNG24*(fileName, input: string, w, h: int): bool =
  result = savePNG(fileName, input, LCT_RGB, 8, w, h)

proc getFilterTypesInterlaced(png: PNG): seq[string] =
  var header = PNGHeader(png.getChunk(IHDR))
  var idat = PNGData(png.getChunk(IDAT))

  if header.interlaceMethod == IM_NONE:
    result = newSeq[string](1)
    result[0] = ""

    #A line is 1 filter byte + all pixels
    let lineBytes = 1 + idatRawSize(header.width, 1, header)
    var i = 0
    while i < idat.idat.len:
      result[0].add idat.idat[i]
      inc(i, lineBytes)
  else:
    result = newSeq[string](7)
    for j in 0..6:
      result[j] = ""
      var w2 = (header.width - ADAM7_IX[j] + ADAM7_DX[j] - 1) div ADAM7_DX[j]
      var h2 = (header.height - ADAM7_IY[j] + ADAM7_DY[j] - 1) div ADAM7_DY[j]
      if(ADAM7_IX[j] >= header.width) or (ADAM7_IY[j] >= header.height):
        w2 = 0
        h2 = 0

      let lineBytes = 1 + idatRawSize(w2, 1, header)
      var pos = 0
      for i in 0..h2-1:
        result[j].add idat.idat[pos]
        inc(pos, linebytes)

proc getFilterTypes*(png: PNG): string =
  var passes = getFilterTypesInterlaced(png)

  if passes.len == 1:
    result = passes[0]
  else:
    var header = PNGHeader(png.getChunk(IHDR))
    #Interlaced. Simplify it: put pass 6 and 7 alternating in the one vector so
    #that one filter per scanline of the uninterlaced image is given, with that
    #filter corresponding the closest to what it would be for non-interlaced image.
    result = ""
    for i in 0..header.height-1:
      if (i mod 2) == 0: result.add passes[5][i div 2]
      else: result.add passes[6][i div 2]
