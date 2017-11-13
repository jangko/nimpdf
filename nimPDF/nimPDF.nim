# Copyright (c) 2015 Andri Lim
#
# Distributed under the MIT license
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------
# the main module for nimPDF, import this one from your project

import strutils, streams, sequtils, times, math, basic2d, algorithm, tables
import image, wtf8, "subsetter/Font", gstate, path, fontmanager, unicode
import objects, resources, encryptdict, encrypt, os

export encryptdict.DocInfo, encrypt.encryptMode
export path, gstate, image, fontmanager

const
  nimPDFVersion = "0.3.0"
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
    ,("Foolscap",210.0,330.0),("Folio[9]",210.0,330.0),("Organizer M",216.0,279.0),("Fanfold",216.0,304.0)
    ,("German Std Fanfold",216.0,304.0),("Government-Legal",216.0,330.0),("Folio",216.0,330.0),("Quarto",229.0,279.0)
    ,("US Std Fanfold",279.0,377.0),("Organizer K",279.0,432.0),("Bible",279.0,432.0)
    ,("Super-B",330.0,483.0),("Post",394.0,489.0),("Crown",381.0,508.0),("Large Post",419.0,533.0),("Demy",445.0,572.0),("Medium",457.0,584.0)
    ,("Broadsheet",457.0,610.0),("Royal",508.0,635.0),("Elephant",584.0,711.0),("REAL Demy",572.0,889.0),("Quad Demy",889.0,1143.0)]

  MAX_DASH_PATTERN = 8
  LABEL_STYLE_CH = ["D", "R", "r", "A", "a"]
  INFO_FIELD = ["Creator", "Producer", "Title", "Subject", "Author", "Keywords"]

type
  LabelStyle* = enum
    LS_DECIMAL, LS_UPPER_ROMAN, LS_LOWER_ROMAN, LS_UPPER_LETTER, LS_LOWER_LETTER

  PageOrientationType* = enum
    PGO_PORTRAIT, PGO_LANDSCAPE

  CoordinateMode* = enum
    TOP_DOWN, BOTTOM_UP
    
  PageSize* = object
    width*, height*: SizeUnit

  Rectangle* = object
    x,y,w,h: float64

  AnnotType = enum
    ANNOT_LINK, ANNOT_TEXT, ANNOT_WIDGET

  Annot* = ref object
    rect: Rectangle
    case annotType: AnnotType
    of ANNOT_LINK:
      dest: Destination
    of ANNOT_TEXT:
      content: string
    of ANNOT_WIDGET:
      annot: dictObj

  Page* = ref object
    content: string
    size: PageSize
    annots: seq[Annot]
    page: dictObj

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

  Destination* = ref object
    style: DestStyle
    a,b,c,d: float64
    page: Page

  Outline* = ref object of dictObj
    kids: seq[Outline]
    dest: Destination
    title: string

  AcroForm* = ref object
    r,g,b:float64
    fontSize:float64
    fontFamily: string
    fontStyle: FontStyles
    encoding: EncodingType
    fields: seq[Annot]
    
  Document* = ref object of RootObj
    pages: seq[Page]
    docUnit: PageUnit
    size: PageSize
    extGStates: seq[ExtGState]
    images: seq[Image]
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
    xref: pdfXref
    encrypt: encryptDict
    acroForm: AcroForm
    coordinateMode: CoordinateMode

  NamedPageSize = tuple[name: string, width: float64, height: float64]

proc init(gs: var ExtGState; id: int; sA, nsA: float64, bm: string = "Normal") =
  gs.ID = id
  gs.strokingAlpha = sA
  gs.nonstrokingAlpha = nsA
  gs.blendMode = bm

proc swap(this: var PageSize) = swap(this.width, this.height)

proc searchPageSize(x: openArray[NamedPageSize], y: string, z: var PageSize): bool =
  for t in items(x):
    if t.name == y:
      z.width = fromMM(t.width)
      z.height = fromMM(t.height)
      return true
  result = false

proc getSizeFromName*(name: string): PageSize =
  if not searchPageSize(PageNames, name, result):
    result.width  = fromMM(210)
    result.height = fromMM(297)

