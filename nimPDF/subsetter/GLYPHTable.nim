# Copyright (c) 2015 Andri Lim
#
# Distributed under the MIT license
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------
import FontData, LOCATable, sets, tables, math

const
  kNumberOfContours = 0
  kXMin = 2
  kYMin = 4
  kXMax = 6
  kYMax = 8

  kGlyphBodyStart = 10
  kFlags = 0
  kGlyphIndex = 2

  ARG_1_AND_2_ARE_WORDS    = 0x0001
  WE_HAVE_A_SCALE          = 0x0008
  MORE_COMPONENTS          = 0x0020
  WE_HAVE_AN_X_AND_Y_SCALE = 0x0040
  WE_HAVE_A_TWO_BY_TWO     = 0x0080
  #WE_HAVE_INSTRUCTIONS     = 0x0100

type
  GLYPHTable* = ref object of FontTable
    loca: LOCATable

proc GetAdditionalGlyphs(t: GLYPHTable, index: int, additionalGlyphs: var HashSet[int]) =
  var offset = kGlyphBodyStart + t.loca.GlyphOffset(index)
  while true:
    let flags = t.data.readUShort(offset + kFlags)
    let glyphIndex = t.data.readUShort(offset + kGlyphIndex)
    additionalGlyphs.incl(glyphIndex)
    offset += 4

    if (flags and ARG_1_AND_2_ARE_WORDS) != 0: offset += 4
    else: offset += 2

    if (flags and WE_HAVE_A_TWO_BY_TWO) != 0: offset += 8
    elif (flags and WE_HAVE_AN_X_AND_Y_SCALE) != 0: offset += 4
    elif (flags and WE_HAVE_A_SCALE) != 0: offset += 2

    if (flags and MORE_COMPONENTS) == 0: break

#proc parse(tt: var TT_glyf, data:TTFStream, id: int, loca: TT_loca, additionalGlyphId: var XSet): bool =
#  let offset = int(loca.offset(id))
#  let length = int(loca.length(id))
#
#  var raw = newTTFStream(data.get_ptr(tt.entry.offset + offset), length)
#  let numberOfContours = raw.read_int16()
#  let xMin = raw.read_int16()
#  let yMin = raw.read_int16()
#  let xMax = raw.read_int16()
#  let yMax = raw.read_int16()
#
#  if numberOfContours < 0:
#    discard tt.parse_compound_glyph(raw, id, additionalGlyphId)

proc XMin*(t: GLYPHTable, index: int): int =
  let offset = t.loca.GlyphOffset(index)
  result = t.data.readFWord(offset + kXMin)

proc YMin*(t: GLYPHTable, index: int): int =
  let offset = t.loca.GlyphOffset(index)
  result = t.data.readFWord(offset + kYMin)

proc XMax*(t: GLYPHTable, index: int): int =
  let offset = t.loca.GlyphOffset(index)
  result = t.data.readFWord(offset + kXMax)

proc YMax*(t: GLYPHTable, index: int): int =
  let offset = t.loca.GlyphOffset(index)
  result = t.data.readFWord(offset + kYMax)

proc NumberOfContours*(t: GLYPHTable, index: int): int =
  let offset = t.loca.GlyphOffset(index)
  #let length = t.loca.GlyphLength(index)
  result = t.data.readShort(offset + kNumberOfContours)

proc SetLoca*(t: GLYPHTable, loca: LOCATable) =
  t.loca = loca

proc GetLoca*(t: GLYPHTable) : LOCATable =
  result = t.loca

proc newGLYPHTable*(header: Header, data: FontData): GLYPHTable =
  new(result)
  initFontTable(result, header, data)

proc CollectMoreGlyphs(t: GLYPHTable, neededGlyphs: HashSet[int]): HashSet[int] =
  var additionalGlyphs = initHashSet[int]()
  var visited = initHashSet[int]()

  for i in items(neededGlyphs):
    let length = t.loca.GlyphLength(i)
    if length == 0:
      visited.incl(i)
      continue

    if t.NumberOfContours(i) < 0:
      t.GetAdditionalGlyphs(i, additionalGlyphs)
      visited.incl(i)

  additionalGlyphs = difference(additionalGlyphs, neededGlyphs)
  var moreGlyphs = initHashSet[int]()

  while true:
    for i in items(additionalGlyphs):
      let length = t.loca.GlyphLength(i)
      if length == 0:
        visited.incl(i)
        continue

      if t.NumberOfContours(i) < 0 and not visited.contains(i):
        t.GetAdditionalGlyphs(i, moreGlyphs)
        visited.incl(i)

    if moreGlyphs.card() == 0: break
    additionalGlyphs = union(additionalGlyphs, moreGlyphs)
    moreGlyphs.init()

  result = difference(additionalGlyphs, neededGlyphs)

proc UpdateGlyphsOffset(fd: FontData, loc: int, GID2GID: OrderedTable[int, int]) =
  var offset = kGlyphBodyStart + loc
  while true:
    let flags = fd.readUShort(offset + kFlags)

    let GlyphIndex = fd.readUShort(offset + kGlyphIndex)
    discard fd.writeUShort(offset + kGlyphIndex, GID2GID[GlyphIndex])

    offset += 4

    if (flags and ARG_1_AND_2_ARE_WORDS) != 0: offset += 4
    else: offset += 2

    if (flags and WE_HAVE_A_TWO_BY_TWO) != 0: offset += 8
    elif (flags and WE_HAVE_AN_X_AND_Y_SCALE) != 0: offset += 4
    elif (flags and WE_HAVE_A_SCALE) != 0: offset += 2

    if (flags and MORE_COMPONENTS) == 0: break

proc EncodeGLYPHTable*(t: GLYPHTable, GID2GID: var OrderedTable[int, int]): GLYPHTable =
  var Glyphs = initHashSet[int](math.nextPowerOfTwo(GID2GID.len))
  for i in keys(GID2GID): Glyphs.incl(i)

  let moreGlyphs = t.CollectMoreGlyphs(Glyphs)
  let loca = t.GetLoca()
  var size = 0
  var newGlyphID = GID2GID.len

  for i in Glyphs: size += loca.GlyphLength(i)
  for i in moreGlyphs:
    GID2GID[i] = newGlyphID
    size += loca.GlyphLength(i)
    inc(newGlyphID)

  GID2GID.sort(proc(x,y: tuple[key,val: int] ):int = cmp(x.val,y.val) )

  var newdata = newFontData(size)
  var olddata = t.getTableData()

  var LocaList : seq[int] = @[]
  #let numGlyphs = Glyphs.len + moreGlyphs.len

  var loc = 0
  for i in keys(GID2GID):
    let offset = loca.GlyphOffset(i)
    let length = loca.GlyphLength(i)

    if length > 0:
      discard olddata.copyTo(newdata, loc, offset, length)
      if newdata.readShort(loc + kNumberOfContours) < 0:
        UpdateGlyphsOffset(newdata, loc, GID2GID)

    LocaList.add(loc)
    inc(loc, length)

  #last dummy loca
  LocaList.add(loc)

  var newglyf = newGLYPHTable(initHeader(TAG.glyf, checksum(newdata, newdata.length()), 0, newdata.length()), newdata)
  var newloca = encodeLOCATable(LocaList)
  newglyf.SetLoca(newloca)

  result = newglyf
