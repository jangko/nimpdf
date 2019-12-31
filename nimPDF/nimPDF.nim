# Copyright (c) 2015 Andri Lim
#
# Distributed under the MIT license
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------
# the main module for nimPDF, import this one from your project

import streams, basic2d
import image, gstate, path, fontmanager
import encryptdict, encrypt, page, options, widgets

export encryptdict.DocInfo, encrypt.EncryptMode, widgets
export path, gstate, image, fontmanager, page, options

const
  nimPDFVersion = "0.4.0"

  PageNames = [
    #my paper size
    ("Faktur",210.0,148.0), ("F4",215.0,330.0),
    #ISO paper sizes
    ("A0",841.0,1189.0),("A1",594.0,841.0),("A2",420.0,594.0),("A3",297.0,420.0),("A4",210.0,297.0),("A5",148.0,210.0),("A6",105.0,148.0),("A7",74.0,105.0),("A8",52.0,74.0),
    ("A9",37.0,52.0),("A10",26.0,37.0),("B0",1000.0,1414.0),("B1",707.0,1000.0),("B2",500.0,707.0),("B3",353.0,500.0),("B4",250.0,353.0),("B5",176.0,250.0),
    ("B6",125.0,176.0),("B7",88.0,125.0),("B8",62.0,88.0),("B9",44.0,62.0),("B10",31.0,44.0),("C0",917.0,1297.0),("C1",648.0,917.0),("C2",458.0,648.0),
    ("C3",324.0,458.0),("C4",229.0,324.0),("C5",162.0,229.0),("C6",114.0,162.0),("C7",81.0,114.0),("C8",57.0,81.0),("C9",40.0,57.0),("C10",28.0,40.0),
    #DIN 476
    ("4A0",1682.0,2378.0),("2A0",1189.0,1682.0),
    #JIS paper sizes
    ("JIS0",1030.0,1456.0),("JIS1",728.0,1030.0),("JIS2",515.0,728.0),("JIS3",364.0,515.0),("JIS4",257.0,364.0),("JIS5",182.0,257.0),("JIS6",128.0,182.0),("JIS7",91.0,128.0),
    ("JIS8",64.0,91.0),("JIS9",45.0,64.0),("JIS10",32.0,45.0),("JIS11",22.0,32.0),("JIS12",16.0,22.0),
    #North American paper sizes
    ("Letter",215.9,279.4),("Legal",215.9,355.6),("Junior Legal",203.2,127.0),("Ledger",432.0,279.0),("Tabloid",279.0,432.0),
    #ANSI
    ("ANSI A",216.0,279.0),("ANSI B",279.0,432.0),("ANSI C",432.0,559.0),("ANSI D",559.0,864.0),("ANSI E",864.0,1118.0),
    #others
    ("Organizer J",70.0,127.0),("Compact", 108.0,171.0),("Organizer L",140.0,216.0),("Statement",140.0,216.0),("Half Letter",140.0,216.0),
    ("Memo",140.0,216.0),("Jepps",140.0,216.0),("Executive",184.0,267.0),("Monarch",184.0,267.0),("Government-Letter",103.0,267.0),
    ("Foolscap",210.0,330.0),("Folio[9]",210.0,330.0),("Organizer M",216.0,279.0),("Fanfold",216.0,304.0),
    ("German Std Fanfold",216.0,304.0),("Government-Legal",216.0,330.0),("Folio",216.0,330.0),("Quarto",229.0,279.0),
    ("US Std Fanfold",279.0,377.0),("Organizer K",279.0,432.0),("Bible",279.0,432.0),
    ("Super-B",330.0,483.0),("Post",394.0,489.0),("Crown",381.0,508.0),("Large Post",419.0,533.0),("Demy",445.0,572.0),("Medium",457.0,584.0),
    ("Broadsheet",457.0,610.0),("Royal",508.0,635.0),("Elephant",584.0,711.0),("REAL Demy",572.0,889.0),("Quad Demy",889.0,1143.0)]

type
  PDF* = ref object of StateBase
    pages: seq[Page]
    curPage: Page

  NamedPageSize = tuple[name: string, width: float64, height: float64]

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

proc initPageSize*(w, h: SizeUnit): PageSize =
  result.width = w
  result.height = h

