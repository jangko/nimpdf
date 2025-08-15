# Copyright (c) 2015 Andri Lim
#
# Distributed under the MIT license
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------
#
# this module perform font related task
# such as when nimPDF as for a font based on family name and style
# this module will search:
# - from standard fonts list
# - from TTF fonts list
# - from TTC fonts list

import base14, tables, strutils, collect, strtabs, unicode, math, encode, os, sets, algorithm
import "subsetter/Font", "subsetter/CMAPTable", "subsetter/HEADTable"
import "subsetter/HMTXTable", "subsetter/FontData", "subsetter/VMTXTable"
import "subsetter/GLYPHTable", "subsetter/NAMETable", "subsetter/FontIOStreams"

export Font, FontRenderMode

const
  defaultFont = "Times"

type
  FontStyle* = enum
    FS_REGULAR, FS_ITALIC, FS_BOLD

  FontStyles* = set[FontStyle]

  EncodingType* = enum
    ENC_STANDARD, ENC_MACROMAN, ENC_WINANSI, ENC_UTF8

  BBox = object
    x1,y1,x2,y2 : int

  TTFont* = ref object of Font
    font*: FontDef
    cmap: CMAP
    hmtx: HMTXTable
    vmtx: VMTXTable
    glyph: GLYPHTable
    scaleFactor: float64
    CH2GID*: CH2GIDMAP
    newGID: int
    fullCharMap*: CH2GIDMAPCache  # Cache for full character mapping

  Base14* = ref object of Font
    baseFont* : string
    getWidth : proc(cp: int): int
    isFontSpecific : bool
    ascent, descent, xHeight, capHeight : int
    bbox : BBox
    missingWidth: int
    encoding*: EncodingType
    encode: proc(val: int): int

  TextWidth* = object
    numchars*, width*, numspace*, numwords*: int

  TextHeight* = int

  FontManager* = object
    fontList*: seq[Font]
    baseFont: seq[Base14]
    ttFontList: StringTableRef
    ttcList: StringTableRef

proc GetCharWidth*(f: TTFont, gid: int): int =
  result = math.round(float(f.hmtx.advanceWidth(gid)) * f.scaleFactor).int

proc GetCharHeight*(f: TTFont, gid: int): int =
  if f.vmtx.isNil:
    let height = (abs(f.glyph.YMin(gid)) + f.glyph.YMax(gid)).float
    result = math.round(height * f.scaleFactor).int
  else:
    result = math.round(float(f.vmtx.advanceHeight(gid)) * f.scaleFactor).int

