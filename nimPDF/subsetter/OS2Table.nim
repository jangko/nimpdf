# Copyright (c) 2015 Andri Lim
#
# Distributed under the MIT license
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------
import FontIOStreams, FontData

const
  kVersion = 0
  kXAvgCharWidth = 2
  kUsWeightClass = 4
  kUsWidthClass = 6
  kFsType = 8
  kYSubscriptXSize = 10
  kYSubscriptYSize = 12
  kYSubscriptXOffset = 14
  kYSubscriptYOffset = 16
  kYSuperscriptXSize = 18
  kYSuperscriptYSize = 20
  kYSuperscriptXOffset = 22
  kYSuperscriptYOffset = 24
  kYStrikeoutSize = 26
  kYStrikeoutPosition = 28
  kSFamilyClass = 30
  kPanose = 32
  kPanoseLength = 10  #Length of panose bytes.
  kUlUnicodeRange1 = 42
  kUlUnicodeRange2 = 46
  kUlUnicodeRange3 = 50
  kUlUnicodeRange4 = 54
  kAchVendId = 58
  kAchVendIdLength = 4  #Length of ach vend id bytes.
  kFsSelection = 62
  kUsFirstCharIndex = 64
  kUsLastCharIndex = 66

  kSTypoAscender = 68
  kSTypoDescender = 70
  kSTypoLineGap = 72
  kUsWinAscent = 74
  kUsWinDescent = 76
  kUlCodePageRange1 = 78
  kUlCodePageRange2 = 82

  kSxHeight = 68
  kSCapHeight = 70
  kUsDefaultChar = 72
  kUsBreakChar = 74
  kUsMaxContext = 76

type
  OS2Table* = ref object of FontTable

proc TableVersion*(t: OS2Table): int = t.data.readUShort(kVersion)
proc XAvgCharWidth*(t: OS2Table): int = t.data.readShort(kXAvgCharWidth)
proc UsWeightClass*(t: OS2Table): int = t.data.readUShort(kUsWeightClass)
proc UsWidthClass*(t: OS2Table): int = t.data.readUShort(kUsWidthClass)
proc FsType*(t: OS2Table): int = t.data.readShort(kFsType)
proc YSubscriptXSize*(t: OS2Table): int = t.data.readShort(kYSubscriptXSize)
proc YSubscriptYSize*(t: OS2Table): int = t.data.readShort(kYSubscriptYSize)
proc YSubscriptXOffset*(t: OS2Table): int = t.data.readShort(kYSubscriptXOffset)
proc YSubscriptYOffset*(t: OS2Table): int = t.data.readShort(kYSubscriptYOffset)
proc YSuperscriptXSize*(t: OS2Table): int = t.data.readShort(kYSuperscriptXSize)
proc YSuperscriptYSize*(t: OS2Table): int = t.data.readShort(kYSuperscriptYSize)
proc YSuperscriptXOffset*(t: OS2Table): int = t.data.readShort(kYSuperscriptXOffset)
proc YSuperscriptYOffset*(t: OS2Table): int = t.data.readShort(kYSuperscriptYOffset)
proc YStrikeoutSize*(t: OS2Table): int = t.data.readShort(kYStrikeoutSize)
proc YStrikeoutPosition*(t: OS2Table): int = t.data.readShort(kYStrikeoutPosition)
proc SFamilyClass*(t: OS2Table): int = t.data.readShort(kSFamilyClass)
proc Panose*(t: OS2Table): ByteVector =
  result = newString(10)
  discard t.data.readBytes(kPanose, result, 0, 10)

proc UlUnicodeRange1*(t: OS2Table): int64 = t.data.readULong(kUlUnicodeRange1)
proc UlUnicodeRange2*(t: OS2Table): int64 = t.data.readULong(kUlUnicodeRange2)
proc UlUnicodeRange3*(t: OS2Table): int64 = t.data.readULong(kUlUnicodeRange3)
proc UlUnicodeRange4*(t: OS2Table): int64 = t.data.readULong(kUlUnicodeRange4)
proc AchVendId*(t: OS2Table): ByteVector =
  result = newString(4)
  discard t.data.readBytes(kAchVendId, result, 0, 4)