proc newPDF*(opts: PDFOptions): PDF =
  new(result)
  result.pages = @[]
  result.curPage = nil
  result.state = newDocState(opts)

proc newPDF*(): PDF =
  var opts = newPDFOptions()
  opts.addFontsPath("fonts")
  opts.addImagesPath("resources")
  opts.addResourcesPath("resources")
  result = newPDF(opts)

proc getVersion*(): string =
  result = nimPDFVersion

proc getVersion*(doc: PDF): string =
  result = nimPDFVersion

proc getOptions*(doc: PDF): PDFOptions =
  result = doc.state.getOpt()

proc setInfo*(doc: PDF, field: DocInfo, info: string) =
  doc.state.setInfo(field, info)

proc setLabel*(doc: PDF, style: LabelStyle, prefix: string, start: int) =
  doc.state.setLabel(style, prefix, start, doc.pages.len)

proc setLabel*(doc: PDF, style: LabelStyle) =
  doc.state.setLabel(style, doc.pages.len)

proc setLabel*(doc: PDF, style: LabelStyle, prefix: string) =
  doc.state.setLabel(style, prefix, doc.pages.len)

proc addPage*(doc: PDF, size: PageSize, orient = PGO_PORTRAIT): Page {.discardable.} =
  var p = newPage(doc.state, size, orient)
  doc.pages.add(p)
  doc.curPage = p
  result = p

proc addPage*(doc: PDF, size: string, orient = PGO_PORTRAIT): Page {.discardable.} =
  result = doc.addPage(getSizeFromName(size), orient)

proc writePDF*(doc: PDF, s: Stream) =
  doc.state.writePDF(s, doc.pages)

proc writePDF*(doc: PDF, fileName: string): bool =
  result = false
  var file = newFileStream(fileName, fmWrite)
  if file != nil:
    doc.writePDF(file)
    file.close()
    result = true

proc setFont*(doc: PDF, family: string, style: FontStyles, size: float64, enc: EncodingType = ENC_STANDARD) =
  assert(doc.curPage != nil)
  doc.curPage.setFont(family, style, size, enc)

proc setFont*(doc: PDF, family: string, size: float64 = 5.0) =
  assert(doc.curPage != nil)
  doc.curPage.setFont(family, size)

proc drawText*(doc: PDF; x,y: float64; text: string) =
  assert(doc.curPage != nil)
  doc.curPage.drawText(x, y, text)

proc drawVText*(doc: PDF; x,y: float64; text: string) =
  assert(doc.curPage != nil)
  doc.curPage.drawVText(x, y, text)

proc beginText*(doc: PDF) =
  assert(doc.curPage != nil)
  doc.curPage.beginText()

proc beginText*(doc: PDF; x,y: float64) =
  assert(doc.curPage != nil)
  doc.curPage.beginText(x,y)

proc moveTextPos*(doc: PDF; x,y: float64) =
  assert(doc.curPage != nil)
  doc.curPage.moveTextPos(x,y)

proc setTextRenderingMode*(doc: PDF, rm: TextRenderingMode) =
  assert(doc.curPage != nil)
  doc.curPage.setTextRenderingMode(rm)

proc setTextMatrix*(doc: PDF, m: Matrix2d) =
  assert(doc.curPage != nil)
  doc.curPage.setTextMatrix(m)

proc showText*(doc: PDF, text: string) =
  assert(doc.curPage != nil)
  doc.curPage.showText(text)

proc setTextLeading*(doc: PDF, val: float64) =
  assert(doc.curPage != nil)
  doc.curPage.setTextLeading(val)

proc moveToNextLine*(doc: PDF) =
  assert(doc.curPage != nil)
  doc.curPage.moveToNextLine()

proc endText*(doc: PDF) =
  assert(doc.curPage != nil)
  doc.curPage.endText()

proc setCharSpace*(doc: PDF; val: float64) =
  assert(doc.curPage != nil)
  doc.curPage.setCharSpace(val)

proc setTextHScale*(doc: PDF; val: float64) =
  assert(doc.curPage != nil)
  doc.curPage.setTextHScale(val)

proc setWordSpace*(doc: PDF; val: float64) =
  assert(doc.curPage != nil)
  doc.curPage.setWordSpace(val)

