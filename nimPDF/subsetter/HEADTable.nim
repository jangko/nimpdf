# Copyright (c) 2015 Andri Lim
#
# Distributed under the MIT license
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------
import FontData

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

proc newHEADTable*(header: Header, data: FontData): HEADTable =
  new(result)
  initFontTable(result, header, data)

proc TableVersion*(t: HEADTable): int = t.data.readFixed(kTableVersion)
proc FontRevision*(t: HEADTable): int = t.data.readFixed(kFontRevision)
proc ChecksumAdjustment*(t: HEADTable): int64 = t.data.readULong(kCheckSumAdjustment)
proc MagicNumber*(t: HEADTable): int64 = t.data.readULong(kMagicNumber)
proc FlagsAsInt*(t: HEADTable): int = t.data.readUShort(kFlags)
proc UnitsPerEm*(t: HEADTable): int = t.data.readUShort(kUnitsPerEm)
proc Created*(t: HEADTable): int64 = t.data.readDateTimeAsLong(kCreated)
proc Modified*(t: HEADTable): int64 = t.data.readDateTimeAsLong(kModified)
proc XMin*(t: HEADTable): int = t.data.readFWord(kXMin)
proc YMin*(t: HEADTable): int = t.data.readFWord(kYMin)
proc XMax*(t: HEADTable): int = t.data.readFWord(kXMax)
proc YMax*(t: HEADTable): int = t.data.readFWord(kYMax)
proc MacStyleAsInt*(t: HEADTable): int = t.data.readUShort(kMacStyle)
proc LowestRecPPEM*(t: HEADTable): int = t.data.readUShort(kLowestRecPPEM)
proc FontDirectionHint*(t: HEADTable): int =  t.data.readShort(kFontDirectionHint)
proc GetIndexToLocFormat*(t: HEADTable): int = t.data.readShort(kIndexToLocFormat)
proc GlyphDataFormat*(t: HEADTable): int = t.data.readShort(kGlyphDataFormat)


proc SetTableVersion*(t: HEADTable, version: int) =  discard t.data.writeFixed(kTableVersion, version)
proc SetFontRevision*(t: HEADTable, revision: int) = discard t.data.writeFixed(kFontRevision, revision)
proc SetChecksumAdjustment*(t: HEADTable, adjustment: int64) = discard t.data.writeULong(kCheckSumAdjustment, adjustment)
proc SetMagicNumber*(t: HEADTable, magic_number: int64) = discard t.data.writeULong(kMagicNumber, magic_number)
proc SetFlagsAsInt*(t: HEADTable, flags: int) = discard t.data.writeUShort(kFlags, flags)
proc SetUnitsPerEm*(t: HEADTable, units: int) = discard t.data.writeUShort(kUnitsPerEm, units)
proc SetCreated*(t: HEADTable, date: int64) = discard t.data.writeDateTime(kCreated, date)
proc SetModified*(t: HEADTable, date: int64) = discard t.data.writeDateTime(kModified, date)
proc SetXMin*(t: HEADTable, xmin: int) = discard t.data.writeShort(kXMin, xmin)
proc SetYMin*(t: HEADTable, ymin: int) = discard t.data.writeShort(kYMin, ymin)
proc SetXMax*(t: HEADTable, xmax: int) = discard t.data.writeShort(kXMax, xmax)
proc SetYMax*(t: HEADTable, ymax: int) = discard t.data.writeShort(kYMax, ymax)
proc SetMacStyleAsInt*(t: HEADTable, style: int) = discard t.data.writeUShort(kMacStyle, style)
proc SetLowestRecPPEM*(t: HEADTable, size: int) = discard t.data.writeUShort(kLowestRecPPEM, size)
proc SetFontDirectionHint*(t: HEADTable, hint: int) = discard t.data.writeShort(kFontDirectionHint, hint)
proc SetIndexToLocFormat*(t: HEADTable, format: int) = discard t.data.writeShort(kIndexToLocFormat, format)
proc SetGlyphDataFormat*(t: HEADTable, format: int) = discard t.data.writeShort(kGlyphDataFormat, format)