proc GenerateWidths*(f: TTFont, renderMode: FontRenderMode): string =
  # Generates the /Widths array for the font descriptor.
  # The format depends on whether we are embedding the full font or a subset.
  case renderMode:
  of frmEmbed:
    # When embedding the full font, use Format 1 for /W array: [ c [w1 ... wn] ... ]
    # Collect unique GIDs and their widths, sorted by GID.
    var gidWidths = initOrderedTable[int, int]() # Use OrderedTable to sort by GID
    # Ensure CH2GID is populated correctly (it maps charCode -> (oldGID, oldGID) when embedding)
    if f.CH2GID.len == 0 and f.font.fullCharMap.len > 0:
      # This case shouldn't happen if EscapeStringAndEmbedFullFont was called, but safety first
      f.CH2GID = f.font.fullCharMap
    elif f.CH2GID.len == 0:
      # If CH2GID is empty (e.g., text was empty), populate minimal map or return empty widths
      # For now, just proceed, might result in empty widths if no chars were processed
      discard

    for code, gidInfo in pairs(f.CH2GID):
      let currentGID = gidInfo.oldGID
      if currentGID != 0 and not gidWidths.hasKey(currentGID):
          gidWidths[currentGID] = f.GetCharWidth(currentGID)

    if gidWidths.len == 0: return "[]" # No glyphs processed

    # Build the /W array string by grouping contiguous GIDs
    var widthsParts: seq[string] = @[]
    var startGID = -1
    var currentWidths: seq[string] = @[]

    for gid, width in pairs(gidWidths): # Iterates in GID order
      if startGID == -1: # First GID in a potential group
        startGID = gid
        currentWidths.add($width)
      elif gid == startGID + currentWidths.len: # Contiguous GID, add to current group
        currentWidths.add($width)
      else: # Non-contiguous GID, finalize previous group and start a new one
        widthsParts.add($startGID & " [ " & currentWidths.join(" ") & " ]")
        startGID = gid
        currentWidths = @[$width]

    # Add the last group
    if startGID != -1:
      widthsParts.add($startGID & " [ " & currentWidths.join(" ") & " ]")

    result = "[ " & widthsParts.join(" ") & " ]"

  of frmPathRendering:
    # When subsetting, GIDs used are sequential newGIDs starting from 1.
    # Sort by newGID to ensure correct order for the widths array.
    f.CH2GID.sort(proc(x,y: tuple[key: int, val: TONGID]):int = cmp(x.val.newGID, y.val.newGID))
    # The format is [ firstGID [w1 w2 ... wn] ], where firstGID is typically 1.
    var firstGID = -1
    var widthsArray: seq[string] = @[]

    for gidInfo in values(f.CH2GID):
      if firstGID == -1: firstGID = gidInfo.newGID # Capture the first new GID (should be 1)
      widthsArray.add($f.GetCharWidth(gidInfo.oldGID)) # Get width using oldGID

    if firstGID == -1: return "[]" # No glyphs in subset

    result = "[ " & $firstGID & " [ " & widthsArray.join(" ") & " ] ]"

  of frmDefault:
    f.CH2GID.sort(proc(x,y: tuple[key: int, val: TONGID]):int = cmp(x.val.newGID, y.val.newGID) )
    var widths = "[ 1["
    var x = 0

    for gid in values(f.CH2GID):
      widths.add($f.GetCharWidth(gid.oldGID))
      if x < f.CH2GID.len-1: widths.add(' ')
      inc(x)

    widths.add("]]")
    result = widths

proc GenerateRanges*(f: TTFont): string =
  var entries: seq[string] = @[]

  case f.renderMode:
  of frmEmbed:
    # For embedded fonts, use oldGID to match the content stream
    # The ToUnicode CMap must match what's used in the content stream
    for item in pairs(f.CH2GID):
      let code = item[0]  # Unicode value
      let gid = item[1].oldGID  # Use oldGID to match content stream
      if code > 0 and gid > 0:  # Only include valid Unicode values and GIDs
        let cidHex = toHex(gid, 4).toUpperAscii
        # Handle Unicode values properly - ensure 4-digit hex for BMP characters
        let codeHex = if code <= 0xFFFF:
                        toHex(code, 4).toUpperAscii
                      else:
                        # For Unicode above BMP, convert to UTF-16 surrogate pair
                        let codePoint = code - 0x10000
                        let highSurrogate = 0xD800 + (codePoint shr 10)
                        let lowSurrogate = 0xDC00 + (codePoint and 0x3FF)
                        toHex(highSurrogate, 4).toUpperAscii & toHex(lowSurrogate, 4).toUpperAscii

        # ToUnicode CMap maps oldGID (used in content stream) to Unicode
        let entry = "<" & cidHex & "> <" & codeHex & ">"
        entries.add(entry)

  of frmPathRendering:
    # For subset fonts, use the existing logic with newGID
    var usedCids = initHashSet[int]()
    for item in pairs(f.CH2GID):
      let code = item[0]  # Unicode value
      let cid = item[1].newGID  # For subset fonts, content stream uses newGID

      # Only include valid CIDs (> 0) and valid Unicode values
      if cid > 0 and code > 0 and not usedCids.contains(cid):
        let cidHex = toHex(cid, 4).toUpperAscii
        # Handle Unicode values properly - ensure 4-digit hex for BMP characters
        let codeHex = if code <= 0xFFFF:
                        toHex(code, 4).toUpperAscii
                      else:
                        # For Unicode above BMP, convert to UTF-16 surrogate pair
                        let codePoint = code - 0x10000
                        let highSurrogate = 0xD800 + (codePoint shr 10)
                        let lowSurrogate = 0xDC00 + (codePoint and 0x3FF)
                        toHex(highSurrogate, 4).toUpperAscii & toHex(lowSurrogate, 4).toUpperAscii

        # ToUnicode CMap maps character IDs (used in content stream) to Unicode
        let entry = "<" & cidHex & "> <" & codeHex & ">"
        entries.add(entry)
        usedCids.incl(cid)

  of frmDefault:
    var range: seq[string] = @[]
    var mapping = ""

    for code, gid in pairs(f.CH2GID):
      if range.len >= 100:
        mapping.add("\x0A" & $range.len & " beginbfchar\x0A" & join(range, "\x0A") & "\x0Aendbfchar")
        range = @[]
      range.add("<" & toHex(gid.newGID, 4) & "><" & toHex(code, 4) & ">")

    if range.len > 0:
      mapping.add("\x0A" & $range.len & " beginbfchar\x0A" & join(range, "\x0A") & "\x0Aendbfchar")

    result = mapping

  if entries.len > 0:
    result = $entries.len & " beginbfchar\n" & entries.join("\n") & "\nendbfchar\n"
  else:
    result = ""

