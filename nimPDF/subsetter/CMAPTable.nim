# Copyright (c) 2015 Andri Lim
#
# Distributed under the MIT license
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------
import FontData, tables

const
  kTableVersion = 0
  kNumberOfEncodingTables = 2
  kHeaderSize = 4

  kSubtableEntryStart = 4
  kPlatformID = 0
  kEncodingID = 2
  kSubtableOffset = 4
  kSubtableEntrySize = 8

  kFormat = 0
  kLength = 2
  kVersion = 4

  kSegCountX2 = 6
  kSearchRange = 8
  kEntrySelector = 10
  kRangeShift = 12
  kSegmentStart = 14

  kSubHeaderKeyStart = 6
  kSubHeaderStart = kSubHeaderKeyStart + 2 * 256
  kSubHeaderSize  = 8
  kFirstCode = 0
  kEntryCount = 2
  kIdDelta = 4
  kIdRangeOffset = 6

  knGroups = 12
  kGroupStart = 16
  kGroupSize = 12
  kStartCode = 0
  kEndCode = 4
  kStartGlyphCode = 8

  kLength32 = 4
  kVersion32 = 8
type
  TONGID* = tuple[oldGID, newGID: int]
  CH2GIDMAP* = OrderedTable[int, TONGID]
  RANGES* = OrderedTable[int, seq[int]]

  CMAP* = ref object of RootObj
    data: FontData

  CMAP0* = ref object of CMAP
  CMAP2* = ref object of CMAP
    numSubHeaders: int

  CMAP4* = ref object of CMAP
  CMAP6* = ref object of CMAP
  CMAP12* = ref object of CMAP

  CMAPTable* = ref object of FontTable
    encodingcmap: CMAP

proc Format*(t: CMAP): int =
  result = t.data.readUShort(kFormat)

method Length*(t: CMAP): int {.base.} =
  result = t.data.readUShort(kLength)

method Version*(t: CMAP): int {.base.} =
  result = t.data.readUShort(kVersion)

method Length(t: CMAP12): int =
  result = t.data.readULongAsInt(kLength32)

method Version(t: CMAP12): int =
  result = t.data.readULongAsInt(kVersion32)

method GlyphIndex*(t: CMAP, charCode: int): int {.base.} =
  discard

method GlyphIndex*(t: CMAP0, charCode: int): int =
  if charCode < 0 or charCode > 255: return 0
  result = t.data.readUByte(6 + charCode)

proc newCMAP0(data: FontData): CMAP0 =
  new(result)
  result.data = data

proc SegCount(t: CMAP4): int =
  result = int(t.data.readUShort(kSegCountX2) div 2)

proc EndCode(t: CMAP4, index: int): int =
  result = t.data.readUShort(kSegmentStart + index * Datasize.kUSHORT)

proc StartCode(t: CMAP4, index: int): int =
  let segcount = t.SegCount()
  result = t.data.readUShort(kSegmentStart + segcount * DataSize.kUSHORT + index * Datasize.kUSHORT + Datasize.kUSHORT)

proc idDelta(t: CMAP4, index: int): int =
  let segcount = t.SegCount() * 2
  result = t.data.readUShort(kSegmentStart + segcount * DataSize.kUSHORT + index * Datasize.kUSHORT + Datasize.kUSHORT)

proc idRangeOffsetOffset(segcount, index: int): int =
  result = kSegmentStart + (segcount * 3 + 1) * DataSize.kUSHORT + index * Datasize.kUSHORT

proc idRangeOffset(t: CMAP4, index: int): int =
  let segcount = t.SegCount()
  result = t.data.readUShort(idRangeOffsetOffset(segcount, index))

proc GlyphIdArray(t: CMAP4, index: int): int =
  let segcount = t.SegCount() * 4
  result = t.data.readUShort(kSegmentStart + segcount * DataSize.kUSHORT + index * Datasize.kUSHORT + Datasize.kUSHORT)

proc GlyphIdArrayLength(t: CMAP4): int =
  let segcount = t.SegCount() * 4
  let offset = kSegmentStart + segcount * DataSize.kUSHORT + Datasize.kUSHORT
  result = int((t.Length() - offset) div 2)

