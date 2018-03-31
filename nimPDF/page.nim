import strutils, gState, objects, fontmanager, image, path
import tables, encryptdict, os, resources, times, "subsetter/Font"
import streams, encryptdict, encrypt, options, wtf8, unicode
import basic2d, math

const
  INFO_FIELD = ["Creator", "Producer", "Title", "Subject", "Author", "Keywords"]
  MAX_DASH_PATTERN = 8
  LABEL_STYLE_CH = ["D", "R", "r", "A", "a"]
  defaultFont = "Times"

type
  LabelStyle* = enum
    LS_DECIMAL, LS_UPPER_ROMAN, LS_LOWER_ROMAN, LS_UPPER_LETTER, LS_LOWER_LETTER

  PageOrientationType* = enum
    PGO_PORTRAIT, PGO_LANDSCAPE

  PageSize* = object
    width*, height*: SizeUnit

  Rectangle* = object
    x*,y*,w*,h*: float64

  AnnotType = enum
    ANNOT_LINK, ANNOT_TEXT

  Annot* = ref object
    rect: Rectangle
    case annotType: AnnotType
    of ANNOT_LINK:
      dest: Destination
    of ANNOT_TEXT:
      content: string

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

  Outline* = ref object of DictObj
    kids: seq[Outline]
    dest: Destination
    title: string

  AcroForm* = ref object
    r,g,b:float64
    fontSize:float64
    fontFamily: string
    fontStyle: FontStyles
    encoding: EncodingType

  DocState* = ref object
    size: PageSize
    ExtGStates: seq[ExtGState]
    images: seq[Image]
    gradients: seq[Gradient]
    fontMan: FontManager
    gState: GState
    pathStartX, pathStartY, pathEndX, pathEndY: float64
    recordShape: bool
    shapes: seq[Path]
    info: Table[int, string]
    opts: PDFOptions
    labels: seq[PageLabel]
    setFontCount: int
    outlines: seq[Outline]
    xref: Pdfxref
    encrypt: EncryptDict
    acroForm: AcroForm

  DictBase = ref object of RootObj
    dictObj*: DictObj

  StateBase* = ref object of DictBase
    state*: DocState

  WidgetBase* = ref object of StateBase

  ContentBase* = ref object of StateBase
    content: string

  AppearanceStream* = ref object of ContentBase

  Page* = ref object of ContentBase
    size: PageSize
    annots: seq[Annot]
    widgets: seq[WidgetBase]

method createObject*(self: WidgetBase): PdfObject {.base.} = discard
method finalizeObject*(self: WidgetBase; page, parent, resourceDict: DictObj) {.base.} = discard
method needCalculateOrder*(self: WidgetBase): bool {.base.} = discard

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

template f2s*(a: typed): untyped =
  formatFloat(a,ffDecimal,4)

proc f2sn(a: float64): string =
  if a == 0: "null" else: f2s(a)

template fromUser*(doc: DocState, val: float64): float64 =
  doc.gState.docUnit.fromUser(val)

template toUser*(doc: DocState, val:float64): float64 =
  doc.gState.docUnit.toUser(val)

proc toObject*(dest: Destination): ArrayObj =
  var arr = newArrayObj()
  arr.add(dest.page.dictObj)

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

  result = arr

proc putDestination(dict: DictObj, dest: Destination) =
  var arr = toObject(dest)
  dict.addElement("Dest", arr)

proc putPages(doc: DocState, resource: DictObj, pages: seq[Page]): DictObj =
  let numpages = pages.len()

  var kids = newArrayObj()
  var root = newDictObj()
  doc.xref.add(root)
  root.addName("Type", "Pages")
  root.addNumber("Count", numpages)
  root.addElement("Kids", kids)

  for p in pages:
    let content = doc.xref.newDictStream(p.content)
    var page = p.dictObj
    kids.add(page)
    page.addName("Type", "Page")
    page.addElement("Parent", root)
    page.addElement("Resources", resource)
    page.addElement("Contents", content)

    #Output the page size.
    var box = newArray(0.0,0.0, p.size.width.toPT, p.size.height.toPT)
    page.addElement("MediaBox", box)

  #the page.page must be initialized first to prevent crash
  var i = 1
  for p in pages:
    if p.annots.len == 0 and p.widgets.len == 0: continue
    var annots = newArrayObj()
    p.dictObj.addElement("Annots", annots)
    for a in p.annots:
      var annot = newDictObj()
      doc.xref.add(annot)
      annots.add(annot)
      annot.addName("Type", "Annot")
      if a.annotType == ANNOT_LINK:
        annot.addName("Subtype", "Link")
        putDestination(annot, a.dest)
      else:
        annot.addName("Subtype", "Text")
        annot.addString("Contents", a.content)
      annot.addElement("Rect", newArray(a.rect.x, a.rect.y, a.rect.w, a.rect.h))
      annot.addElement("Border", newArray(16, 16, 1))
      annot.addPlain("BS", "<</W 0>>")
      inc i
    for x in p.widgets:
      annots.add(x.dictObj)

  result = root

proc putResources(doc: DocState): DictObj =
  let grads = putGradients(doc.xref, doc.gradients)
  let exts  = putExtGStates(doc.xref, doc.ExtGStates)
  let imgs  = putImages(doc.xref, doc.images)
  let fonts = putFonts(doc.xref, doc.fontMan.fontList)

  result = newDictObj()
  doc.xref.add(result)

  #doc.put("<</ProcSet [/PDF /Text /ImageB /ImageC /ImageI]")
  if fonts != nil: result.addElement("Font", fonts)
  if exts != nil: result.addElement("ExtGState", exts)
  if imgs != nil: result.addElement("XObject", imgs)
  if grads != nil: result.addElement("Shading", grads)

