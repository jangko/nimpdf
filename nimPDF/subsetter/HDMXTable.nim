# Copyright (c) 2015 Andri Lim
#
# Distributed under the MIT license
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------
import FontData

const
  kVersion = 0
  kNumRecords = 2
  kSizeDeviceRecord = 4
  kRecords = 8

  #Offsets within a device record
  kDeviceRecordPixelSize = 0
  kDeviceRecordMaxWidth = 1
  kDeviceRecordWidths = 2

type
  HDMXTable* = ref object of FontTable
    num_glyphs: int

proc Version*(t: HDMXTable): int = t.data.readUShort(kVersion)
proc NumRecords*(t: HDMXTable): int = t.data.readShort(kNumRecords)
proc RecordSize*(t: HDMXTable): int = t.data.readLong(kSizeDeviceRecord)

proc PixelSize*(t: HDMXTable, record_index: int): int =
  if record_index < 0 or record_index >= t.NumRecords():
    raise newException(ValueError, "Pixel size index error")

  result = t.data.readUByte(kRecords + record_index * t.RecordSize() + kDeviceRecordPixelSize)

proc MaxWidth*(t: HDMXTable, record_index: int): int =
  if record_index < 0 or record_index >= t.NumRecords():
    raise newException(ValueError, "max width index error")

  result = t.data.readUByte(kRecords + record_index * t.RecordSize() + kDeviceRecordMaxWidth)

proc Width*(t: HDMXTable, record_index, glyph_num: int): int =
  if record_index < 0 or record_index >= t.NumRecords() or glyph_num < 0 or glyph_num >= t.num_glyphs:
    raise newException(ValueError, "max width index error")

  result = t.data.readUByte(kRecords + record_index * t.RecordSize() + kDeviceRecordWidths + glyph_num)

proc newHDMXTable*(header: Header, data: FontData): HDMXTable =
  new(result)
  initFontTable(result, header, data)
  result.num_glyphs = 0

#---------------------------------------------------------
proc SetNumGlyphs*(t: HDMXTable, num_glyphs: int) =
  if num_glyphs < 0:
    raise newException(ValueError, "Number of glyphs can't be negative.")
  t.num_glyphs = num_glyphs
