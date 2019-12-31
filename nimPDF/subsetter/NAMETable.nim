# Copyright (c) 2015 Andri Lim
#
# Distributed under the MIT license
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------
import FontData

const
  kFormat = 0
  kCount  = 2
  kStorageStart = 4

  kRecordSize = 12
  kPlatformID = 0
  kEncodingID = 2
  kLanguageID = 4
  kNameID     = 6
  kStringLength = 8
  kStringOffset = 10

  NAME_COPYRIGHT*     = 0
  NAME_NAME*          = 1
  NAME_SUBFAMILY*     = 2
  NAME_SUBFAMILY_ID*  = 3
  NAME_FULL_NAME*          = 4
  NAME_VERSION*            = 5
  NAME_POSTSCRIPT_NAME*    = 6
  NAME_TRADEMARK*          = 7
  NAME_MANUFACTURER*       = 8
  NAME_DESIGNER*           = 9
  NAME_DESCRIPTION*        = 10
  NAME_VENDOR_URL*         = 11
  NAME_DESIGNER_URL*       = 12
  NAME_LICENSE*            = 13
  NAME_LICENSE_URL*        = 14
  NAME_PREFERRE_FAMILY*    = 16
  NAME_PREFERRE_SUBFAMILY* = 17
  NAME_COMPAT_FULL_NAME*   = 18
  NAME_SAMPLE_TEXT*        = 19

type
  nameEntry = object
    platformID, encodingID, languageID, nameID, length, offset: int
    name: string

  NAMETable* = ref object of FontTable
    postscriptName: string
    fontFamily: string
    postscriptname_found: bool

proc GetFormat*(t: NAMETable): int = t.data.readUShort(kFormat)
proc GetCount*(t: NAMETable): int = t.data.readUShort(kCount)
proc GetStorageStart*(t: NAMETable): int = t.data.readUShort(kStorageStart)

proc GetPlatformID*(t: NAMETable, index: int): int = t.data.readUShort(6 + kRecordSize * index + kPlatformID)
proc GetEncodingID*(t: NAMETable, index: int): int = t.data.readUShort(6 + kRecordSize * index + kEncodingID)
proc GetLanguageID*(t: NAMETable, index: int): int = t.data.readUShort(6 + kRecordSize * index + kLanguageID)
proc GetNameID*(t: NAMETable, index: int): int = t.data.readUShort(6 + kRecordSize * index + kNameID)
proc GetStringLength*(t: NAMETable, index: int): int = t.data.readUShort(6 + kRecordSize * index + kStringLength)
proc GetStringOffset*(t: NAMETable, index: int): int =
  result = t.data.readUShort(6 + kRecordSize * index + kStringOffset) + t.GetStorageStart()

proc GetName*(t: NAMETable, index: int): string =
  var len = t.GetStringLength(index)
  var offset = t.GetStringOffset(index)
  result = newString(len)
  discard t.data.readBytes(offset, result, 0, len)

proc FindName(t: NAMETable, ne: nameEntry) =
  #mac=1 roman=0 english=0
  if ne.platformID == 1 and ne.encodingID == 0 and ne.languageID == 0:
    if ne.nameID == NAME_POSTSCRIPT_NAME: t.postscriptName = ne.name
    if ne.nameID == NAME_NAME: t.fontFamily = ne.name
    t.postscriptname_found = true

  #microsoft=3 unicode=1 US-english=0x409
  if ne.platformID == 3 and ne.encodingID == 1 and ne.languageID == 0x409:
    if ne.nameID == NAME_POSTSCRIPT_NAME: t.postscriptName = fromUnicode(ne.name)
    if ne.nameID == NAME_NAME: t.fontFamily = fromUnicode(ne.name)
    t.postscriptname_found = true

