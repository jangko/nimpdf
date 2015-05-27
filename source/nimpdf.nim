# Copyright (c) 2015 Andri Lim
#
# Distributed under the MIT license 
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------
# the main module for nimPDF, import this one from your project

import strutils, streams, sequtils, times, unsigned, math, basic2d, algorithm, tables
import image, utf8, font, arc, gstate, path, fontmanager, unicode

export fontmanager.Font, fontmanager.FontStyle, fontmanager.FontStyles
export fontmanager.EncodingType
export gstate.PageUnitType, gstate.LineCap, gstate.LineJoin, gstate.DashMode
export gstate.TextRenderingMode, gstate.RGBColor, gstate.CMYKColor, gstate.BlendMode
export gstate.makeRGB, gstate.makeCMYK, gstate.makeLinearGradient, gstate.setUnit
export gstate.fromMM, gstate.fromCM, gstate.fromIN, gstate.fromUser, gstate.toUser
export gstate.makeCoord,gstate.makeRadialGradient
export image.PImage, image.loadImage, arc.drawArc, arc.arcTo, arc.degree_to_radian
export path.Path, path.calculateBounds, path.bound

when defined(Windows):
  const
    dir_sep = "\\"
else:
  const
    dir_sep = "/"
    
const
  nimPDFVersion = "0.1.4"
  
  defaultFont = "Times"
  
  PageNames = [
    #my paper size
    ("Faktur",210.0,148.0), ("F4",215.0,330.0)
    #ISO paper sizes
    ,("A0",841.0,1189.0),("A1",594.0,841.0),("A2",420.0,594.0),("A3",297.0,420.0),("A4",210.0,297.0),("A5",148.0,210.0),("A6",105.0,148.0),("A7",74.0,105.0),("A8",52.0,74.0)
    ,("A9",37.0,52.0),("A10",26.0,37.0),("B0",1000.0,1414.0),("B1",707.0,1000.0),("B2",500.0,707.0),("B3",353.0,500.0),("B4",250.0,353.0),("B5",176.0,250.0)
    ,("B6",125.0,176.0),("B7",88.0,125.0),("B8",62.0,88.0),("B9",44.0,62.0),("B10",31.0,44.0),("C0",917.0,1297.0),("C1",648.0,917.0),("C2",458.0,648.0)
    ,("C3",324.0,458.0),("C4",229.0,324.0),("C5",162.0,229.0),("C6",114.0,162.0),("C7",81.0,114.0),("C8",57.0,81.0),("C9",40.0,57.0),("C10",28.0,40.0)
    #DIN 476
    ,("4A0",1682.0,2378.0),("2A0",1189.0,1682.0)
    #JIS paper sizes
    ,("JIS0",1030.0,1456.0),("JIS1",728.0,1030.0),("JIS2",515.0,728.0),("JIS3",364.0,515.0),("JIS4",257.0,364.0),("JIS5",182.0,257.0),("JIS6",128.0,182.0),("JIS7",91.0,128.0)
    ,("JIS8",64.0,91.0),("JIS9",45.0,64.0),("JIS10",32.0,45.0),("JIS11",22.0,32.0),("JIS12",16.0,22.0)
    #North American paper sizes
    ,("Letter",215.9,279.4),("Legal",215.9,355.6),("Junior Legal",203.2,127.0),("Ledger",432.0,279.0),("Tabloid",279.0,432.0)
    #ANSI
    ,("ANSI A",216.0,279.0),("ANSI B",279.0,432.0),("ANSI C",432.0,559.0),("ANSI D",559.0,864.0),("ANSI E",864.0,1118.0)
    #others
    ,("Organizer J",70.0,127.0),("Compact", 108.0,171.0),("Organizer L",140.0,216.0),("Statement",140.0,216.0),("Half Letter",140.0,216.0)
    ,("Memo",140.0,216.0),("Jepps",140.0,216.0),("Executive",184.0,267.0),("Monarch",184.0,267.0),("Government-Letter",103.0,267.0)
    ,("Foolscap",210.0,330.0),("Folio[9]",210.0,330.0),("Letter",216.0,279.0),("Organizer M",216.0,279.0),("Fanfold",216.0,304.0)
    ,("German Std Fanfold",216.0,304.0),("Government-Legal",216.0,330.0),("Folio",216.0,330.0),("Legal",216.0,356.0),("Quarto",229.0,279.0)
    ,("US Std Fanfold",279.0,377.0),("Ledger",279.0,432.0),("Tabloid",279.0,432.0),("Organizer K",279.0,432.0),("Bible",279.0,432.0)
    ,("Super-B",330.0,483.0),("Post",394.0,489.0),("Crown",381.0,508.0),("Large Post",419.0,533.0),("Demy",445.0,572.0),("Medium",457.0,584.0)
    ,("Broadsheet",457.0,610.0),("Royal",508.0,635.0),("Elephant",584.0,711.0),("REAL Demy",572.0,889.0),("Quad Demy",889.0,1143.0)]

  MAX_DASH_PATTERN = 8
  
  LABEL_STYLE_CH = ["D", "R", "r", "A", "a"]
   
type
  DocInfo* = enum
    DI_CREATOR, DI_PRODUCER, DI_TITLE, DI_SUBJECT, DI_AUTHOR, DI_KEYWORDS
  
  LabelStyle* = enum
    LS_DECIMAL, LS_UPPER_ROMAN, LS_LOWER_ROMAN, LS_UPPER_LETTER, LS_LOWER_LETTER
    
  PageOrientationType* = enum
    PGO_PORTRAIT, PGO_LANDSCAPE
  DocStateType* = enum
    PGS_INITIALIZED, PGS_DOC_OPENED, PGS_PAGE_OPENED, PGS_DOC_CLOSED
  PageSize* = object
    width*, height*: float64
  ExtGState = object
    strokingAlpha, nonstrokingAlpha: float64
    blendMode: string
    ID, objID: int
    
  Rectangle= object
    x,y,w,h: float64
  
  AnnotType = enum
    ANNOT_LINK, ANNOT_TEXT
    
  Annot = ref object
    objID: int
    rect: Rectangle
    case annotType: AnnotType
    of ANNOT_LINK: 
      dest: Destination
    of ANNOT_TEXT: 
      content: string
    
  Page = ref object
    objID: int
    content: string
    size: PageSize
    annots: seq[Annot]
    
  DocOpt* = ref object
    resourcesPath: seq[string]
    fontsPath: seq[string]
    imagesPath: seq[string]
  
  PageLabel = object
    pageIndex: int
    style: LabelStyle
    prefix: string
    start: int
  
  DestStyle* = enum
    DS_XYZ, DS_FIT, DS_FITH, DS_FITV, DS_FITR, DS_FITB, DS_FITBH, DS_FITBV
  
  Destination = ref object
    style: DestStyle
    a,b,c,d: float64
    page: Page
    
  Outline* = ref object
    objID: int
    kids: seq[Outline]
    dest: Destination
    title: string
  
  Document* = ref object of RootObj
    state: DocStateType
    content: string
    offsets: seq[int]
    pages: seq[Page]
    docUnit: PageUnit
    size: PageSize
    extGStates: seq[ExtGState]
    images: seq[PImage]
    gradients: seq[Gradient]
    fontMan: FontManager
    gstate: GState
    path_start_x, path_start_y, path_end_x, path_end_y: float64
    record_shape: bool
    shapes: seq[Path]
    info: Table[int, string]
    opts: DocOpt
    labels: seq[PageLabel]
    setFontCall: int
    outlines: seq[Outline]
    
  NamedPageSize = tuple[name: string, width: float64, height: float64]
  