proc makePageSize*(w, h: SizeUnit): PageSize =
  result.width = w
  result.height = h
  
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
  for s in items(text): p.content.add(s)
  p.content.add('\x0A')

proc put(doc: Document, text: varargs[string]) =
  let p = doc.pages.high()
  doc.pages[p].put(text)

template f2s(a: typed): untyped =
  formatFloat(a,ffDecimal,4)

proc f2sn(a: float64): string =
  if a == 0: "null" else: f2s(a)

proc putDestination(doc: Document, dict: dictObj, dest: Destination) =
  var arr = arrayObjNew()
  dict.addElement("Dest", arr)
  arr.add(dest.page.page)

  case dest.style
  of DS_XYZ:
    arr.addName("XYZ")
    arr.addPlain(f2sn(dest.a))
    arr.addPlain(f2sn(dest.b))
    arr.addPlain(f2sn(dest.c))
  of DS_FIT: arr.addName("Fit")
  of DS_FITH:
    arr.addName("FitH")
    arr.addPlain(f2sn(dest.a))
  of DS_FITV:
    arr.addName("FitV")
    arr.addPlain(f2sn(dest.a) & "]")
  of DS_FITR:
    arr.addName("FitR")
    arr.addPlain(f2s(dest.a))
    arr.addPlain(f2s(dest.b))
    arr.addPlain(f2s(dest.c))
    arr.addPlain(f2s(dest.d))
  of DS_FITB: arr.addName("FitB")
  of DS_FITBH:
    arr.addName("FitBH")
    arr.addPlain(f2sn(dest.a))
  of DS_FITBV:
    arr.addName("FitBV")
    arr.addPlain(f2sn(dest.a))

proc putPages(doc: Document, resource: dictObj): dictObj =
  let numpages = doc.pages.len()

  var kids = arrayObjNew()
  var root = dictObjNew()
  doc.xref.add(root)
  root.addName("Type", "Pages")
  root.addNumber("Count", numpages)
  root.addElement("Kids", kids)

  for p in doc.pages:
    let content = doc.xref.dictStreamNew(p.content)
    var page = dictObjNew()
    p.page = page
    doc.xref.add(page)
    kids.add(page)
    page.addName("Type", "Page")
    page.addElement("Parent", root)
    page.addElement("Resources", resource)
    page.addElement("Contents", content)

    #Output the page size.
    var box = arrayNew(0.0,0.0, p.size.width.toPT, p.size.height.toPT)
    page.addElement("MediaBox", box)

  #the page.page must be initialized first to prevent crash
  var i = 1
  for p in doc.pages:
    if p.annots.len == 0: continue
    var annots = arrayObjNew()
    p.page.addElement("Annots", annots)
    for a in p.annots:
      var annot = dictObjNew()
      doc.xref.add(annot)
      annots.add(annot)
      annot.addName("Type", "Annot")
      if a.annotType == ANNOT_LINK:
        annot.addName("Subtype", "Link")
        doc.putDestination(annot, a.dest)
      elif a.annotType == ANNOT_WIDGET:
        annot.addName("Subtype", "Widget")
        annot.addName("FT", "Tx")
        annot.addString("T", "Text" & $i) #unique label
        a.annot = annot
      else:
        annot.addName("Subtype", "Text")
        annot.addString("Contents", a.content)
      annot.addElement("Rect", arrayNew(a.rect.x, a.rect.y, a.rect.w, a.rect.h))
      annot.addElement("Border", arrayNew(16, 16, 1))
      annot.addPlain("BS", "<</W 0>>")
      inc i
  result = root

proc putResources(doc: Document): dictObj =
  let grads = putGradients(doc.xref, doc.gradients)
  let exts  = putExtGStates(doc.xref, doc.extGStates)
  let imgs  = putImages(doc.xref, doc.images)
  let fonts = putFonts(doc.xref, doc.fontMan.FontList)

  result = dictObjNew()
  doc.xref.add(result)

  #doc.put("<</ProcSet [/PDF /Text /ImageB /ImageC /ImageI]")
  if fonts != nil: result.addElement("Font", fonts)
  if exts != nil: result.addElement("ExtGState", exts)
  if imgs != nil: result.addElement("XObject", imgs)
  if grads != nil: result.addElement("Shading", grads)

