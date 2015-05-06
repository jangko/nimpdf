# Copyright (c) 2015 Andri Lim
#
# Distributed under the MIT license 
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------
import FontIOStreams, FontData, sets, tables

const
    kHMetricsStart = 0
    kHMetricsSize = 4

    #Offset within an hMetric
    kHMetricsAdvanceWidth = 0
    kHMetricsLeftSideBearing = 2

    kLeftSideBearingSize = 2
    
type
    metrix = object
        advance, lsb : int
        
    HMTXTable* = ref object of FontTable
        num_hmetrics: int
        num_glyphs: int
        
proc NumberOfHMetrics*(t: HMTXTable): int = t.num_hmetrics
proc NumberOfLSBs*(t: HMTXTable): int = t.num_glyphs - t.num_hmetrics
proc HMetricAdvanceWidth(t: HMTXTable, entry: int): int =
    if entry > t.num_hmetrics:
        raise newIndexError("HMetricAdvanceWidth index error")

    let offset = kHMetricsStart + (entry * kHMetricsSize) + kHMetricsAdvanceWidth
    result = t.data.ReadUShort(offset)
  
proc HMetricLSB(t: HMTXTable, entry: int): int =
    if entry > t.num_hmetrics:
        raise newIndexError("HMetricLSB index error")

    let offset = kHMetricsStart + (entry * kHMetricsSize) + kHMetricsLeftSideBearing
    result = t.data.ReadFWord(offset)
  
proc LsbTableEntry(t: HMTXTable, entry: int): int =
    if entry > t.NumberOfLSBs():
        raise newIndexError("LsbTableEntry index error")
    
    let offset = kHMetricsStart + (t.num_hmetrics * kHMetricsSize) + (entry * kLeftSideBearingSize)
    result = t.data.ReadFWord(offset)
  
proc AdvanceWidth*(t: HMTXTable, glyph_id: int): int =
    if glyph_id < t.num_hmetrics:
        return t.HMetricAdvanceWidth(glyph_id)
    
    result = t.HMetricAdvanceWidth(t.num_hmetrics - 1)
  
proc LeftSideBearing*(t: HMTXTable, glyph_id: int): int =
    if glyph_id < t.num_hmetrics:
        return t.HMetricLSB(glyph_id)
        
    result = t.LsbTableEntry(glyph_id - t.num_hmetrics)
    
proc makeHMTXTable*(header: Header, data: FontData): HMTXTable =
    new(result)
    initFontTable(result, header, data)
    result.num_hmetrics = 0
    result.num_glyphs = 0
    
#----------------------------------
proc SetNumberOfHMetrics*(t: HMTXTable, num_hmetrics: int) =
    assert num_hmetrics >= 0
    t.num_hmetrics = num_hmetrics

proc SetNumGlyphs*(t: HMTXTable, num_glyphs: int) =
    assert num_glyphs >= 0
    t.num_glyphs = num_glyphs

proc forGlyph*(t: HMTXTable, id: int): metrix =
    result.advance = t.AdvanceWidth(id)
    result.lsb = t.LeftSideBearing(id)

proc SetAdvanceWidth*(t: HMTXTable, entry, val: int) =
    let offset = kHMetricsStart + (entry * kHMetricsSize) + kHMetricsAdvanceWidth
    discard t.data.WriteUShort(offset, val)
  
proc SetLSB*(t: HMTXTable, entry, val: int) =
    let offset = kHMetricsStart + (entry * kHMetricsSize) + kHMetricsLeftSideBearing
    discard t.data.WriteShort(offset, val)
    
proc EncodeHMTXTable*(t: HMTXTable, GID2GID: OrderedTable[int, int]): HMTXTable =
    var data = makeFontData(GID2GID.len * kHMetricsSize)
    var hmtx = makeHMTXTable(makeHeader(TAG.hmtx, checksum(data, data.Length()), 0, data.Length()), data)
    
    var x = 0
    for i in keys(GID2GID):
        hmtx.SetAdvanceWidth(x, t.AdvanceWidth(i))
        hmtx.SetLSB(x, t.LeftSideBearing(i))
        inc(x)
    
    hmtx.num_hmetrics = GID2GID.len
    hmtx.num_glyphs = GID2GID.len
    result = hmtx