proc init(gs: var ExtGState; id: int; sA, nsA: float64, bm: string = "Normal") : int {.discardable.} = 
  gs.ID = id
  gs.strokingAlpha = sA
  gs.nonstrokingAlpha = nsA
  gs.blendMode = bm
  result = 0
  
proc swap(this: var PageSize) : int {.discardable.} = swap(this.width, this.height)

proc searchPageSize(x: openArray[NamedPageSize], y: string, z: var PageSize) : bool =
  for t in items(x):
    if t.name == y:
      z.width = t.width
      z.height = t.height
      return true
  result = false

proc getSizeFromName*(name: string) : PageSize =
  if not searchPageSize(PageNames, name, result):
    result.width  = 210
    result.height = 297

proc escapeString(text: string): string =
  result = ""
  for c in items(text):
    case c
    of chr(0x0A): add(result, "\\n")
    of chr(0x0D): add(result, "\\r")
    of chr(0x09): add(result, "\\t")
    of chr(0x08): add(result, "\\b")
    of chr(0x20)..chr(0x7e): 
      if c == '\\': add(result, "\\\\")
      elif c == ')': add(result, "\\)")
      elif c == '(': add(result, "\\(")
      else: add(result, c)
    else: add(result, "\\" & toOctal(c))

proc put(p: var Page, text: varargs[string]) =
  for s in items(text):
    p.content.add(s)
  p.content.add('\x0A')
  
proc put(doc: Document, text: varargs[string]) =
  if doc.state == PGS_PAGE_OPENED:
    let p = doc.pages.high()
    doc.pages[p].put(text)
  else:
    for s in items(text):
      doc.content.add(s)
    doc.content.add('\x0A')
    
proc newobj(doc: Document) : int =
  doc.offsets.add(doc.content.len())
  result = doc.offsets.len()
  doc.put($result, " 0 obj")

proc putStream(doc: Document, text: string) =
  doc.put("stream")
  doc.content.add(text)
  doc.content.add('\x0A')
  doc.put("endstream")

template f2s(a: expr): expr =
  formatFloat(a,ffDecimal,4)

proc f2sn(a: float64): string =
  if a == 0: "null" else: f2s(a)

proc putDestination(doc: Document, dest: Destination) =
  var destStr = "/Dest [" & $dest.page.objID & " 0 R"
  
  case dest.style 
  of DS_XYZ: destStr.add("/XYZ " & f2sn(dest.a) & " " & f2sn(dest.b) & " " & f2sn(dest.c) & "]")
  of DS_FIT: destStr.add("/Fit]")
  of DS_FITH: destStr.add("/FitH " & f2sn(dest.a) & "]")
  of DS_FITV: destStr.add("/FitV " & f2sn(dest.a) & "]")
  of DS_FITR: destStr.add("/FitR " & f2s(dest.a) & " " & f2s(dest.b) & " " & f2s(dest.c) & " " & f2s(dest.d) & "]")
  of DS_FITB: destStr.add("/FitB]")
  of DS_FITBH: destStr.add("/FitBH " & f2sn(dest.a) & "]")
  of DS_FITBV: destStr.add("/FitBV " & f2sn(dest.a) & "]")
  
  doc.put(destStr)
  
proc putPages(doc: Document, resourceID: int) : int =
  let numpages = doc.pages.len()
    
  let pageRootID = doc.newobj()
  var kids = ""
    
  doc.put("<</Type /Pages")
  kids.add("/Kids [")
  for i in 0..numpages-1:
    kids.add($(pageRootID + 2 * i + 1))
    kids.add(" 0 R ")
  kids.add("]")
  doc.put(kids)
  doc.put("/Count ", $numpages)
  doc.put(">>")
  doc.put("endobj")
  
  var annotID = pageRootID + 2 * numpages + 1
  
  for p in doc.pages:
    p.objID = doc.newobj()
    let contentID = p.objID + 1
    doc.put("<</Type /Page")
    doc.put("/Parent ", $pageRootID, " 0 R")
    doc.put("/Resources ", $resourceID, " 0 R")
    #Output the page size.
    doc.put("/MediaBox [0 0 ",f2s(p.size.width)," ",f2s(p.size.height),"]")
    if p.annots.len > 0:
      var annot = "/Annots ["
      for a in p.annots:
        annot.add($annotID)
        annot.add(" 0 R ")
        inc(annotID)
      annot.add("]")
      doc.put(annot)
    doc.put("/Contents ", $contentID, " 0 R>>")
    doc.put("endobj")

    discard doc.newobj()
    let len = p.content.len()
    let zc = zcompress(p.content)
    let useFlate = zc.len() < len
    if useFlate:
      doc.put("<< /Filter /FlateDecode /Length ", $zc.len(), " >>")
      doc.putStream(zc)
    else:
      doc.put("<< /Length ", $len, " >>")
      doc.putStream(p.content)
    doc.put("endobj")
     
  for p in doc.pages:
    for a in p.annots:
      a.objID = doc.newobj()
      doc.put("<</Type /Annot")
      if a.annotType == ANNOT_LINK:
        doc.put("/Subtype /Link")
        doc.putDestination(a.dest)
      else:
        doc.put("/Subtype /Text")
        doc.put("/Contents (", escapeString(a.content), ")")
      doc.put("/Rect [",f2s(a.rect.x)," ",f2s(a.rect.y)," ",f2s(a.rect.w)," ",f2s(a.rect.h),"]")
      #doc.put("/Border [16 16 1]")
      doc.put("/BS <</W 0>>")
      doc.put(">>")
      doc.put("endobj")
      
  result = pageRootID

proc putBase14Fonts(doc: Document, font: Font) =
  let fon = Base14(font)
  
  fon.objID = doc.newobj()
  doc.put("<</Type /Font")
  doc.put("/BaseFont /", fon.baseFont)
  doc.put("/Subtype /Type1")
  if (fon.baseFont != "Symbol") and (fon.baseFont != "ZapfDingbats"):
    if fon.encoding == ENC_STANDARD:
      doc.put("/Encoding /StandardEncoding")
    elif fon.encoding == ENC_MACROMAN:
      doc.put("/Encoding /MacRomanEncoding")
    elif fon.encoding == ENC_WINANSI:
      doc.put("/Encoding /WinAnsiEncoding")
  doc.put(">>")
  doc.put("endobj")

