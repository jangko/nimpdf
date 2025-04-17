# Copyright (c) 2015 Andri Lim
#
# Distributed under the MIT license
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------
# although it was a port of Google sfntly
# i realize, i dont need all the feature sfntly had
# so i stripped it down, modify it here and there
# basically, this module and other files in this folder
# take a TTF/TTC file and make a subset of it based on
# how much glyphs used in PDF document

import FontData, FontIOStreams, tables, algorithm, sequtils, math

import LOCATable, GLYPHTable, HEADTable, HDMXTable, NAMETable
import HHEATable, HMTXTable, MAXPTable, OS2Table, CMAPTable, POSTTable
import VHEATable, VMTXTable

const
  kSfntVersion = 0
  kNumTables = 4
  kSearchRange = 6
  kEntrySelector = 8
  kRangeShift = 10
  kTableRecordBegin = 12
  kSfntHeaderSize = 12

  #Offsets within a specific table record
  kTableTag = 0
  kTableCheckSum = 4
  kTableOffset = 8
  kTableLength = 12
  kTableRecordSize = 16

  kTTCTag = 0
  kVersion = 4
  kNumFonts = 8
  kOffsetTable = 12

  #TTC Version 2.0 extensions.
  #Offsets from end of OffsetTable.
  #kulDsigTag = 0
  #kulDsigLength = 4
  #kulDsigOffset = 8

  SFNTVERSION_MAJOR = 1
  SFNTVERSION_MINOR = 0

type
  FontTableMap* = Table[TTag, FontTable]
  TableHeaderList = seq[Header]

  FontType* = enum
    FT_BASE14, FT_TRUETYPE

  Font* = ref object of RootObj
    ID*: int
    subType*: FontType
    searchName*: string

  TONGIDCache* = tuple[oldGID, newGID: int]
  CH2GIDMAPCache* = OrderedTable[int, TONGIDCache]

  FontDef* = ref object
    checksum: int64
    tables: FontTableMap
    sfntVersion, numTables, searchRange, entrySelector, rangeShift: int
    fullCharMap*: CH2GIDMAPCache  # Cache for full character mapping

  FontArray* = seq[FontDef]

  FontDescriptor* = ref object
    postscriptName*: string
    firstChar*: int
    lastChar*: int
    fontFamily*: string
    Flags*:int
    BBox*: array[0..3, int]
    italicAngle*: float
    Ascent*: int
    Descent*: int
    capHeight*: int
    stemV*:int
    xHeight*:int
    missingWidth*: int

proc newTable(header: Header, data: FontData): FontTable =
  let tag = header.tag()

  case tag
  of TAG.head: result = newHEADTable(header, data)
  of TAG.cmap: result = newCMAPTable(header, data)
  of TAG.hhea: result = newHHEATable(header, data)
  of TAG.hmtx: result = newHMTXTable(header, data)
  of TAG.maxp: result = newMAXPTable(header, data)
  of TAG.vhea: result = newVHEATable(header, data)
  of TAG.vmtx: result = newVMTXTable(header, data)
  of TAG.name: result = newNAMETable(header, data)
  of TAG.OS_2: result = newOS2Table(header, data)
  of TAG.glyf: result = newGLYPHTable(header, data)
  of TAG.loca: result = newLOCATable(header, data)
  #of Tag.EBDT, Tag.bdat:
    #result = makeEbdtTableBuilder(header, data)
  #of Tag.EBLC, Tag.bloc:
    #result = makeEblcTableBuilder(header, data)
  #of Tag.EBSC:
    #result = makeEbscTableBuilder(header, data)
  of TAG.bhed: result = newHEADTable(header, data)
  of TAG.hdmx: result = newHDMXTable(header, data)
  of TAG.post: result = newPOSTTable(header, data)
  else:
    new(result)
    initFontTable(result, header, data)

