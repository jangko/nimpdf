# Copyright (c) 2015 Andri Lim
#
# Distributed under the MIT license
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------
import FontIOStreams, FontData, tables

const
  kVMetricsStart = 0
  kVMetricsSize = 4

  #Offset within an VMetric
  kVMetricsAdvanceHeight = 0
  kVMetricsTopSideBearing = 2

  kTopSideBearingSize = 2

type
  Metrix = object
    advance, tsb : int

  VMTXTable* = ref object of FontTable
    numVMetrics: int
    numGlyphs: int

proc numberOfVMetrics*(t: VMTXTable): int = t.numVMetrics
proc numberOfTSBs*(t: VMTXTable): int = t.numGlyphs - t.numVMetrics
proc vmetricAdvanceHeight(t: VMTXTable, entry: int): int =
  if entry > t.numVMetrics:
    raise newIndexError("VMetricAdvanceHeight index error")

  let offset = kVMetricsStart + (entry * kVMetricsSize) + kVMetricsAdvanceHeight
  result = t.data.readUShort(offset)

proc vmetricTSB(t: VMTXTable, entry: int): int =
  if entry > t.numVMetrics:
    raise newIndexError("VMetricTSB index error")

  let offset = kVMetricsStart + (entry * kVMetricsSize) + kVMetricsTopSideBearing
  result = t.data.readFWord(offset)

proc tsbTableEntry(t: VMTXTable, entry: int): int =
  if entry > t.numberOfTSBs():
    #echo "num tsb: ", $t.NumberOftsbs()
    raise newIndexError("TSBTableEntry index error")

  let offset = kVMetricsStart + (t.numVMetrics * kVMetricsSize) + (entry * kTopSideBearingSize)
  result = t.data.readFWord(offset)

proc advanceHeight*(t: VMTXTable, glyph_id: int): int =
  if glyph_id < t.numVMetrics:
    return t.vmetricAdvanceHeight(glyph_id)

  result = t.vmetricAdvanceHeight(t.numVMetrics - 1)

proc topSideBearing*(t: VMTXTable, glyph_id: int): int =
  if glyph_id < t.numVMetrics:
    return t.vmetricTSB(glyph_id)

  result = t.tsbTableEntry(glyph_id - t.numVMetrics)

proc newVMTXTable*(header: Header, data: FontData): VMTXTable =
  new(result)
  initFontTable(result, header, data)
  result.numVMetrics = 0
  result.numGlyphs = 0

#----------------------------------
proc setNumberOfVMetrics*(t: VMTXTable, numVMetrics: int) =
  assert numVMetrics >= 0
  t.numVMetrics = numVMetrics

proc setNumGlyphs*(t: VMTXTable, numGlyphs: int) =
  assert numGlyphs >= 0
  t.numGlyphs = numGlyphs

proc forGlyph*(t: VMTXTable, id: int): Metrix =
  result.advance = t.advanceHeight(id)
  result.tsb = t.topSideBearing(id)

proc setAdvanceHeight*(t: VMTXTable, entry, val: int) =
  let offset = kVMetricsStart + (entry * kVMetricsSize) + kVMetricsAdvanceHeight
  discard t.data.writeUShort(offset, val)

proc setTSB*(t: VMTXTable, entry, val: int) =
  let offset = kVMetricsStart + (entry * kVMetricsSize) + kVMetricsTopSideBearing
  discard t.data.writeShort(offset, val)

proc encodeVMTXTable*(t: VMTXTable, GID2GID: OrderedTable[int, int]): VMTXTable =
  var data = newFontData(GID2GID.len * kVMetricsSize)
  var VMTX = newVMTXTable(initHeader(TAG.vmtx, checksum(data, data.length()), 0, data.length()), data)

  var x = 0
  for i in keys(GID2GID):
    VMTX.setAdvanceHeight(x, t.advanceHeight(i))
    VMTX.setTSB(x, t.topSideBearing(i))
    inc(x)

  VMTX.numVMetrics = GID2GID.len
  VMTX.numGlyphs = GID2GID.len
  result = VMTX