proc putTrueTypeFonts(doc: Document, font: Font, seed: int) =
  let fon = TTFont(font)
  let subsetTag  = makeSubsetTag(seed)
   
  let widths   = fon.GenerateWidths() #don't change this order
  let ranges   = fon.GenerateRanges() #coz they sort CH2GID differently
  let desc     = fon.GetDescriptor()
  let buf    = fon.GetSubsetBuffer(subsetTag)
   
  let compressed = zcompress(buf)
  let Length   = compressed.len
  let Length1  = buf.len
  let psName   = subsetTag & desc.postscriptName
   
  let fontFileID = doc.newobj()
  doc.put("<</Filter/FlateDecode/Length ", $Length, "/Length1 ", $Length1, ">>")
  doc.putStream(compressed)
  doc.put("endobj")
   
  let descriptorID = doc.newobj()
  doc.put("<</Type /FontDescriptor")
  doc.put("/FontName /", psName)
  doc.put("/FontFamily (", desc.fontFamily, ")")
  doc.put("/Flags ", $desc.Flags)
  doc.put("/FontBBox [",$desc.BBox[0]," ", $desc.BBox[1]," ", $desc.BBox[2]," ", $desc.BBox[3],"]")
  doc.put("/ItalicAngle ", $desc.italicAngle)
  doc.put("/Ascent ", $desc.Ascent)
  doc.put("/Descent ", $desc.Descent)
  doc.put("/CapHeight ", $desc.capHeight)
  doc.put("/StemV ", $desc.StemV)
  doc.put("/XHeight ", $desc.xHeight)
  doc.put("/FontFile2 ", $fontFileID, " 0 R")
  doc.put(">>")
  doc.put("endobj")
   
  # CIDFontType2
  # A CIDFont whose glyph descriptions are based on TrueType font technology
  let descendantID = doc.newobj()
  doc.put("<</Type/Font")
  doc.put("/Subtype/CIDFontType2")
  doc.put("/BaseFont /", psName)
  doc.put("/CIDSystemInfo <</Registry(Adobe)/Ordering(Identity)/Supplement 0>>")
  doc.put("/FontDescriptor ", $descriptorID, " 0 R")
  doc.put("/DW ", $desc.MissingWidth)
  doc.put("/W ", widths)
  doc.put(">>")
  doc.put("endobj")
   
  # ToUnicode
  let toUni1 = """/CIDInit /ProcSet findresource begin
12 dict begin
begincmap
/CIDSystemInfo
<</Registry(Adobe)/Ordering(Identity)/Supplement 0>> def
/CMapName /Adobe-Identity-UCS def
/CMapType 2 def
1 begincodespacerange
<0000> <FFFF>
endcodespacerange"""

  let toUni2 = """\x0Aendcmap
CMapName currentdict /CMap defineresource pop
end
end"""
   
  let ToUnicodeID = doc.newobj()
  let toUni = toUni1 & ranges & toUni2
  doc.put("<</Length ", $toUni.len , ">>")
  doc.putStream(toUni)
  doc.put("endobj")
   
  fon.objID = doc.newobj()
  doc.put("<</Type /Font")
  doc.put("/BaseFont /", psName)
  doc.put("/Subtype /Type0")
  doc.put("/Encoding /Identity-H")
  doc.put("/DescendantFonts [", $descendantID ," 0 R]")
  doc.put("/ToUnicode " , $ToUnicodeID, " 0 R")
  doc.put("/FirstChar ", $desc.FirstChar)
  doc.put("/LastChar ", $desc.LastChar)
  ##doc.put("/Widths ", $widthsID, " 0 R")
  doc.put(">>")
  doc.put("endobj")
    
proc putFonts(doc: Document) : int =
  var seed = fromBase26("NIMPDF")
  for fon in items(doc.fontMan.FontList):
    if fon.subType == FT_BASE14: doc.putBase14Fonts(fon)
    if fon.subType == FT_TRUETYPE: doc.putTrueTypeFonts(fon, seed)
    inc(seed)
    
  result = 0

proc putExtGStates(doc: Document) : int =
  for i in 0..high(doc.extGStates):
    let objID = doc.newobj()
    doc.extGStates[i].objID = objID
    doc.put("<</Type /ExtGState")
    let nsa = doc.extGStates[i].nonstrokingAlpha
    let sa = doc.extGStates[i].strokingAlpha
    
    if nsa > 0.0: doc.put("/ca ", $nsa)
    if sa > 0.0: doc.put("/CA ", $sa)
    
    doc.put("/BM /", doc.extGStates[i].blendMode)
    doc.put(">>")
    doc.put("endobj")
  result = 0

proc putGradients(doc: Document) : int =
  for i in 0..high(doc.gradients):
    var gd = doc.gradients[i]
    let a = gd.a
    let b = gd.b
    let funcID = doc.newobj()
    doc.put("<<")
    doc.put("/FunctionType 2")
    doc.put("/Domain [0.0 1.0]")
    doc.put("/C0 [",f2s(a.r)," ",f2s(a.g)," ",f2s(a.b),"]")
    doc.put("/C1 [",f2s(b.r)," ",f2s(b.g)," ",f2s(b.b),"]")
    doc.put("/N 1")
    doc.put(">>")
    doc.put("endobj")
    
    let objID = doc.newobj()
    doc.put("<<")
    if gd.gradType == GDT_LINEAR:
      let cr = gd.axis
      doc.put("/ShadingType 2")
      doc.put("/Coords [",f2s(cr.x1)," ",f2s(cr.y1)," ",f2s(cr.x2)," ",f2s(cr.y2),"]")
    elif gd.gradType == GDT_RADIAL:
      let cr = gd.radCoord
      doc.put("/ShadingType 3")
      doc.put("/Coords [",f2s(cr.x1)," ",f2s(cr.y1)," ",f2s(cr.r1)," ",f2s(cr.x2)," ",f2s(cr.y2)," ",f2s(cr.r2),"]")
    doc.put("/ColorSpace /DeviceRGB")    
    doc.put("/Function ",$funcID," 0 R")
    doc.put("/Extend [true true] ")
    doc.put(">>")
    doc.put("endobj")
    doc.gradients[i].objID = objID
  result = 0

proc putImages(doc: Document) : int =
  for i in 0..high(doc.images):
    if doc.images[i].haveMask():
      doc.images[i].maskID = doc.newobj()
      let len = doc.images[i].height * doc.images[i].width
      let zc = zcompress(doc.images[i].mask)
      let useFlate = zc.len() < doc.images[i].mask.len()
      doc.put("<</Type /XObject")
      doc.put("/Subtype /Image")
      doc.put("/Width ", $doc.images[i].width)
      doc.put("/Height ", $doc.images[i].height)
      doc.put("/ColorSpace /DeviceGray")
      doc.put("/BitsPerComponent 8")
      #doc.put("/Filter /ASCIIHexDecode")
      if useflate:
        doc.put("/Filter /FlateDecode")
        doc.put("/Length ", $len)
      else:
        doc.put("/Length ", $zc.len())
      doc.put(">>")
      if useFlate:
        doc.putStream(zc)
      else:
        doc.putStream(doc.images[i].mask)
      doc.put("endobj")

    doc.images[i].objID = doc.newobj()
    let len = doc.images[i].height * doc.images[i].width * 3
    let zc = zcompress(doc.images[i].data)
    let useFlate = zc.len() < doc.images[i].data.len()
    doc.put("<</Type /XObject")
    doc.put("/Subtype /Image")
    doc.put("/Width ", $doc.images[i].width)
    doc.put("/Height ", $doc.images[i].height)
    if doc.images[i].haveMask():
      doc.put("/SMask ",$doc.images[i].maskID," 0 R")
    doc.put("/ColorSpace /DeviceRGB")
    doc.put("/BitsPerComponent 8")
    #doc.put("/Filter /ASCIIHexDecode")
    if useFlate:
      doc.put("/Filter /FlateDecode")
      doc.put("/Length ", $zc.len())
    else:
      doc.put("/Length ", $len)
    doc.put(">>")
    if useFlate:
      doc.putStream(zc)
    else:
      doc.putStream(doc.images[i].data)
    doc.put("endobj")
  result = 0
  
proc putResources(doc: Document) : int =
  discard doc.putGradients()
  discard doc.putExtGStates()
  discard doc.putImages()
  discard doc.putFonts()
  
  result = doc.newobj()
  #doc.put("<</ProcSet [/PDF /Text /ImageB /ImageC /ImageI]")

  doc.put("<</Font <<")
  for fon in items(doc.fontMan.FontList):
    doc.put("/F",$fon.ID," ",$fon.objID," 0 R")
  doc.put(">>")
  
  if doc.extGStates.len > 0:
    doc.put("/ExtGState <<")
    for gs in items(doc.extGStates):
      doc.put("/GS",$gs.ID," ",$gs.objID," 0 R")
    doc.put(">>")
  
  if doc.images.len > 0:
    doc.put("/XObject <<")
    for img in items(doc.images):
      if img.haveMask():
        doc.put("/Im",$img.ID," ",$img.maskID," 0 R")
      doc.put("/I",$img.ID," ",$img.objID," 0 R")
    doc.put(">>")
  
  if doc.gradients.len > 0:  
    doc.put("/Shading <<")
    for gd in items(doc.gradients):
      doc.put("/Sh",$gd.ID," ",$gd.objID," 0 R")
    doc.put(">>")
  
  doc.put(">>")
  doc.put("endobj")