proc GlyphIndex1*(t: CMAP4, charCode: int): int =
  let segCount = t.SegCount()
  if segCount == 0: return 0 #no glyph

  var i = 0
  while i < segCount:
    if charCode <= t.EndCode(i): break
    inc(i)

  let startCode = t.StartCode(i)
  let idDelta = t.idDelta(i)
  let idRangeOffset = t.idRangeOffset(i)

  if startCode > charCode: return 0 #missing glyph
  if idRangeOffset == 0: return (charCode + idDelta) and 0xFFFF

  let idx = int(idRangeOffset div 2) + (charCode - startCode) - (segCount - i)
  if idx >= t.GlyphIdArrayLength(): return 0

  let GlyphId = t.GlyphIdArray(idx)
  if GlyphId == 0: return 0
  result = (GlyphId + idDelta) and 0xFFFF

method GlyphIndex*(t: CMAP4, charCode: int): int =
  let segCount = t.SegCount()
  if segCount == 0: return 0 #no glyph

  var i = 0
  while i < segCount:
    if charCode <= t.EndCode(i): break
    inc(i)

  let startCode = t.StartCode(i)
  let IdDelta = t.idDelta(i)
  let IdRangeOffsetOffset = idRangeOffsetOffset(segCount, i)
  let IdRangeOffset = t.data.readUShort(IdRangeOffsetOffset)

  if startCode > charCode: return 0 #missing glyph
  if IdRangeOffset == 0: return (charCode + IdDelta) and 0xFFFF

  #(idRangeOffset[i] / 2) + (charCode - StartCode) + &idRangeOffset[i]
  let offset = IdRangeOffset + Datasize.kUSHORT * (charCode - startCode) + IdRangeOffsetOffset
  if offset > (t.Length() - Datasize.kUSHORT): return 0

  let GlyphId = t.data.readUShort(offset)
  if GlyphId == 0: return 0
  result = (GlyphId + IdDelta) and 0xFFFF

proc newCMAP4(data: FontData): CMAP4 =
  new(result)
  result.data = data

proc SubHeaderKey(t: CMAP2, idx: int): int =
  assert(idx >= 0 and idx <= 256)
  result = t.data.readUShort(kSubHeaderKeyStart + Datasize.kUSHORT * idx) div 8

proc FirstCode(t: CMAP2, idx: int): int =
  assert(idx >= 0 and idx <= t.numSubHeaders)
  result = t.data.readUShort(kSubHeaderStart + kSubHeaderSize * idx + kFirstCode)

proc EntryCount(t: CMAP2, idx: int): int =
  assert(idx >= 0 and idx <= t.numSubHeaders)
  result = t.data.readUShort(kSubHeaderStart + kSubHeaderSize * idx + kEntryCount)

proc IdDelta(t: CMAP2, idx: int): int =
  assert(idx >= 0 and idx <= t.numSubHeaders)
  result = t.data.readShort(kSubHeaderStart + kSubHeaderSize * idx + kIdDelta)

proc IdRangeOffset(t: CMAP2, idx: int): int =
  assert(idx >= 0 and idx <= t.numSubHeaders)
  result = t.data.readUShort(kSubHeaderStart + kSubHeaderSize * idx + kIdRangeOffset)

#proc GlyphIdArrayLength(t: CMAP2): int =
#  result = (t.Length() - 518 - t.numSubHeaders * 8) div 2

#proc GlyphIndexArray(t: CMAP2, idx: int): int =
#  result = t.data.readUShort(kSubHeaderStart + kSubHeaderSize * t.numSubHeaders + Datasize.kUSHORT * idx)

proc GetSubHeader(t: CMAP2, charCode: int): int =
  result = -1
  if charCode < 0x10000:
    let charLo = charCode and 0xFF
    let charHi = charCode shr 8
    if charHi == 0:
      # an 8-bit character code -- we use subHeader 0 in this case
      # to test whether the character code is in the charmap

      # check that the sub-header for this byte is 0, which
      # indicates that it is really a valid one-byte value
      if t.SubHeaderKey(charLo) == 0: result = 0
    else:
      # a 16-bit character code
      let i = t.SubHeaderKey(charLo)

      # check that the high byte isn't a valid one-byte value
      if i != 0: result = i