proc GetDescriptor*(f: TTFont, renderMode: FontRenderMode): FontDescriptor =
  if renderMode == frmDefault:
    f.CH2GID.sort(proc(x,y: tuple[key: int, val: TONGID]):int = cmp(x.key, y.key) )
  result = f.font.newFontDescriptor(f.CH2GID)

proc GetSubsetBuffer*(f: TTFont, subsetTag: string, renderMode: FontRenderMode): string =
  case renderMode:
  of frmEmbed:
    let fd = f.font.embedFullFont(subsetTag)
    result = fd.getInternalBuffer()
  of frmDefault:
    let fd = f.font.subset(f.CH2GID, subsetTag)
    result = fd.getInternalBuffer()
  of frmPathRendering:
    # For path rendering, we still need a subset buffer for fallback cases
    # but it should be minimal since text is drawn as paths
    let fd = f.font.subset(f.CH2GID, subsetTag)
    result = fd.getInternalBuffer()

method CanWriteVertical*(f: Font): bool {.base.} = false
method CanWriteVertical*(f: Base14): bool = false
method CanWriteVertical*(f: TTFont): bool =
  result = f.vmtx != nil

method EscapeString*(f: Font, text: string): string {.base.} =
  discard


proc EscapeStringAndEmbedFullFont*(f: TTFont, text: string): string =
  # For font embedding, map characters using their Unicode values
  # This ensures proper character-to-Unicode mapping in ToUnicode CMap
  for c in runes(text):
    let charCode = int(c)
    if not f.CH2GID.hasKey(charCode):
      let oldGID = f.cmap.GlyphIndex(charCode)
      if oldGID != 0:
        f.CH2GID[charCode] = (oldGID, oldGID)

  result = ""
  for c in runes(text):
    let charCode = int(c)
    if f.CH2GID.hasKey(charCode):
      # For embedded fonts, use the oldGID in content stream
      # The ToUnicode CMap will map oldGID to Unicode for text extraction
      result.add(toHex(f.CH2GID[charCode].oldGID, 4))
    else:
      result.add("0000") # Missing glyph

