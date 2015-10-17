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
    mtag: TTag
    moffset, mlength: int
    mchecksum: int64
    
  FontData* = ref object of RootObj
    data: ByteArray
    boundOffset: int
    boundLength: int
  
  IntegerList* = seq[int]
  
  FontTable* = ref object of RootObj
    header: Header
    data*: FontData
    padding: int
    checksum_set: bool
    checksum: int64

proc GenerateTag*(cc: string): TTag = 
  result = TTag(((ord(cc[0]) shl 24) or (ord(cc[1]) shl 16) or (ord(cc[2]) shl 8) or ord(cc[3])))

proc hash*(c: TTag): THash =
  result = !$ (0 !& int(c))

proc TagToString*(tag: TTag): string =
  result = newString(4)
  let t = int(tag)
  result[0] = chr(toU32(t shr 24) and 0xFF)
  result[1] = chr(toU32(t shr 16) and 0xFF)
  result[2] = chr(toU32(t shr 8) and 0xFF)
  result[3] = chr(toU32(t) and 0xFF)

#---------------------------------------------------
proc TagSortedComparator*(x,y: Header): int = cmp(int(x.mtag), int(y.mtag))

proc OffsetSortedComparator*(x,y: Header): int = cmp(x.moffset, y.moffset)

proc hash*(c: Header): THash =
  var h: THash = 0
  h = h !& int(c.mtag)
  h = h !& c.moffset
  h = h !& c.mlength
  result = !$h

proc makeHeader*(tag: TTag, checksum: int64, offset, length: int): Header =
  result.mtag = tag
  result.moffset = offset
  result.mlength = length
  result.mchecksum = checksum

proc tag*(h: Header): TTag {.inline.} = h.mtag
proc offset*(h: Header): int {.inline.} = h.moffset
proc length*(h: Header): int {.inline.} = h.mlength
proc checksum*(h: Header): int64 {.inline.} = h.mchecksum
proc `==`*(a,b:TTag): bool {.inline.} = int(a) == int(b)
proc SetOffset*(h: var Header, offset:int) {.inline.} = h.moffset = offset
proc SetChecksum*(h: var Header, checksum:int64) {.inline.} = h.mchecksum = checksum
#-----------------------------------------------------

proc Log2*(aa: int): int =
  var r = 0  #r will be lg(a)
  var a = aa
  while a != 0:
    a = a shr 1
    inc(r)
  result = r - 1
  
proc PaddingRequired*(size, alignment_size: int): int =
  let padding = alignment_size - (size mod alignment_size)
  result = padding
  if padding == alignment_size: result = 0
  
proc Fixed1616Integral*(fixed: int): int =
  result = fixed shr 16

proc Fixed1616Fractional*(fixed: int): int =
  result = fixed and 0xffff

proc Fixed1616Fixed*(integral, fractional: int): int =
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
  TAG* = (ttcf : GenerateTag("ttcf"),
    cmap : GenerateTag("cmap"),
    head : GenerateTag("head"),
    hhea : GenerateTag("hhea"),
    hmtx : GenerateTag("hmtx"),
    maxp : GenerateTag("maxp"),
    name : GenerateTag("name"),
    OS_2 : GenerateTag("OS/2"),
    post : GenerateTag("post"),
    cvt  : GenerateTag("cvt "),
    fpgm : GenerateTag("fpgm"),
    glyf : GenerateTag("glyf"),
    loca : GenerateTag("loca"),
    prep : GenerateTag("prep"),
    CFF  : GenerateTag("CFF "),
    VORG : GenerateTag("VORG"),
    EBDT : GenerateTag("EBDT"),
    EBLC : GenerateTag("EBLC"),
    EBSC : GenerateTag("EBSC"),
    BASE : GenerateTag("BASE"),
    GDEF : GenerateTag("GDEF"),
    GPOS : GenerateTag("GPOS"),
    GSUB : GenerateTag("GSUB"),
    JSTF : GenerateTag("JSTF"),
    DSIG : GenerateTag("DSIG"),
    gasp : GenerateTag("gasp"),
    hdmx : GenerateTag("hdmx"),
    kern : GenerateTag("kern"),
    LTSH : GenerateTag("LTSH"),
    PCLT : GenerateTag("PCLT"),
    VDMX : GenerateTag("VDMX"),
    vhea : GenerateTag("vhea"),
    vmtx : GenerateTag("vmtx"),
    bsln : GenerateTag("bsln"),
    feat : GenerateTag("feat"),
    lcar : GenerateTag("lcar"),
    morx : GenerateTag("morx"),
    opbd : GenerateTag("opbd"),
    prop : GenerateTag("prop"),
    Feat : GenerateTag("Feat"),
    Glat : GenerateTag("Glat"),
    Gloc : GenerateTag("Gloc"),
    Sile : GenerateTag("Sile"),
    Silf : GenerateTag("Silf"),
    bhed : GenerateTag("bhed"),
    bdat : GenerateTag("bdat"),
    bloc : GenerateTag("bloc"))

  CFF_TABLE_ORDERING* = [TAG.head, TAG.hhea, TAG.maxp, TAG.OS_2, TAG.name, TAG.cmap, TAG.post, TAG.CFF]

  TRUE_TYPE_TABLE_ORDERING* = [TAG.head, TAG.hhea, TAG.maxp, TAG.OS_2, 
    TAG.hmtx, TAG.LTSH, TAG.VDMX, TAG.hdmx, TAG.cmap, 
    TAG.fpgm, TAG.prep, TAG.cvt, TAG.loca, TAG.glyf, 
    TAG.kern, TAG.name, TAG.post, TAG.gasp, TAG.PCLT, TAG.DSIG]

