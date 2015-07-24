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
  kMinLeftSideBearing = 12
  kMinRightSideBearing = 14
  kXMaxExtent = 16
  kCaretSlopeRise = 18
  kCaretSlopeRun = 20
  kCaretOffset = 22
  kMetricDataFormat = 32
  kNumberOfHMetrics = 34

type
  HHEATable* = ref object of FontTable
  
proc makeHHEATable*(header: Header, data: FontData): HHEATable =
  new(result)
  initFontTable(result, header, data)

proc TableVersion*(t: HHEATable): int = t.data.ReadFixed(kVersion)
proc Ascender*(t: HHEATable): int = t.data.ReadFWord(kAscender)
proc Descender*(t: HHEATable): int = t.data.ReadFWord(kDescender)
proc LineGap*(t: HHEATable): int = t.data.ReadFWord(kLineGap)
proc AdvanceWidthMax*(t: HHEATable): int = t.data.ReadUShort(kAdvanceWidthMax)
proc MinLeftSideBearing*(t: HHEATable): int = t.data.ReadFWord(kMinLeftSideBearing)
proc MinRightSideBearing*(t: HHEATable): int = t.data.ReadFWord(kMinRightSideBearing)
proc XMaxExtent*(t: HHEATable): int = t.data.ReadFWord(kXMaxExtent)
proc CaretSlopeRise*(t: HHEATable): int = t.data.ReadShort(kCaretSlopeRise)
proc CaretSlopeRun*(t: HHEATable): int = t.data.ReadShort(kCaretSlopeRun)
proc CaretOffset*(t: HHEATable): int = t.data.ReadShort(kCaretOffset)
proc MetricDataFormat*(t: HHEATable): int = t.data.ReadShort(kMetricDataFormat)
proc NumberOfHMetrics*(t: HHEATable): int = t.data.ReadUShort(kNumberOfHMetrics)

#----------------------------------
proc SetTableVersion*(t: HHEATable, version: int) = discard t.data.WriteFixed(kVersion, version)
proc SetAscender*(t: HHEATable, ascender: int) = discard t.data.WriteFWord(kVersion, ascender)
proc SetDescender*(t: HHEATable, descender: int) = discard t.data.WriteFWord(kDescender, descender)
proc SetLineGap*(t: HHEATable, line_gap: int) = discard t.data.WriteFWord(kLineGap, line_gap)
proc SetAdvanceWidthMax*(t: HHEATable, value: int) = discard t.data.WriteUShort(kAdvanceWidthMax, value)
proc SetMinLeftSideBearing*(t: HHEATable, value: int) = discard t.data.WriteFWord(kMinLeftSideBearing, value)
proc SetMinRightSideBearing*(t: HHEATable, value: int) = discard t.data.WriteFWord(kMinRightSideBearing, value)
proc SetXMaxExtent*(t: HHEATable, value: int) = discard t.data.WriteFWord(kXMaxExtent, value)
proc SetCaretSlopeRise*(t: HHEATable, value: int) = discard t.data.WriteUShort(kCaretSlopeRise, value)
proc SetCaretSlopeRun*(t: HHEATable, value: int) = discard t.data.WriteUShort(kCaretSlopeRun, value)
proc SetCaretOffset*(t: HHEATable, value: int) = discard t.data.WriteUShort(kCaretOffset, value)
proc SetMetricDataFormat*(t: HHEATable, value: int) = discard t.data.WriteUShort(kMetricDataFormat, value)
proc SetNumberOfHMetrics*(t: HHEATable, value: int) = discard t.data.WriteUShort(kNumberOfHMetrics, value)