proc setTransform*(doc: PDF, m: Matrix2d) =
  assert(doc.curPage != nil)
  doc.curPage.setTransform(m)

proc rotate*(doc: PDF, angle: float64) =
  assert(doc.curPage != nil)
  doc.curPage.rotate(angle)

proc rotate*(doc: PDF, angle, x, y: float64) =
  assert(doc.curPage != nil)
  doc.curPage.rotate(angle, x, y)

proc move*(doc: PDF, x, y: float64) =
  assert(doc.curPage != nil)
  doc.curPage.move(x, y)

proc scale*(doc: PDF, s: float64) =
  assert(doc.curPage != nil)
  doc.curPage.scale(s)

proc scale*(doc: PDF, s, x, y: float64) =
  assert(doc.curPage != nil)
  doc.curPage.scale(s, x, y)

proc stretch*(doc: PDF, sx, sy: float64) =
  assert(doc.curPage != nil)
  doc.curPage.stretch(sx, sy)

proc stretch*(doc: PDF, sx, sy, x, y: float64) =
  assert(doc.curPage != nil)
  doc.curPage.stretch(sx, sy, x, y)

proc skew*(doc: PDF, sx,sy: float64) =
  assert(doc.curPage != nil)
  doc.curPage.skew(sx, sy)

proc skew*(doc: PDF, sx, sy, x, y: float64) =
  assert(doc.curPage != nil)
  doc.curPage.skew(sx, sy, x, y)

proc arcTo*(doc: PDF; x, y, rx, ry, angle: float64; largeArcFlag, sweepFlag: bool) =
  assert(doc.curPage != nil)
  doc.curPage.arcTo(x, y, rx, ry, angle, largeArcFlag, sweepFlag)

proc moveTo*(doc: PDF, x, y: float64) =
  assert(doc.curPage != nil)
  doc.curPage.moveTo(x, y)

proc moveTo*(doc: PDF, p: Point2d) {.inline.} = doc.moveTo(p.x, p.y)

proc lineTo*(doc: PDF, x, y: float64) =
  assert(doc.curPage != nil)
  doc.curPage.lineTo(x, y)

proc lineTo*(doc: PDF, p: Point2d) {.inline.} = doc.lineTo(p.x, p.y)

proc bezierCurveTo*(doc: PDF; cp1x, cp1y, cp2x, cp2y, x, y: float64) =
  assert(doc.curPage != nil)
  doc.curPage.bezierCurveTo(cp1x, cp1y, cp2x, cp2y, x, y)

proc bezierCurveTo*(doc: PDF; cp1, cp2, p: Point2d) {.inline.} =
  doc.bezierCurveTo(cp1.x,cp1.y,cp2.x,cp2.y,p.x,p.y)

proc curveTo1*(doc: PDF; cpx, cpy, x, y: float64) =
  assert(doc.curPage != nil)
  doc.curPage.curveTo1(cpx, cpy, x, y)

proc curveTo1*(doc: PDF; cp, p: Point2d) {.inline.} =
  doc.curveTo1(cp.x,cp.y,p.x,p.y)

proc curveTo2*(doc: PDF; cpx, cpy, x, y: float64) =
  assert(doc.curPage != nil)
  doc.curPage.curveTo2(cpx, cpy, x, y)

proc curveTo2*(doc: PDF; cp, p: Point2d) {.inline.} =
  doc.curveTo2(cp.x,cp.y,p.x,p.y)

proc closePath*(doc: PDF) =
  assert(doc.curPage != nil)
  doc.curPage.closePath()

proc drawRoundRect*(doc: PDF; x, y, w, h: float64; r: float64 = 0.0) =
  assert(doc.curPage != nil)
  doc.curPage.drawRoundRect(x, y, w, h, r)

proc drawEllipse*(doc: PDF; x, y, r1, r2: float64) =
  assert(doc.curPage != nil)
  doc.curPage.drawEllipse(x, y, r1, r2)

proc drawCircle*(doc: PDF; x, y, radius: float64) =
  assert(doc.curPage != nil)
  doc.curPage.drawCircle(x, y, radius)

proc drawImage*(doc: PDF, x, y: float64, source: Image) =
  assert(doc.curPage != nil)
  doc.curPage.drawImage(x, y, source)

proc drawRect*(doc: PDF, x, y, w, h: float64) =
  assert(doc.curPage != nil)
  doc.curPage.drawRect(x, y, w, h)