proc writeInfo(doc: Document, dict: dictObj, field: DocInfo) =
  var idx = int(field)
  if doc.info.hasKey(idx):
    dict.addString(INFO_FIELD[idx], doc.info[idx])

proc putInfo(doc: Document): dictObj =
  var dict = dictObjNew()
  doc.xref.add(dict)

  var lt = getLocalTime(getTime())
  doc.writeInfo(dict, DI_CREATOR)
  doc.writeInfo(dict, DI_PRODUCER)
  doc.writeInfo(dict, DI_TITLE)
  doc.writeInfo(dict, DI_SUBJECT)
  doc.writeInfo(dict, DI_KEYWORDS)
  doc.writeInfo(dict, DI_AUTHOR)
  dict.addString("CreationDate", "D:" & lt.format("yyyyMMddHHmmss"))
  result = dict

proc putLabels(doc: Document): dictObj =
  if doc.labels.len == 0: return nil

  var labels = dictObjNew()
  doc.xref.add(labels)
  var nums = arrayObjNew()
  labels.addElement("Nums", nums)

  for label in doc.labels:
    var dict = dictObjNew()
    nums.addNumber(label.pageIndex)
    nums.add(dict)
    dict.addName("S", LABEL_STYLE_CH[int(label.style)])
    if label.prefix != nil:
      if label.prefix.len > 0: dict.addString("P", label.prefix)
    if label.start > 0: dict.addNumber("St", label.start)

  result = labels

proc putOutlineItem(doc: Document, outlines: seq[Outline], parent: dictObj, root: Outline, i: int) =
  for kid in root.kids:
    doc.xref.add(kid)

  root.addString("Title", root.title)
  root.addElement("Parent", parent)
  root.addNumber("Count", 0)

  if outlines.len == 2:
    if i == 0: root.addElement("Next", outlines[1])
    if i == 1: root.addElement("Prev", outlines[0])
  elif outlines.len > 2:
    let lastIdx = outlines.len - 1
    if i == 0: root.addElement("Next", outlines[1])
    if i == lastIdx: root.addElement("Prev", outlines[lastIdx-1])
    if i > 0 and i < lastIdx:
      root.addElement("Next", outlines[i+1])
      root.addElement("Prev", outlines[i-1])

  doc.putDestination(root, root.dest)

  if root.kids.len > 0:
    let firstKid = root.kids[0]
    let lastKid = root.kids[root.kids.high]
    root.addElement("First", firstKid)
    root.addElement("Last", lastKid)

  var i = 0
  for kid in root.kids:
    doc.putOutlineItem(root.kids, root, kid, i)
    inc(i)

proc putOutlines(doc: Document): dictObj =
  if doc.outlines.len == 0: return nil

  for ot in doc.outlines:
    doc.xref.add(ot)

  var root = dictObjNew()
  doc.xref.add(root)

  let firstKid = doc.outlines[0]
  let lastKid = doc.outlines[doc.outlines.high]
  root.addName("Type", "Outlines")
  root.addElement("First", firstKid)
  root.addElement("Last", lastKid)

  var i = 0
  for ot in doc.outlines:
    doc.putOutlineItem(doc.outlines, root, ot, i)
    inc i

  result = root