proc getSfntVersion*(f: FontDef): int = f.sfntVersion
proc getChecksum*(f: FontDef): int64 = f.checksum
proc getNumTables*(f: FontDef): int = f.tables.len

proc hasTable*(f: FontDef, tag: TTag): bool = f.tables.hasKey(tag)

proc getTable*(f: FontDef, tag: TTag): FontTable =
  if not f.hasTable(tag): return nil
  result = f.tables[tag]

proc getTableMap*(f: FontDef): FontTableMap = f.tables

proc newFont*(): FontDef =
  new(result)
  result.sfntVersion = fixed1616Fixed(SFNTVERSION_MAJOR, SFNTVERSION_MINOR)

proc readHeader(f: FontDef, fis: FontInputStream): TableHeaderList =
  result = @[]

  f.sfntVersion   = fis.readFixed()
  f.numTables     = fis.readUShort()
  f.searchRange   = fis.readUShort()
  f.entrySelector = fis.readUShort()
  f.rangeShift    = fis.readUShort()

  for table_number in 0..f.numTables-1:
    #Need to use temporary vars here.  C++ evaluates function parameters from
    #right to left and thus breaks the order of input stream.
    let tag      = TTag(fis.readULongAsInt())
    let checksum = fis.readULong()
    let offset   = fis.readULongAsInt()
    let length   = fis.readULongAsInt()
    var header   = initHeader(tag, checksum, offset, length)
    result.add(header)

  result.sort(proc(x,y: Header): int = offsetSortedComparator(x,y) )

proc readHeader(f: FontDef, fd: FontData, offset: int): TableHeaderList =
  result = @[]
  f.sfntVersion   = fd.readFixed(offset + kSfntVersion)
  f.numTables     = fd.readUShort(offset + kNumTables)
  f.searchRange   = fd.readUShort(offset + kSearchRange)
  f.entrySelector = fd.readUShort(offset + kEntrySelector)
  f.rangeShift    = fd.readUShort(offset + kRangeShift)

  var tableOffset = offset + kTableRecordBegin
  for table_number in 0..f.numTables-1:
    let tag      = TTag(fd.readULongAsInt(tableOffset + kTableTag))
    let checksum = fd.readULong(tableOffset + kTableCheckSum)
    let offset   = fd.readULongAsInt(tableOffset + kTableOffset)
    let length   = fd.readULongAsInt(tableOffset + kTableLength)
    var header   = initHeader(tag, checksum, offset, length)
    result.add(header)
    inc(tableOffset, kTableRecordSize)

  result.sort(proc(x,y: Header): int = offsetSortedComparator(x,y) )

proc loadTable(headers: TableHeaderList, fis: FontInputStream): FontTableMap =
  result = initTable[TTag, FontTable]()
  for header in headers:
    discard fis.skip(header.offset() - fis.position())
    var data = newFontData(header.length())
    data.copyFrom(fis, header.length())
    result[header.tag()] = newTable(header, data)

proc loadTable(headers: TableHeaderList, fd: FontData): FontTableMap =
  result = initTable[TTag, FontTable]()
  for header in headers:
    var data = newFontData(header.length())
    discard fd.copyTo(data, 0, header.offset(), header.length())
    result[header.tag()] = newTable(header, data)