proc writeInfo(doc: DocState, dict: DictObj, field: DocInfo) =
  var idx = int(field)
  if doc.info.hasKey(idx):
    dict.addString(INFO_FIELD[idx], doc.info[idx])

proc putInfo(doc: DocState): DictObj =
  var dict = newDictObj()
  doc.xref.add(dict)

  var lt = times.local(getTime())
  doc.writeInfo(dict, DI_CREATOR)
  doc.writeInfo(dict, DI_PRODUCER)
  doc.writeInfo(dict, DI_TITLE)
  doc.writeInfo(dict, DI_SUBJECT)
  doc.writeInfo(dict, DI_KEYWORDS)
  doc.writeInfo(dict, DI_AUTHOR)
  dict.addString("CreationDate", "D:" & lt.format("yyyyMMddHHmmss"))
  result = dict

proc putLabels(doc: DocState): DictObj =
  if doc.labels.len == 0: return nil

  var labels = newDictObj()
  doc.xref.add(labels)
  var nums = newArrayObj()
  labels.addElement("Nums", nums)

  for label in doc.labels:
    var dict = newDictObj()
    nums.addNumber(label.pageIndex)
    nums.add(dict)
    dict.addName("S", LABEL_STYLE_CH[int(label.style)])
    if label.prefix != nil:
      if label.prefix.len > 0: dict.addString("P", label.prefix)
    if label.start > 0: dict.addNumber("St", label.start)

  result = labels

proc putOutlineItem(doc: DocState, outlines: seq[Outline], parent: DictObj, root: Outline, i: int) =
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

  putDestination(root, root.dest)

  if root.kids.len > 0:
    let firstKid = root.kids[0]
    let lastKid = root.kids[root.kids.high]
    root.addElement("First", firstKid)
    root.addElement("Last", lastKid)

  var i = 0
  for kid in root.kids:
    doc.putOutlineItem(root.kids, root, kid, i)
    inc(i)

proc putOutlines(doc: DocState): DictObj =
  if doc.outlines.len == 0: return nil

  for ot in doc.outlines:
    doc.xref.add(ot)

  var root = newDictObj()
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

proc putCatalog(doc: DocState, pages: seq[Page]) =
  var catalog = newDictObj()
  doc.xref.add(catalog)
  catalog.addName("Type", "Catalog")

  var font: Font
  if doc.acroForm != nil:
    #set acroform default appearance
    font = doc.fontMan.makeFont(doc.acroForm.fontFamily, doc.acroForm.fontStyle, doc.acroForm.encoding)

  for p in pages:
    for x in p.widgets:
      var annot = x.createObject()
      doc.xref.add(annot)

  let resource = doc.putResources()
  let pageRoot = doc.putPages(resource, pages)
  #let firstPageID = pageRootID + 1

  if doc.acroForm != nil:
    let fontSize = doc.fromUser(doc.acroForm.fontSize)
    var acro = newDictObj()
    doc.xref.add(acro)
    var fields = newArrayObj()

    var co: ArrayObj
    for page in pages:
      for w in page.widgets:
        w.finalizeObject(page.dictObj, acro, resource)
        fields.add w.dictObj
        if w.needCalculateOrder():
          if co.isNil: co = newArrayObj()
          co.add w.dictObj

    if co != nil: acro.addElement("CO", co)
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

    var id = ArrayObj(trailer.getItem("ID", CLASS_ARRAY))
    if id == nil:
      id = newArrayObj()
      trailer.addElement("ID", id)
    else:
      id.clear()

    var enc = doc.encrypt.enc
    var encrypt_id = newString(enc.encrypt_id.len)
    for i in 0..enc.encrypt_id.high: encrypt_id[i] = chr(enc.encrypt_id[i])
    id.addBinary(encrypt_id)
    id.addBinary(encrypt_id)

    trailer.addElement("Encrypt", doc.encrypt)

proc writePDF*(doc: DocState, s: Stream, pages: seq[Page]) =
  doc.putCatalog(pages)
  s.write("%PDF-1.7\x0A")
  var enc = PdfEncrypt(nil)
  if doc.encrypt != nil: enc = doc.encrypt.enc
  doc.xref.writeToStream(s, enc)

proc setInfo*(doc: DocState, field: DocInfo, info: string) =
  doc.info[int(field)] = info

proc newDocState*(opts: PDFOptions): DocState =
  new(result)
  result.ExtGStates = @[]
  result.images = @[]
  result.gradients = @[]
  result.fontMan.init(opts.getFontsPath())
  result.gState = newGState()
  result.pathStartX = 0
  result.pathStartY = 0
  result.pathEndX = 0
  result.pathEndY = 0
  result.recordShape = false
  result.shapes = nil
  result.info = initTable[int, string]()
  result.opts = opts
  result.labels = @[]
  result.outlines = @[]
  result.xref = newPdfxref()
  result.setInfo(DI_PRODUCER, "nimPDF")
  result.setFontCount = 0

proc makeFont*(doc: DocState, family: string, style: FontStyles, enc: EncodingType = ENC_STANDARD): Font =
  result = doc.fontMan.makeFont(family, style, enc)

proc getOpt*(doc: DocState): PDFOptions =
  result = doc.opts

proc setLabel*(doc: DocState, style: LabelStyle, prefix: string, start, pageIndex: int) =
  var label: PageLabel
  label.pageIndex = pageIndex
  label.style = style
  label.prefix = prefix
  label.start = start
  doc.labels.add(label)

