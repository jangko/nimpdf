# Copyright (c) 2015 Andri Lim
#
# Distributed under the MIT license
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------
import ByteArray, FontIOStreams, hashes

const
  MAX_INT = high(int)
  GROWABLE_SIZE = MAX_INT
  DataSize* = (kBYTE : 1,
    kCHAR : 1,
    kUSHORT : 2,
    kSHORT : 2,
    kUINT24 : 3,
    kULONG : 4,
    kLONG : 4,
    kFixed : 4,
    kFUNIT : 4,
    kFWORD : 2,
    kUFWORD : 2,
    kF2DOT14 : 2,
    kLONGDATETIME : 8,
    kTag : 4,
    kGlyphID : 2,
    kOffset : 2)

type
  TTag* = distinct int

  Header* = object
    mTag: TTag
    mOffset, mLength: int
    mChecksum: int64

  FontData* = ref object of RootObj
    data: ByteArray
    boundOffset: int
    boundLength: int

  IntegerList* = seq[int]

  FontTable* = ref object of RootObj
    header: Header
    data*: FontData
    padding: int
    checksumSet: bool
    checksum: int64

proc generateTag*(cc: string): TTag =
  result = TTag(((ord(cc[0]) shl 24) or (ord(cc[1]) shl 16) or (ord(cc[2]) shl 8) or ord(cc[3])))

proc hash*(c: TTag): Hash =
  result = !$ (0 !& int(c))

proc toString*(tag: TTag): string =
  result = newString(4)
  let t = int(tag)
  result[0] = chr(uint32(t shr 24) and 0xFF)
  result[1] = chr(uint32(t shr 16) and 0xFF)
  result[2] = chr(uint32(t shr 8) and 0xFF)
  result[3] = chr(uint32(t) and 0xFF)

#---------------------------------------------------
proc tagSortedComparator*(x,y: Header): int = cmp(int(x.mTag), int(y.mTag))

proc offsetSortedComparator*(x,y: Header): int = cmp(x.mOffset, y.mOffset)

proc hash*(c: Header): Hash =
  var h: Hash = 0
  h = h !& int(c.mTag)
  h = h !& c.mOffset
  h = h !& c.mLength
  result = !$h

proc initHeader*(tag: TTag, checksum: int64, offset, length: int): Header =
  result.mTag = tag
  result.mOffset = offset
  result.mLength = length
  result.mChecksum = checksum

proc tag*(h: Header): TTag {.inline.} = h.mTag
proc offset*(h: Header): int {.inline.} = h.mOffset
proc length*(h: Header): int {.inline.} = h.mLength
proc checksum*(h: Header): int64 {.inline.} = h.mChecksum
proc `==`*(a,b:TTag): bool {.inline.} = int(a) == int(b)
proc setOffset*(h: var Header, offset:int) {.inline.} = h.mOffset = offset
proc setChecksum*(h: var Header, checksum:int64) {.inline.} = h.mChecksum = checksum
#-----------------------------------------------------

proc Log2*(aa: int): int =
  var r = 0  #r will be lg(a)
  var a = aa
  while a != 0:
    a = a shr 1
    inc(r)
  result = r - 1

proc paddingRequired*(size, alignmentSize: int): int =
  let padding = alignmentSize - (size mod alignmentSize)
  result = padding
  if padding == alignmentSize: result = 0

proc fixed1616Integral*(fixed: int): int =
  result = fixed shr 16

proc fixed1616Fractional*(fixed: int): int =
  result = fixed and 0xffff

proc fixed1616Fixed*(integral, fractional: int): int =
  result = ((integral and 0xffff) shl 16) or (fractional and 0xffff)

proc fromUnicode*(s:string): string =
  let len = s.len shr 1
  result = newString(len)
  var i=0
  var j=0

  while i < s.len:
    inc(i)
    result[j] = s[i]
    inc(j)
    inc(i)

proc toUnicode*(s:string): string =
  let len = s.len shl 1
  result = newString(len)
  var i=0
  var j=0

  while i < s.len:
    result[j] = chr(0)
    result[j + 1] = s[i]
    inc(i)
    inc(j, 2)