proc InterRelateTables(f: FontDef) =
  var head = HEADTable(f.getTable(TAG.head))
  var hhea = HHEATable(f.getTable(TAG.hhea))
  var maxp = MAXPTable(f.getTable(TAG.maxp))
  var loca = LOCATable(f.getTable(TAG.loca))
  var hmtx = HMTXTable(f.getTable(TAG.hmtx))
  var hdmx = HDMXTable(f.getTable(TAG.hdmx))
  var glyf = GLYPHTable(f.getTable(TAG.glyf))
  var vhea = VHEATable(f.getTable(TAG.vhea))
  var vmtx = VMTXTable(f.getTable(TAG.vmtx))

  if vmtx != nil:
    if maxp != nil: vmtx.setNumGlyphs(maxp.NumGlyphs())
    if vhea != nil: vmtx.setNumberOfVMetrics(vhea.NumberOfVMetrics())

  if hmtx != nil:
    if maxp != nil: hmtx.setNumGlyphs(maxp.NumGlyphs())
    if hhea != nil: hmtx.setNumberOfHMetrics(hhea.NumberOfHMetrics())

  if loca != nil:
    if maxp != nil: loca.SetNumGlyphs(maxp.NumGlyphs())
    if head != nil: loca.SetFormatVersion(head.GetIndexToLocFormat())
    if glyf != nil: glyf.SetLoca(loca)

  #Note: In C++, hdmx can be nil in a subsetter.
  if maxp != nil and hdmx != nil:
    hdmx.SetNumGlyphs(maxp.NumGlyphs())

proc loadFont(f: FontDef, istream: InputStream) =
  var fis = newFontInputStream(istream)
  var headers = f.readHeader(fis)
  f.tables = loadTable(headers, fis)
  InterRelateTables(f)
  fis.close()

proc loadFont(f: FontDef, fd: FontData, offset_to_offset_table: int) =
  var headers = f.readHeader(fd, offset_to_offset_table)
  f.tables = loadTable(headers, fd)
  InterRelateTables(f)

#-------------------------------------------------------------
proc isCollection(istream: InputStream): bool =
  var tag = newString(4)
  discard istream.read(tag)
  discard istream.skip(-4)
  result = TAG.ttcf == generateTag(tag)

proc isCollection(fd: FontData): bool =
  var tag = newString(4)
  discard fd.readBytes(0, tag, 0, tag.len)
  result = TAG.ttcf == generateTag(tag)

proc loadSingleOTF*(istream: InputStream): FontDef =
  result = newFont()
  loadFont(result, istream)

proc loadSingleOTF*(fd: FontData): FontDef =
  result = newFont()
  loadFont(result, fd, 0)

proc loadCollection*(fd: FontData): FontArray =
  result = @[]

  discard fd.readULongAsInt(kTTCTag)
  discard fd.readFixed(kVersion)
  let numFonts = fd.readULongAsInt(kNumFonts)

  var offsetTableOffset = kOffsetTable
  for i in 0..numFonts-1:
    let offset = fd.readULongAsInt(offsetTableOffset)
    var font = newFont()
    loadFont(font, fd, offset)
    result.add(font)
    offsetTableOffset += DataSize.kULONG

proc loadCollection*(istream: InputStream): FontArray =
  var fd = newFontData(istream.available())
  fd.copyFrom(istream)
  result = loadCollection(fd)

proc loadFonts*(istream: InputStream): FontArray =
  if isCollection(istream):
    return loadCollection(istream)

  var font = loadSingleOTF(istream)
  if font != nil:
    return @[font]

  result = @[]

proc loadFonts*(b: ByteVector): FontArray =
  var fd = newFontData(b)
  if isCollection(fd):
    return loadCollection(fd)

  var font = loadSingleOTF(fd)
  if font != nil:
    return @[font]

  result = @[]

proc loadTTF*(fileName: string): FontDef =
  var fis = newFileInputStream(fileName)
  if fis == nil:
    echo "cannot open ", fileName
    return nil
  result = loadSingleOTF(fis)

proc loadTTC*(fileName: string, fontIndex: int): FontDef =
  var fis = newFileInputStream(fileName)
  if fis == nil:
    echo "cannot open ", fileName
    return nil
  let fonts = loadCollection(fis)
  if fontIndex < 0 or fontIndex >= fonts.len:
    echo "loadTTC out of bound"
    return nil
  result = fonts[fontIndex]

