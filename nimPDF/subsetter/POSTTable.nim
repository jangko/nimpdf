# Copyright (c) 2015 Andri Lim
#
# Distributed under the MIT license
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------
import FontData

const
  kFormatType  = 0
  kItalicAngle = 4
  kUnderlinePosition = 8
  kUnderlineThickness = 10
  kIsFixedPitch = 12
  kMinMemType42 = 16
  kMaxMemType42 = 20
  kMinMemType1  = 24
  kMaxMemType1  = 28

type
  POSTTable* = ref object of FontTable

proc FormatType*(t: POSTTable): int = t.data.readFixed(kFormatType)
proc ItalicAngle*(t: POSTTable): int = t.data.readFixed(kItalicAngle)
proc UnderlinePosition*(t: POSTTable): int = t.data.readFWord(kUnderlinePosition)
proc UnderlineThickness*(t: POSTTable): int = t.data.readFWord(kUnderlineThickness)
proc IsFixedPitch*(t: POSTTable): int64 = t.data.readULong(kIsFixedPitch)
proc MinMemType42*(t: POSTTable): int64 = t.data.readULong(kMinMemType42)
proc MaxMemType42*(t: POSTTable): int64 = t.data.readULong(kMaxMemType42)
proc MinMemType1*(t: POSTTable): int64 = t.data.readULong(kMinMemType1)
proc MaxMemType1*(t: POSTTable): int64 = t.data.readULong(kMaxMemType1)

proc newPOSTTable*(header: Header, data: FontData): POSTTable =
  new(result)
  initFontTable(result, header, data)

proc encodePOSTTable*(t: POSTTable): POSTTable =
  let size = 4 + 12 + 16
  var fd = newFontData(size)
  discard fd.writeFixed(kFormatType, fixed1616Fixed(3, 0))
  discard t.data.copyTo(fd, 4, 4, 12)
  for i in 0..15:
    discard fd.writeByte(i + 16, chr(0))

  result = newPOSTTable(initHeader(TAG.post, checksum(fd, fd.length()), 0, fd.length()), fd)