#--------------------------------------------------------------
    
proc Length*(fd: FontData): int = min(fd.data.Length() - fd.boundOffset, fd.boundLength)
proc Size*(fd: FontData): int = min(fd.data.Size() - fd.boundOffset, fd.boundLength)
proc BoundOffset(fd: FontData, offset: int): int = offset + fd.boundOffset
proc BoundLength(fd: FontData, offset, length: int): int = min(length, fd.boundLength - offset)
proc GetInternalBuffer*(fd: FontData): ByteVector = fd.data.InternalBuffer()  
  
proc Bound(fd: FontData, offset, length: int) =
  fd.boundOffset += offset
  fd.boundLength = length
  
proc initFontData(fd: FontData, ba: ByteArray) = 
  fd.data = ba
  fd.bound_offset = 0
  fd.bound_length = GROWABLE_SIZE
  
proc initFontData(fd, data: FontData, offset, length: int) =
  fd.initFontData(data.data)
  fd.Bound(data.boundOffset + offset, length)

proc initFontData(fd, data: FontData, offset: int) =
  fd.initFontData(data.data)
  if data.boundLength == GROWABLE_SIZE:
    fd.Bound(data.boundOffset + offset, GROWABLE_SIZE)
  else:
    fd.Bound(data.boundOffset + offset, data.boundLength - offset)

#-------------------------------------------------------
proc makeFontData*(b: ByteVector, growable: bool = false): FontData =
  var ba: ByteArray
  if growable: ba = makeGrowableMemoryByteArray()
  else: ba = makeMemoryByteArray(b.len)
  discard ba.Put(0, b)
  new(result)
  initFontData(result, ba)

proc makeFontData*(ba: ByteArray): FontData =
  new(result)
  initFontData(result, ba)

proc makeFontData(data: FontData, offset: int) : FontData =
  new(result)
  initFontData(result, data, offset)

proc makeFontData(data: FontData, offset, length: int) : FontData =
  new(result)
  initFontData(result, data, offset, length)
  
proc makeFontData*(length: int): FontData =
  var ba: ByteArray
  if length > 0:
    ba = makeMemoryByteArray(length)
    ba.SetFilledLength(length)
  else:
    ba = makeGrowableMemoryByteArray()
  result = makeFontData(ba)

proc ReadUByte*(fd: FontData, index: int): int =
  let b = fd.data.Get(fd.BoundOffset(index))
  if b < 0:
    raise newIndexError("Index attempted to be read from is out of bounds " & $index)
  result = b

proc ReadByte*(fd: FontData, index: int): int =
  let b = fd.data.Get(fd.BoundOffset(index))
  if b < 0:
    raise newIndexError("Index attempted to be read from is out of bounds " & $index)
    
  result = b
  if b >= 0x80: result = b - 0x100

proc ReadBytes*(fd: FontData, index: int, b: var string, offset, length: int): int =
  result = fd.data.Get(fd.BoundOffset(index), b, offset, fd.BoundLength(index, length))

proc ReadUShort*(fd: FontData, index: int): int =
  result = 0xffff and (fd.ReadUByte(index) shl 8 or fd.ReadUByte(index + 1))

proc ReadShort*(fd: FontData, index: int): int =
  result = fd.ReadUShort(index)
  if result >= 0x8000: result -= 0x10000