proc i2s10(val: int) : string = 
  let s = $val
  let blank = 9 - s.len()
  result = repeatChar(blank, '0')
  result.add(s)

proc writeInfo(doc: Document, field: DocInfo, fieldName: string) =
  if doc.info.hasKey(int(field)):
    doc.put(fieldName, "(", escapeString(doc.info[int(field)]), ")")

proc putInfo(doc: Document): int =
  var lt = getLocalTime(getTime())

  let infoID = doc.newobj()
  doc.put("<<")
  doc.writeInfo(DI_CREATOR, "/Creator")
  doc.writeInfo(DI_PRODUCER, "/Producer")
  doc.writeInfo(DI_TITLE, "/Title")
  doc.writeInfo(DI_SUBJECT, "/Subject")
  doc.writeInfo(DI_AUTHOR, "/Author")
  doc.writeInfo(DI_KEYWORDS, "/Keywords")
  doc.put("/CreationDate (D:", lt.format("yyyyMMddHHmmss"), ")")
  doc.put(">>")
  doc.put("endobj")
  
  result = infoID
  
proc putLabels(doc: Document): int =
  if doc.labels.len == 0: return -1
  
  let labelsID = doc.newobj()
  doc.put("<< /Nums [")
  for label in doc.labels:
    doc.put($label.pageIndex, " << /S /", LABEL_STYLE_CH[int(label.style)])
    if label.prefix != nil: 
      if label.prefix.len > 0: doc.put("/P (", escapeString(label.prefix), ")")
    if label.start > 0: doc.put("/St ", $label.start)
    doc.put(">>")
    
  doc.put("] >>")
  doc.put("endobj")
  result = labelsID

proc assignID(o: Outline, objID: var int) =
  for k in o.kids:
    k.objID = objID
    inc(objID)
    assignID(k, objID)
  
proc putOutlineItem(doc: Document, outlines: seq[Outline], parentID: int, ot: Outline, i: int) =
  let objID = doc.newobj()
  assert objID == ot.objID
  #echo " ", $objID
  
  doc.put("<</Title (",escapeString(ot.title),")/Parent ", $parentID, " 0 R/Count 0")
  if outlines.len == 2:
    if i == 0: doc.put("/Next ", $outlines[1].objID ," 0 R")
    if i == 1: doc.put("/Prev ", $outlines[0].objID ," 0 R")
  elif outlines.len > 2:
    let lastIdx = outlines.len - 1
    if i == 0: doc.put("/Next ", $outlines[1].objID ," 0 R")
    if i == lastIdx: doc.put("/Prev ", $outlines[lastIdx-1].objID ," 0 R")
    if i > 0 and i < lastIdx:
      doc.put("/Next ", $outlines[i+1].objID ," 0 R")
      doc.put("/Prev ", $outlines[i-i].objID ," 0 R")
  
  doc.putDestination(ot.dest)
  
  if ot.kids.len > 0:
    let firstKid = ot.kids[0].objID
    let lastKid = ot.kids[ot.kids.len-1].objID
    doc.put("/First ", $firstKid ," 0 R/Last ", $lastKid ," 0 R>>")
  else:
    doc.put(">>")
  doc.put("endobj")
  
  var i = 0
  for kid in ot.kids:
    doc.putOutlineItem(ot.kids, ot.objID, kid, i)
    inc(i)
    
proc putOutlines(doc: Document): int =
  if doc.outlines.len == 0: return -1

  let outlineID = doc.newobj()
  var objID = outlineID + 1
  for o in items(doc.outlines):
    o.objID = objID
    inc(objID)
    assignID(o, objID)
  
  let firstKid = doc.outlines[0].objID
  let lastKid = doc.outlines[doc.outlines.len-1].objID
  doc.put("<</Type/Outlines/First ", $firstKid ," 0 R/Last ", $lastKid ," 0 R>>")
  doc.put("endobj")
  
  var i = 0
  for ot in items(doc.outlines):
    doc.putOutlineItem(doc.outlines, outlineID, ot, i)
    inc(i)
    
  result = outlineID
    
proc putCatalog(doc: Document) =
  doc.state = PGS_DOC_OPENED
  let resourceID = doc.putResources()
  let pageRootID = doc.putPages(resourceID)
  #let firstPageID = pageRootID + 1
    
  let infoID = doc.putInfo()
  let pageLabelsID = doc.putLabels()
  let outlinesID = doc.putOutlines()
  
  let catalogID = doc.newobj()
  doc.put("<<")
  doc.put("/Type /Catalog")
  doc.put("/Pages ", $pageRootID, " 0 R")
  if doc.labels.len > 0: doc.put("/PageLabels ", $pageLabelsID, " 0 R")
  if doc.outlines.len > 0: doc.put("/Outlines ", $outlinesID, " 0 R")
  #doc.put("/OpenAction [",$firstPageID," 0 R /FitH null]")
  #doc.put("/PageLayout /OneColumn")
  doc.put(">>")
  doc.put("endobj")

  let start_xref = doc.content.len()
  let numoffset = doc.offsets.len()
  let numobject = numoffset + 1
  
  doc.put("xref")
  doc.put("0 ", $numobject)
  doc.put("0000000000 65535 f ")

  for i in 0..high(doc.offsets):
    doc.put("0", i2s10(doc.offsets[i]), " 00000 n ", )

  doc.put("trailer")
  doc.put("<<")
  doc.put("/Size ", $numobject)
  doc.put("/Root ", $catalogID, " 0 R")
  doc.put("/Info ", $infoID, " 0 R")
  doc.put(">>")
  doc.put("startxref")
  doc.put($start_xref)
  doc.put("%%EOF")
  
  doc.state = PGS_DOC_CLOSED

proc setInfo*(doc: Document, field: DocInfo, info: string) =
  doc.info[int(field)] = info
  
proc initPDF*(opts: DocOpt): Document =
  new(result)
  result.state = PGS_INITIALIZED
  result.offsets = @[]
  result.pages = @[]
  result.extGStates = @[]
  result.images = @[]
  result.gradients = @[]
  result.docUnit.setUnit(PGU_MM)
  result.content = ""
  result.fontMan.init(opts.fontsPath)
  result.gstate = newGState()
  result.path_start_x = 0
  result.path_start_y = 0
  result.path_end_x = 0
  result.path_end_y = 0
  result.record_shape = false
  result.shapes = nil
  result.info = initTable[int, string]()
  result.opts = opts
  result.labels = @[]
  result.outlines = @[]
  result.put("%PDF-1.5")
  result.setInfo(DI_PRODUCER, "nimPDF")

proc makeDocOpt*(): DocOpt =
  new(result)
  result.resourcesPath = @[]
  result.fontsPath = @[]
  result.imagesPath = @[]

proc addResourcesPath*(opt: DocOpt, path: string) =
  opt.resourcesPath.add(path)

proc addImagesPath*(opt: DocOpt, path: string) =
  opt.imagesPath.add(path)

proc addFontsPath*(opt: DocOpt, path: string) =
  opt.fontsPath.add(path)
  
proc initPDF*(): Document =
  var opts = makeDocOpt()
  opts.addFontsPath("fonts")
  opts.addImagesPath("resources")
  opts.addResourcesPath("resources")
  result = initPDF(opts)

proc setLabel*(doc: Document, style: LabelStyle, prefix: string, start: int) =
  var label: PageLabel
  label.pageIndex = doc.pages.len
  label.style = style
  label.prefix = prefix
  label.start = start
  doc.labels.add(label)