#-------------------------------------------------------
proc serializeFont*(tables: var seq[FontTable]): FontData =
  keepItIf(tables, it != nil)

  let numTables = tables.len
  var offset = kSfntHeaderSize + kTableRecordSize * numTables

  tables.sort(proc(x,y: FontTable): int = cmp( int(x.headerTag()), int(y.headerTag()) ) )

  var headoffset = 0
  for i in 0..tables.len-1:
    if tables[i] == nil: continue
    if tables[i].headerTag() == TAG.head:
      HEADTable(tables[i]).SetChecksumAdjustment(0)
      headoffset = offset

    discard tables[i].calculatedChecksum()
    tables[i].setTableOffset(offset)
    offset += ((tables[i].dataLength() + 3) and not 3)

  var fd = newFontData(offset)

  discard fd.writeFixed(kSfntVersion, fixed1616Fixed(SFNTVERSION_MAJOR, SFNTVERSION_MINOR))
  discard fd.writeUShort(kNumTables, numTables)

  let log2_of_max_power_of_2 = Log2(numTables)
  let searchRange = 2 shl (log2_of_max_power_of_2 - 1 + 4)

  discard fd.writeUShort(kSearchRange, searchRange)
  discard fd.writeUShort(kEntrySelector, log2_of_max_power_of_2)
  discard fd.writeUShort(kRangeShift, (numTables * kTableRecordSize) - searchRange)

  var tableOffset = kTableRecordBegin
  for i in 0..tables.len-1:
    if tables[i] == nil: continue
    let header = tables[i].getHeader()
    discard fd.writeULong(tableOffset + kTableTag, int(header.tag()))
    discard fd.writeULong(tableOffset + kTableCheckSum, header.checksum())
    discard fd.writeULong(tableOffset + kTableOffset, header.offset())
    discard fd.writeULong(tableOffset + kTableLength, header.length())
    tableOffset += kTableRecordSize

  for i in 0..tables.len-1:
    if tables[i] == nil: continue
    discard tables[i].serialize(fd, tableOffset)
    let tableSize = tables[i].dataLength()
    let paddingSize = ((tableSize + 3) and not 3) - tableSize
    tableOffset += tableSize
    for i in 0..paddingSize-1:
      discard fd.writeByte(tableOffset, chr(0))
      inc(tableOffset)

  var checksum = checksum(fd, fd.length())
  discard fd.writeULong(headoffset + 8, 0xB1B0AFBA - checksum)
  result = fd

proc embedFullFont*(font: FontDef, newTag: string): FontData =
  var cmap = CMAPTable(font.getTable(TAG.cmap))
  var maxp = MAXPTable(font.getTable(TAG.maxp))
  var glyf = GLYPHTable(font.getTable(TAG.glyf))
  var head = HEADTable(font.getTable(TAG.head))
  var hhea = HHEATable(font.getTable(TAG.hhea))
  var hmtx = HMTXTable(font.getTable(TAG.hmtx))
  var name = NAMETable(font.getTable(TAG.name))
  var post = POSTTable(font.getTable(TAG.post))
  var os2  = OS2Table(font.getTable(TAG.OS_2))
  var cvt  = font.getTable(TAG.cvt)
  var fpgm = font.getTable(TAG.fpgm)
  var prep = font.getTable(TAG.prep)
  var gasp = font.getTable(TAG.gasp)
  var vhea = VHEATable(font.getTable(TAG.vhea))
  var vmtx = VMTXTable(font.getTable(TAG.vmtx))

  var isSymbol = false
  if os2 != nil:
    isSymbol = os2.IsSymbolCharSet() and
      cmap.CMAPavailable(proc(platformID, encodingID, format: int): bool =
        result = (platformID == 3) and (encodingID == 0) )

  # Use the cached full character mapping from FontDef
  var CH2GID = initOrderedTable[int, TONGID]()
  var encodingcmap = cmap.GetEncodingCMAP()
  if encodingcmap != nil:
    if font.fullCharMap.len > 0:
      CH2GID = font.fullCharMap
    else:
      # Initialize the cache if not already done
      for i in 0..0xFFFF:
        let gid = encodingcmap.GlyphIndex(i)
        if gid != 0:
          CH2GID[i] = (gid, gid)
      font.fullCharMap = CH2GID

  var newglyf = glyf # Keep original glyph table
  var newloca = newglyf.GetLoca()
  head.SetIndexToLocFormat(newLoca.GetFormatVersion())
  hhea.SetNumberOfHMetrics(maxp.NumGlyphs())
  maxp.SetNumGlyphs(maxp.NumGlyphs())
  var newhmtx = hmtx # Keep original hmtx table
  var newcmap = encodeCMAPTable(CH2GID, isSymbol)
  var newname = encodeNAMETable(name, newTag)
  var newpost = encodePOSTTable(post)

  # Keep all original tables
  var tables = @[newcmap, newglyf, head, hhea, newhmtx, newloca, maxp, newname, os2, newpost, prep, cvt, fpgm, gasp]
  if vhea != nil and vmtx != nil:
    vhea.SetNumberOfVMetrics(maxp.NumGlyphs())
    var newvmtx = vmtx # Keep original vmtx table
    tables.add(vhea)
    tables.add(newvmtx)

  result = serializeFont(tables)