method EscapeString*(f: TTFont, text: string): string =
  # Use the font's renderMode property
  case f.renderMode:
  of frmEmbed:
    # Use the dedicated function for full font embedding
    result = f.EscapeStringAndEmbedFullFont(text)

  of frmDefault, frmPathRendering:
    # Original logic for non-embedded fonts: build character-to-glyph mapping
    for c in runes(text):
      let charCode = int(c)
      if not f.CH2GID.hasKey(charCode):
        let oldGID = f.cmap.GlyphIndex(charCode)
        if oldGID != 0:
          f.CH2GID[charCode] = (oldGID, f.newGID)
          inc(f.newGID)

    result = ""
    for c in runes(text):
      let charCode = int(c)
      if f.renderMode == frmDefault:
        if f.CH2GID.hasKey(charCode):
          let gid = f.CH2GID[charCode].newGID
          result.add(toHex(gid, 4))
        else:
          result.add("0000")
      else:
        if f.CH2GID.hasKey(charCode):
          # For subsetted fonts, use the newGID in the content stream
          result.add(toHex(f.CH2GID[charCode].newGID, 4))
        else:
          result.add("0000")

method GetTextWidth*(f: Font, text: string): TextWidth {.base.} =
  discard

method GetTextWidth(f: Base14, text: string): TextWidth =
  result.numchars = 0
  result.width = 0
  result.numspace = 0
  result.numwords = 0
  var b:int

  for i in 0..text.len-1:
    b = ord(text[i])
    inc(result.numchars)
    var ww = f.getWidth(f.encode(b))
    if ww == 0: ww = f.missingWidth
    result.width += ww
    if chr(b) in Whitespace:
      inc(result.numspace)
      inc(result.numwords)

  if chr(b) notin Whitespace:
    inc(result.numwords)

method GetTextWidth(f: TTFont, text: string): TextWidth =
  result.width = 0
  result.numchars = 0
  result.numwords = 0
  result.numspace = 0

  for b in runes(text):
    inc(result.numchars)
    let GID = f.cmap.GlyphIndex(int(b))
    result.width += f.GetCharWidth(GID)
    if isWhiteSpace(b):
      inc(result.numspace)
      inc(result.numwords)

  let lastChar = runeLen(text) - 1
  if not isWhiteSpace(runeAt(text, lastChar)):
    inc(result.numwords)

method GetTextHeight*(f: Font, text: string): TextHeight {.base.} =
  discard

method GetTextHeight*(f: Base14, text: string): TextHeight =
  for c in text:
    let ww = if isUpperAscii(c): f.capHeight else: f.xHeight
    result = max(ww, result)

method GetTextHeight*(f: TTFont, text: string): TextHeight =
  for b in runes(text):
    let GID = f.cmap.GlyphIndex(int(b))
    result = max(f.GetCharHeight(GID), result)

method GetVTextHeight*(f: Font, text: string): TextWidth {.base.} =
  discard

method GetVTextHeight*(f: Base14, text: string): TextWidth =
  result.width = 0
  result.numchars = 0
  result.numwords = 0
  result.numspace = 0

  for c in text:
    inc(result.numchars)
    let ww = if isUpperAscii(c): f.capHeight else: f.xHeight
    result.width += ww
    if c in Whitespace:
      inc(result.numspace)
      inc(result.numwords)

  let lastChar = text[^1]
  if lastChar notin Whitespace:
    inc(result.numwords)

method GetVTextHeight*(f: TTFont, text: string): TextWidth =
  result.width = 0
  result.numchars = 0
  result.numwords = 0
  result.numspace = 0

  for b in runes(text):
    inc(result.numchars)
    let GID = f.cmap.GlyphIndex(int(b))
    result.width += f.GetCharHeight(GID)
    if isWhiteSpace(b):
      inc(result.numspace)
      inc(result.numwords)

  let lastChar = runeLen(text) - 1
  if not isWhiteSpace(runeAt(text, lastChar)):
    inc(result.numwords)

method GetVTextWidth*(f: Font, text: string): TextHeight {.base.} =
  discard

method GetVTextWidth*(f: Base14, text: string): TextHeight =
  for c in text:
    let ww = f.getWidth(f.encode(c.int))
    result = max(ww, result)

method GetVTextWidth*(f: TTFont, text: string): TextHeight =
  for b in runes(text):
    let GID = f.cmap.GlyphIndex(int(b))
    result = max(f.GetCharWidth(GID), result)