proc FsSelection*(t: OS2Table): int = t.data.readUShort(kFsSelection)
proc UsFirstCharIndex*(t: OS2Table): int = t.data.readUShort(kUsFirstCharIndex)
proc UsLastCharIndex*(t: OS2Table): int = t.data.readUShort(kUsLastCharIndex)

proc STypoAscender*(t: OS2Table): int =
  result = 0
  if t.TableVersion() == 1:
    result = t.data.readUShort(kSTypoAscender)

proc STypoDescender*(t: OS2Table): int =
  result = 0
  if t.TableVersion() == 1:
    result = t.data.readUShort(kSTypoDescender)

proc STypoLineGap*(t: OS2Table): int =
  result = 0
  if t.TableVersion() == 1:
    result = t.data.readUShort(kSTypoLineGap)

proc UsWinAscent*(t: OS2Table): int =
  result = 0
  if t.TableVersion() == 1:
    result = t.data.readUShort(kUsWinAscent)

proc UsWinDescent*(t: OS2Table): int =
  result = 0
  if t.TableVersion() == 1:
    result = t.data.readUShort(kUsWinDescent)

proc UlCodePageRange1*(t: OS2Table): int64 =
  result = 0
  if t.TableVersion() == 1:
    result = t.data.readULong(kUlCodePageRange1)

proc UlCodePageRange2*(t: OS2Table): int64 =
  result = 0
  if t.TableVersion() == 1:
    result = t.data.readULong(kUlCodePageRange2)

proc IsSymbolCharSet*(t: OS2Table): bool =
  result = (t.UlCodePageRange1() and 0x80000000) != 0

proc SxHeight*(t: OS2Table): int =
  result = 0
  if t.TableVersion() == 0: result = t.data.readShort(kSxHeight)

proc SCapHeight*(t: OS2Table): int =
  result = 0
  if t.TableVersion() == 0: result = t.data.readShort(kSCapHeight)

proc UsDefaultChar*(t: OS2Table): int =
  result = 0
  if t.TableVersion() == 0: result = t.data.readUShort(kUsDefaultChar)

proc UsBreakChar*(t: OS2Table): int =
  result = 0
  if t.TableVersion() == 0: result = t.data.readUShort(kUsBreakChar)

proc UsMaxContext*(t: OS2Table): int =
  result = 0
  if t.TableVersion() == 0: result = t.data.readUShort(kUsMaxContext)

proc newOS2Table*(header: Header, data: FontData): OS2Table =
  new(result)
  initFontTable(result, header, data)

#------------------------------------
proc SetTableVersion*(t: OS2Table, version: int) = discard t.data.writeUShort(kVersion, version)
proc SetXAvgCharWidth*(t: OS2Table, width: int) = discard t.data.writeShort(kXAvgCharWidth, width)
proc SetUsWeightClass*(t: OS2Table, weight: int) = discard t.data.writeUShort(kUsWeightClass, weight)
proc SetUsWidthClass*(t: OS2Table, width: int) = discard t.data.writeUShort(kUsWidthClass, width)
proc SetFsType*(t: OS2Table, fs_type: int) = discard t.data.writeShort(kFsType, fs_type)
proc SetYSubscriptXSize*(t: OS2Table, size: int) = discard t.data.writeShort(kYSubscriptXSize, size)
proc SetYSubscriptYSize*(t: OS2Table, size: int) = discard t.data.writeShort(kYSubscriptYSize, size)
proc SetYSubscriptXOffset*(t: OS2Table, offset: int) = discard t.data.writeShort(kYSubscriptXOffset, offset)
proc SetYSubscriptYOffset*(t: OS2Table, offset: int) = discard t.data.writeShort(kYSubscriptYOffset, offset)
proc SetYSuperscriptXSize*(t: OS2Table, size: int) = discard t.data.writeShort(kYSuperscriptXSize, size)
proc SetYSuperscriptYSize*(t: OS2Table, size: int) = discard t.data.writeShort(kYSuperscriptYSize, size)
proc SetYSuperscriptXOffset*(t: OS2Table, offset: int) = discard t.data.writeShort(kYSuperscriptXOffset, offset)
proc SetYSuperscriptYOffset*(t: OS2Table, offset: int) = discard t.data.writeShort(kYSuperscriptYOffset, offset)
proc SetYStrikeoutSize*(t: OS2Table, size: int) = discard t.data.writeShort(kYStrikeoutSize, size)
proc SetYStrikeoutPosition*(t: OS2Table, position: int) = discard t.data.writeShort(kYStrikeoutPosition, position)
proc SetSFamilyClass*(t: OS2Table, family: int) = discard t.data.writeShort(kSFamilyClass, family)
proc SetPanose*(t: OS2Table, panose: ByteVector) =
  if panose.len != kPanoseLength:
    raise newException(ValueError, "Panose bytes must be exactly 10 in length")
  discard t.data.writeBytes(kPanose, panose)