proc drawLine*(doc: PDF, x1, y1, x2, y2: float64) =
  assert(doc.curPage != nil)
  doc.curPage.drawLine(x1, y1, x2, y2)

proc drawArc*(doc: PDF; cx, cy, rx, ry, startAngle, sweepAngle: float64) =
  assert(doc.curPage != nil)
  doc.curPage.drawArc(cx, cy, rx, ry, startAngle, sweepAngle)

proc setLineWidth*(doc: PDF, lineWidth: float64) =
  assert(doc.curPage != nil)
  doc.curPage.setLineWidth(lineWidth)

proc setLineCap*(doc: PDF, lineCap: LineCap) =
  assert(doc.curPage != nil)
  doc.curPage.setLineCap(lineCap)

proc setLineJoin*(doc: PDF, lineJoin: LineJoin) =
  assert(doc.curPage != nil)
  doc.curPage.setLineJoin(lineJoin)

proc setMiterLimit*(doc: PDF, miterLimit: float64) =
  assert(doc.curPage != nil)
  doc.curPage.setMiterLimit(miterLimit)

proc setDash*(doc: PDF, dash: openArray[int], phase: int) =
  assert(doc.curPage != nil)
  doc.curPage.setDash(dash, phase)

proc setGrayFill*(doc: PDF; g: float64) =
  assert(doc.curPage != nil)
  doc.curPage.setGrayFill(g)

proc setGrayStroke*(doc: PDF; g: float64) =
  assert(doc.curPage != nil)
  doc.curPage.setGrayStroke(g)

proc setFillColor*(doc: PDF; r,g,b: float64) =
  assert(doc.curPage != nil)
  doc.curPage.setFillColor(r,g,b)

proc setStrokeColor*(doc: PDF; r,g,b: float64) =
  assert(doc.curPage != nil)
  doc.curPage.setStrokeColor(r,g,b)

proc setFillColor*(doc: PDF; col: RGBColor) =
  assert(doc.curPage != nil)
  doc.curPage.setFillColor(col)

proc setStrokeColor*(doc: PDF; col: RGBColor) =
  assert(doc.curPage != nil)
  doc.curPage.setStrokeColor(col)

proc setFillColor*(doc: PDF, col: string) =
  assert(doc.curPage != nil)
  doc.curPage.setFillColor(col)

proc setStrokeColor*(doc: PDF, col: string) =
  assert(doc.curPage != nil)
  doc.curPage.setStrokeColor(col)

proc setCMYKFill*(doc: PDF; c,m,y,k: float64) =
  assert(doc.curPage != nil)
  doc.curPage.setCMYKFill(c,m,y,k)

proc setCMYKStroke*(doc: PDF; c,m,y,k: float64) =
  assert(doc.curPage != nil)
  doc.curPage.setCMYKStroke(c,m,y,k)

proc setCMYKFill*(doc: PDF; col: CMYKColor) =
  assert(doc.curPage != nil)
  doc.curPage.setCMYKFill(col)

proc setCMYKStroke*(doc: PDF; col: CMYKColor) =
  assert(doc.curPage != nil)
  doc.curPage.setCMYKStroke(col)

proc setGradientFill*(doc: PDF, grad: Gradient) =
  assert(doc.curPage != nil)
  doc.curPage.setGradientFill(grad)

proc setAlpha*(doc: PDF, a: float64) =
  assert(doc.curPage != nil)
  doc.curPage.setAlpha(a)

proc setBlendMode*(doc: PDF, bm: BlendMode) =
  assert(doc.curPage != nil)
  doc.curPage.setBlendMode(bm)

proc saveState*(doc: PDF) =
  assert(doc.curPage != nil)
  doc.curPage.saveState()

proc restoreState*(doc: PDF) =
  assert(doc.curPage != nil)
  doc.curPage.restoreState()

proc getTextWidth*(doc: PDF, text: string): float64 =
  assert(doc.curPage != nil)
  doc.curPage.getTextWidth(text)

proc getTextHeight*(doc: PDF, text: string): float64 =
  assert(doc.curPage != nil)
  doc.curPage.getTextHeight(text)

proc clip*(doc: PDF) =
  assert(doc.curPage != nil)
  doc.curPage.clip()