proc setLabel*(doc: DocState, style: LabelStyle, pageIndex: int) =
  var label: PageLabel
  label.pageIndex = pageIndex
  label.style = style
  label.start = -1
  doc.labels.add(label)

proc setLabel*(doc: DocState, style: LabelStyle, prefix: string, pageIndex: int) =
  var label: PageLabel
  label.pageIndex = pageIndex
  label.style = style
  label.prefix = prefix
  label.start = -1
  doc.labels.add(label)

proc loadImage*(doc: DocState, fileName: string): Image =
  var imagePath = doc.opts.getImagesPath()
  for p in imagePath:
    let fileName = p & DirSep & fileName
    if fileExists(fileName):
      let image = loadImage(fileName)
      if image != nil: return image
      break
  result = nil

proc setUnit*(doc: DocState, unit: PageUnitType) =
  doc.gState.docUnit.setUnit(unit)

proc getUnit*(doc: DocState): PageUnitType =
  result = doc.gState.docUnit.unitType

proc setCoordinateMode*(doc: DocState, mode: CoordinateMode) =
  doc.gState.coordMode = mode

proc getCoordinateMode*(doc: DocState): CoordinateMode =
  result = doc.gState.coordMode

template coordMode(doc: DocState): CoordinateMode =
  doc.gState.coordMode

proc vPoint*(doc: DocState, val: float64): float64 =
  if doc.coordMode == TOP_DOWN:
    result = doc.size.height.toPT - doc.fromUser(val)
  else:
    result = doc.fromUser(val)

proc vPointMirror*(doc: DocState, val: float64): float64 =
  if doc.coordMode == TOP_DOWN:
    result = doc.fromUser(-val)
  else:
    result = doc.fromUser(val)

proc getPageSize*(doc: DocState): PageSize = doc.size

proc newOutline*(doc: DocState, title: string, dest: Destination): Outline =
  new(result)
  result.class = CLASS_DICT
  result.subclass = SUBCLASS_OUTLINE
  result.value  = initTable[string, PdfObject]()
  result.filter = {}
  result.filterParams = nil
  result.kids = @[]
  result.dest = dest
  result.title = title
  doc.outlines.add(result)
  result.objID = 0

proc newOutline*(ot: Outline, title: string, dest: Destination): Outline =
  new(result)
  result.class = CLASS_DICT
  result.subclass = SUBCLASS_OUTLINE
  result.value  = initTable[string, PdfObject]()
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

proc newArray*(rc: Rectangle): ArrayObj =
  result = newArray(rc.x, rc.y, rc.w, rc.h)

proc newLinkAnnot*(doc: DocState, rect: Rectangle, src: Page, dest: Destination): Annot =
  new(result)
  let xx = doc.fromUser(rect.x)
  let yy = doc.vPoint(rect.y)
  let ww = doc.fromUser(rect.x + rect.w)
  let hh = doc.vPoint(rect.y + rect.h)
  result.annotType = ANNOT_LINK
  result.rect = initRect(xx,yy,ww,hh)
  result.dest = dest
  src.annots.add(result)

proc newTextAnnot*(doc: DocState, rect: Rectangle, src: Page, content: string): Annot =
  new(result)
  let xx = doc.fromUser(rect.x)
  let yy = doc.vPoint(rect.y)
  let ww = doc.fromUser(rect.x + rect.w)
  let hh = doc.vPoint(rect.y + rect.h)
  result.annotType = ANNOT_TEXT
  result.rect = initRect(xx,yy,ww,hh)
  result.content = content
  src.annots.add(result)

proc setPassword*(doc: DocState, ownerPass, userPass: string): bool =
  doc.encrypt = newEncryptDict()
  result = doc.encrypt.setPassword(ownerPass, userPass)
  doc.xref.add(doc.encrypt)

proc setEncryptionMode*(doc: DocState, mode: EncryptMode) =
  if doc.encrypt == nil: return
  var enc = doc.encrypt.enc

  if mode == ENCRYPT_R2: enc.keyLen = 5
  elif mode in {ENCRYPT_R3, ENCRYPT_R4_ARC4, ENCRYPT_R4_AES}: enc.keyLen = 16
  else: enc.keyLen = 32 # ENCRYPT_R5
  enc.mode = mode

proc newDictStream*(doc: DocState, data: string): DictObj =
  result = doc.xref.newDictStream(data)

proc newAcroForm*(doc: DocState): AcroForm =
  if doc.acroForm != nil: return doc.acroForm
  new(result)
  result.r = 0.0
  result.g = 0.0
  result.b = 0.0
  result.fontSize = doc.toUser(12)
  result.fontFamily = "Helvetica"
  result.fontStyle = {FS_REGULAR}
  result.encoding = ENC_STANDARD
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

proc put(self: ContentBase, text: varargs[string]) =
  for s in items(text): self.content.add(s)
  self.content.add('\x0A')

proc swap(this: var PageSize) = swap(this.width, this.height)

proc newPage*(state: DocState, size: PageSize, orient = PGO_PORTRAIT): Page =
  new(result)
  result.size.width = size.width
  result.size.height = size.height
  result.content = ""
  result.annots = @[]
  result.widgets = @[]
  if orient == PGO_LANDSCAPE:
    result.size.swap()
  result.state = state
  state.size = result.size
  result.dictObj = newDictObj()
  state.xref.add(result.dictObj)


proc loadImage*(self: StateBase, fileName: string): Image =
  result = self.state.loadImage(fileName)

