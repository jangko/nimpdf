# Copyright (c) 2015 Andri Lim
#
# Distributed under the MIT license 
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------
import FontIOStreams, FontData

const
  kVersion = 0
  kAscender = 4
  kDescender = 6
  kLineGap = 8
  kAdvanceWidthMax = 10
  kMinTopSideBearing = 12
  kMinBottomSideBearing = 14
  kXMaxExtent = 16
  kCaretSlopeRise = 18
  kCaretSlopeRun = 20
  kCaretOffset = 22
  kMetricDataFormat = 32
  kNumberOfVMetrics = 34

type
  VHEATable* = ref object of FontTable
  
proc makeVHEATable*(header: Header, data: FontData): VHEATable =
  new(result)
  initFontTable(result, header, data)

proc TableVersion*(t: VHEATable): int = t.data.ReadFixed(kVersion)
proc Ascender*(t: VHEATable): int = t.data.ReadFWord(kAscender)
proc Descender*(t: VHEATable): int = t.data.ReadFWord(kDescender)
proc LineGap*(t: VHEATable): int = t.data.ReadFWord(kLineGap)
proc AdvanceWidthMax*(t: VHEATable): int = t.data.ReadUShort(kAdvanceWidthMax)
proc MinTopSideBearing*(t: VHEATable): int = t.data.ReadFWord(kMinTopSideBearing)
proc MinBottomSideBearing*(t: VHEATable): int = t.data.ReadFWord(kMinBottomSideBearing)
proc XMaxExtent*(t: VHEATable): int = t.data.ReadFWord(kXMaxExtent)
proc CaretSlopeRise*(t: VHEATable): int = t.data.ReadShort(kCaretSlopeRise)
proc CaretSlopeRun*(t: VHEATable): int = t.data.ReadShort(kCaretSlopeRun)
proc CaretOffset*(t: VHEATable): int = t.data.ReadShort(kCaretOffset)
proc MetricDataFormat*(t: VHEATable): int = t.data.ReadShort(kMetricDataFormat)
proc NumberOfVMetrics*(t: VHEATable): int = t.data.ReadUShort(kNumberOfVMetrics)

#----------------------------------
proc SetTableVersion*(t: VHEATable, version: int) = discard t.data.WriteFixed(kVersion, version)
proc SetAscender*(t: VHEATable, ascender: int) = discard t.data.WriteFWord(kVersion, ascender)
proc SetDescender*(t: VHEATable, descender: int) = discard t.data.WriteFWord(kDescender, descender)
proc SetLineGap*(t: VHEATable, line_gap: int) = discard t.data.WriteFWord(kLineGap, line_gap)
proc SetAdvanceWidthMax*(t: VHEATable, value: int) = discard t.data.WriteUShort(kAdvanceWidthMax, value)
proc SetMinTopSideBearing*(t: VHEATable, value: int) = discard t.data.WriteFWord(kMinTopSideBearing, value)
proc SetMinBottomSideBearing*(t: VHEATable, value: int) = discard t.data.WriteFWord(kMinBottomSideBearing, value)
proc SetXMaxExtent*(t: VHEATable, value: int) = discard t.data.WriteFWord(kXMaxExtent, value)
proc SetCaretSlopeRise*(t: VHEATable, value: int) = discard t.data.WriteUShort(kCaretSlopeRise, value)
proc SetCaretSlopeRun*(t: VHEATable, value: int) = discard t.data.WriteUShort(kCaretSlopeRun, value)
proc SetCaretOffset*(t: VHEATable, value: int) = discard t.data.WriteUShort(kCaretOffset, value)
proc SetMetricDataFormat*(t: VHEATable, value: int) = discard t.data.WriteUShort(kMetricDataFormat, value)
proc SetNumberOfVMetrics*(t: VHEATable, value: int) = discard t.data.WriteUShort(kNumberOfVMetrics, value)