proc SetUlUnicodeRange1*(t: OS2Table, range: int64) = discard t.data.writeULong(kUlUnicodeRange1, range)
proc SetUlUnicodeRange2*(t: OS2Table, range: int64) = discard t.data.writeULong(kUlUnicodeRange2, range)
proc SetUlUnicodeRange3*(t: OS2Table, range: int64) = discard t.data.writeULong(kUlUnicodeRange3, range)
proc SetUlUnicodeRange4*(t: OS2Table, range: int64) = discard t.data.writeULong(kUlUnicodeRange4, range)
proc SetAchVendId*(t: OS2Table, b: ByteVector) = discard t.data.writeBytesPad(kAchVendId, b, 0, min(kAchVendIdLength, b.len), ' ')
proc SetFsSelection*(t: OS2Table, fs_selection: int) = discard t.data.writeUShort(kFsSelection, fs_selection)
proc SetUsFirstCharIndex*(t: OS2Table, first_index: int) = discard t.data.writeUShort(kUsFirstCharIndex, first_index)
proc SetUsLastCharIndex*(t: OS2Table, last_index: int) = discard t.data.writeUShort(kUsLastCharIndex, last_index)
proc SetSTypoAscender*(t: OS2Table, ascender: int) = discard t.data.writeUShort(kSTypoAscender, ascender)
proc SetSTypoDescender*(t: OS2Table, descender: int) = discard t.data.writeUShort(kSTypoDescender, descender)
proc SetSTypoLineGap*(t: OS2Table, line_gap: int) = discard t.data.writeUShort(kSTypoLineGap, line_gap)
proc SetUsWinAscent*(t: OS2Table, ascent: int) = discard t.data.writeUShort(kUsWinAscent, ascent)
proc SetUsWinDescent*(t: OS2Table, descent: int) = discard t.data.writeUShort(kUsWinDescent, descent)
proc SetUlCodePageRange1*(t: OS2Table, range: int64) = discard t.data.writeULong(kUlCodePageRange1, range)
proc SetUlCodePageRange2*(t: OS2Table, range: int64) = discard t.data.writeULong(kUlCodePageRange2, range)
proc SetSxHeight*(t: OS2Table, height: int) = discard t.data.writeShort(kSxHeight, height)
proc SetSCapHeight*(t: OS2Table, height: int) = discard t.data.writeShort(kSCapHeight, height)
proc SetUsDefaultChar*(t: OS2Table, default_char: int) = discard t.data.writeUShort(kUsDefaultChar, default_char)
proc SetUsBreakChar*(t: OS2Table, break_char: int) = discard t.data.writeUShort(kUsBreakChar, break_char)
proc SetUsMaxContext*(t: OS2Table, max_context: int) = discard t.data.writeUShort(kUsMaxContext, max_context)