proc setLabel*(doc: Document, style: LabelStyle) =
  var label: PageLabel
  label.pageIndex = doc.pages.len
  label.style = style
  label.start = -1
  doc.labels.add(label)

proc setLabel*(doc: Document, style: LabelStyle, prefix: string) =
  var label: PageLabel
  label.pageIndex = doc.pages.len
  label.style = style
  label.prefix = prefix
  label.start = -1
  doc.labels.add(label)
  
proc loadImage*(doc: Document, fileName: string): PImage =
  for p in doc.opts.imagesPath:
    let image = loadImage(p & dir_sep & fileName)
    if image != nil: return image
  result = nil
  
proc getVersion(): string =
  result = nimPDFVersion
  
proc getVersion*(doc: Document): string = 
  result = nimPDFVersion

proc setUnit*(doc: Document, unit: PageUnitType) =
  doc.docUnit.setUnit(unit)

proc getSize*(doc: Document): PageSize = 
  result.width = doc.docUnit.toUser(doc.size.width)
  result.height = doc.docUnit.toUser(doc.size.height)

proc setFont*(doc: Document, family:string, style: FontStyles, size: float64, enc: EncodingType = ENC_STANDARD) =
  var font = doc.fontMan.makeFont(family, style, enc)
  let fontNumber = font.ID
  let fontSize = doc.docUnit.fromUser(size)
  doc.put("BT /F",$fontNumber," ",$fontSize," Tf ET")
  doc.gstate.font = font
  doc.gstate.font_size = fontSize
  inc(doc.setFontCall)
  
proc addPage*(doc: Document, s: PageSize, o: PageOrientationType): Page {.discardable.} =
  var p : Page
  new(p)
  p.size.width = fromMM(s.width)
  p.size.height = fromMM(s.height)
  p.content = ""
  p.annots = @[]
  if o == PGO_LANDSCAPE:
    p.size.swap()
  doc.pages.add(p)
  doc.state = PGS_PAGE_OPENED
  doc.size = p.size
  doc.setFontCall = 0  
  result = p

proc writePDF*(doc: Document, s: Stream) =
  doc.putCatalog()
  s.write(doc.content)
   
proc drawText*(doc: Document; x,y: float64; text: string) =
  let xx = doc.docUnit.fromUser(x)
  let yy = doc.size.height - doc.docUnit.fromUser(y)

  if doc.gstate.font == nil or doc.setFontCall == 0:
    doc.setFont(defaultFont, {FS_REGULAR}, 5)

  var font = doc.gstate.font
  
  if font.subType == FT_TRUETYPE:
    var utf8 = replace_invalid(text)
    doc.put("BT ",f2s(xx)," ",f2s(yy)," Td <",font.EscapeString(utf8),"> Tj ET")
  else:
    doc.put("BT ",f2s(xx)," ",f2s(yy)," Td (",escapeString(text),") Tj ET")

proc drawVText*(doc: Document; x,y: float64; text: string) =
  if doc.gstate.font == nil or doc.setFontCall == 0:
    doc.setFont(defaultFont, {FS_REGULAR}, 5)

  var font = doc.gstate.font

  if not font.CanWriteVertical():
    #echo "cannot write vertical"
    doc.drawText(x, y, text)
    return
    
  var xx = doc.docUnit.fromUser(x)
  var yy = doc.size.height - doc.docUnit.fromUser(y)
  let utf8 = replace_invalid(text)
  let cid = font.EscapeString(utf8)
  
  doc.put("BT")
  var i = 0
  for b in runes(utf8):
    doc.put(f2s(xx)," ",f2s(yy)," Td <", substr(cid, i, i + 3),"> Tj")
    yy = -float(TTFont(font).GetCharHeight(int(b))) * doc.gstate.font_size / 1000
    xx = 0
    inc(i, 4)
  doc.put("ET")
    

proc beginText*(doc: Document) =
  if doc.gstate.font == nil or doc.setFontCall == 0:
    doc.setFont(defaultFont, {FS_REGULAR}, 5)
    
  doc.put("BT")
  
proc beginText*(doc: Document; x,y: float64) =
  if doc.gstate.font == nil:
    doc.setFont(defaultFont, {FS_REGULAR}, 5)
    
  let xx = doc.docUnit.fromUser(x)
  let yy = doc.size.height - doc.docUnit.fromUser(y)
  doc.put("BT ", f2s(xx)," ",f2s(yy)," Td")
   
proc moveTextPos*(doc: Document; x,y: float64) =
  let xx = doc.docUnit.fromUser(x)
  let yy = doc.docUnit.fromUser(-y)
  doc.put(f2s(xx)," ",f2s(yy)," Td")

proc setTextRenderingMode*(doc: Document, rm: TextRenderingMode) =
  let trm = cast[int](rm)
  if doc.gstate.rendering_mode != rm: doc.put($trm, " Tr")
  doc.gstate.rendering_mode = rm
  
proc setTextMatrix*(doc: Document, m: TMatrix2d) =
  doc.put(f2s(m.ax)," ", f2s(m.ay), " ", f2s(m.bx), " ", f2s(m.by), " ", f2s(m.tx)," ",f2s(m.ty)," Tm")
  
proc showText*(doc: Document, text:string) =
  var font = doc.gstate.font
  
  if font.subType == FT_TRUETYPE:
    var utf8 = replace_invalid(text)
    doc.put("<",font.EscapeString(utf8),"> Tj")
  else:
    doc.put("(",escapeString(text),") Tj")

proc setTextLeading*(doc: Document, val: float64) =
  let tl = doc.docUnit.fromUser(val)
  doc.put(f2s(tl)," TL")

proc moveToNextLine*(doc: Document) =
  doc.put("T*")
  
proc endText*(doc: Document) =
  doc.put("ET")

proc setCharSpace*(doc: Document; val: float64) =
  doc.put(f2s(val)," Tc")
  doc.gstate.char_space = val

proc setWordSpace*(doc: Document; val: float64) =
  doc.put(f2s(val)," Tw")
  doc.gstate.word_space = val
  
proc setTransform*(doc: Document, m: TMatrix2d) =
  doc.put(f2s(m.ax)," ", f2s(m.ay), " ", f2s(m.bx), " ", f2s(m.by), " ", f2s(m.tx)," ",f2s(m.ty)," cm")
  doc.gstate.trans_matrix = doc.gstate.trans_matrix & m

proc rotate*(doc: Document, angle:float64) =
  doc.setTransform(rotate(degree_to_radian(angle)))
  
proc rotate*(doc: Document, angle, x,y:float64) =
  let xx = doc.docUnit.fromUser(x)
  let yy = doc.size.height - doc.docUnit.fromUser(y)
  doc.setTransform(rotate(degree_to_radian(angle), point2d(xx, yy)))
  
proc move*(doc: Document, x,y:float64) =
  let xx = doc.docUnit.fromUser(x)
  let yy = -doc.docUnit.fromUser(y)
  doc.setTransform(move(xx,yy))
  
proc scale*(doc: Document, s:float64) =
  doc.setTransform(scale(s))
  
proc scale*(doc: Document, s, x,y:float64) =
  let xx = doc.docUnit.fromUser(x)
  let yy = doc.size.height - doc.docUnit.fromUser(y)
  doc.setTransform(scale(s, point2d(xx, yy)))
  
proc stretch*(doc: Document, sx,sy:float64) =
  doc.setTransform(stretch(sx,sy))
  
proc stretch*(doc: Document, sx,sy,x,y:float64) =
  let xx = doc.docUnit.fromUser(x)
  let yy = doc.size.height - doc.docUnit.fromUser(y)
  doc.setTransform(stretch(sx, sy, point2d(xx, yy)))