proc setUnit*(self: StateBase, unit: PageUnitType) =
  self.state.setUnit(unit)

proc getUnit*(self: StateBase): PageUnitType =
  result = self.state.getUnit()

proc setCoordinateMode*(self: StateBase, mode: CoordinateMode) =
  self.state.setCoordinateMode(mode)

proc getCoordinateMode*(self: StateBase): CoordinateMode =
  result = self.state.getCoordinateMode()

proc getPageSize*(self: StateBase): PageSize =
  result = self.state.getPageSize()

proc toUser*(self: StateBase, val: float64): float64 =
  self.state.toUser(val)

proc fromUser*(self: StateBase, val: float64): float64 =
  self.state.fromUser(val)

proc newAppearanceStream*(state: DocState): AppearanceStream =
  new(result)
  result.content = ""
  result.state = state

proc newDictStream*(self: AppearanceStream): DictObj =
  result = self.state.newDictStream(self.content)

template fromUser(self: ContentBase, val: float64): float64 =
  self.state.gState.docUnit.fromUser(val)

template toUser(self: ContentBase, val: float64): float64 =
  self.state.gState.docUnit.toUser(val)

proc setFont*(self: ContentBase, family: string, style: FontStyles, size: float64, enc: EncodingType = ENC_STANDARD) =
  var font = self.state.fontMan.makeFont(family, style, enc)
  let fontNumber = font.ID
  let fontSize = self.fromUser(size)
  self.put("BT /F",$fontNumber," ",$fontSize," Tf ET")
  self.state.gState.font = font
  self.state.gState.fontSize = fontSize
  inc(self.state.setFontCount)

proc setFont*(self: ContentBase, family: string, size: float64 = 5.0) =
  self.setFont(family, {FS_REGULAR}, size)

proc drawText*(self: ContentBase; x,y: float64; text: string) =
  let xx = self.fromUser(x)
  let yy = self.state.vPoint(y)

  if self.state.gState.font == nil or self.state.setFontCount == 0:
    self.setFont(defaultFont, {FS_REGULAR}, 5)

  var font = self.state.gState.font

  if font.subType == FT_TRUETYPE:
    var utf8 = replace_invalid(text)
    self.put("BT ",f2s(xx)," ",f2s(yy)," Td <",font.EscapeString(utf8),"> Tj ET")
  else:
    self.put("BT ",f2s(xx)," ",f2s(yy)," Td (",escapeString(text),") Tj ET")

proc drawVText*(self: ContentBase; x,y: float64; text: string) =
  if self.state.gState.font == nil or self.state.setFontCount == 0:
    self.setFont(defaultFont, {FS_REGULAR}, 5)

  var font = self.state.gState.font

  if not font.CanWriteVertical():
    self.drawText(x, y, text)
    return

  var xx = self.fromUser(x)
  var yy = self.state.vPoint(y)
  let utf8 = replace_invalid(text)
  let cid = font.EscapeString(utf8)

  self.put("BT")
  var i = 0
  for b in runes(utf8):
    self.put(f2s(xx)," ",f2s(yy)," Td <", substr(cid, i, i + 3),"> Tj")
    yy = -float(TTFont(font).GetCharHeight(int(b))) * self.state.gState.fontSize / 1000
    xx = 0
    inc(i, 4)
  self.put("ET")

proc beginText*(self: ContentBase) =
  if self.state.gState.font == nil or self.state.setFontCount == 0:
    self.setFont(defaultFont, {FS_REGULAR}, 5)

  self.put("BT")

proc beginText*(self: ContentBase; x,y: float64) =
  if self.state.gState.font == nil:
    self.setFont(defaultFont, {FS_REGULAR}, 5)

  let xx = self.fromUser(x)
  let yy = self.state.vPoint(y)
  self.put("BT ", f2s(xx)," ",f2s(yy)," Td")

proc moveTextPos*(self: ContentBase; x,y: float64) =
  let xx = self.fromUser(x)
  let yy = self.state.vPointMirror(y)
  self.put(f2s(xx)," ",f2s(yy)," Td")

proc setTextRenderingMode*(self: ContentBase, rm: TextRenderingMode) =
  let trm = cast[int](rm)
  if self.state.gState.renderingMode != rm: self.put($trm, " Tr")
  self.state.gState.renderingMode = rm

proc setTextMatrix*(self: ContentBase, m: Matrix2d) =
  self.put(f2s(m.ax)," ", f2s(m.ay), " ", f2s(m.bx), " ", f2s(m.by), " ", f2s(m.tx)," ",f2s(m.ty)," Tm")

proc showText*(self: ContentBase, text:string) =
  var font = self.state.gState.font

  if font.subType == FT_TRUETYPE:
    var utf8 = replace_invalid(text)
    self.put("<",font.EscapeString(utf8),"> Tj")
  else:
    self.put("(",escapeString(text),") Tj")

proc setTextLeading*(self: ContentBase, val: float64) =
  let tl = self.fromUser(val)
  self.put(f2s(tl)," TL")

proc moveToNextLine*(self: ContentBase) =
  self.put("T*")

proc endText*(self: ContentBase) =
  self.put("ET")

proc degree_to_radian*(x: float): float =
  result = (x * math.PI) / 180.0

proc setCharSpace*(self: ContentBase; val: float64) =
  self.put(f2s(val)," Tc")
  self.state.gState.charSpace = val

proc setTextHScale*(self: ContentBase; val: float64) =
  self.put(f2s(val)," Th")
  self.state.gState.hScaling = val