proc putCatalog(doc: Document) =
  var catalog = dictObjNew()
  doc.xref.add(catalog)
  catalog.addName("Type", "Catalog")
  
  var font: Font
  if doc.acroForm != nil:
    #set acroform default appearance
    font = doc.fontMan.makeFont(doc.acroForm.fontFamily, doc.acroForm.fontStyle, doc.acroForm.encoding)
  
  let resource = doc.putResources()
  let pageRoot = doc.putPages(resource)
  #let firstPageID = pageRootID + 1

  if doc.acroForm != nil:
    let fontSize = doc.docunit.fromUser(doc.acroForm.fontSize)
    var acro = dictObjNew()
    doc.xref.add(acro)
    var fields = arrayObjNew()
    for a in doc.acroForm.fields:
      fields.add a.annot
    catalog.addElement("AcroForm", acro)
    acro.addElement("DR", resource)
    let fontColor = "(" & f2s(doc.acroForm.r) & " " & f2s(doc.acroForm.g) & " " & f2s(doc.acroForm.b) & " rg /F"
    let fontID = $font.ID & " " & f2s(fontSize) & " Tf)"
    acro.addPlain("DA", fontColor & fontID)
    acro.addElement("Fields", fields)
    
  let info = doc.putInfo()
  let labels = doc.putLabels()
  let outlines = doc.putOutlines()

  catalog.addElement("Pages", pageRoot)
  
  if labels != nil: catalog.addElement("PageLabels", labels)
  if outlines != nil: catalog.addElement("Outlines", outlines)
  #doc.put("/OpenAction [",$firstPageID," 0 R /FitH null]")
  #doc.put("/PageLayout /OneColumn")

  var trailer = doc.xref.getTrailer()
  trailer.addElement("Root", catalog)
  trailer.addElement("Info", info)
  if doc.encrypt != nil:
    doc.encrypt.prepare(doc.info, doc.xref)

    var id = arrayObj(trailer.getItem("ID", CLASS_ARRAY))
    if id == nil:
      id = arrayObjNew()
      trailer.addElement("ID", id)
    else:
      id.clear()

    var enc = doc.encrypt.enc
    var encrypt_id = newString(enc.encrypt_id.len)
    for i in 0..enc.encrypt_id.high: encrypt_id[i] = chr(enc.encrypt_id[i])
    id.addBinary(encrypt_id)
    id.addBinary(encrypt_id)

    trailer.addElement("Encrypt", doc.encrypt)

proc setInfo*(doc: Document, field: DocInfo, info: string) =
  doc.info[int(field)] = info

proc initPDF*(opts: DocOpt): Document =
  new(result)
  result.pages = @[]
  result.extGStates = @[]
  result.images = @[]
  result.gradients = @[]
  result.coordinateMode = TOP_DOWN
  result.docUnit.setUnit(PGU_MM)
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
  result.xref = xrefNew()
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

proc clearFontsPath*(opt: DocOpt) =
  opt.fontsPath.setLen(0)
  
proc clearImagesPath*(opt: DocOpt) =
  opt.imagesPath.setLen(0)

proc clearResourcesPath*(opt: DocOpt) =
  opt.resourcesPath.setLen(0)
  
proc clearAllPath*(opt: DocOpt) =
  opt.clearFontsPath()
  opt.clearImagesPath()
  opt.clearResourcesPath()

proc getOpt*(doc: Document): DocOpt =
  result = doc.opts

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

proc loadImage*(doc: Document, fileName: string): Image =
  for p in doc.opts.imagesPath:
    let image = loadImage(p & DirSep & fileName)
    if image != nil: return image
  result = nil

proc getVersion*(): string =
  result = nimPDFVersion

proc getVersion*(doc: Document): string =
  result = nimPDFVersion

proc setUnit*(doc: Document, unit: PageUnitType) =
  doc.docUnit.setUnit(unit)

proc getUnit*(doc: Document): PageUnitType =
  result = doc.docUnit.unitType
  
proc setCoordinateMode*(doc: Document, mode: CoordinateMode) =
  doc.coordinateMode = mode
  
proc getCoordinateMode*(doc: Document): CoordinateMode =
  result = doc.coordinateMode
  
proc vPoint(doc: Document, val: float64): float64 =
  if doc.coordinateMode == TOP_DOWN:
    result = doc.size.height.toPT - doc.docUnit.fromUser(val)
  else:
    result = doc.docUnit.fromUser(val)

proc vPointMirror(doc: Document, val: float64): float64 =
  if doc.coordinateMode == TOP_DOWN:
    result = doc.docUnit.fromUser(-val)
  else:
    result = doc.docUnit.fromUser(val)
    
proc getSize*(doc: Document): PageSize = doc.size