proc reverse(s: string): string =
  result = newString(s.len)
  for i in 1..s.len:
    result[i-1] = s[s.len-i]

proc toBase26*(number: int): string =
  var n = number
  if n < 0: n = -n
  var converted = ""

  #Repeatedly divide the number by 26 and convert the
  #remainder into the appropriate letter.
  while n > 0:
    let remainder = n mod 26
    converted.add(chr(remainder + ord('A')))
    n = int((n - remainder) / 26)
  result = reverse(converted)

proc fromBase26*(number: string): int =
  result = 0
  if number.len > 0:
    for i in 0..number.len - 1:
      result += (ord(number[i]) - ord('A'))
      #echo " ", $result
      if i < number.len-1: result *= 26

proc searchFrom[T](list: seq[T], name: string): Font =
  result = nil
  for i in items(list):
    if i.searchName == name:
      result = i
      break

proc init*(ff: var FontManager, fontDirs: seq[string]) =
  ff.fontList = @[]

  ff.ttFontList = newStringTable(modeCaseInsensitive)
  ff.ttcList = newStringTable(modeCaseInsensitive)

  for fontDir in fontDirs:
    collectTTF(fontDir, ff.ttFontList)
    collectTTC(fontDir, ff.ttcList)

  #echo ff.ttFontList
  #echo ff.ttcList

  newSeq(ff.baseFont, 14)

  for i in 0..high(BUILTIN_FONTS):
    new(ff.baseFont[i])
    ff.baseFont[i].baseFont   = BUILTIN_FONTS[i][0]
    ff.baseFont[i].searchName = BUILTIN_FONTS[i][1]
    ff.baseFont[i].getWidth   = BUILTIN_FONTS[i][2]
    ff.baseFont[i].xHeight    = BUILTIN_FONTS[i][6]
    ff.baseFont[i].capHeight  = BUILTIN_FONTS[i][7]
    ff.baseFont[i].subType    = FT_BASE14
    ff.baseFont[i].missingWidth = ff.baseFont[i].getWidth(0x20)

proc makeTTFont(font: FontDef, searchName: string): TTFont =
  var cmap = CMAPTable(font.getTable(TAG.cmap))
  var head = HEADTable(font.getTable(TAG.head))
  var hmtx = HMTXTable(font.getTable(TAG.hmtx))
  if cmap == nil or head == nil or hmtx == nil: return nil
  var encodingcmap = cmap.GetEncodingCMAP()

  if encodingcmap == nil:
    echo "no unicode cmap found"
    return nil

  var res: TTFont
  new(res)

  res.subType  = FT_TRUETYPE
  res.searchName = searchName
  res.font     = font
  res.cmap     = encodingcmap
  res.hmtx     = hmtx
  res.vmtx     = VMTXTable(font.getTable(TAG.vmtx))
  res.glyph    = GLYPHTable(font.getTable(TAG.glyf))
  res.scaleFactor= 1000 / head.UnitsPerEm()
  res.CH2GID   = initOrderedTable[int, TONGID]()
  res.newGID   = 1

  res.fullCharMap = initOrderedTable[int, TONGID]()  # Initialize cache
  res.ID = 0  # Initialize ID field
  res.renderMode = frmDefault  # Initialize with default render mode

  # Pre-populate the full character mapping cache
  if encodingcmap != nil:
    # Only map characters that are actually in the font's cmap
    var cmapTable = CMAPTable(font.getTable(TAG.cmap))
    if cmapTable != nil:
      let encodingcmap = cmapTable.GetEncodingCMAP()
      if encodingcmap != nil:
        # Get the actual character ranges from the cmap
        var ranges = initOrderedTable[int, seq[int]]()
        for i in 0..0xFFFF:
          let gid = encodingcmap.GlyphIndex(i)
          if gid != 0:
            res.fullCharMap[i] = (gid, gid)

  result = res

