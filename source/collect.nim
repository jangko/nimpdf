# Copyright (c) 2015 Andri Lim
#
# Distributed under the MIT license 
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------
#
# this module responsible to collect TTF/TTC files from 
# folder/directory specified by user
# and then read the font(s) internal name and style
# then build a search map using StringTable
# 
# TTF: 'font family' + style -> TTF file name
# TTC: 'font family' + style -> TTC file name + font index number

import macros, strutils, streams, os, strtabs

macro fourcc(ccx: string): int = 
  let cc = ccx.strVal
  result = ((ord(cc[0]) shl 24) or (ord(cc[1]) shl 16) or (ord(cc[2]) shl 8) or ord(cc[3])).newLit

const
  HEAD = fourcc("head")
  NAME = fourcc("name")
  TTCF = fourcc("ttcf")

type
  TableRec {.pure,final.} = object
    tag, checksum, offset, length: int32

  nameEntry {.pure,final.} = object
    platformID, encodingID, languageID, nameID, length, offset: int16
 
proc swap32(v:int32):int32=
  var tmp = v
  var val = cast[cstring](addr(tmp))
  var res = cast[cstring](addr(result))
  res[3] = val[0]
  res[2] = val[1]
  res[1] = val[2]
  res[0] = val[3]

proc swap16(num:int16): int32 {.inline.} = (num shr 8) or (num shl 8)

proc fromUnicode(s:string): string =
  let len = s.len shr 1
  result = newString(len)
  var i=0
  var j=0
  
  while i < s.len:
    inc(i)
    result[j] = s[i]
    inc(j)
    inc(i)

proc parseHead(tt:TableRec, s:Stream): string =
  s.setPosition(tt.offset + 44)
  let macStyle = swap16(s.readInt16())
  
  result = "00" #regular
  if (macStyle and 0x01) != 0: result[0] = '1' #bold
  if (macStyle and 0x02) != 0: result[1] = '1' #italic

proc Read[T](s: Stream, ne: var T): bool =
  result = s.readData(addr(ne), sizeof(T)) == sizeof(T)
  
proc parseName(tt:TableRec, s:Stream, fontFamily: var string): bool =
  s.setPosition(tt.offset)
  
  let format = s.readInt16()
  let count  = swap16(s.readInt16())
  let offset = swap16(s.readInt16())
  var ne: nameEntry
  result = false
  
  let storage_start = tt.offset + 6 + 12*count;
  let storage_limit = tt.offset + tt.length;
  
  if storage_start > storage_limit:
    echo "invalid `name' table"
    return false

  for i in 1..count:
    if not s.Read(ne): return false
    let platformID = swap16(ne.platformID)
    let encodingID = swap16(ne.encodingID)
    let languageID = swap16(ne.languageID)
    let nameID = swap16(ne.nameID)
    let stringOffset = swap16(ne.offset) + tt.offset + offset
    let stringLength = swap16(ne.length)
    if (stringOffset < storage_start) or ((stringOffset + stringLength) > storage_limit):
      #echo "invalid entry"
      continue
    if stringLength == 0: continue
    if platformID == 1 and encodingID == 0 and languageID == 0 and nameID == 1:
      s.setPosition(stringOffset)
      fontFamily = s.readStr(stringLength)
      result = true
      break
  
    if platformID == 3 and encodingID == 1 and languageID == 0x409 and nameID == 1 and not result:
      s.setPosition(stringOffset)
      fontFamily = fromUnicode(s.readStr(stringLength))
      result = true
      break
  
proc parseTTF(s:Stream, fontFamily: var string): bool =
  result = false
  let version = s.readInt32()
  let numTables = swap16(s.readInt16())
  let searchRange = s.readInt16()
  let entrySelector = s.readInt16()
  let rangeShift = s.readInt16()
  
  var numParse = 0
  var head, name, tmp: TableRec
  
  for i in 0..numTables-1:
    if not s.Read(tmp):
      echo "error reading tag"
      return false
    tmp.tag = swap32(tmp.tag)
    tmp.offset = swap32(tmp.offset)
    tmp.length = swap32(tmp.length)
    
    if tmp.tag == HEAD:
      head = tmp
      inc(numParse)
    
    if tmp.tag == NAME:
      name = tmp
      inc(numParse)
    
    if numParse == 2:
      if not parseName(name, s, fontFamily): return false
      fontFamily.add(parseHead(head, s))
      result = true
      break
      
proc parseTTF(fileName: string, res: var string): bool =
  result = true
  var file = newFileStream(fileName, fmRead)
  if file == nil:
    return false
  try:
    if not parseTTF(file, res): return false
  except IOError:
    echo("IO error!")
    result = false
  except:
    echo("Unknown exception!")
    result = false
  finally:
    file.close()

proc parseTTC(fileName: string, tables: StringTableRef) =
  var file = newFileStream(fileName, fmRead)
  if file == nil: 
    echo "cannot open ", fileName
    return
  var key = ""
  
  try:
    let tag = swap32(file.readInt32())
    if tag != TTCF: 
      echo "not TTCF ", fileName
      return
    
    discard file.readInt32() #version
    let numFonts = swap32(file.readInt32())
  
    var offsets: seq[int]
    newSeq(offsets, numFonts)
    #echo "num fonts: ", $numFonts
    
    for i in 0..numFonts-1:
      offsets[i] = swap32(file.readInt32())
    
    for i in 0..numFonts-1:
      file.setPosition(offsets[i])
      #echo "processing ", fileName, " font no: ", $i
      if parseTTF(file, key):
        tables[key] = fileName & $i

  except IOError:
    echo("IO error!")
  except:
    echo("Unknown exception!")
  finally:
    file.close()
  
proc collectTTF*(dir:string, t: StringTableRef) =
  var key = ""
  
  for fileName in walkDirRec(dir, {pcFile}):
    let path = splitFile(fileName)
    if path.ext.len() == 0: continue
    
    let ext = toLower(path.ext)
    if ext != ".ttf": continue
    
    if parseTTF(fileName, key):
      t[key] = fileName
    else:
      echo "failed ", fileName 

proc collectTTC*(dir:string, t: StringTableRef) =
  for fileName in walkDirRec(dir, {pcFile}):
    let path = splitFile(fileName)
    if path.ext.len() == 0: continue
    
    let ext = toLower(path.ext)
    if ext != ".ttc": continue
    parseTTC(fileName, t)

when isMainModule:
  if paramCount() > 0: 
    let dir = paramStr(1)
    var u = collectTTC(dir)
    echo "Fonts: ", $u