#-----------------------------------------------------
const
  TAG* = (ttcf : generateTag("ttcf"),
    cmap : generateTag("cmap"),
    head : generateTag("head"),
    hhea : generateTag("hhea"),
    hmtx : generateTag("hmtx"),
    maxp : generateTag("maxp"),
    name : generateTag("name"),
    OS_2 : generateTag("OS/2"),
    post : generateTag("post"),
    cvt  : generateTag("cvt "),
    fpgm : generateTag("fpgm"),
    glyf : generateTag("glyf"),
    loca : generateTag("loca"),
    prep : generateTag("prep"),
    CFF  : generateTag("CFF "),
    VORG : generateTag("VORG"),
    EBDT : generateTag("EBDT"),
    EBLC : generateTag("EBLC"),
    EBSC : generateTag("EBSC"),
    BASE : generateTag("BASE"),
    GDEF : generateTag("GDEF"),
    GPOS : generateTag("GPOS"),
    GSUB : generateTag("GSUB"),
    JSTF : generateTag("JSTF"),
    DSIG : generateTag("DSIG"),
    gasp : generateTag("gasp"),
    hdmx : generateTag("hdmx"),
    kern : generateTag("kern"),
    LTSH : generateTag("LTSH"),
    PCLT : generateTag("PCLT"),
    VDMX : generateTag("VDMX"),
    vhea : generateTag("vhea"),
    vmtx : generateTag("vmtx"),
    bsln : generateTag("bsln"),
    feat : generateTag("feat"),
    lcar : generateTag("lcar"),
    morx : generateTag("morx"),
    opbd : generateTag("opbd"),
    prop : generateTag("prop"),
    Feat : generateTag("Feat"),
    Glat : generateTag("Glat"),
    Gloc : generateTag("Gloc"),
    Sile : generateTag("Sile"),
    Silf : generateTag("Silf"),
    bhed : generateTag("bhed"),
    bdat : generateTag("bdat"),
    bloc : generateTag("bloc"))

  CFF_TABLE_ORDERING* = [TAG.head, TAG.hhea, TAG.maxp, TAG.OS_2, TAG.name, TAG.cmap, TAG.post, TAG.CFF]

  TRUE_TYPE_TABLE_ORDERING* = [TAG.head, TAG.hhea, TAG.maxp, TAG.OS_2,
    TAG.hmtx, TAG.LTSH, TAG.VDMX, TAG.hdmx, TAG.cmap,
    TAG.fpgm, TAG.prep, TAG.cvt, TAG.loca, TAG.glyf,
    TAG.kern, TAG.name, TAG.post, TAG.gasp, TAG.PCLT, TAG.DSIG]

#--------------------------------------------------------------

proc length*(fd: FontData): int = min(fd.data.length() - fd.boundOffset, fd.boundLength)
proc size*(fd: FontData): int = min(fd.data.size() - fd.boundOffset, fd.boundLength)
proc getBoundOffset(fd: FontData, offset: int): int = offset + fd.boundOffset
proc getBoundLength(fd: FontData, offset, length: int): int = min(length, fd.boundLength - offset)
proc getInternalBuffer*(fd: FontData): ByteVector = fd.data.internalBuffer()

proc bound(fd: FontData, offset, length: int) =
  fd.boundOffset += offset
  fd.boundLength = length

proc initFontData(fd: FontData, ba: ByteArray) =
  fd.data = ba
  fd.boundOffset = 0
  fd.boundLength = GROWABLE_SIZE

proc initFontData(fd, data: FontData, offset, length: int) =
  fd.initFontData(data.data)
  fd.bound(data.boundOffset + offset, length)

proc initFontData(fd, data: FontData, offset: int) =
  fd.initFontData(data.data)
  if data.boundLength == GROWABLE_SIZE:
    fd.bound(data.boundOffset + offset, GROWABLE_SIZE)
  else:
    fd.bound(data.boundOffset + offset, data.boundLength - offset)

#-------------------------------------------------------
proc newFontData*(b: ByteVector, growable: bool = false): FontData =
  var ba: ByteArray
  if growable: ba = newGrowableMemoryByteArray()
  else: ba = newMemoryByteArray(b.len)
  discard ba.put(0, b)
  new(result)
  initFontData(result, ba)

proc newFontData*(ba: ByteArray): FontData =
  new(result)
  initFontData(result, ba)

proc newFontData(data: FontData, offset: int) : FontData =
  new(result)
  initFontData(result, data, offset)

proc newFontData(data: FontData, offset, length: int) : FontData =
  new(result)
  initFontData(result, data, offset, length)

proc newFontData*(length: int): FontData =
  var ba: ByteArray
  if length > 0:
    ba = newMemoryByteArray(length)
    ba.setFilledLength(length)
  else:
    ba = newGrowableMemoryByteArray()
  result = newFontData(ba)

proc readUByte*(fd: FontData, index: int): int =
  let b = fd.data.get(fd.getBoundOffset(index))
  if b < 0:
    raise newIndexError("Index attempted to be read from is out of bounds " & $index)
  result = b

