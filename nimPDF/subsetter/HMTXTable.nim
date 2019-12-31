# Copyright (c) 2015 Andri Lim
#
# Distributed under the MIT license
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------
import FontIOStreams, FontData, tables

const
  kHMetricsStart = 0
  kHMetricsSize = 4

  #Offset within an hMetric
  kHMetricsAdvanceWidth = 0
  kHMetricsLeftSideBearing = 2

  kLeftSideBearingSize = 2

type
  Metrix = object
    advance, lsb : int

  HMTXTable* = ref object of FontTable
    numHMetrics: int
    numGlyphs: int

proc numberOfHMetrics*(t: HMTXTable): int = t.numHMetrics
proc numberOfLSBs*(t: HMTXTable): int = t.numGlyphs - t.numHMetrics
proc hmetricAdvanceWidth(t: HMTXTable, entry: int): int =
  if entry > t.numHMetrics:
    raise newIndexError("HMetricAdvanceWidth index error")

  let offset = kHMetricsStart + (entry * kHMetricsSize) + kHMetricsAdvanceWidth
  result = t.data.readUShort(offset)

proc hmetricLSB(t: HMTXTable, entry: int): int =
  if entry > t.numHMetrics:
    raise newIndexError("HMetricLSB index error")

  let offset = kHMetricsStart + (entry * kHMetricsSize) + kHMetricsLeftSideBearing
  result = t.data.readFWord(offset)

proc lsbTableEntry(t: HMTXTable, entry: int): int =
  if entry > t.numberOfLSBs():
    raise newIndexError("LsbTableEntry index error")

  let offset = kHMetricsStart + (t.numHMetrics * kHMetricsSize) + (entry * kLeftSideBearingSize)
  result = t.data.readFWord(offset)

proc advanceWidth*(t: HMTXTable, glyph_id: int): int =
  if glyph_id < t.numHMetrics:
    return t.hmetricAdvanceWidth(glyph_id)

  result = t.hmetricAdvanceWidth(t.numHMetrics - 1)

proc leftSideBearing*(t: HMTXTable, glyph_id: int): int =
  if glyph_id < t.numHMetrics:
    return t.hmetricLSB(glyph_id)

  result = t.lsbTableEntry(glyph_id - t.numHMetrics)

proc newHMTXTable*(header: Header, data: FontData): HMTXTable =
  new(result)
  initFontTable(result, header, data)
  result.numHMetrics = 0
  result.numGlyphs = 0

#----------------------------------
proc setNumberOfHMetrics*(t: HMTXTable, numHMetrics: int) =
  assert numHMetrics >= 0
  t.numHMetrics = numHMetrics

proc setNumGlyphs*(t: HMTXTable, numGlyphs: int) =
  assert numGlyphs >= 0
  t.numGlyphs = numGlyphs

proc forGlyph*(t: HMTXTable, id: int): Metrix =
  result.advance = t.advanceWidth(id)
  result.lsb = t.leftSideBearing(id)

proc setAdvanceWidth*(t: HMTXTable, entry, val: int) =
  let offset = kHMetricsStart + (entry * kHMetricsSize) + kHMetricsAdvanceWidth
  discard t.data.writeUShort(offset, val)

proc setLSB*(t: HMTXTable, entry, val: int) =
  let offset = kHMetricsStart + (entry * kHMetricsSize) + kHMetricsLeftSideBearing
  discard t.data.writeShort(offset, val)

proc encodeHMTXTable*(t: HMTXTable, GID2GID: OrderedTable[int, int]): HMTXTable =
  var data = newFontData(GID2GID.len * kHMetricsSize)
  var hmtx = newHMTXTable(initHeader(TAG.hmtx, checksum(data, data.length()), 0, data.length()), data)

  var x = 0
  for i in keys(GID2GID):
    hmtx.setAdvanceWidth(x, t.advanceWidth(i))
    hmtx.setLSB(x, t.leftSideBearing(i))
    inc(x)

  hmtx.numHMetrics = GID2GID.len
  hmtx.numGlyphs = GID2GID.len
  result = hmtx