proc setFont*(doc: Document, family:string, style: FontStyles, size: float64, enc: EncodingType = ENC_STANDARD) =
  var font = doc.fontMan.makeFont(family, style, enc)
  let fontNumber = font.ID
  let fontSize = doc.docUnit.fromUser(size)
  doc.put("BT /F",$fontNumber," ",$fontSize," Tf ET")
  doc.gstate.font = font
  doc.gstate.font_size = fontSize
  inc(doc.setFontCall)

proc addPage*(doc: Document, size: PageSize, orient = PGO_PORTRAIT): Page {.discardable.} =
  var p : Page
  new(p)
  p.size.width = size.width
  p.size.height = size.height
  p.content = ""
  p.annots = @[]
  if orient == PGO_LANDSCAPE:
    p.size.swap()
  doc.pages.add(p)
  doc.size = p.size
  doc.setFontCall = 0
  result = p

proc writePDF*(doc: Document, s: Stream) =
  doc.putCatalog()
  #s.write(doc.content)
  s.write("%PDF-1.7\x0A")
  var enc = pdfEncrypt(nil)
  if doc.encrypt != nil: enc = doc.encrypt.enc
  doc.xref.writeToStream(s, enc)

proc writePDF*(doc: Document, fileName: string): bool =
  result = false
  var file = newFileStream(fileName, fmWrite)
  if file != nil:
    doc.writePDF(file)
    file.close()
    result = true

proc drawText*(doc: Document; x,y: float64; text: string) =
  let xx = doc.docUnit.fromUser(x)
  let yy = doc.vPoint(y)

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
  var yy = doc.vPoint(y)
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
  let yy = doc.vPoint(y)
  doc.put("BT ", f2s(xx)," ",f2s(yy)," Td")

proc moveTextPos*(doc: Document; x,y: float64) =
  let xx = doc.docUnit.fromUser(x)
  let yy = doc.vPointMirror(y)
  doc.put(f2s(xx)," ",f2s(yy)," Td")

proc setTextRenderingMode*(doc: Document, rm: TextRenderingMode) =
  let trm = cast[int](rm)
  if doc.gstate.rendering_mode != rm: doc.put($trm, " Tr")
  doc.gstate.rendering_mode = rm

proc setTextMatrix*(doc: Document, m: Matrix2d) =
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

proc degree_to_radian*(x: float): float =
  result = (x * math.PI) / 180.0
  
proc setCharSpace*(doc: Document; val: float64) =
  doc.put(f2s(val)," Tc")
  doc.gstate.char_space = val

proc setTextHScale*(doc: Document; val: float64) =
  doc.put(f2s(val)," Th")
  doc.gstate.h_scaling = val

proc setWordSpace*(doc: Document; val: float64) =
  doc.put(f2s(val)," Tw")
  doc.gstate.word_space = val

proc setTransform*(doc: Document, m: Matrix2d) =
  doc.put(f2s(m.ax)," ", f2s(m.ay), " ", f2s(m.bx), " ", f2s(m.by), " ", f2s(m.tx)," ",f2s(m.ty)," cm")
  doc.gstate.trans_matrix = doc.gstate.trans_matrix & m

proc rotate*(doc: Document, angle:float64) =
  doc.setTransform(rotate(degree_to_radian(angle)))

proc rotate*(doc: Document, angle, x,y:float64) =
  let xx = doc.docUnit.fromUser(x)
  let yy = doc.vPoint(y)
  doc.setTransform(rotate(degree_to_radian(angle), point2d(xx, yy)))

proc move*(doc: Document, x,y:float64) =
  let xx = doc.docUnit.fromUser(x)
  let yy = doc.vPointMirror(y)
  doc.setTransform(move(xx,yy))

proc scale*(doc: Document, s:float64) =
  doc.setTransform(scale(s))

proc scale*(doc: Document, s, x,y:float64) =
  let xx = doc.docUnit.fromUser(x)
  let yy = doc.vPoint(y)
  doc.setTransform(scale(s, point2d(xx, yy)))

proc stretch*(doc: Document, sx,sy:float64) =
  doc.setTransform(stretch(sx,sy))

