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

proc newVHEATable*(header: Header, data: FontData): VHEATable =
  new(result)
  initFontTable(result, header, data)

proc TableVersion*(t: VHEATable): int = t.data.readFixed(kVersion)
proc Ascender*(t: VHEATable): int = t.data.readFWord(kAscender)
proc Descender*(t: VHEATable): int = t.data.readFWord(kDescender)
proc LineGap*(t: VHEATable): int = t.data.readFWord(kLineGap)
proc AdvanceWidthMax*(t: VHEATable): int = t.data.readUShort(kAdvanceWidthMax)
proc MinTopSideBearing*(t: VHEATable): int = t.data.readFWord(kMinTopSideBearing)
proc MinBottomSideBearing*(t: VHEATable): int = t.data.readFWord(kMinBottomSideBearing)
proc XMaxExtent*(t: VHEATable): int = t.data.readFWord(kXMaxExtent)
proc CaretSlopeRise*(t: VHEATable): int = t.data.readShort(kCaretSlopeRise)
proc CaretSlopeRun*(t: VHEATable): int = t.data.readShort(kCaretSlopeRun)
proc CaretOffset*(t: VHEATable): int = t.data.readShort(kCaretOffset)
proc MetricDataFormat*(t: VHEATable): int = t.data.readShort(kMetricDataFormat)
proc NumberOfVMetrics*(t: VHEATable): int = t.data.readUShort(kNumberOfVMetrics)

#----------------------------------
proc SetTableVersion*(t: VHEATable, version: int) = discard t.data.writeFixed(kVersion, version)
proc SetAscender*(t: VHEATable, ascender: int) = discard t.data.writeFWord(kVersion, ascender)
proc SetDescender*(t: VHEATable, descender: int) = discard t.data.writeFWord(kDescender, descender)
proc SetLineGap*(t: VHEATable, line_gap: int) = discard t.data.writeFWord(kLineGap, line_gap)
proc SetAdvanceWidthMax*(t: VHEATable, value: int) = discard t.data.writeUShort(kAdvanceWidthMax, value)
proc SetMinTopSideBearing*(t: VHEATable, value: int) = discard t.data.writeFWord(kMinTopSideBearing, value)
proc SetMinBottomSideBearing*(t: VHEATable, value: int) = discard t.data.writeFWord(kMinBottomSideBearing, value)
proc SetXMaxExtent*(t: VHEATable, value: int) = discard t.data.writeFWord(kXMaxExtent, value)
proc SetCaretSlopeRise*(t: VHEATable, value: int) = discard t.data.writeUShort(kCaretSlopeRise, value)
proc SetCaretSlopeRun*(t: VHEATable, value: int) = discard t.data.writeUShort(kCaretSlopeRun, value)
proc SetCaretOffset*(t: VHEATable, value: int) = discard t.data.writeUShort(kCaretOffset, value)
proc SetMetricDataFormat*(t: VHEATable, value: int) = discard t.data.writeUShort(kMetricDataFormat, value)
proc SetNumberOfVMetrics*(t: VHEATable, value: int) = discard t.data.writeUShort(kNumberOfVMetrics, value)