proc executePath*(doc: PDF, p: Path) =
  assert(doc.curPage != nil)
  doc.curPage.executePath(p)

proc drawBounds*(doc: PDF, p: Path) =
  assert(doc.curPage != nil)
  doc.curPage.drawBounds(p)

proc drawBounds*(doc: PDF) =
  assert(doc.curPage != nil)
  doc.curPage.drawBounds()

proc fill*(doc: PDF) =
  assert(doc.curPage != nil)
  doc.curPage.fill()

proc stroke*(doc: PDF) =
  assert(doc.curPage != nil)
  doc.curPage.stroke()

proc fillAndStroke*(doc: PDF) =
  assert(doc.curPage != nil)
  doc.curPage.fillAndStroke()

proc outline*(doc: PDF, title: string, dest: Destination): Outline =
  result = doc.state.newOutline(title, dest)

proc linkAnnot*(doc: PDF, rect: Rectangle, src: Page, dest: Destination): Annot =
  result = doc.state.newLinkAnnot(rect, src, dest)

proc textAnnot*(doc: PDF, rect: Rectangle, src: Page, content: string): Annot =
  result = doc.state.newTextAnnot(rect, src, content)

proc setPassword*(doc: PDF, ownerPass, userPass: string): bool =
  result = doc.state.setPassword(ownerPass, userPass)

proc setEncryptionMode*(doc: PDF, mode: EncryptMode) =
  doc.state.setEncryptionMode(mode)

proc newTextField*(doc: PDF, x,y,w,h: float64, id: string): TextField =
  assert(doc.curPage != nil)

  let xx = doc.state.fromUser(x)
  let yy = doc.state.vPoint(y)
  let ww = doc.state.fromUser(w)
  let hh = doc.state.vPointMirror(h)

  result = newTextField(doc.state, xx, yy, ww, hh, id)
  doc.curPage.addWidget result
  discard doc.state.newAcroForm()

proc newCheckBox*(doc: PDF, x,y,w,h: float64, id: string): CheckBox =
  assert(doc.curPage != nil)

  let xx = doc.state.fromUser(x)
  let yy = doc.state.vPoint(y)
  let ww = doc.state.fromUser(w)
  let hh = doc.state.vPointMirror(h)

  result = newCheckBox(doc.state, xx, yy, ww, hh, id)
  doc.curPage.addWidget result
  discard doc.state.newAcroForm()

proc newRadioButton*(doc: PDF, x,y,w,h: float64, id: string): RadioButton =
  assert(doc.curPage != nil)

  let xx = doc.state.fromUser(x)
  let yy = doc.state.vPoint(y)
  let ww = doc.state.fromUser(w)
  let hh = doc.state.vPointMirror(h)

  result = newRadioButton(doc.state, xx, yy, ww, hh, id)
  doc.curPage.addWidget result
  discard doc.state.newAcroForm()

proc newComboBox*(doc: PDF, x,y,w,h: float64, id: string): ComboBox =
  assert(doc.curPage != nil)

  let xx = doc.state.fromUser(x)
  let yy = doc.state.vPoint(y)
  let ww = doc.state.fromUser(w)
  let hh = doc.state.vPointMirror(h)

  result = newComboBox(doc.state, xx, yy, ww, hh, id)
  doc.curPage.addWidget result
  discard doc.state.newAcroForm()

proc newListBox*(doc: PDF, x,y,w,h: float64, id: string): ListBox =
  assert(doc.curPage != nil)

  let xx = doc.state.fromUser(x)
  let yy = doc.state.vPoint(y)
  let ww = doc.state.fromUser(w)
  let hh = doc.state.vPointMirror(h)

  result = newListBox(doc.state, xx, yy, ww, hh, id)
  doc.curPage.addWidget result
  discard doc.state.newAcroForm()

proc newPushButton*(doc: PDF, x,y,w,h: float64, id: string): PushButton =
  assert(doc.curPage != nil)

  let xx = doc.state.fromUser(x)
  let yy = doc.state.vPoint(y)
  let ww = doc.state.fromUser(w)
  let hh = doc.state.vPointMirror(h)

  result = newPushButton(doc.state, xx, yy, ww, hh, id)
  doc.curPage.addWidget result
  discard doc.state.newAcroForm()