proc subset*(font: FontDef, CH2GID: CH2GIDMAP, newTag: string): FontData =
  var cmap = CMAPTable(font.getTable(TAG.cmap))
  var maxp = MAXPTable(font.getTable(TAG.maxp))
  var glyf = GLYPHTable(font.getTable(TAG.glyf))
  var head = HEADTable(font.getTable(TAG.head))
  var hhea = HHEATable(font.getTable(TAG.hhea))
  var hmtx = HMTXTable(font.getTable(TAG.hmtx))
  var name = NAMETable(font.getTable(TAG.name))
  var post = POSTTable(font.getTable(TAG.post))
  var os2  = OS2Table(font.getTable(TAG.OS_2))
  var cvt  = font.getTable(TAG.cvt)
  var fpgm = font.getTable(TAG.fpgm)
  var prep = font.getTable(TAG.prep)
  var gasp = font.getTable(TAG.gasp)
  var vhea = VHEATable(font.getTable(TAG.vhea))
  var vmtx = VMTXTable(font.getTable(TAG.vmtx))

  var isSymbol = false
  if os2 != nil:
    isSymbol = os2.IsSymbolCharSet() and
      cmap.CMAPavailable(proc(platformID, encodingID, format: int): bool =
        result = (platformID == 3) and (encodingID == 0) )

  var GID2GID = initOrderedTable[int, int](math.nextPowerOfTwo(CH2GID.len))
  GID2GID[0] = 0
  for key, val in pairs(CH2GID):
    if not GID2GID.hasKey(val.oldGID):
      GID2GID[val.oldGID] = val.newGID

  GID2GID.sort(proc(x,y: tuple[key,val: int] ):int = cmp(x.val, y.val) )

  var newglyf = EncodeGLYPHTable(glyf, GID2GID) #GID2GID maybe larger after this line
  var newloca = newglyf.GetLoca()
  head.SetIndexToLocFormat(newLoca.GetFormatVersion())
  hhea.SetNumberOfHMetrics(GID2GID.len)
  maxp.SetNumGlyphs(GID2GID.len)
  var newhmtx = encodeHMTXTable(hmtx, GID2GID)
  var newcmap = encodeCMAPTable(CH2GID, isSymbol)
  var newname = encodeNAMETable(name, newTag)
  var newpost = encodePOSTTable(post)

  #cmap, glyf, head, hhea, hmtx, loca, maxp, name, post, os/2
  var tables = @[newcmap, newglyf, head, hhea, newhmtx, newloca, maxp, newname, os2, newpost, prep, cvt, fpgm, gasp]
  if vhea != nil and vmtx != nil:
    vhea.SetNumberOfVMetrics(GID2GID.len)
    var newvmtx = encodeVMTXTable(vmtx, GID2GID)
    tables.add(vhea)
    tables.add(newvmtx)

  result = serializeFont(tables)