proc setWordSpace*(self: ContentBase; val: float64) =
  self.put(f2s(val)," Tw")
  self.state.gState.wordSpace = val

proc setTransform*(self: ContentBase, m: Matrix2d) =
  self.put(f2s(m.ax)," ", f2s(m.ay), " ", f2s(m.bx), " ", f2s(m.by), " ", f2s(m.tx)," ",f2s(m.ty)," cm")
  self.state.gState.transMatrix = self.state.gState.transMatrix & m

proc rotate*(self: ContentBase, angle:float64) =
  self.setTransform(rotate(degree_to_radian(angle)))

proc rotate*(self: ContentBase, angle, x,y:float64) =
  let xx = self.fromUser(x)
  let yy = self.state.vPoint(y)
  self.setTransform(rotate(degree_to_radian(angle), point2d(xx, yy)))

proc move*(self: ContentBase, x,y:float64) =
  let xx = self.fromUser(x)
  let yy = self.state.vPointMirror(y)
  self.setTransform(move(xx,yy))

proc scale*(self: ContentBase, s:float64) =
  self.setTransform(scale(s))

proc scale*(self: ContentBase, s, x,y:float64) =
  let xx = self.fromUser(x)
  let yy = self.state.vPoint(y)
  self.setTransform(scale(s, point2d(xx, yy)))

proc stretch*(self: ContentBase, sx,sy:float64) =
  self.setTransform(stretch(sx,sy))

proc stretch*(self: ContentBase, sx,sy,x,y:float64) =
  let xx = self.fromUser(x)
  let yy = self.state.vPoint(y)
  self.setTransform(stretch(sx, sy, point2d(xx, yy)))

proc shear(sx,sy,x,y:float64): Matrix2d =
  let
    m = move(-x,-y)
    s = matrix2d(1.0,sx,sy,1.0,0.0,0.0)
  result = m & s & move(x,y)

proc skew*(self: ContentBase, sx,sy:float64) =
  let tsx = math.tan(degree_to_radian(sx))
  let tsy = math.tan(degree_to_radian(sy))
  self.setTransform(matrix2d(1,tsx,tsy,1,0,0))

proc skew*(self: ContentBase, sx,sy,x,y:float64) =
  let xx = self.fromUser(x)
  let yy = self.state.vPoint(y)
  let tsx = math.tan(degree_to_radian(sx))
  let tsy = math.tan(degree_to_radian(sy))
  self.setTransform(shear(tsx, tsy, xx, yy))

proc drawImage*(self: ContentBase, x, y:float64, source: Image) =
  let size = self.state.images.len()
  var found = false
  var img = source

  if img == nil: return

  for image in items(self.state.images):
    if image == img:
      found = true
      break

  if self.state.gState.alphaFill > 0.0 and self.state.gState.alphaFill < 1.0:
    img = img.clone()
    img.adjustTransparency(self.state.gState.alphaFill)
    found = false

  if not found:
    img.ID = size + 1
    self.state.images.add(img)

  let hh = float(img.height)
  let ww = float(img.width)

  #if img.haveMask():
    #self.put("q")
    #
    ##embed hidden, outside canvas
    #var xx = self.state.size.width.toPT + fromMM(10.0).toPT
    #var yy = self.state.size.height.toPT + fromMM(10.0).toPT
    #
    #self.put(f2s(ww)," 0 0 ",f2s(hh)," ",f2s(xx)," ",f2s(yy)," cm")
    #self.put("/Im",$img.ID," Do")
    #self.put("Q")

  self.put("q")
  var xx = self.fromUser(x)
  var yy = self.state.vPoint(y)

  self.put(f2s(ww)," 0 0 ",f2s(hh)," ",f2s(xx)," ",f2s(yy)," cm")

  self.put("/I",$img.ID," Do")
  self.put("Q")

proc drawRect*(self: ContentBase, x, y, w, h: float64) =
  if self.state.recordShape:
    self.state.shapes[self.state.shapes.len - 1].addRect(x, y, w, h)
    self.state.shapes.add(makePath())
  else:
    let xx = self.fromUser(x)
    let yy = self.state.vPoint(y)
    let ww = self.fromUser(w)
    let hh = self.state.vPointMirror(h)
    self.put(f2s(xx)," ",f2s(yy)," ",f2s(ww)," ",f2s(hh)," re")

proc moveTo*(self: ContentBase, x, y: float64) =
  let xx = self.fromUser(x)
  let yy = self.state.vPoint(y)
  self.put(f2s(xx)," ",f2s(yy)," m")
  self.state.pathStartX = x
  self.state.pathStartY = y
  self.state.pathEndX = x
  self.state.pathEndY = y

proc moveTo*(self: ContentBase, p: Point2d) {.inline.} = self.moveTo(p.x, p.y)

proc lineTo*(self: ContentBase, x, y: float64) =
  if self.state.recordShape:
    self.state.shapes[self.state.shapes.len - 1].addLine(self.state.pathStartX, self.state.pathStartY, x, y)
    if x == self.state.pathStartX and y == self.state.pathStartY:
      self.state.shapes.add(makePath())
  else:
    let xx = self.fromUser(x)
    let yy = self.state.vPoint(y)
    self.put(f2s(xx)," ",f2s(yy)," l")
  self.state.pathEndX = x
  self.state.pathEndY = y

proc lineTo*(self: ContentBase, p: Point2d) {.inline.} = self.lineTo(p.x, p.y)

proc drawLine*(self: ContentBase, x1, y1, x2, y2: float64) =
  self.moveTo(x1, y1)
  self.lineTo(x2, y2)