proc stretch*(doc: Document, sx,sy,x,y:float64) =
  let xx = doc.docUnit.fromUser(x)
  let yy = doc.vPoint(y)
  doc.setTransform(stretch(sx, sy, point2d(xx, yy)))

proc shear(sx,sy,x,y:float64): Matrix2d =
  let
    m = move(-x,-y)
    s = matrix2d(1.0,sx,sy,1.0,0.0,0.0)
  result = m & s & move(x,y)

proc skew*(doc: Document, sx,sy:float64) =
  let tsx = math.tan(degree_to_radian(sx))
  let tsy = math.tan(degree_to_radian(sy))
  doc.setTransform(matrix2d(1,tsx,tsy,1,0,0))

proc skew*(doc: Document, sx,sy,x,y:float64) =
  let xx = doc.docUnit.fromUser(x)
  let yy = doc.vPoint(y)
  let tsx = math.tan(degree_to_radian(sx))
  let tsy = math.tan(degree_to_radian(sy))
  doc.setTransform(shear(tsx, tsy, xx, yy))

proc toUser*(doc: Document, val:float64): float64 =
  result = doc.docUnit.toUser(val)

proc fromUser*(doc: Document, val:float64): float64 =
  result = doc.docUnit.fromUser(val)

proc drawImage*(doc: Document, x:float64, y:float64, source: Image) =
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

  #if img.haveMask():
    #doc.put("q")
    #
    ##embed hidden, outside canvas
    #var xx = doc.size.width.toPT + fromMM(10.0).toPT
    #var yy = doc.size.height.toPT + fromMM(10.0).toPT
    #
    #doc.put(f2s(ww)," 0 0 ",f2s(hh)," ",f2s(xx)," ",f2s(yy)," cm")
    #doc.put("/Im",$img.ID," Do")
    #doc.put("Q")

  doc.put("q")
  var xx = doc.docUnit.fromUser(x)
  var yy = doc.vPoint(y)

  doc.put(f2s(ww)," 0 0 ",f2s(hh)," ",f2s(xx)," ",f2s(yy)," cm")

  doc.put("/I",$img.ID," Do")
  doc.put("Q")

proc drawRect*(doc: Document, x: float64, y: float64, w: float64, h: float64) =
  if doc.record_shape:
    doc.shapes[doc.shapes.len - 1].addRect(x, y, w, h)
    doc.shapes.add(makePath())
  else:
    let xx = doc.docUnit.fromUser(x)
    let yy = doc.vPoint(y)
    let ww = doc.docUnit.fromUser(w)
    let hh = doc.vPointMirror(h)
    doc.put(f2s(xx)," ",f2s(yy)," ",f2s(ww)," ",f2s(hh)," re")

proc moveTo*(doc: Document, x: float64, y: float64) =
  let xx = doc.docUnit.fromUser(x)
  let yy = doc.vPoint(y)
  doc.put(f2s(xx)," ",f2s(yy)," m")
  doc.path_start_x = x
  doc.path_start_y = y
  doc.path_end_x = x
  doc.path_end_y = y

proc moveTo*(doc: Document, p: Point2d) {.inline.} = doc.moveTo(p.x, p.y)

proc lineTo*(doc: Document, x: float64, y: float64) =
  if doc.record_shape:
    doc.shapes[doc.shapes.len - 1].addLine(doc.path_start_x, doc.path_start_y, x, y)
    if x == doc.path_start_x and y == doc.path_start_y:
      doc.shapes.add(makePath())
  else:
    let xx = doc.docUnit.fromUser(x)
    let yy = doc.vPoint(y)
    doc.put(f2s(xx)," ",f2s(yy)," l")
  doc.path_end_x = x
  doc.path_end_y = y

proc lineTo*(doc: Document, p: Point2d) {.inline.} = doc.lineTo(p.x, p.y)