proc ReadUInt24*(fd: FontData, index: int): int =
  result = 0xffffff and (fd.ReadUByte(index) shl 16 or fd.ReadUByte(index + 1) shl 8 or fd.ReadUByte(index + 2))

proc ReadULong*(fd: FontData, index: int): int64 =
  let val = (fd.ReadUByte(index) shl 24) or 
    fd.ReadUByte(index + 1) shl 16 or 
    fd.ReadUByte(index + 2) shl 8 or 
    fd.ReadUByte(index + 3)

  result = 0xffffffff and int64(cast[uint32](val))
    
proc ReadULongAsInt*(fd: FontData, index: int): int =
  let ulong = fd.ReadULong(index)

  if (ulong and 0x80000000) == 0x80000000:
    raise newArithErr("Long value too large to fit into an integer.")
    
  result = cast[int](ulong)

proc ReadULongLE*(fd: FontData, index: int): int64 =
  let val = (fd.ReadUByte(index) or
    fd.ReadUByte(index + 1) shl 8 or
    fd.ReadUByte(index + 2) shl 16 or
    fd.ReadUByte(index + 3) shl 24)
    
  result = 0xffffffff and int64(cast[uint32](val))

proc ReadLong*(fd: FontData, index: int): int =
  result = fd.ReadByte(index) shl 24 or
    fd.ReadUByte(index + 1) shl 16 or
    fd.ReadUByte(index + 2) shl 8 or
    fd.ReadUByte(index + 3)

proc ReadFixed*(fd: FontData, index: int): int =
  result = fd.ReadLong(index)

proc ReadDateTimeAsLong*(fd: FontData, index: int): int64 =
  result = int64(fd.ReadULong(index)) shl 32 or fd.ReadULong(index + 4)

proc ReadFWord*(fd: FontData, index: int): int =
  result = fd.ReadShort(index)

proc ReadUFWord*(fd: FontData, index: int): int =
  result = fd.ReadUShort(index)

proc CopyTo*(fd: FontData, os: OutputStream): int =
  result = fd.data.CopyTo(os, fd.BoundOffset(0), fd.Length())
  
proc CopyTo*(fd: FontData, wfd: FontData): int = 
  result = fd.data.CopyTo(wfd.BoundOffset(0), wfd.data, fd.BoundOffset(0), fd.Length())

proc CopyTo*(fd: FontData, wfd: FontData, index, offset, length: int): int = 
  result = fd.data.CopyTo(index, wfd.data, offset, length)

proc CopyTo*(fd: FontData, wfd: FontData, index : int): int = 
  result = fd.data.CopyTo(index, wfd.data, fd.BoundOffset(0), fd.Length())
  
proc CopyTo*(fd: FontData, ba: ByteArray): int =
  result = fd.data.CopyTo(ba, fd.BoundOffset(0), fd.Length())

proc Slice*(fd: FontData, offset, length: int): FontData =
  if (offset < 0) or ((offset + length) > fd.Size()):
    raise newIndexError("Attempt to bind data outside of its limits")

  result = makeFontData(fd, offset, length)

proc Slice*(fd: FontData, offset: int): FontData =
  if (offset < 0) or (offset > fd.Size()):
    raise newIndexError("Attempt to bind data outside of its limits")

  result = makeFontData(fd, offset)

#-------------------------------------------------------------------------
proc WriteByte*(fd: FontData, index: int, b: char): int =
  fd.data.Put(fd.BoundOffset(index), b)
  result = 1

proc WriteBytes*(fd: FontData, index: int, b: ByteVector, offset, length: int): int =
  result = fd.data.Put(fd.BoundOffset(index), b, offset, fd.BoundLength(index, length))

proc WriteBytes*(fd: FontData, index: int, b: ByteVector): int =
  result = fd.WriteBytes(index, b, 0, b.len)

proc WritePadding*(fd: FontData, index, count: int, pad: char): int =
  for i in 0..count-1:
    fd.data.Put(index + i, pad)
  result = count

proc WritePadding*(fd: FontData, index, count: int): int =
  result = fd.WritePadding(index, count, chr(0))
  
proc WriteBytesPad*(fd: FontData, index: int, b: ByteVector, offset, length: int, pad: char): int =
  var written =  fd.data.Put(fd.BoundOffset(index), b, offset, fd.BoundLength(index, min(length, b.len - offset)))
  written += fd.WritePadding(written + index, length - written, pad)
  result = written

proc WriteChar*(fd: FontData, index: int, c: char): int =
  result = fd.WriteByte(index, c)