proc bezierCurveTo*(self: ContentBase; cp1x, cp1y, cp2x, cp2y, x, y: float64) =
  if self.state.recordShape:
    self.state.shapes[self.state.shapes.len - 1].addCubicCurve(self.state.pathEndX, self.state.pathEndY, cp1x,cp1y, cp2x,cp2y, x, y)
    if x == self.state.pathStartX and y == self.state.pathStartY:
      self.state.shapes.add(makePath())
  else:
    let cp1xx = self.fromUser(cp1x)
    let cp2xx = self.fromUser(cp2x)
    let xx = self.fromUser(x)

    let cp1yy = self.state.vPoint(cp1y)
    let cp2yy = self.state.vPoint(cp2y)
    let yy = self.state.vPoint(y)
    self.put(f2s(cp1xx)," ",f2s(cp1yy)," ",f2s(cp2xx)," ",f2s(cp2yy)," ",f2s(xx)," ",f2s(yy)," c")
  self.state.pathEndX = x
  self.state.pathEndY = y

proc bezierCurveTo*(self: ContentBase; cp1, cp2, p: Point2d) {.inline.} = self.bezierCurveTo(cp1.x,cp1.y,cp2.x,cp2.y,p.x,p.y)

proc curveTo1*(self: ContentBase; cpx, cpy, x, y: float64) =
  if self.state.recordShape:
    self.state.shapes[self.state.shapes.len - 1].addQuadraticCurve(self.state.pathEndX, self.state.pathEndY, cpx,cpy, x, y)
    if x == self.state.pathStartX and y == self.state.pathStartY:
      self.state.shapes.add(makePath())
  else:
    let cpxx = self.fromUser(cpx)
    let xx = self.fromUser(x)
    let cpyy = self.state.vPoint(cpy)
    let yy = self.state.vPoint(y)
    self.put(f2s(cpxx)," ",f2s(cpyy)," ",f2s(xx)," ",f2s(yy)," v")
  self.state.pathEndX = x
  self.state.pathEndY = y

proc curveTo1*(self: ContentBase; cp, p: Point2d) {.inline.} = self.curveTo1(cp.x,cp.y,p.x,p.y)

proc curveTo2*(self: ContentBase; cpx, cpy, x, y: float64) =
  if self.state.recordShape:
    self.state.shapes[self.state.shapes.len - 1].addQuadraticCurve(self.state.pathEndX, self.state.pathEndY, cpx,cpy, x, y)
    if x == self.state.pathStartX and y == self.state.pathStartY:
      self.state.shapes.add(makePath())
  else:
    let cpxx = self.fromUser(cpx)
    let xx = self.fromUser(x)
    let cpyy = self.state.vPoint(cpy)
    let yy = self.state.vPoint(y)
    self.put(f2s(cpxx)," ",f2s(cpyy)," ",f2s(xx)," ",f2s(yy)," y")
  self.state.pathEndX = x
  self.state.pathEndY = y

proc curveTo2*(self: ContentBase; cp, p: Point2d) {.inline.} = self.curveTo2(cp.x,cp.y,p.x,p.y)

proc closePath*(self: ContentBase) =
  if self.state.recordShape:
    self.state.shapes[self.state.shapes.len - 1].addLine(self.state.pathEndX, self.state.pathEndY, self.state.pathStartX, self.state.pathStartY)
    self.state.shapes.add(makePath())
  else:
    self.put("h")

  self.state.pathEndX = self.state.pathStartX
  self.state.pathEndY = self.state.pathStartY

proc drawRoundRect*(self: ContentBase; x, y, w, h: float64; r: float64 = 0.0) =
  self.moveTo(x + r, y)
  self.lineTo(x + w - r, y)
  self.curveTo1(x + w, y, x + w, y + r)
  self.lineTo(x + w, y + h - r)
  self.curveTo1(x + w, y + h, x + w - r, y + h)
  self.lineTo(x + r, y + h)
  self.curveTo1(x, y + h, x, y + h - r)
  self.lineTo(x, y + r)
  self.curveTo1(x, y, x + r, y)

proc drawEllipse*(self: ContentBase; x, y, r1, r2 : float64) =
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

  self.moveTo(xx, ym)
  self.bezierCurveTo(xx, ym - oy, xm - ox, yy, xm, yy)
  self.bezierCurveTo(xm + ox, yy, xe, ym - oy, xe, ym)
  self.bezierCurveTo(xe, ym + oy, xm + ox, ye, xm, ye)
  self.bezierCurveTo(xm - ox, ye, xx, ym + oy, xx, ym)

proc drawCircle*(self: ContentBase; x, y, radius : float64) =
  self.drawEllipse(x,y,radius,radius)

proc setLineWidth*(self: ContentBase, lineWidth: float64) =
  let lw = self.fromUser(lineWidth)
  if lineWidth != self.state.gState.lineWidth: self.put(f2s(lw), " w")
  self.state.gState.lineWidth = lineWidth

proc setLineCap*(self: ContentBase, lineCap: LineCap) =
  let lc = cast[int](lineCap)
  if lineCap != self.state.gState.lineCap: self.put($lc, " J")
  self.state.gState.lineCap = lineCap

proc setLineJoin*(self: ContentBase, lineJoin: LineJoin) =
  let lj = cast[int](lineJoin)
  if self.state.gState.lineJoin != lineJoin: self.put($lj, " j")
  self.state.gState.lineJoin = lineJoin