proc readByte*(fd: FontData, index: int): int =
  let b = fd.data.get(fd.getBoundOffset(index))
  if b < 0:
    raise newIndexError("Index attempted to be read from is out of bounds " & $index)

  result = b
  if b >= 0x80: result = b - 0x100

proc readBytes*(fd: FontData, index: int, b: var string, offset, length: int): int =
  result = fd.data.get(fd.getBoundOffset(index), b, offset, fd.getBoundLength(index, length))

proc readUShort*(fd: FontData, index: int): int =
  result = 0xffff and (fd.readUByte(index) shl 8 or fd.readUByte(index + 1))

proc readShort*(fd: FontData, index: int): int =
  result = fd.readUShort(index)
  if result >= 0x8000: result -= 0x10000

proc readUInt24*(fd: FontData, index: int): int =
  result = 0xffffff and (fd.readUByte(index) shl 16 or fd.readUByte(index + 1) shl 8 or fd.readUByte(index + 2))

proc readULong*(fd: FontData, index: int): int64 =
  let val = (fd.readUByte(index) shl 24) or
    fd.readUByte(index + 1) shl 16 or
    fd.readUByte(index + 2) shl 8 or
    fd.readUByte(index + 3)

  result = 0xffffffff and int64(cast[uint32](val))

proc readULongAsInt*(fd: FontData, index: int): int =
  let ulong = fd.readULong(index)

  if (ulong and 0x80000000) == 0x80000000:
    raise newArithErr("Long value too large to fit into an integer.")

  result = cast[int](ulong)

proc readULongLE*(fd: FontData, index: int): int64 =
  let val = (fd.readUByte(index) or
    fd.readUByte(index + 1) shl 8 or
    fd.readUByte(index + 2) shl 16 or
    fd.readUByte(index + 3) shl 24)

  result = 0xffffffff and int64(cast[uint32](val))

proc readLong*(fd: FontData, index: int): int =
  result = fd.readByte(index) shl 24 or
    fd.readUByte(index + 1) shl 16 or
    fd.readUByte(index + 2) shl 8 or
    fd.readUByte(index + 3)

proc readFixed*(fd: FontData, index: int): int =
  result = fd.readLong(index)

proc readDateTimeAsLong*(fd: FontData, index: int): int64 =
  result = int64(fd.readULong(index)) shl 32 or fd.readULong(index + 4)

proc readFWord*(fd: FontData, index: int): int =
  result = fd.readShort(index)

proc readUFWord*(fd: FontData, index: int): int =
  result = fd.readUShort(index)

proc copyTo*(fd: FontData, os: OutputStream): int =
  result = fd.data.copyToOS(fd.getBoundOffset(0), fd.length(), os)

proc copyTo*(fd: FontData, wfd: FontData): int =
  result = fd.data.copyTo(wfd.getBoundOffset(0), wfd.data, fd.getBoundOffset(0), fd.length())

proc copyTo*(fd: FontData, wfd: FontData, index, offset, length: int): int =
  result = fd.data.copyTo(index, wfd.data, offset, length)

proc copyTo*(fd: FontData, wfd: FontData, index : int): int =
  result = fd.data.copyTo(index, wfd.data, fd.getBoundOffset(0), fd.length())

proc copyTo*(fd: FontData, ba: ByteArray): int =
  result = fd.data.copyTo(ba, fd.getBoundOffset(0), fd.length())

proc slice*(fd: FontData, offset, length: int): FontData =
  if (offset < 0) or ((offset + length) > fd.size()):
    raise newIndexError("Attempt to bind data outside of its limits")

  result = newFontData(fd, offset, length)

proc slice*(fd: FontData, offset: int): FontData =
  if (offset < 0) or (offset > fd.size()):
    raise newIndexError("Attempt to bind data outside of its limits")

  result = newFontData(fd, offset)

#-------------------------------------------------------------------------
proc writeByte*(fd: FontData, index: int, b: char): int =
  fd.data.put(fd.getBoundOffset(index), b)
  result = 1

proc writeBytes*(fd: FontData, index: int, b: ByteVector, offset, length: int): int =
  result = fd.data.put(fd.getBoundOffset(index), b, offset, fd.getBoundLength(index, length))

proc writeBytes*(fd: FontData, index: int, b: ByteVector): int =
  result = fd.writeBytes(index, b, 0, b.len)

proc writePadding*(fd: FontData, index, count: int, pad: char): int =
  for i in 0..count-1:
    fd.data.put(index + i, pad)
  result = count

proc writePadding*(fd: FontData, index, count: int): int =
  result = fd.writePadding(index, count, chr(0))

proc writeBytesPad*(fd: FontData, index: int, b: ByteVector, offset, length: int, pad: char): int =
  var written =  fd.data.put(fd.getBoundOffset(index), b, offset, fd.getBoundLength(index, min(length, b.len - offset)))
  written += fd.writePadding(written + index, length - written, pad)
  result = written