proc WriteUShort*(fd: FontData, index, us: int): int =
  discard fd.WriteByte(index, char((us shr 8) and 0xff))
  discard fd.WriteByte(index + 1, char(us and 0xff))
  result = 2

proc WriteFWord*(fd: FontData, index, us: int): int =
  result = fd.WriteUShort(index, us)
  
proc WriteUShortLE*(fd: FontData, index, us: int): int =
  discard fd.WriteByte(index, char(us and 0xff))
  discard fd.WriteByte(index + 1, char((us shr 8) and 0xff))
  result = 2

proc WriteShort*(fd: FontData, index, s: int): int =
  result = fd.WriteUShort(index, s)

proc WriteUInt24*(fd: FontData, index, ui: int): int =
  discard fd.WriteByte(index, char((ui shr 16) and 0xff))
  discard fd.WriteByte(index + 1, char((ui shr 8) and 0xff))
  discard fd.WriteByte(index + 2, char(ui and 0xff))
  result = 3

proc WriteULong*(fd: FontData, index: int, ul: int64): int =
  discard fd.WriteByte(index, char((ul shr 24) and 0xff))
  discard fd.WriteByte(index + 1, char((ul shr 16) and 0xff))
  discard fd.WriteByte(index + 2, char((ul shr 8) and 0xff))
  discard fd.WriteByte(index + 3, char(ul and 0xff))
  result = 4

proc WriteULongLE*(fd: FontData, index: int, ul: int64): int =
  discard fd.WriteByte(index, char(ul and 0xff))
  discard fd.WriteByte(index + 1, char((ul shr 8) and 0xff))
  discard fd.WriteByte(index + 2, char((ul shr 16) and 0xff))
  discard fd.WriteByte(index + 3, char((ul shr 24) and 0xff))
  result = 4

proc WriteLong*(fd: FontData, index: int, lg: int64): int =
  result = fd.WriteULong(index, lg)

proc WriteFixed*(fd: FontData, index, f: int): int =
  result = fd.WriteLong(index, f)

proc WriteDateTime*(fd: FontData, index: int, date: int64): int =
  discard fd.WriteULong(index, (date shr 32) and 0xffffffff)
  discard fd.WriteULong(index + 4, date and 0xffffffff)
  result = 8

proc CopyFrom*(fd: FontData, inp: InputStream, length: int) =
  fd.data.CopyFrom(inp, length)

proc CopyFrom*(fd: FontData, inp: InputStream) =
  fd.data.CopyFrom(inp)

#-----------------------------------------------------
proc checksum*(data: FontData, len:int): int64 =
  result = 0
  let off = len and -4
  
  for i in countup(0, len-4, 4):
    result = result + data.ReadULong(i)
    #result = result and 0xFFFFFFFF
  
  if off < len:
    var b3 = data.ReadUByte(off)
    var b2 = 0
    var b1 = 0
    var b0 = 0
    if off + 1 < len: b2 = data.ReadUByte(off + 1)
    if off + 2 < len: b1 = data.ReadUByte(off + 2)
    result += (b3 shl 24) or (b2 shl 16) or (b1 shl 8) or b0
  
  result = result and 0xFFFFFFFF

proc CalculatedChecksum*(t: FontTable): int64 = 
  if not t.checksum_set:
    t.checksum = checksum(t.data, t.header.length())
    t.checksum_set = true
    t.header.SetChecksum(t.checksum)
  result = t.checksum

proc GetHeader*(t: FontTable): Header = t.header
proc HeaderTag*(t: FontTable): TTag = t.header.tag()
proc HeaderOffset*(t: FontTable): int = t.header.offset()
proc HeaderLength*(t: FontTable): int = t.header.length()
proc HeaderChecksum*(t: FontTable): int64 = t.header.checksum()
proc GetPadding*(t: FontTable): int = t.padding
proc SetPadding*(t: FontTable, padding: int) = t.padding = padding
proc DataLength*(t: FontTable): int = t.data.Length()
proc Serialize*(t: FontTable, os: OutputStream): int = t.data.CopyTo(os)
proc Serialize*(t: FontTable, data: FontData, index: int): int = t.data.CopyTo(data, index, 0, data.Length())
proc SetHeader*(t: FontTable, header: Header) = t.header = header
proc GetTableData*(t: FontTable): FontData = t.data
proc SetTableOffset*(t: FontTable, offset:int) = t.header.SetOffset(offset)

proc initFontTable*(t: FontTable, header: Header, data: FontData) =
  t.header = header
  t.data = data
  t.padding = 0
  t.checksum_set = false
  t.checksum = 0