proc setMiterLimit*(self: ContentBase, miterLimit: float64) =
  let ml = self.fromUser(miterLimit)
  if self.state.gState.miterLimit != miterLimit: self.put(f2s(ml), " M")
  self.state.gState.miterLimit = miterLimit

proc setGrayFill*(self: ContentBase; g: float64) =
  self.put(f2s(g), " g")
  self.state.gState.grayFill = g
  self.state.gState.csFill = CS_DEVICE_GRAY
  self.state.shapes = nil
  self.state.recordShape = false

proc setGrayStroke*(self: ContentBase; g: float64) =
  self.put(f2s(g), " G")
  self.state.gState.grayStroke = g
  self.state.gState.csStroke = CS_DEVICE_GRAY

proc setFillColor*(self: ContentBase; r,g,b: float64) =
  self.put(f2s(r), " ",f2s(g), " ",f2s(b), " rg")
  self.state.gState.rgbFill = initRGB(r,g,b)
  self.state.gState.csFill = CS_DEVICE_RGB
  self.state.shapes = nil
  self.state.recordShape = false

proc setStrokeColor*(self: ContentBase; r,g,b: float64) =
  self.put(f2s(r), " ",f2s(g), " ",f2s(b), " RG")
  self.state.gState.rgbStroke = initRGB(r,g,b)
  self.state.gState.csStroke = CS_DEVICE_RGB

proc setFillColor*(self: ContentBase; col: RGBColor) =
  self.setFillColor(col.r,col.g,col.b)

proc setStrokeColor*(self: ContentBase; col: RGBColor) =
  self.setStrokeColor(col.r,col.g,col.b)

proc setFillColor*(self: ContentBase; col: string) =
  self.setFillColor(initRGB(col))

proc setStrokeColor*(self: ContentBase; col: string) =
  self.setStrokeColor(initRGB(col))

proc setCMYKFill*(self: ContentBase; c,m,y,k: float64) =
  self.put(f2s(c), " ",f2s(m), " ",f2s(y), " ",f2s(k), " k")
  self.state.gState.cmykFill = initCMYK(c,m,y,k)
  self.state.gState.csFill = CS_DEVICE_CMYK
  self.state.shapes = nil
  self.state.recordShape = false

proc setCMYKStroke*(self: ContentBase; c,m,y,k: float64) =
  self.put(f2s(c), " ",f2s(m), " ",f2s(y), " ",f2s(k), " K")
  self.state.gState.cmykFill = initCMYK(c,m,y,k)
  self.state.gState.csFill = CS_DEVICE_CMYK

proc setCMYKFill*(self: ContentBase; col: CMYKColor) =
  self.setCMYKFill(col.c,col.m,col.y,col.k)

proc setCMYKStroke*(self: ContentBase; col: CMYKColor) =
  self.setCMYKStroke(col.c,col.m,col.y,col.k)

proc init(gs: var ExtGState; id: int; sA, nsA: float64, bm: string = "Normal") =
  gs.ID = id
  gs.strokingAlpha = sA
  gs.nonstrokingAlpha = nsA
  gs.blendMode = bm

proc setAlpha*(self: ContentBase, a: float64) =
  let id = self.state.ExtGStates.len() + 1
  var gs : ExtGState
  gs.init(id, a, a)
  self.state.ExtGStates.add(gs)
  self.put("/GS",$id," gs")
  self.state.gState.alphaFill = a
  self.state.gState.alphaStroke = a

proc setBlendMode*(self: ContentBase, bm: BlendMode) =
  let id = self.state.ExtGStates.len() + 1
  var gs : ExtGState
  var bmid = cast[int](bm)
  gs.init(id, -1.0, -1.0, BM_NAMES[bmid])
  self.state.ExtGStates.add(gs)
  self.put("/GS",$id," gs")
  self.state.gState.blendMode = bm

proc saveState*(self: ContentBase) =
  self.state.gState = newGState(self.state.gState)
  self.put("q")

proc restoreState*(self: ContentBase) =
  self.state.gState = freeGState(self.state.gState)
  self.put("Q")

proc getTextWidth*(self: ContentBase, text:string): float64 =
  var res = 0.0
  let tw = self.state.gState.font.GetTextWidth(text)

  res += self.state.gState.wordSpace * float64(tw.numspace)
  res += float64(tw.width) * self.state.gState.fontSize / 1000
  res += self.state.gState.charSpace * float64(tw.numchars)

  result = self.toUser(res)

proc getTextHeight*(self: ContentBase, text:string): float64 =
  var res = 0.0
  let tw = self.state.gState.font.GetTextHeight(text)

  res += self.state.gState.wordSpace * float64(tw.numspace)
  res += float64(tw.width) * self.state.gState.fontSize / 1000
  res += self.state.gState.charSpace * float64(tw.numchars)

  result = self.toUser(res)

proc setDash*(self: ContentBase, dash:openArray[int], phase:int) =
  var ptn = "["
  var num_ptn = 0

  for i in 0..high(dash):
    if dash[i] == 0 or i > MAX_DASH_PATTERN: break
    ptn.add($dash[i])
    ptn.add(" ")
    inc(num_ptn)

  ptn.add("] " & $phase & " d")
  self.put(ptn)

  self.state.gState.dash.num_ptn = num_ptn
  self.state.gState.dash.phase = phase

  for i in 0..num_ptn-1:
    self.state.gState.dash.ptn[i] = dash[i]

proc clip*(self: ContentBase) =
  self.put("W")