proc FindName(t: NAMETable) =
  var name: nameEntry
  let count = t.GetCount()

  for i in 0..count-1:
    name.platformID = t.GetPlatformID(i)
    name.encodingID = t.GetEncodingID(i)
    name.languageID = t.GetLanguageID(i)
    name.nameID = t.GetNameID(i)
    name.length = t.GetStringLength(i)
    name.offset = t.GetStringOffset(i)
    name.name   = t.GetName(i)
    t.FindName(name)

proc GetPostScriptName*(t: NAMETable): string =
  if t.postscriptname_found: return t.postscriptName
  t.FindName()
  result = t.postscriptName

proc GetFontFamily*(t: NAMETable): string =
  if t.postscriptname_found: return t.fontFamily
  t.FindName()
  result = t.fontFamily

proc newNAMETable*(header: Header, data: FontData): NAMETable =
  new(result)
  initFontTable(result, header, data)
  result.postscriptname_found = false
  result.postscriptName = ""
  result.fontFamily = ""

proc UpdateName(ne: var nameEntry, subsettag: string) =
  if ne.nameID == NAME_NAME or ne.nameID == NAME_FULL_NAME or ne.nameID == NAME_POSTSCRIPT_NAME:
    if ne.platformID == 0 or ne.platformID == 3:
      ne.name = toUnicode(subsettag) & ne.name
    else:
      ne.name = subsettag & ne.name

  #mac=1 roman=0 english=0
  #if ne.platformID == 1 and ne.encodingID == 0 and ne.languageID == 0:
  #  if ne.nameID == NAME_POSTSCRIPT_NAME: ne.name = subsettag & ne.name
  #  if ne.nameID == NAME_NAME: ne.name = subsettag & ne.name
  #  #echo ne.name
  #microsoft=3 unicode=1 US-english=0x409
  #if ne.platformID == 3 and ne.encodingID == 1 and ne.languageID == 0x409:
  #  if ne.nameID == NAME_POSTSCRIPT_NAME: ne.name = toUnicode(subsettag) & ne.name
  #  if ne.nameID == NAME_NAME: ne.name = toUnicode(subsettag) & ne.name

proc encodeNAMETable*(t: NAMETable, subsettag: string): NAMETable =
  let numRecord = t.GetCount()
  let storageStart = 6 + numRecord * kRecordSize
  var storageSize = 0
  var names: seq[nameEntry]
  newSeq(names, numRecord)

  var string_offset = 0
  for i in 0..numRecord-1:
    names[i].platformID = t.GetPlatformID(i)
    names[i].encodingID = t.GetEncodingID(i)
    names[i].languageID = t.GetLanguageID(i)
    names[i].nameID = t.GetNameID(i)
    names[i].name   = t.GetName(i)
    UpdateName(names[i], subsettag)
    #echo names[i].name, $names[i].name.len
    names[i].length = names[i].name.len
    names[i].offset = string_offset
    string_offset += names[i].length
    storageSize += names[i].length

  var fd = newFontData(storageStart + storageSize)

  discard fd.writeUShort(kFormat, 0)
  discard fd.writeUShort(kCount, numRecord)
  discard fd.writeUShort(kStorageStart, storageStart)

  var offset = 6
  for i in 0..numRecord-1:
    discard fd.writeUShort(offset + kPlatformID, names[i].platformID)
    discard fd.writeUShort(offset + kEncodingID, names[i].encodingID)
    discard fd.writeUShort(offset + kLanguageID, names[i].languageID)
    discard fd.writeUShort(offset + kNameID, names[i].nameID)
    discard fd.writeUShort(offset + kStringLength, names[i].length)
    discard fd.writeUShort(offset + kStringOffset, names[i].offset)
    inc(offset, kRecordSize)

  assert(offset == storageStart)
  offset = storageStart
  for i in 0..numRecord-1:
    discard fd.writeBytes(offset, names[i].name)
    inc(offset, names[i].length)

  result = newNAMETable(initHeader(TAG.name, checksum(fd, fd.length()), 0, fd.length()), fd)
