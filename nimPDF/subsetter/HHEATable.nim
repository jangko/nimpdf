# Copyright (c) 2015 Andri Lim
#
# Distributed under the MIT license
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------
import FontData

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

proc newHHEATable*(header: Header, data: FontData): HHEATable =
  new(result)
  initFontTable(result, header, data)

proc TableVersion*(t: HHEATable): int = t.data.readFixed(kVersion)
proc Ascender*(t: HHEATable): int = t.data.readFWord(kAscender)
proc Descender*(t: HHEATable): int = t.data.readFWord(kDescender)
proc LineGap*(t: HHEATable): int = t.data.readFWord(kLineGap)
proc AdvanceWidthMax*(t: HHEATable): int = t.data.readUShort(kAdvanceWidthMax)
proc MinLeftSideBearing*(t: HHEATable): int = t.data.readFWord(kMinLeftSideBearing)
proc MinRightSideBearing*(t: HHEATable): int = t.data.readFWord(kMinRightSideBearing)
proc XMaxExtent*(t: HHEATable): int = t.data.readFWord(kXMaxExtent)
proc CaretSlopeRise*(t: HHEATable): int = t.data.readShort(kCaretSlopeRise)
proc CaretSlopeRun*(t: HHEATable): int = t.data.readShort(kCaretSlopeRun)
proc CaretOffset*(t: HHEATable): int = t.data.readShort(kCaretOffset)
proc MetricDataFormat*(t: HHEATable): int = t.data.readShort(kMetricDataFormat)
proc NumberOfHMetrics*(t: HHEATable): int = t.data.readUShort(kNumberOfHMetrics)

#----------------------------------
proc SetTableVersion*(t: HHEATable, version: int) = discard t.data.writeFixed(kVersion, version)
proc SetAscender*(t: HHEATable, ascender: int) = discard t.data.writeFWord(kVersion, ascender)
proc SetDescender*(t: HHEATable, descender: int) = discard t.data.writeFWord(kDescender, descender)
proc SetLineGap*(t: HHEATable, line_gap: int) = discard t.data.writeFWord(kLineGap, line_gap)
proc SetAdvanceWidthMax*(t: HHEATable, value: int) = discard t.data.writeUShort(kAdvanceWidthMax, value)
proc SetMinLeftSideBearing*(t: HHEATable, value: int) = discard t.data.writeFWord(kMinLeftSideBearing, value)
proc SetMinRightSideBearing*(t: HHEATable, value: int) = discard t.data.writeFWord(kMinRightSideBearing, value)
proc SetXMaxExtent*(t: HHEATable, value: int) = discard t.data.writeFWord(kXMaxExtent, value)
proc SetCaretSlopeRise*(t: HHEATable, value: int) = discard t.data.writeUShort(kCaretSlopeRise, value)
proc SetCaretSlopeRun*(t: HHEATable, value: int) = discard t.data.writeUShort(kCaretSlopeRun, value)
proc SetCaretOffset*(t: HHEATable, value: int) = discard t.data.writeUShort(kCaretOffset, value)
proc SetMetricDataFormat*(t: HHEATable, value: int) = discard t.data.writeUShort(kMetricDataFormat, value)
proc SetNumberOfHMetrics*(t: HHEATable, value: int) = discard t.data.writeUShort(kNumberOfHMetrics, value)