proc bezierCurveTo*(doc: Document; cp1x, cp1y, cp2x, cp2y, x, y: float64) =
  if doc.record_shape:
    doc.shapes[doc.shapes.len - 1].addCubicCurve(doc.path_end_x, doc.path_end_y, cp1x,cp1y, cp2x,cp2y, x, y)
    if x == doc.path_start_x and y == doc.path_start_y:
      doc.shapes.add(makePath())
  else:
    let cp1xx = doc.docUnit.fromUser(cp1x)
    let cp2xx = doc.docUnit.fromUser(cp2x)
    let xx = doc.docUnit.fromUser(x)

    let cp1yy = doc.vPoint(cp1y)
    let cp2yy = doc.vPoint(cp2y)
    let yy = doc.vPoint(y)
    doc.put(f2s(cp1xx)," ",f2s(cp1yy)," ",f2s(cp2xx)," ",f2s(cp2yy)," ",f2s(xx)," ",f2s(yy)," c")
  doc.path_end_x = x
  doc.path_end_y = y

proc bezierCurveTo*(doc: Document; cp1, cp2, p: Point2d) {.inline.}= doc.bezierCurveTo(cp1.x,cp1.y,cp2.x,cp2.y,p.x,p.y)

proc curveTo1*(doc: Document; cpx, cpy, x, y: float64) =
  if doc.record_shape:
    doc.shapes[doc.shapes.len - 1].addQuadraticCurve(doc.path_end_x, doc.path_end_y, cpx,cpy, x, y)
    if x == doc.path_start_x and y == doc.path_start_y:
      doc.shapes.add(makePath())
  else:
    let cpxx = doc.docUnit.fromUser(cpx)
    let xx = doc.docUnit.fromUser(x)
    let cpyy = doc.vPoint(cpy)
    let yy = doc.vPoint(y)
    doc.put(f2s(cpxx)," ",f2s(cpyy)," ",f2s(xx)," ",f2s(yy)," v")
  doc.path_end_x = x
  doc.path_end_y = y

proc curveTo1*(doc: Document; cp, p: Point2d) {.inline.}= doc.curveTo1(cp.x,cp.y,p.x,p.y)

proc curveTo2*(doc: Document; cpx, cpy, x, y: float64) =
  if doc.record_shape:
    doc.shapes[doc.shapes.len - 1].addQuadraticCurve(doc.path_end_x, doc.path_end_y, cpx,cpy, x, y)
    if x == doc.path_start_x and y == doc.path_start_y:
      doc.shapes.add(makePath())
  else:
    let cpxx = doc.docUnit.fromUser(cpx)
    let xx = doc.docUnit.fromUser(x)
    let cpyy = doc.vPoint(cpy)
    let yy = doc.vPoint(y)
    doc.put(f2s(cpxx)," ",f2s(cpyy)," ",f2s(xx)," ",f2s(yy)," y")
  doc.path_end_x = x
  doc.path_end_y = y

proc curveTo2*(doc: Document; cp, p: Point2d) {.inline.}= doc.curveTo2(cp.x,cp.y,p.x,p.y)

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
  let KAPPA = 4.0 * ((math.sqrt(2.0) - 1.0) / 3.0)
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
      let yy = doc.vPoint(bb.ymin + bb.ymax - bb.ymin)
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
  result.b = doc.vPoint(y)
  result.c = z

proc makeFitDest*(doc: Document, page: Page): Destination =
  new(result)
  result.style = DS_FIT
  result.page  = page

proc makeFitHDest*(doc: Document, page: Page, top: float64): Destination =
  new(result)
  result.style = DS_FITH
  result.page  = page
  result.a = doc.vPoint(top)

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
  result.b = doc.vPoint(bottom)
  result.c = doc.docUnit.fromUser(right)
  result.d = doc.vPoint(top)

proc makeFitBDest*(doc: Document, page: Page): Destination =
  new(result)
  result.style = DS_FITB
  result.page  = page

proc makeFitBHDest*(doc: Document, page: Page, top: float64): Destination =
  new(result)
  result.style = DS_FITBH
  result.page  = page
  result.a = doc.vPoint(top)

proc makeFitBVDest*(doc: Document, page: Page, left: float64): Destination =
  new(result)
  result.style = DS_FITBV
  result.page  = page
  result.a = left