proc executePath*(self: ContentBase, p: Path) =
  let len = p.len()
  var i = 0
  self.moveTo(p[i+1], p[i+2])
  while i < len:
    let op = p[i]
    if op == straight_line:
      self.lineTo(p[i+3], p[i+4])
      inc(i, 5)
    if op == rectangle:
      self.drawRect(p[i+1], p[i+2], p[i+3]-p[i+1], p[i+4]-p[i+2])
      inc(i, 5)
    if op == quadratic_curve:
      self.curveTo1(p[i+3],p[i+4],p[i+5],p[i+6])
      inc(i, 7)
    if op == cubic_curve:
      self.bezierCurveTo(p[i+3],p[i+4],p[i+5],p[i+6],p[i+7],p[i+8])
      inc(i, 9)

proc drawBounds*(self: ContentBase, p: Path) =
  let len = p.len
  var i = 0
  while i < len:
    let op = p[i]
    if op == straight_line or op == rectangle:
      self.drawRect(p[i+1], p[i+2], p[i+3]-p[i+1], p[i+4]-p[i+2])
      inc(i, 5)
    if op == quadratic_curve:
      let bb = quadraticCurveBounds(p[i+1],p[i+2],p[i+3],p[i+4],p[i+5],p[i+6])
      self.drawRect(bb.xmin, bb.ymin, bb.xmax-bb.xmin, bb.ymax-bb.ymin)
      self.put("S")
      inc(i, 7)
    if op == cubic_curve:
      let bb = cubicCurveBounds(p[i+1],p[i+2],p[i+3],p[i+4],p[i+5],p[i+6],p[i+7],p[i+8])
      self.drawRect(bb.xmin, bb.ymin, bb.xmax-bb.xmin, bb.ymax-bb.ymin)
      self.put("S")
      inc(i, 9)

proc drawBounds*(self: ContentBase) =
  if self.state.recordShape:
    self.state.recordShape = false
    for p in self.state.shapes:
      if p.len > 0: self.drawBounds(p)
    self.state.recordShape = true

proc applyGradient(self: ContentBase) =
  for p in self.state.shapes:
    if p.len > 0 and p.isClosed():
      self.put("q")
      self.executePath(p)
      self.put("W n") #set gradient clipping area
      let bb = calculateBounds(p)
      let xx = self.fromUser(bb.xmin)
      let yy = self.state.vPoint(bb.ymin + bb.ymax - bb.ymin)
      let ww = self.fromUser(bb.xmax - bb.xmin)
      let hh = self.fromUser(bb.ymax - bb.ymin)
      #set up transformation matrix for gradient
      self.put(f2s(ww)," 0 0 ", f2s(hh), " ", f2s(xx), " ", f2s(yy), " cm")
      self.put("/Sh",$self.state.gState.gradientFill.ID," sh") #paint the gradient
      self.put("Q")

proc fill*(self: ContentBase) =
  if self.state.recordShape:
    self.state.recordShape = false
    if self.state.gState.csFill == CS_GRADIENT: self.applyGradient()
    self.state.shapes = @[]
    self.state.shapes.add(makePath())
    self.state.recordShape = true
  else:
    self.put("f")

proc stroke*(self: ContentBase) =
  if self.state.recordShape:
    self.state.recordShape = false
    for p in self.state.shapes:
      if p.len > 0:
        self.executePath(p)
        self.put("S")
    self.state.recordShape = true
  else:
    self.put("S")

proc fillAndStroke*(self: ContentBase) =
  if self.state.recordShape:
    self.state.recordShape = false
    if self.state.gState.csFill == CS_GRADIENT: self.applyGradient()
    self.state.recordShape = true
    self.stroke()
  else:
    self.put("B")

proc setGradientFill*(self: ContentBase, grad: Gradient) =
  let size = self.state.gradients.len()
  var found = false
  if grad == nil: return

  for gradient in items(self.state.gradients):
    if gradient == grad:
      found = true
      break
  if not found:
    grad.ID = size + 1
    self.state.gradients.add(grad)

  self.state.shapes = @[]
  self.state.shapes.add(makePath())
  self.state.recordShape = true
  self.state.gState.csFill = CS_GRADIENT
  self.state.gState.gradientFill = grad

proc addWidget*(page: Page, w: WidgetBase) =
  page.widgets.add w

proc newXYZDest*(page: Page, x, y, z: float64): Destination =
  new(result)
  result.style = DS_XYZ
  result.page  = page
  result.a = page.fromUSer(x)
  result.b = page.state.vPoint(y)
  result.c = z

proc newFitDest*(page: Page): Destination =
  new(result)
  result.style = DS_FIT
  result.page  = page

proc newFitHDest*(page: Page, top: float64): Destination =
  new(result)
  result.style = DS_FITH
  result.page  = page
  result.a = page.state.vPoint(top)

proc newFitVDest*(page: Page, left: float64): Destination =
  new(result)
  result.style = DS_FITV
  result.page  = page
  result.a = page.fromUSer(left)

proc newFitRDest*(page: Page, left, bottom, right, top: float64): Destination =
  new(result)
  result.style = DS_FITR
  result.page  = page
  result.a = page.fromUSer(left)
  result.b = page.state.vPoint(bottom)
  result.c = page.fromUSer(right)
  result.d = page.state.vPoint(top)

proc newFitBDest*(page: Page): Destination =
  new(result)
  result.style = DS_FITB
  result.page  = page

proc newFitBHDest*(page: Page, top: float64): Destination =
  new(result)
  result.style = DS_FITBH
  result.page  = page
  result.a = page.state.vPoint(top)

proc newFitBVDest*(page: Page, left: float64): Destination =
  new(result)
  result.style = DS_FITBV
  result.page  = page
  result.a = left

include arc