proc newFontDescriptor*(font: FontDef, CH2GID: CH2GIDMAP): FontDescriptor =
  var fd: FontDescriptor
  new(fd)

  var name = NAMETable(font.getTable(TAG.name))
  var post = POSTTable(font.getTable(TAG.post))
  var os2  = OS2Table(font.getTable(TAG.OS_2))
  var head = HEADTable(font.getTable(TAG.head))
  var hhea = HHEATable(font.getTable(TAG.hhea))
  var hmtx = HMTXTable(font.getTable(TAG.hmtx))
  var cmap = CMAPTable(font.getTable(TAG.cmap))

  fd.postscriptName = name.GetPostscriptName()
  fd.fontFamily = name.GetFontFamily()

  var Ascent = hhea.Ascender()
  var Descent = hhea.Descender()
  var LineGap = hhea.LineGap()
  var isSymbol = false

  if os2 != nil and os2.TableVersion() == 1:
    Ascent = os2.STypoAscender()
    Descent = os2.STypoDescender()
    LineGap = os2.STypoLineGap()
    isSymbol = os2.IsSymbolCharSet() and
      cmap.CMAPavailable(proc(platformID, encodingID, format: int): bool =
        result = (platformID == 3) and (encodingID == 0) )

  fd.capHeight = Ascent
  fd.xHeight = 0
  if os2 != nil and os2.TableVersion() == 0:
    fd.capHeight = os2.SCapHeight()
    fd.xHeight = os2.SxHeight()

  var usWeightClass = 500
  var familyClass = 0

  if os2 != nil:
    usWeightClass = os2.UsWeightClass()
    familyClass = os2.SFamilyClass() shr 8

  let scaleFactor = 1000 / head.UnitsPerEm()
  fd.BBox[0] = math.round(float(head.XMin()) * scaleFactor).int
  fd.BBox[1] = math.round(float(head.YMin()) * scaleFactor).int
  fd.BBox[2] = math.round(float(head.XMax()) * scaleFactor).int
  fd.BBox[3] = math.round(float(head.YMax()) * scaleFactor).int

  fd.missingWidth = math.round(float(hmtx.advanceWidth(0)) * scaleFactor).int
  fd.stemV = 50 + int(math.pow(float(usWeightClass) / 65.0, 2))

  fd.Ascent = math.round(float(Ascent) * scaleFactor).int
  fd.Descent = math.round(float(Descent) * scaleFactor).int

  let isSerif  = familyClass in {1,2,3,4,5,7}
  let isScript = familyClass == 10

  if post != nil:
    let raw = post.ItalicAngle()
    var hi = raw shr 16
    var lo = raw and 0xFFFF
    if (hi and 0x8000) != 0: hi = -((hi xor 0xFFFF) + 1)
    fd.italicAngle = toFloat(hi) + (toFloat(lo) / 65536)
  else:
    fd.italicAngle = 0.0

  fd.Flags = 0
  if post.IsFixedPitch() != 0: fd.Flags = fd.Flags or 1
  if isSerif: fd.Flags = fd.Flags or (1 shl 1)
  if isScript: fd.Flags = fd.Flags or (1 shl 3)
  if fd.italicAngle != 0: fd.Flags = fd.Flags or (1 shl 6)

  if isSymbol:
    fd.Flags = fd.Flags or (1 shl 2)
  else:
    fd.Flags = fd.Flags or (1 shl 5) # assume the font is nonsymbolic...

  var i = 0
  for ch in keys(CH2GID):
    if i == 0:
      fd.firstChar = ch
      fd.lastChar = ch
    fd.firstChar = min(fd.firstChar, ch)
    fd.lastChar = max(fd.lastChar, ch)
    inc(i)

  result = fd