proc searchFromTTList(ff: FontManager, name:string): Font =
  if not ff.ttFontList.hasKey(name): return nil
  let fileName = ff.ttFontList[name]
  let font = loadTTF(fileName)
  if font != nil: return makeTTFont(font, name)
  result = nil

proc searchFromttcList(ff: FontManager, name:string): Font =
  if not ff.ttcList.hasKey(name): return nil
  let fName = ff.ttcList[name]
  let fileName = substr(fName, 0, fName.len - 2)
  let fontIndex = ord(fName[fName.len-1]) - ord('0')
  let font = loadTTC(fileName, fontIndex)
  if font != nil: return makeTTFont(font, name)
  result = nil

proc makeSubsetTag*(number: int): string =
  let val = toBase26(number)
  let blank = 6 - val.len
  result = repeat('A', blank)
  result.add(val)
  result.add('+')

proc enc_std_map(val: int): int = STDMAP[val]
proc enc_mac_map(val: int): int = MACMAP[val]
proc enc_win_map(val: int): int = WINMAP[val]

proc clone(src: Base14): Base14 =
  new(result)
  result.ID = src.ID
  result.subType = src.subType
  result.searchName = src.searchName
  result.baseFont = src.baseFont
  result.getWidth = src.getWidth
  result.isFontSpecific = src.isFontSpecific
  result.ascent = src.ascent
  result.descent = src.descent
  result.xHeight = src.xHeight
  result.capHeight = src.capHeight
  result.bbox = src.bbox
  result.missingWidth = src.missingWidth
  result.encoding = src.encoding
  result.encode = src.encode

proc makeFont*(
    ff: var FontManager,
    family: string = "Times",
    style: FontStyles = {FS_REGULAR},
    enc: EncodingType,
    renderMode: FontRenderMode = frmDefault,
): Font =
  var searchStyle = "00"
  if FS_BOLD in style:
    searchStyle[0] = '1'
  if FS_ITALIC in style:
    searchStyle[1] = '1'

  var searchName = family
  searchName.add(searchStyle)


  # First check if font already exists in fontList
  var res = searchFrom(ff.fontList, searchName)
  if res != nil:
    return res

  # Search TrueType fonts first (preferred over Base14)
  res = searchFromTTList(ff, searchName)
  if res != nil:
    res.ID = ff.fontList.len + 1
    res.renderMode = renderMode
    ff.fontList.add(res)
    return res

  res = searchFromttcList(ff, searchName)
  if res != nil:
    res.ID = ff.fontList.len + 1
    res.renderMode = renderMode
    ff.fontList.add(res)
    return res

  # Fallback to Base14 fonts only if TrueType not found
  res = searchFrom(ff.baseFont, searchName)
  if res != nil:
    var encoding = ENC_STANDARD
    if enc in {ENC_STANDARD, ENC_MACROMAN, ENC_WINANSI}:
      encoding = enc
    var fon = searchFrom(ff.fontList, searchName & $int(enc))
    if fon != nil:
      return fon

    var fon14 = clone(Base14(res))
    fon14.searchName = fon14.searchName & $int(enc)
    fon14.encoding = encoding

    if encoding == ENC_STANDARD:
      fon14.encode = enc_std_map
    elif encoding == ENC_MACROMAN:
      fon14.encode = enc_mac_map
    elif encoding == ENC_WINANSI:
      fon14.encode = enc_win_map

    fon14.ID = ff.fontList.len + 1
    fon14.renderMode = frmDefault # Base14 fonts use standard text rendering
    ff.fontList.add(fon14)
    return fon14

  result = makeFont(ff, defaultFont, style, enc, renderMode)
  #result = nil

when isMainModule:
  var ff: FontManager
  ff.init(@[])

  for key, val in pairs(ff.ttFontList):
    echo key, ": ", val

  var font = ff.makeFont("GoodDog", {FS_REGULAR}, ENC_STANDARD)
  if font == nil:
    echo "NULL"
  else:
    echo font.searchName

  var times = ff.makeFont("GoodDogx", {FS_REGULAR}, ENC_STANDARD)
  echo times.searchName