proc shear(sx,sy,x,y:float64): TMatrix2d =
  let 
    m = move(-x,-y)
    s = matrix2d(1,sx,sy,1,0,0)
  result = m & s & move(x,y)

proc skew*(doc: Document, sx,sy:float64) =
  let tsx = math.tan(degree_to_radian(sx))
  let tsy = math.tan(degree_to_radian(sy))
  doc.setTransform(matrix2d(1,tsx,tsy,1,0,0))

proc skew*(doc: Document, sx,sy,x,y:float64) =
  let xx = doc.docUnit.fromUser(x)
  let yy = doc.size.height - doc.docUnit.fromUser(y)
  let tsx = math.tan(degree_to_radian(sx))
  let tsy = math.tan(degree_to_radian(sy))
  doc.setTransform(shear(tsx, tsy, xx, yy))

proc toUser*(doc: Document, val:float64): float64 =
  result = doc.docUnit.toUser(val)

proc fromUser*(doc: Document, val:float64): float64 =
  result = doc.docUnit.fromUser(val)
  
proc drawImage*(doc: Document, x:float64, y:float64, source: PImage) =
  let size = doc.images.len()
  var found = false
  var img = source

  if img == nil: return
  
  for image in items(doc.images):
    if image == img:
      found = true
      break
      
  if doc.gstate.alpha_fill > 0.0 and doc.gstate.alpha_fill < 1.0:
    img = img.clone()
    img.adjustTransparency(doc.gstate.alpha_fill)
    found = false
    
  if not found:
    img.ID = size + 1
    doc.images.add(img)
  
  let hh = float(img.height)
  let ww = float(img.width)
    
  if img.haveMask():
    doc.put("q")
  
    #embed hidden, outside canvas
    var xx = doc.docUnit.fromUser(doc.size.width + 10)
    var yy = doc.docUnit.fromUser(doc.size.height + 10)
  
    doc.put(f2s(ww)," 0 0 ",f2s(hh)," ",f2s(xx)," ",f2s(yy)," cm")
    doc.put("/Im",$img.ID," Do")
    doc.put("Q")

  doc.put("q")
  var xx = doc.docUnit.fromUser(x)
  var yy = doc.size.height - doc.docUnit.fromUser(y)
  
  doc.put(f2s(ww)," 0 0 ",f2s(hh)," ",f2s(xx)," ",f2s(yy)," cm")
    
  doc.put("/I",$img.ID," Do")
  doc.put("Q")

proc drawRect*(doc: Document, x: float64, y: float64, w: float64, h: float64) =
  if doc.record_shape:
    doc.shapes[doc.shapes.len - 1].addRect(x, y, w, h)
    doc.shapes.add(makePath())
  else:
    let xx = doc.docUnit.fromUser(x)
    let yy = doc.size.height - doc.docUnit.fromUser(y)
    let ww = doc.docUnit.fromUser(w)
    let hh = -doc.docUnit.fromUser(h)
    doc.put(f2s(xx)," ",f2s(yy)," ",f2s(ww)," ",f2s(hh)," re")

proc moveTo*(doc: Document, x: float64, y: float64) =
  let xx = doc.docUnit.fromUser(x)
  let yy = doc.size.height - doc.docUnit.fromUser(y)
  doc.put(f2s(xx)," ",f2s(yy)," m")
  doc.path_start_x = x
  doc.path_start_y = y
  doc.path_end_x = x
  doc.path_end_y = y

proc moveTo*(doc: Document, p: TPoint2d) {.inline.} = doc.moveTo(p.x, p.y)
     
proc lineTo*(doc: Document, x: float64, y: float64) =
  if doc.record_shape:
    doc.shapes[doc.shapes.len - 1].addLine(doc.path_start_x, doc.path_start_y, x, y)
    if x == doc.path_start_x and y == doc.path_start_y:
      doc.shapes.add(makePath())
  else:
    let xx = doc.docUnit.fromUser(x)
    let yy = doc.size.height - doc.docUnit.fromUser(y)
    doc.put(f2s(xx)," ",f2s(yy)," l")
  doc.path_end_x = x
  doc.path_end_y = y

proc lineTo*(doc: Document, p: TPoint2d) {.inline.} = doc.lineTo(p.x, p.y)
  
proc bezierCurveTo*(doc: Document; cp1x, cp1y, cp2x, cp2y, x, y: float64) =
  if doc.record_shape:
    doc.shapes[doc.shapes.len - 1].addCubicCurve(doc.path_end_x, doc.path_end_y, cp1x,cp1y, cp2x,cp2y, x, y)
    if x == doc.path_start_x and y == doc.path_start_y:
      doc.shapes.add(makePath())
  else:
    let cp1xx = doc.docUnit.fromUser(cp1x)
    let cp2xx = doc.docUnit.fromUser(cp2x)
    let xx = doc.docUnit.fromUser(x)
  
    let cp1yy = doc.size.height - doc.docUnit.fromUser(cp1y)
    let cp2yy = doc.size.height - doc.docUnit.fromUser(cp2y)
    let yy = doc.size.height - doc.docUnit.fromUser(y)
    doc.put(f2s(cp1xx)," ",f2s(cp1yy)," ",f2s(cp2xx)," ",f2s(cp2yy)," ",f2s(xx)," ",f2s(yy)," c")
  doc.path_end_x = x
  doc.path_end_y = y

proc bezierCurveTo*(doc: Document; cp1, cp2, p: TPoint2d) {.inline.}= doc.bezierCurveTo(cp1.x,cp1.y,cp2.x,cp2.y,p.x,p.y)
  
proc curveTo1*(doc: Document; cpx, cpy, x, y: float64) =
  if doc.record_shape:
    doc.shapes[doc.shapes.len - 1].addQuadraticCurve(doc.path_end_x, doc.path_end_y, cpx,cpy, x, y)
    if x == doc.path_start_x and y == doc.path_start_y:
      doc.shapes.add(makePath())
  else:
    let cpxx = doc.docUnit.fromUser(cpx)
    let xx = doc.docUnit.fromUser(x)
    let cpyy = doc.size.height - doc.docUnit.fromUser(cpy)
    let yy = doc.size.height - doc.docUnit.fromUser(y)
    doc.put(f2s(cpxx)," ",f2s(cpyy)," ",f2s(xx)," ",f2s(yy)," v")
  doc.path_end_x = x
  doc.path_end_y = y

proc curveTo1*(doc: Document; cp, p: TPoint2d) {.inline.}= doc.curveTo1(cp.x,cp.y,p.x,p.y)

proc curveTo2*(doc: Document; cpx, cpy, x, y: float64) =
  if doc.record_shape:
    doc.shapes[doc.shapes.len - 1].addQuadraticCurve(doc.path_end_x, doc.path_end_y, cpx,cpy, x, y)
    if x == doc.path_start_x and y == doc.path_start_y:
      doc.shapes.add(makePath())
  else:
    let cpxx = doc.docUnit.fromUser(cpx)
    let xx = doc.docUnit.fromUser(x)
    let cpyy = doc.size.height - doc.docUnit.fromUser(cpy)
    let yy = doc.size.height - doc.docUnit.fromUser(y)
    doc.put(f2s(cpxx)," ",f2s(cpyy)," ",f2s(xx)," ",f2s(yy)," y")
  doc.path_end_x = x
  doc.path_end_y = y

proc curveTo2*(doc: Document; cp, p: TPoint2d) {.inline.}= doc.curveTo2(cp.x,cp.y,p.x,p.y)
  
