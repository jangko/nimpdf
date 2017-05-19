# Copyright (c) 2015 Andri Lim
#
# Distributed under the MIT license 
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------
import FontIOStreams, FontData

const
  kTableVersion = 0
  kFontRevision = 4
  kCheckSumAdjustment = 8
  kMagicNumber = 12
  kFlags = 16
  kUnitsPerEm = 18
  kCreated = 20
  kModified = 28
  kXMin = 36
  kYMin = 38
  kXMax = 40
  kYMax = 42
  kMacStyle = 44
  kLowestRecPPEM = 46
  kFontDirectionHint = 48
  kIndexToLocFormat = 50
  kGlyphDataFormat = 52  

type
  HEADTable* = ref object of FontTable
  
proc makeHEADTable*(header: Header, data: FontData): HEADTable =
  new(result)
  initFontTable(result, header, data)
  
proc TableVersion*(t: HEADTable): int = t.data.ReadFixed(kTableVersion)
proc FontRevision*(t: HEADTable): int = t.data.ReadFixed(kFontRevision)
proc ChecksumAdjustment*(t: HEADTable): int64 = t.data.ReadULong(kCheckSumAdjustment)
proc MagicNumber*(t: HEADTable): int64 = t.data.ReadULong(kMagicNumber)
proc FlagsAsInt*(t: HEADTable): int = t.data.ReadUShort(kFlags)
proc UnitsPerEm*(t: HEADTable): int = t.data.ReadUShort(kUnitsPerEm)
proc Created*(t: HEADTable): int64 = t.data.ReadDateTimeAsLong(kCreated)
proc Modified*(t: HEADTable): int64 = t.data.ReadDateTimeAsLong(kModified)
proc XMin*(t: HEADTable): int = t.data.ReadFWord(kXMin)
proc YMin*(t: HEADTable): int = t.data.ReadFWord(kYMin)
proc XMax*(t: HEADTable): int = t.data.ReadFWord(kXMax)
proc YMax*(t: HEADTable): int = t.data.ReadFWord(kYMax)
proc MacStyleAsInt*(t: HEADTable): int = t.data.ReadUShort(kMacStyle)
proc LowestRecPPEM*(t: HEADTable): int = t.data.ReadUShort(kLowestRecPPEM)
proc FontDirectionHint*(t: HEADTable): int =  t.data.ReadShort(kFontDirectionHint)
proc GetIndexToLocFormat*(t: HEADTable): int = t.data.ReadShort(kIndexToLocFormat)  
proc GlyphDataFormat*(t: HEADTable): int = t.data.ReadShort(kGlyphDataFormat)

   
proc SetTableVersion*(t: HEADTable, version: int) =  discard t.data.WriteFixed(kTableVersion, version)
proc SetFontRevision*(t: HEADTable, revision: int) = discard t.data.WriteFixed(kFontRevision, revision)
proc SetChecksumAdjustment*(t: HEADTable, adjustment: int64) = discard t.data.WriteULong(kCheckSumAdjustment, adjustment)
proc SetMagicNumber*(t: HEADTable, magic_number: int64) = discard t.data.WriteULong(kMagicNumber, magic_number)
proc SetFlagsAsInt*(t: HEADTable, flags: int) = discard t.data.WriteUShort(kFlags, flags)
proc SetUnitsPerEm*(t: HEADTable, units: int) = discard t.data.WriteUShort(kUnitsPerEm, units)
proc SetCreated*(t: HEADTable, date: int64) = discard t.data.WriteDateTime(kCreated, date)
proc SetModified*(t: HEADTable, date: int64) = discard t.data.WriteDateTime(kModified, date)
proc SetXMin*(t: HEADTable, xmin: int) = discard t.data.WriteShort(kXMin, xmin)
proc SetYMin*(t: HEADTable, ymin: int) = discard t.data.WriteShort(kYMin, ymin)
proc SetXMax*(t: HEADTable, xmax: int) = discard t.data.WriteShort(kXMax, xmax)
proc SetYMax*(t: HEADTable, ymax: int) = discard t.data.WriteShort(kYMax, ymax)
proc SetMacStyleAsInt*(t: HEADTable, style: int) = discard t.data.WriteUShort(kMacStyle, style)
proc SetLowestRecPPEM*(t: HEADTable, size: int) = discard t.data.WriteUShort(kLowestRecPPEM, size)
proc SetFontDirectionHint*(t: HEADTable, hint: int) = discard t.data.WriteShort(kFontDirectionHint, hint)
proc SetIndexToLocFormat*(t: HEADTable, format: int) = discard t.data.WriteShort(kIndexToLocFormat, format)
proc SetGlyphDataFormat*(t: HEADTable, format: int) = discard t.data.WriteShort(kGlyphDataFormat, format)