method GlyphIndex*(t: CMAP2, charCode: int): int =
  proc idRangeOffsetOffset(idx: int): int {.inline.} =
    result = kSubHeaderStart + kSubHeaderSize * idx + kIdRangeOffset

  result = 0
  let subheader = t.GetSubHeader(charCode)
  if subheader >= 0:
    var idx = charCode and 0xFF

    let firstCode     = t.FirstCode(subheader)
    let entryCount    = t.EntryCount(subheader)
    let idDelta       = t.IdDelta(subheader)
    var idRangeOffset = t.IdRangeOffset(subheader)

    idx -= firstCode
    if (idx < entryCount) and (idRangeOffset != 0):
      let offset = idRangeOffset + Datasize.kUSHORT * idx + idRangeOffsetOffset(subheader)
      if offset > (t.Length() - Datasize.kUSHORT): return 0
      idx = t.data.readUShort(offset)
      if idx != 0: result = (idx + idDelta) and 0xFFFF

proc newCMAP2(data: FontData): CMAP2 =
  new(result)
  result.data = data
  result.numSubHeaders = 0
  for i in 0..255:
    result.numSubHeaders = max(result.numSubHeaders, result.SubHeaderKey(i))

  #the number of subHeaders is one plus the max of subHeaderKeys
  inc result.numSubHeaders

proc FirstCode(t: CMAP6): int =
  result = t.data.readUShort(6 + kFirstCode)

proc EntryCount(t: CMAP6): int =
  result = t.data.readUShort(6 + kEntryCount)

proc GlyphIndexArray(t: CMAP6, idx: int): int =
  result = t.data.readUShort(10 + idx * Datasize.kUSHORT)

method GlyphIndex*(t: CMAP6, charCode: int): int =
  result = 0
  let idx = charCode - t.FirstCode()
  if idx < t.EntryCount():
    result = t.GlyphIndexArray(idx)

proc newCMAP6(data: FontData): CMAP6 =
  new(result)
  result.data = data

proc nGroups(t: CMAP12): int =
  result = t.data.readULongAsInt(knGroups)

proc StartCode(t: CMAP12, idx: int): int =
  result = t.data.readULongAsInt(kGroupStart + idx * kGroupSize + kStartCode)

proc EndCode(t: CMAP12, idx: int): int =
  result = t.data.readULongAsInt(kGroupStart + idx * kGroupSize + kEndCode)

proc StartGlyphCode(t: CMAP12, idx: int): int =
  result = t.data.readULongAsInt(kGroupStart + idx * kGroupSize + kStartGlyphCode)

method GlyphIndex*(t: CMAP12, charCode: int): int =
  result = 0
  var i = t.nGroups() - 1
  while (i >= 0) and (charCode <= t.EndCode(i)):
    let startCode = t.StartCode(i)
    if charCode >= startCode:
      result = charCode - startCode + t.StartGlyphCode(i)
      break
    dec i

proc newCMAP12(data: FontData): CMAP12 =
  new(result)
  result.data = data

#proc TableVersion(t: CMAPTable): int =
#  result = t.data.readUShort(kTableVersion)

proc NumberOfEncodingTables(t: CMAPTable): int =
  result = t.data.readUShort(kNumberOfEncodingTables)

proc PlatformID(t: CMAPTable, index: int): int =
  result = t.data.readUShort(kSubtableEntryStart + index * kSubtableEntrySize + kPlatformID)

proc EncodingID(t: CMAPTable, index: int): int =
  result = t.data.readUShort(kSubtableEntryStart + index * kSubtableEntrySize + kEncodingID)

proc SubtableOffset(t: CMAPTable, index: int): int =
  result = t.data.readULongAsInt(kSubtableEntryStart + index * kSubtableEntrySize + kSubtableOffset)

proc FindEncodingCMap(t: CMAPTable, filter: proc(platformID, encodingID, format: int): bool): CMAP =
  let numberOfEncodingTables = t.NumberOfEncodingTables()

  for i in 0..numberOfEncodingTables-1:
    let platformID = t.PlatformID(i)
    let encodingID = t.EncodingID(i)
    let offsetx = t.SubtableOffset(i)
    let format = t.data.readUShort(offsetx + kFormat)
    let length = if format in {0, 2, 4, 6}: t.data.readUShort(offsetx + kLength) else: t.data.readULongAsInt(offsetx + 4)

    if filter(platformID, encodingID, format):
      if format == 12: result = newCMAP12(t.data.slice(offsetx, length))
      if format == 4: result = newCMAP4(t.data.slice(offsetx, length))
      if format == 6: result = newCMAP6(t.data.slice(offsetx, length))
      if format == 2: result = newCMAP2(t.data.slice(offsetx, length))
      if format == 0: result = newCMAP0(t.data.slice(offsetx, length))
      break