proc writeChar*(fd: FontData, index: int, c: char): int =
  result = fd.writeByte(index, c)

proc writeUShort*(fd: FontData, index, us: int): int =
  discard fd.writeByte(index, char((us shr 8) and 0xff))
  discard fd.writeByte(index + 1, char(us and 0xff))
  result = 2

proc writeFWord*(fd: FontData, index, us: int): int =
  result = fd.writeUShort(index, us)

proc writeUShortLE*(fd: FontData, index, us: int): int =
  discard fd.writeByte(index, char(us and 0xff))
  discard fd.writeByte(index + 1, char((us shr 8) and 0xff))
  result = 2

proc writeShort*(fd: FontData, index, s: int): int =
  result = fd.writeUShort(index, s)

proc writeUInt24*(fd: FontData, index, ui: int): int =
  discard fd.writeByte(index, char((ui shr 16) and 0xff))
  discard fd.writeByte(index + 1, char((ui shr 8) and 0xff))
  discard fd.writeByte(index + 2, char(ui and 0xff))
  result = 3

proc writeULong*(fd: FontData, index: int, ul: int64): int =
  discard fd.writeByte(index, char((ul shr 24) and 0xff))
  discard fd.writeByte(index + 1, char((ul shr 16) and 0xff))
  discard fd.writeByte(index + 2, char((ul shr 8) and 0xff))
  discard fd.writeByte(index + 3, char(ul and 0xff))
  result = 4

proc writeULongLE*(fd: FontData, index: int, ul: int64): int =
  discard fd.writeByte(index, char(ul and 0xff))
  discard fd.writeByte(index + 1, char((ul shr 8) and 0xff))
  discard fd.writeByte(index + 2, char((ul shr 16) and 0xff))
  discard fd.writeByte(index + 3, char((ul shr 24) and 0xff))
  result = 4

proc writeLong*(fd: FontData, index: int, lg: int64): int =
  result = fd.writeULong(index, lg)

proc writeFixed*(fd: FontData, index, f: int): int =
  result = fd.writeLong(index, f)

proc writeDateTime*(fd: FontData, index: int, date: int64): int =
  discard fd.writeULong(index, (date shr 32) and 0xffffffff)
  discard fd.writeULong(index + 4, date and 0xffffffff)
  result = 8

proc copyFrom*(fd: FontData, inp: InputStream, length: int) =
  fd.data.copyFrom(inp, length)

proc copyFrom*(fd: FontData, inp: InputStream) =
  fd.data.copyFrom(inp)

#-----------------------------------------------------
proc checksum*(data: FontData, len:int): int64 =
  result = 0
  let off = len and -4

  for i in countup(0, len-4, 4):
    result = result + data.readULong(i)
    #result = result and 0xFFFFFFFF

  if off < len:
    var b3 = data.readUByte(off)
    var b2 = 0
    var b1 = 0
    var b0 = 0
    if off + 1 < len: b2 = data.readUByte(off + 1)
    if off + 2 < len: b1 = data.readUByte(off + 2)
    result += (b3 shl 24) or (b2 shl 16) or (b1 shl 8) or b0

  result = result and 0xFFFFFFFF

proc calculatedChecksum*(t: FontTable): int64 =
  if not t.checksumSet:
    t.checksum = checksum(t.data, t.header.length())
    t.checksumSet = true
    t.header.setChecksum(t.checksum)
  result = t.checksum

proc getHeader*(t: FontTable): Header = t.header
proc headerTag*(t: FontTable): TTag = t.header.tag()
proc headerOffset*(t: FontTable): int = t.header.offset()
proc headerLength*(t: FontTable): int = t.header.length()
proc headerChecksum*(t: FontTable): int64 = t.header.checksum()
proc getPadding*(t: FontTable): int = t.padding
proc setPadding*(t: FontTable, padding: int) = t.padding = padding
proc dataLength*(t: FontTable): int = t.data.length()
proc serialize*(t: FontTable, os: OutputStream): int = t.data.copyTo(os)
proc serialize*(t: FontTable, data: FontData, index: int): int = t.data.copyTo(data, index, 0, data.length())
proc setHeader*(t: FontTable, header: Header) = t.header = header
proc getTableData*(t: FontTable): FontData = t.data
proc setTableOffset*(t: FontTable, offset:int) = t.header.setOffset(offset)

proc initFontTable*(t: FontTable, header: Header, data: FontData) =
  t.header = header
  t.data = data
  t.padding = 0
  t.checksumSet = false
  t.checksum = 0