proc closePath*(doc: Document) =
  if doc.record_shape:
    doc.shapes[doc.shapes.len - 1].addLine(doc.path_end_x, doc.path_end_y, doc.path_start_x, doc.path_start_y)
    doc.shapes.add(makePath())
  else:
    doc.put("h")
    
  doc.path_end_x = doc.path_start_x
  doc.path_end_y = doc.path_start_y
  
proc roundRect*(doc: Document; x, y, w, h: float64; r:float64 = 0.0) =
  doc.moveTo(x + r, y)
  doc.lineTo(x + w - r, y)
  doc.curveTo1(x + w, y, x + w, y + r)
  doc.lineTo(x + w, y + h - r)
  doc.curveTo1(x + w, y + h, x + w - r, y + h)
  doc.lineTo(x + r, y + h)
  doc.curveTo1(x, y + h, x, y + h - r)
  doc.lineTo(x, y + r)
  doc.curveTo1(x, y, x + r, y)
  
proc drawEllipse*(doc: Document; x, y, r1, r2 : float64) =
  # based on http://stackoverflow.com/questions/2172798/how-to-draw-an-oval-in-html5-canvas/2173084#2173084
  let KAPPA = 4.0 * ((math.sqrt(2) - 1.0) / 3.0)
  let xx = x - r1
  let yy = y - r2
  let ox = r1 * KAPPA
  let oy = r2 * KAPPA
  let xe = xx + r1 * 2
  let ye = yy + r2 * 2
  let xm = xx + r1
  let ym = yy + r2
  
  doc.moveTo(xx, ym)
  doc.bezierCurveTo(xx, ym - oy, xm - ox, yy, xm, yy)
  doc.bezierCurveTo(xm + ox, yy, xe, ym - oy, xe, ym)
  doc.bezierCurveTo(xe, ym + oy, xm + ox, ye, xm, ye)
  doc.bezierCurveTo(xm - ox, ye, xx, ym + oy, xx, ym)
  #doc.closePath()

proc drawCircle*(doc: Document; x, y, radius : float64) =
  doc.drawEllipse(x,y,radius,radius)

proc setLineWidth*(doc: Document, line_width: float64) =
  let lw = doc.docUnit.fromUser(line_width)
  if line_width != doc.gstate.line_width: doc.put(f2s(lw), " w")
  doc.gstate.line_width = line_width

proc setLineCap*(doc: Document, line_cap: LineCap) =
  let lc = cast[int](line_cap)
  if line_cap != doc.gstate.line_cap: doc.put($lc, " J")
  doc.gstate.line_cap = line_cap

proc setLineJoin*(doc: Document, line_join: LineJoin) =
  let lj = cast[int](line_join)
  if doc.gstate.line_join != line_join: doc.put($lj, " j")
  doc.gstate.line_join = line_join

proc setMiterLimit*(doc: Document, miter_limit: float64) =
  let ml = doc.docUnit.fromUser(miter_limit)
  if doc.gstate.miter_limit != miter_limit: doc.put(f2s(ml), " M")
  doc.gstate.miter_limit = miter_limit

proc setGrayFill*(doc: Document; g:float64) =
  doc.put(f2s(g), " g")
  doc.gstate.gray_fill = g
  doc.gstate.cs_fill = CS_DEVICE_GRAY
  doc.shapes = nil
  doc.record_shape = false

proc setGrayStroke*(doc: Document; g:float64) =
  doc.put(f2s(g), " G")    
  doc.gstate.gray_stroke = g
  doc.gstate.cs_stroke = CS_DEVICE_GRAY
  
proc setRGBFill*(doc: Document; r,g,b:float64) =
  doc.put(f2s(r), " ",f2s(g), " ",f2s(b), " rg")
  doc.gstate.rgb_fill = makeRGB(r,g,b)
  doc.gstate.cs_fill = CS_DEVICE_RGB
  doc.shapes = nil
  doc.record_shape = false

proc setRGBStroke*(doc: Document; r,g,b:float64) =
  doc.put(f2s(r), " ",f2s(g), " ",f2s(b), " RG")    
  doc.gstate.rgb_stroke = makeRGB(r,g,b)
  doc.gstate.cs_stroke = CS_DEVICE_RGB

proc setRGBFill*(doc: Document; col: RGBColor) =
  doc.setRGBFill(col.r,col.g,col.b)
  
proc setRGBStroke*(doc: Document; col: RGBColor) =
  doc.setRGBStroke(col.r,col.g,col.b)

proc setCMYKFill*(doc: Document; c,m,y,k:float64) =
  doc.put(f2s(c), " ",f2s(m), " ",f2s(y), " ",f2s(k), " k")
  doc.gstate.cmyk_fill = makeCMYK(c,m,y,k)
  doc.gstate.cs_fill = CS_DEVICE_CMYK
  doc.shapes = nil
  doc.record_shape = false

proc setCMYKStroke*(doc: Document; c,m,y,k:float64) =
  doc.put(f2s(c), " ",f2s(m), " ",f2s(y), " ",f2s(k), " K")
  doc.gstate.cmyk_fill = makeCMYK(c,m,y,k)
  doc.gstate.cs_fill = CS_DEVICE_CMYK

proc setCMYKFill*(doc: Document; col: CMYKColor) =
  doc.setCMYKFill(col.c,col.m,col.y,col.k)

proc setCMYKStroke*(doc: Document; col: CMYKColor) =
  doc.setCMYKStroke(col.c,col.m,col.y,col.k)
  
proc setAlpha*(doc: Document, a: float64) =
  let id = doc.extGStates.len() + 1
  var gs : ExtGState
  gs.init(id, a, a)
  doc.extGStates.add(gs)
  doc.put("/GS",$id," gs")
  doc.gstate.alpha_fill = a
  doc.gstate.alpha_stroke = a

proc setBlendMode*(doc: Document, bm: BlendMode) =
  let id = doc.extGStates.len() + 1
  var gs : ExtGState
  var bmid = cast[int](bm)
  gs.init(id, -1.0, -1.0, BM_NAMES[bmid])
  doc.extGStates.add(gs)
  doc.put("/GS",$id," gs")
  doc.gstate.blend_mode = bm

proc saveState*(doc: Document) =
  doc.gstate = newGState(doc.gstate)
  doc.put("q")

proc restoreState*(doc: Document) =
  doc.gstate = freeGState(doc.gstate)
  doc.put("Q")

proc getTextWidth*(doc: Document, text:string): float64 =
  var res = 0.0
  let tw = doc.gstate.font.GetTextWidth(text)
  
  res += doc.gstate.word_space * float64(tw.numspace)
  res += float64(tw.width) * doc.gstate.font_size / 1000
  res += doc.gstate.char_space * float64(tw.numchars)

  result = doc.docUnit.toUser(res)

proc getTextHeight*(doc: Document, text:string): float64 =
  var res = 0.0
  let tw = doc.gstate.font.GetTextHeight(text)
  
  res += doc.gstate.word_space * float64(tw.numspace)
  res += float64(tw.width) * doc.gstate.font_size / 1000
  res += doc.gstate.char_space * float64(tw.numchars)

  result = doc.docUnit.toUser(res)
  
proc setDash*(doc: Document, dash:openArray[int], phase:int) =
  var ptn = "["
  var num_ptn = 0

  for i in 0..high(dash):
    if dash[i] == 0 or i > MAX_DASH_PATTERN: break
    ptn.add($dash[i])
    ptn.add(" ")
    inc(num_ptn)
    
  ptn.add("] " & $phase & " d")
  doc.put(ptn)
  
  doc.gstate.dash.num_ptn = num_ptn
  doc.gstate.dash.phase = phase

  for i in 0..num_ptn-1:
    doc.gstate.dash.ptn[i] = dash[i]
    
proc clip*(doc: Document) =
  doc.put("W")

