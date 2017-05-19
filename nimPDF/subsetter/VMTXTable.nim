# Copyright (c) 2015 Andri Lim
#
# Distributed under the MIT license 
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------
import FontIOStreams, FontData, sets, tables

const
  kVMetricsStart = 0
  kVMetricsSize = 4

  #Offset within an VMetric
  kVMetricsAdvanceHeight = 0
  kVMetricsTopSideBearing = 2

  kTopSideBearingSize = 2
  
type
  metrix = object
    advance, tsb : int
    
  VMTXTable* = ref object of FontTable
    num_vmetrics: int
    num_glyphs: int
    
proc NumberOfVMetrics*(t: VMTXTable): int = t.num_vmetrics
proc NumberOfTSBs*(t: VMTXTable): int = t.num_glyphs - t.num_vmetrics
proc VMetricAdvanceHeight(t: VMTXTable, entry: int): int =
  if entry > t.num_vmetrics:
    raise newIndexError("VMetricAdvanceHeight index error")

  let offset = kVMetricsStart + (entry * kVMetricsSize) + kVMetricsAdvanceHeight
  result = t.data.ReadUShort(offset)
  
proc VMetricTSB(t: VMTXTable, entry: int): int =
  if entry > t.num_vmetrics:
    raise newIndexError("VMetricTSB index error")

  let offset = kVMetricsStart + (entry * kVMetricsSize) + kVMetricsTopSideBearing
  result = t.data.ReadFWord(offset)
  
proc TsbTableEntry(t: VMTXTable, entry: int): int =
  if entry > t.NumberOftsbs():
    #echo "num tsb: ", $t.NumberOftsbs()
    raise newIndexError("TSBTableEntry index error")
  
  let offset = kVMetricsStart + (t.num_vmetrics * kVMetricsSize) + (entry * kTopSideBearingSize)
  result = t.data.ReadFWord(offset)
  
proc AdvanceHeight*(t: VMTXTable, glyph_id: int): int =
  if glyph_id < t.num_vmetrics:
    return t.VMetricAdvanceHeight(glyph_id)
  
  result = t.VMetricAdvanceHeight(t.num_vmetrics - 1)
  
proc TopSideBearing*(t: VMTXTable, glyph_id: int): int =
  if glyph_id < t.num_vmetrics:
    return t.VMetrictsb(glyph_id)
    
  result = t.TsbTableEntry(glyph_id - t.num_vmetrics)
  
proc makeVMTXTable*(header: Header, data: FontData): VMTXTable =
  new(result)
  initFontTable(result, header, data)
  result.num_vmetrics = 0
  result.num_glyphs = 0
  
#----------------------------------
proc SetNumberOfVMetrics*(t: VMTXTable, num_vmetrics: int) =
  assert num_vmetrics >= 0
  t.num_vmetrics = num_vmetrics
  #echo "num v metrics: ", $num_vmetrics

proc SetNumGlyphs*(t: VMTXTable, num_glyphs: int) =
  assert num_glyphs >= 0
  t.num_glyphs = num_glyphs

proc forGlyph*(t: VMTXTable, id: int): metrix =
  result.advance = t.AdvanceHeight(id)
  result.tsb = t.TopSideBearing(id)

proc SetAdvanceHeight*(t: VMTXTable, entry, val: int) =
  let offset = kVMetricsStart + (entry * kVMetricsSize) + kVMetricsAdvanceHeight
  discard t.data.WriteUShort(offset, val)
  
proc SetTSB*(t: VMTXTable, entry, val: int) =
  let offset = kVMetricsStart + (entry * kVMetricsSize) + kVMetricsTopSideBearing
  discard t.data.WriteShort(offset, val)
  
proc EncodeVMTXTable*(t: VMTXTable, GID2GID: OrderedTable[int, int]): VMTXTable =
  var data = makeFontData(GID2GID.len * kVMetricsSize)
  var VMTX = makeVMTXTable(makeHeader(TAG.vmtx, checksum(data, data.Length()), 0, data.Length()), data)
  
  var x = 0
  for i in keys(GID2GID):
    VMTX.SetAdvanceHeight(x, t.AdvanceHeight(i))
    VMTX.Settsb(x, t.TopSideBearing(i))
    inc(x)
  
  VMTX.num_vmetrics = GID2GID.len
  VMTX.num_glyphs = GID2GID.len
  result = VMTX