proc CMAPavailable*(t: CMAPTable, filter: proc(platformID, encodingID, format: int): bool): bool =
  let numberOfEncodingTables = t.NumberOfEncodingTables()

  for i in 0..numberOfEncodingTables-1:
    let platformID = t.PlatformID(i)
    let encodingID = t.EncodingID(i)
    let offsetx = t.SubtableOffset(i)
    let format = t.data.readUShort(offsetx + kFormat)

    if filter(platformID, encodingID, format):
      return true

  return false

proc newCMAPTable*(header: Header, data: FontData): CMAPTable =
  new(result)
  initFontTable(result, header, data)
  result.encodingcmap = nil

proc GetEncodingCMAP*(t: CMAPTable): CMAP =
  if t.encodingcmap != nil: return t.encodingcmap

  t.encodingcmap = t.FindEncodingCMap(
    proc(platformID, encodingID, format: int): bool =
      result = (platformID == 3) and (encodingID == 10) and (format == 12))
  if t.encodingcmap != nil: return t.encodingcmap

  t.encodingcmap = t.FindEncodingCMap(
    proc(platformID, encodingID, format: int): bool =
      result = (platformID == 0) and (encodingID == 4) and (format == 12))
  if t.encodingcmap != nil: return t.encodingcmap

  t.encodingcmap = t.FindEncodingCMap(
    proc(platformID, encodingID, format: int): bool =
      result = (platformID == 3) and (encodingID == 1) and (format == 4) )
  if t.encodingcmap != nil: return t.encodingcmap

  t.encodingcmap = t.FindEncodingCMap(
    proc(platformID, encodingID, format: int): bool =
      result = (platformID == 0) and (format == 4) )
  if t.encodingcmap != nil: return t.encodingcmap

  t.encodingcmap = t.FindEncodingCMap(
    proc(platformID, encodingID, format: int): bool =
      result = (platformID == 1) and (format == 0) )
  if t.encodingcmap != nil: return t.encodingcmap

  result = nil

proc EncodeCMAP0(CH2GID: CH2GIDMAP): FontData =
  let size = 6 + 256
  var fd = newFontData(size)
  discard fd.writeUShort(kFormat, 0)
  discard fd.writeUShort(kLength, size)
  discard fd.writeUShort(kVersion, 0)
  for i in 0..255:
    if CH2GID.hasKey(i):
      let id = CH2GID[i].newGID
      if id >= 0 and id <= 255: discard fd.writeByte(6 + i, chr(id))
      else: discard fd.writeByte(6 + i, chr(0))
    else: discard fd.writeByte(6 + i, chr(0))
  result = fd

proc makeRanges*(CH2GID: CH2GIDMAP): RANGES =
  var rangeid = 0
  var ranger = initOrderedTable[int, seq[int]]()
  var prevcid = -2
  var prevglidx = -1
  # for each character
  var glidx = 0
  for cid, gid in pairs(CH2GID):
    glidx = gid.newGID
    if (cid == (prevcid + 1) and glidx == (prevglidx + 1)):
      ranger[rangeid].add(glidx)
    else:
      # new range
      rangeid = cid
      ranger[rangeid] = @[]
      ranger[rangeid].add(glidx)
    prevcid = cid
    prevglidx = glidx

  ranger.sort(proc(x,y: tuple[key: int, val: seq[int]] ):int = cmp(x.key,y.key) )
  result = ranger