proc executePath*(doc: Document, p: Path) =
  let len = p.len()
  var i = 0
  doc.moveTo(p[i+1], p[i+2])
  while i < len:
    let op = p[i]
    if op == straight_line:
      doc.lineTo(p[i+3], p[i+4])
      inc(i, 5)
    if op == rectangle:
      doc.drawRect(p[i+1], p[i+2], p[i+3]-p[i+1], p[i+4]-p[i+2])
      inc(i, 5)
    if op == quadratic_curve:
      doc.curveTo1(p[i+3],p[i+4],p[i+5],p[i+6])
      inc(i, 7)
    if op == cubic_curve:
      doc.bezierCurveTo(p[i+3],p[i+4],p[i+5],p[i+6],p[i+7],p[i+8])
      inc(i, 9)

proc drawBounds*(doc: Document, p: Path) =
  let len = p.len
  var i = 0
  while i < len:
    let op = p[i]
    if op == straight_line or op == rectangle:
      doc.drawRect(p[i+1], p[i+2], p[i+3]-p[i+1], p[i+4]-p[i+2])
      inc(i, 5)
    if op == quadratic_curve:
      let bb = quadraticCurveBounds(p[i+1],p[i+2],p[i+3],p[i+4],p[i+5],p[i+6])
      doc.drawRect(bb.xmin, bb.ymin, bb.xmax-bb.xmin, bb.ymax-bb.ymin)
      doc.put("S")
      inc(i, 7)
    if op == cubic_curve:
      let bb = cubicCurveBounds(p[i+1],p[i+2],p[i+3],p[i+4],p[i+5],p[i+6],p[i+7],p[i+8])
      doc.drawRect(bb.xmin, bb.ymin, bb.xmax-bb.xmin, bb.ymax-bb.ymin)
      doc.put("S")
      inc(i, 9)

proc drawBounds*(doc: Document) =
  if doc.record_shape:
    doc.record_shape = false
    for p in doc.shapes:
      if p.len > 0: doc.drawBounds(p)
    doc.record_shape = true
    
proc applyGradient(doc: Document) =
  for p in doc.shapes:
    if p.len > 0 and p.isClosed():
      doc.put("q")
      doc.executePath(p)
      doc.put("W n") #set gradient clipping area
      let bb = calculateBounds(p)
      let xx = doc.docUnit.fromUser(bb.xmin)
      let yy = doc.size.height - doc.docUnit.fromUser(bb.ymin + bb.ymax - bb.ymin)
      let ww = doc.docUnit.fromUser(bb.xmax - bb.xmin)
      let hh = doc.docUnit.fromUser(bb.ymax - bb.ymin)
      #set up transformation matrix for gradient
      doc.put(f2s(ww)," 0 0 ", f2s(hh), " ", f2s(xx), " ", f2s(yy), " cm")
      doc.put("/Sh",$doc.gstate.gradient_fill.ID," sh") #paint the gradient
      doc.put("Q")
  
proc fill*(doc: Document) =
  if doc.record_shape:
    doc.record_shape = false
    if doc.gstate.cs_fill == CS_GRADIENT: doc.applyGradient()
    doc.shapes = @[]
    doc.shapes.add(makePath())
    doc.record_shape = true
  else:
    doc.put("f")

proc stroke*(doc: Document) =
  if doc.record_shape:
    doc.record_shape = false
    for p in doc.shapes:
      if p.len > 0:
        doc.executePath(p)
        doc.put("S")
    doc.record_shape = true
  else:
    doc.put("S")
  
proc fillAndStroke*(doc: Document) =
  if doc.record_shape:
    doc.record_shape = false
    if doc.gstate.cs_fill == CS_GRADIENT: doc.applyGradient()
    doc.record_shape = true
    doc.stroke()
  else:
    doc.put("B")
  
proc setGradientFill*(doc: Document, grad: Gradient) =
  let size = doc.gradients.len()
  var found = false
  if grad == nil: return
  
  for gradient in items(doc.gradients):
    if gradient == grad:
      found = true
      break
  if not found:
    grad.ID = size + 1
    doc.gradients.add(grad)
    
  doc.shapes = @[]
  doc.shapes.add(makePath())
  doc.record_shape = true
  doc.gstate.cs_fill = CS_GRADIENT
  doc.gstate.gradient_fill = grad

proc makeXYZDest*(doc: Document, page: Page, x,y,z: float64): Destination =
  new(result)
  result.style = DS_XYZ
  result.page  = page
  result.a = doc.docUnit.fromUser(x)
  result.b = doc.size.height - doc.docUnit.fromUser(y)
  result.c = z

proc makeFitDest*(doc: Document, page: Page): Destination =     
  new(result)
  result.style = DS_FIT
  result.page  = page
  
proc makeFitHDest*(doc: Document, page: Page, top: float64): Destination =
  new(result)
  result.style = DS_FITH
  result.page  = page
  result.a = doc.size.height - doc.docUnit.fromUser(top)
  
proc makeFitVDest*(doc: Document, page: Page, left: float64): Destination =
  new(result)
  result.style = DS_FITV
  result.page  = page
  result.a = doc.docUnit.fromUser(left)
  
proc makeFitRDest*(doc: Document, page: Page, left,bottom,right,top: float64): Destination =
  new(result)
  result.style = DS_FITR
  result.page  = page
  result.a = doc.docUnit.fromUser(left)
  result.b = doc.size.height - doc.docUnit.fromUser(bottom)
  result.c = doc.docUnit.fromUser(right)
  result.d = doc.size.height - doc.docUnit.fromUser(top)
  
proc makeFitBDest*(doc: Document, page: Page): Destination =
  new(result)
  result.style = DS_FITB
  result.page  = page

proc makeFitBHDest*(doc: Document, page: Page, top: float64): Destination =
  new(result)
  result.style = DS_FITBH
  result.page  = page
  result.a = doc.size.height - doc.docUnit.fromUser(top)

proc makeFitBVDest*(doc: Document, page: Page, left: float64): Destination =
  new(result)
  result.style = DS_FITBV
  result.page  = page
  result.a = left
    
proc makeOutline*(doc: Document, title: string, dest: Destination): Outline =
  new(result)
  result.kids = @[]
  result.dest = dest
  result.title = title
  doc.outlines.add(result)

proc makeOutline*(ot: Outline, title: string, dest: Destination): Outline =
  new(result)
  result.kids = @[]
  result.dest = dest
  result.title = title
  ot.kids.add(result)

proc initRect*(x,y,w,h: float64): Rectangle =
  result.x = x
  result.y = y
  result.w = w
  result.h = h
  
proc linkAnnot*(doc: Document, rect: Rectangle, src: Page, dest: Destination): Annot =
  new(result)
  let xx = doc.docUnit.fromUser(rect.x)
  let yy = doc.size.height - doc.docUnit.fromUser(rect.y)
  let ww = doc.docUnit.fromUser(rect.x + rect.w)
  let hh = doc.size.height - doc.docUnit.fromUser(rect.y + rect.h)
  result.annotType = ANNOT_LINK
  result.rect = initRect(xx,yy,ww,hh)
  result.dest = dest
  src.annots.add(result)

proc textAnnot*(doc: Document, rect: Rectangle, src: Page, content: string): Annot =
  new(result)
  let xx = doc.docUnit.fromUser(rect.x)
  let yy = doc.size.height - doc.docUnit.fromUser(rect.y)
  let ww = doc.docUnit.fromUser(rect.x + rect.w)
  let hh = doc.size.height - doc.docUnit.fromUser(rect.y + rect.h)
  result.annotType = ANNOT_TEXT
  result.rect = initRect(xx,yy,ww,hh)
  result.content = content
  src.annots.add(result)