proc makeOutline*(doc: Document, title: string, dest: Destination): Outline =
  new(result)
  result.class = CLASS_DICT
  result.subclass = SUBCLASS_OUTLINE
  result.value  = initTable[string, pdfObj]()
  result.filter = {}
  result.filterParams = nil
  result.kids = @[]
  result.dest = dest
  result.title = title
  doc.outlines.add(result)
  result.objID = 0

proc makeOutline*(ot: Outline, title: string, dest: Destination): Outline =
  new(result)
  result.class = CLASS_DICT
  result.subclass = SUBCLASS_OUTLINE
  result.value  = initTable[string, pdfObj]()
  result.filter = {}
  result.filterParams = nil
  result.kids = @[]
  ot.kids.add(result)
  result.dest = dest
  result.title = title
  result.objID = 0

proc initRect*(x,y,w,h: float64): Rectangle =
  result.x = x
  result.y = y
  result.w = w
  result.h = h

proc linkAnnot*(doc: Document, rect: Rectangle, src: Page, dest: Destination): Annot =
  new(result)
  let xx = doc.docUnit.fromUser(rect.x)
  let yy = doc.vPoint(rect.y)
  let ww = doc.docUnit.fromUser(rect.x + rect.w)
  let hh = doc.vPoint(rect.y + rect.h)
  result.annotType = ANNOT_LINK
  result.rect = initRect(xx,yy,ww,hh)
  result.dest = dest
  src.annots.add(result)

proc textAnnot*(doc: Document, rect: Rectangle, src: Page, content: string): Annot =
  new(result)
  let xx = doc.docUnit.fromUser(rect.x)
  let yy = doc.vPoint(rect.y)
  let ww = doc.docUnit.fromUser(rect.x + rect.w)
  let hh = doc.vPoint(rect.y + rect.h)
  result.annotType = ANNOT_TEXT
  result.rect = initRect(xx,yy,ww,hh)
  result.content = content
  src.annots.add(result)

proc setPassword*(doc: Document, ownerPass, userPass: string): bool =
  doc.encrypt = newEncryptDict()
  result = doc.encrypt.setPassword(ownerPass, userPass)
  doc.xref.add(doc.encrypt)

proc setEncryptionMode*(doc: Document, mode: encryptMode) =
  if doc.encrypt == nil: return
  var enc = doc.encrypt.enc

  if mode == ENCRYPT_R2: enc.keyLen = 5
  elif mode in {ENCRYPT_R3, ENCRYPT_R4_ARC4, ENCRYPT_R4_AES}: enc.keyLen = 16
  else: enc.keyLen = 32 # ENCRYPT_R5
  enc.mode = mode

proc initAcroForm*(doc: Document): AcroForm =
  if doc.acroForm != nil: return doc.acroForm
  new(result)
  result.r = 0.0
  result.g = 0.0
  result.b = 0.0
  result.fontSize = doc.docunit.toUser(12)
  result.fontFamily = "Helvetica"
  result.fontStyle = {FS_REGULAR}
  result.encoding = ENC_STANDARD
  result.fields = @[]
  doc.acroForm = result

proc setFontColor*(a: AcroForm, r,g,b: float64) =
  a.r = r
  a.g = r
  a.b = r
  
proc setFontColor*(a: AcroForm, col: RGBColor) =
  a.setFontColor(col.r,col.g,col.b)
  
proc setFontSize*(a: AcroForm, size: float64) =
  a.fontSize = size
  
proc setFontFamily*(a: AcroForm, family: string) =
  a.fontFamily = family
  
proc setFontStyle*(a: AcroForm, style: FontStyles) =
  a.fontStyle = style

proc setEncoding*(a: AcroForm, enc: EncodingType) =
  a.encoding = enc
  
proc textField*(doc: Document, rect: Rectangle, src: Page): Annot =
  var acro = doc.initAcroForm()
  new(result)
  let xx = doc.docUnit.fromUser(rect.x)
  let yy = doc.vPoint(rect.y)
  let ww = doc.docUnit.fromUser(rect.x + rect.w)
  let hh = doc.vPoint(rect.y + rect.h)
  result.annotType = ANNOT_WIDGET
  result.rect = initRect(xx,yy,ww,hh)
  src.annots.add(result)
  acro.fields.add(result)
  
include arc