proc EncodeCMAP4(CH2GID: CH2GIDMAP): FontData =
  let ranger = makeRanges(CH2GID)

  var segCount = ranger.len + 1
  var endCode, startCode, idDelta, idRangeOffsets: seq[int]
  newSeq(endCode, segCount)
  newSeq(startCode, segCount)
  newSeq(idDelta, segCount)
  newSeq(idRangeOffsets, segCount)
  var glyphIDs: seq[int] = @[]

  var i = 0
  for start, subrange in ranger:
    startCode[i] = start
    endCode[i] = start + (len(subrange)-1)

    let startGlyph = subrange[0]
    if start - startGlyph >= 0x8000:
      idDelta[i] = 0
      idRangeOffsets[i] = 2 * (glyphIDs.len + segCount - i)
      for id in subrange: glyphIDs.add(id)
    else:
      idDelta[i] = -(start-subrange[0])
      idRangeOffsets[i] = 0

    inc(i)

  startCode[i] = 0xFFFF
  endCode[i] = 0xFFFF
  idDelta[i] = 1
  idRangeOffsets[i] = 0

  var searchRange = 1
  var entrySelector = 0
  while (searchRange * 2 <= segCount ):
    searchRange = searchRange * 2
    entrySelector = entrySelector + 1

  searchRange = searchRange * 2
  var rangeShift = segCount * 2 - searchRange

  var size = 16 + (8 * segCount) + glyphIDs.len * 2
  var fd = newFontData(size)

  discard fd.writeUShort(kFormat, 4)
  discard fd.writeUShort(kLength, size)
  discard fd.writeUShort(kVersion, 0)
  discard fd.writeUShort(kSegCountX2, segCount * 2)
  discard fd.writeUShort(kSearchRange, searchRange)
  discard fd.writeUShort(kEntrySelector, entrySelector)
  discard fd.writeUShort(kRangeShift, rangeShift)

  var offset = kSegmentStart
  for i in endCode:
    discard fd.writeUShort(offset, i)
    inc(offset, DataSize.kUSHORT)

  #reserved pad
  discard fd.writeUShort(offset, 0)
  inc(offset, DataSize.kUSHORT)

  for i in startCode:
    discard fd.writeUShort(offset, i)
    inc(offset, DataSize.kUSHORT)

  for i in idDelta:
    discard fd.writeUShort(offset, i)
    inc(offset, DataSize.kUSHORT)

  for i in idRangeOffsets:
    discard fd.writeUShort(offset, i)
    inc(offset, DataSize.kUSHORT)

  for i in glyphIDs:
    discard fd.writeUShort(offset, i)
    inc(offset, DataSize.kUSHORT)

  result = fd
#[
proc EncodeCMAP12(CH2GID: CH2GIDMAP): FontData =
  let ranger = makeRanges(CH2GID)

  var nGroups = ranger.len
  var endCode, startCode, startGlyph: seq[int]
  newSeq(endCode, nGroups)
  newSeq(startCode, nGroups)
  newSeq(startGlyph, nGroups)

  var i = 0
  for start, subrange in ranger:
    startCode[i] = start
    endCode[i] = start + subrange.high
    startGlyph[i] = subrange[0]
    inc i

  let size = 16 + kGroupSize * nGroups
  var fd = newFontData(size)
  discard fd.writeUShort(kFormat, 12)
  discard fd.writeULong(kLength32, size)
  discard fd.writeULong(kVersion32, 0)
  discard fd.writeULong(knGroups, nGroups)

  for i in 0.. <nGroups:
    discard fd.writeULong(kGroupStart + kGroupSize * i + kStartCode, startCode[i])
    discard fd.writeULong(kGroupStart + kGroupSize * i + kEndCode, endCode[i])
    discard fd.writeULong(kGroupStart + kGroupSize * i + kStartGlyphCode, startGlyph[i])
]#
proc encodeCMAPTable*(CH2GID: CH2GIDMAP, isSymbol: bool): CMAPTable =
  var tables = [EncodeCMAP0(CH2GID), EncodeCMAP4(CH2GID)]
  let tableStart = kHeaderSize + kSubtableEntrySize * tables.len
  var encID = 1
  if isSymbol: encID = 0

  let platformID = [1, 3]
  let encodingID = [0, encID]

  var size = tableStart
  for t in tables: size += t.length()
  var fd = newFontData(size)

  discard fd.writeUShort(kTableVersion, 0)
  discard fd.writeUShort(kNumberOfEncodingTables, tables.len)

  var subTableOffset = tableStart
  var offset = kHeaderSize
  var i = 0
  for t in tables:
    discard fd.writeUShort(offset + kPlatformID, platformID[i])
    discard fd.writeUShort(offset + kEncodingID, encodingID[i])
    discard fd.writeULong(offset + kSubtableOffset, subTableOffset)
    discard t.copyTo(fd, subTableOffset)
    inc(i)
    inc(subTableOffset, t.length())
    inc(offset, kSubtableEntrySize)

  result = newCMAPTable(initHeader(TAG.cmap, checksum(fd, fd.length()), 0, fd.length()), fd)
