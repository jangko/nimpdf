# Copyright (c) 2015 Andri Lim
#
# Distributed under the MIT license
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------
# demo for various features implemented in nimPDF
# also act as how to use, while the proper documentation being generated

import streams, math, basic2d, nimPDF, spline

type
  Canvas = ref object
    width, height: float64
    cright, cleft, ctop, cbottom: float64
    XTransform, YTransform: TFunction
    doc: PDF

proc draw_circles(doc: PDF, desc: string, x, y: float64) =
  let radius = 10.0
  let r2 = radius / 2
  doc.setLineWidth(0.5)
  doc.setStrokeColor(0.0, 0.0, 0.0)
  doc.setFillColor(1.0, 0.0, 0.0)
  doc.drawCircle(x + radius, y + radius, radius)
  doc.fillAndStroke()
  doc.setFillColor(0.0, 1.0, 0.0)
  doc.drawCircle(x + radius + radius + r2, y + radius, radius)
  doc.fillAndStroke()
  doc.setFillColor(0.0, 0.0, 1.0)
  doc.drawCircle(x + radius + (radius + r2)/2, y + radius + radius, radius)
  doc.fillAndStroke()

  doc.setFillColor(0.0, 0.0, 0.0)
  doc.drawText(x + 0.0, y + radius * 4, desc)

proc draw_title(doc: PDF, text:string) =
  let size = getSizeFromName("A4")

  doc.setFont("Helvetica", {FS_BOLD}, 5)
  let tw = doc.getTextWidth(text)
  let x = size.width.toMM/2 - tw/2

  doc.setFillColor(0,0,0)
  doc.drawText(x, 10.0, text)
  doc.setStrokeColor(0,0,0)
  doc.drawRect(10,15,size.width.toMM - 20, size.height.toMM-25)
  doc.stroke()

proc draw_demo_1(doc: PDF) =
  let size = getSizeFromName("A4")

  doc.addPage(size, PGO_PORTRAIT)
  draw_title(doc, "GRAPHIC STATE DEMO")

  doc.setFont("Helvetica", {FS_BOLD}, 5)

  draw_circles(doc, "normal", 20, 20)

  doc.saveState()
  doc.setAlpha(0.8)
  draw_circles(doc, "alpha fill = 0.8", 80, 20)
  doc.restoreState()

  doc.saveState()
  doc.setAlpha(0.4)
  draw_circles(doc, "alpha fill = 0.4", 150, 20)
  doc.restoreState()

  doc.saveState()
  doc.setBlendMode(BM_MULTIPLY)
  draw_circles(doc, "BM_MULTIPLY", 20, 70)
  doc.restoreState()

  doc.saveState()
  doc.setBlendMode(BM_SCREEN)
  draw_circles(doc, "BM_SCREEN", 80, 70)
  doc.restoreState()

  doc.saveState()
  doc.setBlendMode(BM_OVERLAY)
  draw_circles(doc, "BM_OVERLAY", 150, 70)
  doc.restoreState()

  doc.saveState()
  doc.setBlendMode(BM_DARKEN)
  draw_circles(doc, "BM_DARKEN", 20, 120)
  doc.restoreState()

  doc.saveState()
  doc.setBlendMode(BM_LIGHTEN)
  draw_circles(doc, "BM_LIGHTEN", 80, 120)
  doc.restoreState()

  doc.saveState()
  doc.setBlendMode(BM_COLOR_DODGE)
  draw_circles(doc, "BM_COLOR_DODGE", 150, 120)
  doc.restoreState()

  doc.saveState()
  doc.setBlendMode(BM_COLOR_BURN)
  draw_circles(doc, "BM_COLOR_BURN", 20, 170)
  doc.restoreState()

  doc.saveState()
  doc.setBlendMode(BM_SOFT_LIGHT)
  draw_circles(doc, "BM_SOFT_LIGHT", 80, 170)
  doc.restoreState()

  doc.saveState()
  doc.setBlendMode(BM_HARD_LIGHT)
  draw_circles(doc, "BM_HARD_LIGHT", 150, 170)
  doc.restoreState()

  doc.saveState()
  doc.setBlendMode(BM_DIFFERENCE)
  draw_circles(doc, "BM_DIFFERENCE", 20, 220)
  doc.restoreState()

  doc.saveState()
  doc.setBlendMode(BM_EXCLUSION)
  draw_circles(doc, "BM_EXCLUSION", 80, 220)
  doc.restoreState()

proc draw_demo_2(doc: PDF) =
  let size = getSizeFromName("A4")
  doc.addPage(size, PGO_PORTRAIT)

  draw_title(doc, "ARC DEMO")

  let radius = 80.0
  let cx = 100.0
  let cy = 100.0

  doc.setFillColor(1.0,0.0,0.0)
  doc.drawArc(cx, cy, radius, radius, 0, 90)
  doc.lineTo(cx, cy)
  doc.closePath()
  doc.fill()

  doc.setFillColor(0.0,1.0,0.0)
  doc.drawArc(cx, cy, radius, radius, 90, 70)
  doc.lineTo(cx, cy)
  doc.closePath()
  doc.fill()

  doc.setFillColor(0.0,0.0,1.0)
  doc.drawArc(cx, cy, radius, radius, 160, 80)
  doc.lineTo(cx, cy)
  doc.closePath()
  doc.fill()

  doc.setFillColor(1.0,1.0,0.0)
  doc.drawArc(cx, cy, radius, radius, 240, 120)
  doc.lineTo(cx, cy)
  doc.closePath()
  doc.fill()

  doc.setFillColor(1.0,1.0,1.0)
  doc.drawCircle(cx,cy,radius * 0.5)
  doc.fill()

  doc.setStrokeColor(initRGB("indigo"))
  doc.drawEllipse(100, 250, 60, 20)
  doc.drawEllipse(100, 230, 20, 40)
  doc.stroke()

proc draw_demo_3(doc: PDF) =
  let size = getSizeFromName("A4")
  doc.addPage(size, PGO_PORTRAIT)

  draw_title(doc, "ADOBE STANDARD FONT DEMO")

  let fonts = [("Courier", {FS_REGULAR}),
  ("Courier", {FS_BOLD}),
  ("Courier", {FS_ITALIC}),
  ("Courier", {FS_BOLD, FS_ITALIC}),
  ("Helvetica", {FS_REGULAR}),
  ("Helvetica", {FS_BOLD}),
  ("Helvetica", {FS_ITALIC}),
  ("Helvetica", {FS_BOLD, FS_ITALIC}),
  ("Times",{FS_REGULAR}),
  ("Times",{FS_BOLD}),
  ("Times",{FS_ITALIC}),
  ("Times",{FS_BOLD, FS_ITALIC}),
  ("Symbol",{FS_REGULAR}),
  ("ZapfDingbats",{FS_REGULAR})]

  let text = "abcdefgABCDEFG12345!#$%&+-@?\\()[]<>\""
  var y = 25.0
  for f in fonts:
    var name = f[0]

    if FS_BOLD in f[1]:
      name.add(" Bold")
    if FS_ITALIC in f[1]:
      name.add(" Italic")

    doc.setFont("Helvetica", {FS_REGULAR}, 4)
    doc.drawText(20.0, y, name)
    y += 7.0

    doc.setFont(f[0], f[1], 5)
    doc.drawText(20.0, y, text)
    y += 7.0

proc draw_demo_4(doc: PDF) =
  let size = getSizeFromName("A4")
  doc.addPage(size, PGO_PORTRAIT)

  doc.setFont("Times", {FS_REGULAR}, 4)
  let gray_thin = initRGB(0.5,0.5,0.5)
  let gray_bold = initRGB(0.8,0.8,0.8)

  doc.setFillColor(gray_thin)
  doc.setStrokeColor(gray_bold)

  let width = size.width.toMM
  let height = size.height.toMM

  #Draw horizontal lines
  var y = 0.0
  while y < height:
    if `mod`(y, 10.0) == 0.0:
      doc.setLineWidth(0.3)
    else:
      doc.setLineWidth(0.1)

    doc.moveTo(0, y)
    doc.lineTo(width, y)
    doc.stroke()

    if (`mod`(y, 10.0) == 0) and (y > 0):
      doc.setStrokeColor(gray_thin)

      doc.moveTo(0, y)
      doc.lineTo(5, y)
      doc.stroke()

      doc.setStrokeColor(gray_bold)

    y += 5.0

  #Draw vertical lines
  var x = 0.0
  while x < width:
    if `mod`(x, 10) == 0:
      doc.setLineWidth(0.3)
    else:
      doc.setLineWidth(0.1)

    doc.moveTo(x, 0)
    doc.lineTo(x, height)
    doc.stroke()

    if (`mod`(x,50.0) == 0) and (x > 0):
      doc.setStrokeColor(gray_thin)

      doc.moveTo(x, 0)
      doc.lineTo(x, 5)
      doc.stroke()

      doc.moveTo(x, height - 5)
      doc.lineTo(x, height)
      doc.stroke()

      doc.setStrokeColor(gray_bold)
    x += 5.0

  # Draw horizontal text
  y = 0.0
  while y < height:
    if (`mod`(y,10.0) == 0) and (y > 0):
      doc.drawText(5, y - 2, $y)
    y += 5.0

  #Draw vertical text
  x = 0
  while x < width:
    if (`mod`(x,50) == 0) and (x > 0):
      doc.drawText(x, 5, $x)
      doc.drawText(x, height - 5, $x)
    x += 5.0


proc show_desc(doc: PDF; x,y: float; text:string) =
  doc.moveTo(x, y - 10)
  doc.lineTo(x, y + 5)
  doc.moveTo(x - 5, y)
  doc.lineTo(x + 10, y)
  doc.stroke()

  doc.setFont("Times", {FS_REGULAR}, 4)
  doc.setFillColor(0, 0, 0)

  var buf = "(x=" & $x & ",y=" & $y & ")"

  doc.drawText(x + 10 - doc.getTextWidth(buf), y + 15, buf)
  doc.drawText(x + 10 - doc.getTextWidth(text), y + 10, text)

proc draw_demo_5(doc: PDF) =
  let size = getSizeFromName("A4")
  doc.addPage(size, PGO_PORTRAIT)
  draw_title(doc, "IMAGE DEMO")

  doc.setFont("Times", {FS_REGULAR}, 3)

  var image = doc.loadImage("basn3p02.png")
  var x = 40.0
  var y = 40.0
  doc.drawImage(x, y, image)
  show_desc(doc, x, y, "Actual Size")

  x += 60.0
  doc.saveState()
  doc.stretch(1.5, 1, x, y)
  doc.drawImage(x, y, image)
  doc.restoreState()
  show_desc(doc, x, y, "Scaling image (X direction)")

  x += 60.0
  doc.saveState()
  doc.stretch(1, 1.5, x, y)
  doc.drawImage(x, y, image)
  doc.restoreState()
  show_desc(doc, x, y, "Scaling image (Y direction)")

  x = 40.0
  y += 50.0
  doc.saveState()
  doc.rotate(30.0, x, y)
  doc.drawImage(x, y, image)
  doc.restoreState()
  show_desc(doc, x, y, "Rotating Image")

  x += 60.0
  doc.saveState()
  doc.skew(10, 20, x, y)
  doc.drawImage(x, y, image)
  doc.restoreState()
  show_desc(doc, x, y, "Skewing Image")

  var toucan = doc.loadImage("toucan.png")
  x += 60.0
  doc.setStrokeColor(initRGB("red"))
  doc.drawCircle(x,y,20.0)
  doc.stroke()
  doc.saveState()
  doc.stretch(0.5, 0.5, x, y)
  doc.drawImage(x, y, toucan)
  doc.restoreState()
  show_desc(doc, x, y, "PNG trans")

  x = 40.0
  y += 50.0
  var one = doc.loadImage("1bit.bmp")
  doc.drawImage(x, y, one)
  show_desc(doc, x, y, "bmp 1 bit")

  x += 60.0
  var two = doc.loadImage("4bit.bmp")
  doc.drawImage(x, y, two)
  show_desc(doc, x, y, "bmp 4 bit")

  x += 60.0
  var tri = doc.loadImage("8bit.bmp")
  doc.saveState()
  doc.stretch(0.5, 0.5, x, y)
  doc.drawImage(x, y, tri)
  doc.restoreState()
  show_desc(doc, x, y, "bmp 8 bit")

  x = 40.0
  y += 50.0
  var four = doc.loadImage("16bit.bmp")
  doc.drawImage(x, y, four)
  show_desc(doc, x, y, "bmp 16 bit")

  x += 60.0
  var fiv = doc.loadImage("24bit.bmp")
  doc.saveState()
  doc.stretch(0.5, 0.5, x, y)
  doc.drawImage(x, y, fiv)
  doc.restoreState()
  show_desc(doc, x, y, "bmp 24 bit")

  x += 60.0
  var six = doc.loadImage("32bit.bmp")
  doc.drawImage(x, y, six)
  show_desc(doc, x, y, "bmp 32 bit")

  doc.saveState()
  image = doc.loadImage("missing.jpg")
  x = 40.0
  y += 50
  doc.drawImage(x, y, image)
  show_desc(doc, x, y, "Original")

  x += 60
  doc.setAlpha(0.8)
  doc.drawImage(x, y, image)
  show_desc(doc, x, y, "Alpha = 0.8")

  x += 60
  doc.setAlpha(0.4)
  doc.drawImage(x, y, image)
  show_desc(doc, x, y, "Alpha = 0.4")
  doc.restoreState()

  doc.drawText(50, y + 30, "Adjustable Image Transparency")

proc draw_line(doc: PDF, x, y: float64, label:string) =
  doc.drawText(x, y - 10, label)
  doc.moveTo(x, y - 15)
  doc.lineTo(x + 60, y - 15)
  doc.stroke()

proc draw_line2(doc: PDF, x, y: float64, label:string) =
  doc.drawText(x, y - 10, label)
  doc.moveTo(x + 10, y)
  doc.lineTo(x + 60, y)
  doc.stroke()

proc draw_rect(doc: PDF, x, y: float64, label:string) =
  doc.drawText(x, y, label)
  doc.drawRect(x, y + 2, 60, 10)

proc drawJoin(doc: PDF, x, y: float64, label:string, join: LineJoin) =
  doc.setLineJoin(join)
  doc.moveTo(x+10, y+10)
  doc.lineTo(x+20, y)
  doc.lineTo(x+30, y+10)
  doc.stroke()
  doc.drawText(x, y - 5, label)

proc draw_demo_6(doc: PDF) =
  let size = getSizeFromName("A4")
  doc.addPage(size, PGO_PORTRAIT)

  draw_title(doc, "LINE DEMO")

  doc.setFont("Times", {FS_REGULAR}, 3)

  #Draw various widths of lines.
  doc.setLineWidth(0)
  draw_line(doc, 20, 40, "line width = 0")

  doc.setLineWidth(0.5)
  draw_line(doc, 20, 50, "line width = 0.5")

  doc.setLineWidth(1.0)
  draw_line(doc, 20, 60, "line width = 1.0")

  #Line dash pattern
  doc.setLineWidth(0.3)
  doc.setDash([3], 1)
  draw_line(doc, 20, 70, "dash_ptn=[3], phase=1 -- 2 on, 3 off, 3 on...")

  doc.setDash([7,3], 2)
  draw_line(doc, 20, 80, "dash_ptn=[7, 3], phase=2 -- 5 on 3 off, 7 on,...")

  doc.setDash([8,7,2,7], 0)
  draw_line(doc, 20, 90, "dash_ptn=[8, 7, 2, 7], phase=0")

  doc.setDash([], 0)

  doc.setLineWidth(10)
  doc.setStrokeColor(initRGB("green"))

  #Line Cap Style
  doc.setLineCap(BUTT_END)
  draw_line2(doc, 20, 100, "BUTT_END")

  doc.setLineCap(ROUND_END)
  draw_line2(doc, 20, 120, "ROUND_END")

  doc.setLineCap(SQUARE_END)
  draw_line2(doc, 20, 140, "SQUARE_END")


  #Line Join Style
  doc.setLineWidth(10)
  doc.setStrokeColor(initRGB("blue"))

  drawJoin(doc, 30, 180, "MITER JOIN", MITER_JOIN)
  drawJoin(doc, 30, 210, "ROUND JOIN", ROUND_JOIN)
  drawJoin(doc, 30, 240, "BEVEL JOIN", BEVEL_JOIN)

  # Draw Rectangle
  doc.setLineWidth(0.5)
  doc.setStrokeColor(0,0,0)
  doc.setFillColor(initRGB("maroon"))

  draw_rect(doc, 100, 20, "Stroke");
  doc.stroke()

  draw_rect(doc, 100, 40, "Fill");
  doc.fill()

  draw_rect(doc, 100, 60, "Fill then Stroke")
  doc.fillAndStroke()

  #Clip Rect
  doc.saveState()
  draw_rect(doc, 100, 80, "Clip Rectangle")
  doc.clip()
  doc.stroke()
  doc.setFont("Times", {FS_REGULAR}, 4)
  doc.drawText(100, 84, "Clip Clip Clip Clip Clip Clipi Clip Clip Clip")
  doc.drawText(100, 88, "Clip Clip Clip Clip Clip Clipi Clip Clip Clip")
  doc.drawText(100, 92, "Clip Clip Clip Clip Clip Clipi Clip Clip Clip")

  doc.restoreState()

  var cx = 120.0
  var cy = 140.0
  var cpx = 160.0
  var cpy = 100.0
  var x = 180.0
  var y = 120.0

  doc.setLineWidth(0.5)
  doc.moveTo(cx, cy)
  doc.curveTo1(cpx, cpy, x, y)
  doc.stroke()

  doc.setLineWidth(0.2)
  doc.setDash([3], 1)
  doc.moveTo(x,y)
  doc.lineTo(cpx, cpy)
  doc.stroke()
  doc.setDash([], 0)

  doc.drawText(cx,cpy, "curveTo1(cpx,cpy,x,y)")
  doc.drawText(cx+3,cy, "current point")
  doc.drawText(cpx+3,cpy, "(cpx,cpy)")
  doc.drawText(x+3,y, "(x,y)")

  cx = 120.0
  cy = 190.0
  cpx = 160.0
  cpy = 160.0
  x = 180.0
  y = 180.0

  doc.setLineWidth(0.5)
  doc.moveTo(cx, cy)
  doc.curveTo2(cpx, cpy, x, y)
  doc.stroke()

  doc.setLineWidth(0.2)
  doc.setDash([3], 1)
  doc.moveTo(cx,cy)
  doc.lineTo(cpx, cpy)
  doc.stroke()
  doc.setDash([], 0)

  doc.drawText(cx,cpy, "curveTo2(cpx,cpy,x,y)")
  doc.drawText(cx+3,cy, "current point")
  doc.drawText(cpx+3,cpy, "(cpx,cpy)")
  doc.drawText(x+3,y, "(x,y)")


  cx = 120.0
  cy = 270.0
  cpx = 130.0
  cpy = 240.0
  x = 180.0
  y = 260.0
  var cp2x = 160.0
  var cp2y = 230.0

  doc.setLineWidth(0.5)
  doc.moveTo(cx, cy)
  doc.bezierCurveTo(cpx, cpy, cp2x, cp2y, x, y)
  doc.stroke()

  doc.setLineWidth(0.2)
  doc.setDash([3], 1)
  doc.moveTo(cx,cy)
  doc.lineTo(cpx, cpy)
  doc.stroke()
  doc.moveTo(x,y)
  doc.lineTo(cp2x, cp2y)
  doc.stroke()
  doc.setDash([], 0)

  doc.drawText(cx,cpy-25, "bezierCurveTo(cp1x,cp1y,cp2x,cp2y,x,y)")
  doc.drawText(cx+3,cy, "current point")
  doc.drawText(cpx+3,cpy, "(cpx,cpy)")
  doc.drawText(cp2x+3,cp2y, "(cp2x,cp2y)")
  doc.drawText(x+3,y, "(x,y)")

proc draw_stripe_pattern(doc: PDF; x,y:float64) =
  var iy = 0.0

  while iy < 10:
    doc.setStrokeColor(0.0, 0.0, 0.5)
    doc.setLineWidth(0.1)
    doc.moveTo(x, y - iy)
    doc.lineTo(x + 200, y - iy)
    doc.stroke()
    iy += 0.8

  doc.setLineWidth(0.4)


proc draw_demo_7(doc: PDF) =
  draw_demo_4(doc)
  draw_title(doc, "TEXT DEMO 1")

  let samp_text = "abcdefgABCDEFG123!#$%&+-@?"

  var size = 3.0
  var y = 20.0
  doc.setFillColor(0,0,0)
  while size < 13:
    doc.setFont("Helvetica", {FS_REGULAR}, size)
    doc.drawText(20, y, samp_text)
    doc.setFont("Times", {FS_REGULAR}, 3)
    y += 4
    doc.drawText(20, y, "Font Size = " & $size)
    y += size + 5
    size = size + 2

  doc.setFont("Helvetica", {FS_ITALIC}, 8.0)
  doc.beginText(20, y)
  #doc.moveTextPos(20, y)

  let len = samp_text.len
  var buf = " "
  for i in 0..len-1:
    let r = i / len
    let g = 1 - (i / len)
    buf[0] = samp_text[i]
    doc.setFillColor(r,g,0)
    doc.showText(buf)

  doc.moveTextPos(0, 9.0)

  for i in 0..len-1:
    let r = i / len
    let b = 1 - (i / len)
    buf[0] = samp_text[i]
    doc.setFillColor(r,0,b)
    doc.showText(buf)

  doc.moveTextPos(0, 9.0)

  for i in 0..len-1:
    let b = i / len
    let g = 1 - (i / len)
    buf[0] = samp_text[i]
    doc.setFillColor(0,g,b)
    doc.showText(buf)

  doc.endText()

  y += 35.0
  doc.setFont("Helvetica", {FS_REGULAR}, 3.0)
  doc.setFillColor(initRGB("black"))
  doc.drawText(20, y, "Text Rendering Mode:")

  #Font rendering mode
  doc.setFont("Helvetica", {FS_REGULAR}, 9.0)
  doc.setFillColor(0.5,0.5,0.0)
  doc.setLineWidth(0.4)
  doc.setStrokeColor(1,0,0)

  #PDF_FILL
  y += 10.0
  doc.setTextRenderingMode(TR_FILL)
  doc.drawText(20, y, "TR_FILL")

  #PDF_STROKE
  y += 10.0
  doc.setTextRenderingMode(TR_STROKE)
  doc.drawText(20, y, "TR_STROKE")

  #PDF_FILL_THEN_STROKE
  y += 10.0
  doc.setTextRenderingMode(TR_FILL_THEN_STROKE)
  doc.drawText(20, y, "TR_FILL_THEN_STROKE")

  #TR_FILL_CLIPPING
  y += 10.0
  doc.saveState()
  doc.setTextRenderingMode(TR_FILL_CLIPPING)
  doc.drawText(20, y, "TR_FILL_CLIPPING")
  draw_stripe_pattern(doc, 20, y)
  doc.restoreState()

  #TR_STROKE_CLIPPING
  y += 10.0
  doc.saveState()
  doc.setTextRenderingMode(TR_STROKE_CLIPPING)
  doc.drawText(20, y, "TR_STROKE_CLIPPING")
  draw_stripe_pattern(doc, 20, y)
  doc.restoreState()

  #PDF_FILL_STROKE_CLIPPING
  y += 10.0
  doc.saveState()
  doc.setTextRenderingMode(TR_FILL_STROKE_CLIPPING)
  doc.drawText(20, y, "TR_FILL_STROKE_CLIPPING")
  draw_stripe_pattern(doc, 20, y)
  doc.restoreState()

  doc.setFont("Helvetica", {FS_REGULAR}, 9.0)
  doc.setFillColor(initRGB("red"))
  let samp_text2 = "ABC123xyz"
  let oldy = y
  doc.setTextRenderingMode(TR_FILL)

  y += 30
  doc.saveState()
  doc.rotate(20, 20, y)
  doc.drawText(20, y, samp_text2)
  doc.restoreState()

  doc.saveState()
  doc.skew(10, 20, 100, y)
  doc.drawText(100, y, samp_text2)
  doc.restoreState()

  y += 30
  doc.saveState()
  doc.stretch(1, 2, 20, y)
  doc.drawText(20, y, samp_text2)
  doc.restoreState()

  doc.saveState()
  doc.stretch(2, 1, 100, y)
  doc.drawText(100, y, samp_text2)
  doc.restoreState()

  doc.setFont("Times", {FS_REGULAR}, 3.0)
  doc.setFillColor(initRGB("black"))
  y = oldy + 35
  doc.drawText(20, y, "Rotating Text")
  doc.drawText(100, y, "Skewing Text")
  y += 35
  doc.drawText(20, y, "Scaling Text Y Direction")
  doc.drawText(100, y, "Scaling Text X Direction")

proc draw_demo_8(doc: PDF) =
  draw_demo_4(doc)
  draw_title(doc, "TEXT DEMO 2")

  doc.setFont("Helvetica", {FS_REGULAR}, 3.0)
  doc.setFillColor(initRGB("black"))
  doc.drawText(20, 20, "char-spacing 0")
  doc.drawText(20, 40, "char-spacing 1.5")
  doc.drawText(20, 60, "char-spacing 1.5, word-spacing 2.5")

  let samp_text = "The quick brown fox jumps over the lazy dog."
  doc.setFont("Times", {FS_REGULAR}, 7.0)
  doc.setFillColor(initRGB("seagreen"))
  doc.saveState()
  doc.setCharSpace(0)
  doc.drawText(20, 30, samp_text)
  doc.setCharSpace(1.5)
  doc.drawText(20, 50, samp_text)
  doc.setWordSpace(2.5)
  doc.drawText(20, 70, samp_text)
  doc.restoreState()

  # text along a circle
  let size = getSizeFromName("A4")
  let height = size.height.toPT

  doc.setStrokeColor(initRGB("fuchsia"))
  doc.setFillColor(initRGB("orange"))
  doc.setLineWidth(0.3)
  let cx = 110.0
  let cy = 170.0
  doc.drawCircle(cx, cy, 90)
  doc.drawCircle(cx, cy, 70)
  doc.stroke()

  let angle1 = 360.0 / float(samp_text.len)
  var angle2 = 180.0

  doc.setFont("Courier", {FS_BOLD}, 16)
  doc.beginText()
  var buf = " "
  let radii = fromMM(76).toPT

  for c in samp_text:
    let rad1 = degree_to_radian(angle2 - 90)
    let rad2 = degree_to_radian(angle2)

    let x = fromMM(cx).toPT + cos(rad2) * radii
    let y = height - fromMM(cy).toPT + sin(rad2) * radii

    doc.setTextMatrix(matrix2d(cos(rad1), sin(rad1), -sin(rad1), cos(rad1), x, y))

    buf[0] = c
    doc.showText(buf)
    angle2 -= angle1

  doc.endText()

  var img = doc.loadImage("monkey.png")
  doc.saveState()
  let ccx = cx - doc.toUser(float(img.width))/4
  let ccy = doc.toUser(height) - (cy - doc.toUser(float(img.width))/2) - 10
  doc.scale(0.5,ccx, ccy)
  doc.drawImage(ccx, ccy, img)
  doc.restoreState()

type
  tspec = tuple[x0, y0, w, h: float, num_x, num_y, step_x, step_y: int]
  tproc = proc(doc: PDF, rng, x, y: int)

proc rgb1(doc: PDF, rng, x, y: int) =
  let r = float(rng)
  doc.setFillColor(float(x)/r, float(y)/r, 0.0)
  doc.setStrokeColor(float(x)/r, float(y)/r, 0.0)

proc rgb2(doc: PDF, rng, x, y: int) =
  let r = float(rng)
  doc.setFillColor(float(x)/r, 0.0, float(y)/r)
  doc.setStrokeColor(float(x)/r, 0.0, float(y)/r)

proc rgb3(doc: PDF, rng, x, y: int) =
  let r = float(rng)
  doc.setFillColor(0.0,float(x)/r, float(y)/r)
  doc.setStrokeColor(0.0,float(x)/r, float(y)/r)

proc cmyk1(doc: PDF, rng, x, y: int) =
  let r = float(rng)
  doc.setCMYKFill(float(x)/r, float(y)/r, 0.0, 0.0)
  doc.setCMYKStroke(float(x)/r, float(y)/r, 0.0, 0.0)

proc cmyk2(doc: PDF, rng, x, y: int) =
  let r = float(rng)
  doc.setCMYKFill(float(x)/r, 0.0, float(y)/r, 0.0)
  doc.setCMYKStroke(float(x)/r, 0.0, float(y)/r, 0.0)

proc cmyk3(doc: PDF, rng, x, y: int) =
  let r = float(rng)
  doc.setCMYKFill(0.0,float(x)/r, float(y)/r, 0.0)
  doc.setCMYKStroke(0.0,float(x)/r, float(y)/r, 0.0)

proc gray1(doc: PDF, rng, x, y: int) =
  let r = float(rng)
  doc.setGrayFill(float(x)/r)
  doc.setGrayStroke(float(x)/r)

proc draw_rect_grid(doc: PDF, spec: tspec, it: tproc) =
  # spec.x0,y0,w,h,nx,ny,step_x, step_y
  for yc in 0..spec.num_y-1:
    for xc in 0..spec.num_x-1:
      let x = spec.x0 + float(xc)*spec.w + float(xc*spec.step_x)
      let y = spec.y0 + float(yc)*spec.h + float(yc*spec.step_y)
      it(doc, spec.num_x, xc, yc)
      doc.drawRect(x, y, spec.w, spec.h)
      doc.fillAndStroke()

proc draw_demo_9(doc: PDF) =
  let size = getSizeFromName("A4")
  doc.addPage(size, PGO_PORTRAIT)
  draw_title(doc, "COLOR SPACE DEMO")

  doc.setFont("Times", {FS_REGULAR}, 4)

  var spec: tspec = (x0:15.0, y0:25.0, w:3.0, h:3.0, num_x:14, num_y:14, step_x:1, step_y:1)
  draw_rect_grid(doc, spec, rgb1)
  spec.x0 += float(spec.num_x) * spec.w + float(spec.num_x * spec.step_x) + 3.0
  draw_rect_grid(doc, spec, rgb2)
  spec.x0 += float(spec.num_x) * spec.w + float(spec.num_x * spec.step_x) + 3.0
  draw_rect_grid(doc, spec, rgb3)

  spec.x0 = 15.0
  spec.y0 += float(spec.num_y) * spec.h + float(spec.num_y * spec.step_y) + 10.0
  doc.setFillColor(0,0,0)
  doc.drawText(15, spec.y0 - 5, "RGB color space")

  draw_rect_grid(doc, spec, cmyk1)
  spec.x0 += float(spec.num_x) * spec.w + float(spec.num_x * spec.step_x) + 3.0
  draw_rect_grid(doc, spec, cmyk2)
  spec.x0 += float(spec.num_x) * spec.w + float(spec.num_x * spec.step_x) + 3.0
  draw_rect_grid(doc, spec, cmyk3)

  spec.y0 += float(spec.num_y) * spec.h + float(spec.num_y * spec.step_y) + 10.0
  doc.setFillColor(0,0,0)
  doc.drawText(15, spec.y0 - 5, "CMYK color space")

  spec =(x0:15.0, y0:spec.y0, w:6.0, h:6.0, num_x:24, num_y:1, step_x:1, step_y:1)
  draw_rect_grid(doc, spec, gray1)
  doc.setFillColor(0,0,0)
  doc.drawText(15, spec.y0 + 10, "Gray color space")

  doc.setStrokeColor(initRGB("red"))
  doc.setLineWidth(1.0)
  doc.drawRoundRect(20, spec.y0 + 20, 160.0, 30.0, 7.0)
  doc.stroke()

proc makeCanvas(doc: PDF): Canvas =
  var res: Canvas
  new(res)

  res.width = 50
  res.height = 50
  res.doc = doc
  res.cleft = -30.0
  res.cright = 30.0
  res.ctop = 30.0
  res.cbottom = -30.0

  res.XTransform = makeFunction(
    proc (x:float64): float64 = (res.width / (res.cright - res.cleft)) * (x - res.cleft),
    proc (x:float64): float64 = res.width / (res.cright - res.cleft))

  res.YTransform = makeFunction(
    proc (y:float64): float64 = (res.height / (res.cbottom - res.ctop)) * (y - res.ctop),
    proc (y:float64): float64 = res.height / (res.cbottom - res.ctop))

  result = res

#proc Transform(cnv: Canvas, p: Point2d): Point2d =
#  result = point2d(cnv.XTransform.Val(p.x), cnv.YTransform.Val(p.y))

proc drawBBox(doc: PDF, p: Path): bound =
  let bounds = p.calculateBounds()
  doc.setDash([3], 1)
  doc.setStrokeColor(initRGB("skyblue"))
  doc.drawRect(bounds.xmin, bounds.ymin, bounds.xmax - bounds.xmin, bounds.ymax - bounds.ymin)
  doc.stroke()
  doc.setDash([], 0)
  result = bounds

#proc addCurve(cnv: Canvas, curve: Curve, fstart, fend: float64, segments: int): bound =
#  let tf = TransformedCurve(curve, cnv.XTransform, cnv.YTransform)
#  var path = CubicBezierGeometry(tf, fstart, fend, segments)
#  cnv.doc.executePath(path)
#  cnv.doc.stroke()
#  result = cnv.doc.drawBBox(path)

proc addCyclicCurve(cnv: Canvas, curve: CyclicCurve, segments:int): bound =
  let tf = TransformedCurve(curve, cnv.XTransform, cnv.YTransform)
  var path = CubicBezierGeometry(tf, curve.CycleStart, curve.CycleEnd, segments)
  cnv.doc.executePath(path)
  cnv.doc.stroke()
  result = cnv.doc.drawBBox(path)

proc addFunction(cnv: Canvas, f: TFunction, fstart, fend: float64, segments: int): bound =
  let tf = makeTransformedFunction(f, cnv.XTransform, cnv.YTransform)
  var path = CubicBezierGeometry(tf, fstart, fend, segments)
  cnv.doc.executePath(path)
  cnv.doc.stroke()
  result = cnv.doc.drawBBox(path)

proc drawCurve(cnv:Canvas, c: CyclicCurve, x, y: float64, text:string) =
  cnv.doc.saveState()
  cnv.doc.move(x,y)
  cnv.doc.setStrokeColor(initRGB("pink"))
  let bb = cnv.addCyclicCurve(c, 60)
  cnv.doc.drawText(bb.xmin, bb.ymax + 5, text)
  cnv.doc.restoreState()

proc drawFunction(cnv:Canvas, c: TFunction, x, y: float64, text:string) =
  cnv.doc.saveState()
  cnv.doc.move(x,y)
  cnv.doc.setStrokeColor(initRGB("pink"))
  let bb = cnv.addFunction(c, 0, degree_to_radian(360), 50)
  cnv.doc.drawText(bb.xmin, bb.ymax + 5, text)
  cnv.doc.restoreState()


proc draw_demo_10(doc: PDF) =
  let size = getSizeFromName("AA")
  doc.addPage(size, PGO_PORTRAIT)
  draw_title(doc, "Bezier Curve Bounding Box Demo")
  doc.setFont("Times", {FS_REGULAR}, 3)

  var cnv = makeCanvas(doc)
  var sine = makeSine(20, 5, 3)
  var rose = makeRose(20.0, 7, 1)
  var lisa = makeLissaJous(20,20,1,4,0)
  var epic = makeEpicycloid(10,0,5,6)
  var epit = makeEpitrochoid(5,0,1,5,6)
  var farris = makeFarrisWheel(1,7,-17,1,1/2,1/3,0,0,0.5,30,-0.5)
  var hipoc  = makeHipocycloid(20,0,5,7)
  var hipot  = makeHipotrochoid(30,0,-0.75,6,5)

  cnv.drawCurve(rose, 10, 20, "ROSE")
  cnv.drawCurve(lisa, 70, 20, "LISSAJOUSE")
  cnv.drawCurve(epic, 140, 20, "EPICYCLOID")
  cnv.drawCurve(epit, 10, 90, "EPITROCHOID")
  cnv.drawCurve(farris, 70, 90, "FARRIS WHEEL")
  cnv.drawCurve(hipoc, 140, 90, "HIPOCYCLOID")
  cnv.drawCurve(hipot, 10, 150, "HIPOTROCHOID")

  cnv.cleft = -5
  cnv.cright = 5
  cnv.drawFunction(sine, 70, 150, "SINE WAVE")

proc draw_demo_11(doc: PDF) =
  let size = getSizeFromName("AA")
  doc.addPage(size, PGO_PORTRAIT)
  draw_title(doc, "Gradient Demo")

  var coord = initCoord(0,0,1,0)
  var gd = newLinearGradient(initRGB("red"), initRGB("blue"), coord)
  doc.setGradientFill(gd)
  doc.drawCircle(50, 50, 30)
  doc.drawRoundRect(50, 50, 30, 30, 10)
  doc.fill()

  coord = initCoord(0,0,0,1)
  gd = newLinearGradient(initRGB("yellow"), initRGB("pink"), coord)
  doc.setGradientFill(gd)
  doc.drawRoundRect(150, 50, 30, 30, 10)
  doc.drawEllipse(100, 90, 30, 10)
  doc.fill()

  var radCoord = initCoord(0.5,0.5,0,0.5,0.5,1)
  gd = newRadialGradient(initRGB("yellow"), initRGB("brown"), radCoord)
  doc.setGradientFill(gd)
  doc.drawRoundRect(10, 70, 30, 30, 10)
  doc.drawEllipse(70, 100, 30, 10)
  doc.fillAndStroke()

  doc.setFillColor(0,0,0)
  doc.drawText(15, 130, "How gradient works in PDF?")
  doc.drawText(15, 137, "1. Calculate the bounding box")
  doc.drawText(115, 137, "3. Paint gradient inside bbox")

  doc.drawText(15, 197, "2. Set clipping area")
  doc.drawText(115, 197, "4. Voila")

  doc.setStrokeColor(initRGB("black"))
  doc.drawCircle(15+25, 140+25, 25)
  doc.stroke()

  doc.setDash([3], 1)
  doc.setStrokeColor(initRGB("skyblue"))
  doc.drawRect(15, 140, 50, 50)
  doc.drawRect(15, 200, 50, 50)
  doc.drawRect(115, 140, 50, 50)
  doc.drawCircle(15+25, 200+25, 25)
  doc.stroke()
  doc.setDash([], 0)

  doc.setGradientFill(gd)
  doc.drawCircle(115+25, 140+25, 25)
  doc.drawCircle(115+25, 200+25, 25)
  doc.fill()

proc draw_demo_12(doc: PDF) =
  let size = getSizeFromName("A4")
  let SAMP_TEXT = "The Quick Brown Fox Jump Over The Lazy Dog"

  doc.addPage(size, PGO_PORTRAIT)
  draw_title(doc, "TRUE TYPE FONT DEMO")

  doc.setFont("Eunjin", {FS_REGULAR}, 10)
  doc.drawText(15, 50, "헬로우 월드")

  doc.setFont("KaiTi", {FS_REGULAR}, 10)
  doc.drawText(15, 70, "你好世界")

  doc.drawVText(100, 70, "你好世界")
  doc.drawVText(120, 70, "天下大勢")
  doc.drawVText(130, 70, "分久必合")
  doc.drawVText(140, 70, "合久必分")

  #doc.setFont("XANO-mincho-U32", {FS_REGULAR}, 10)
  #doc.drawText(15, 90, "クィ団䪥榜穨 갣갤䤦お珦 稣榥裃觟ユ 嫯滯だ")

  doc.setFont("Calligrapher", {FS_REGULAR}, 10)
  doc.drawText(15, 30, "Hello World!")

  doc.setFont("Calligrapher", {FS_REGULAR}, 4)
  doc.drawText(15, 90, SAMP_TEXT)

  doc.setFont("FreeMono", {FS_REGULAR}, 5'f64, ENC_UTF8)
  doc.drawText(15, 110, "Обычный текст в кодировке UTF-8")

proc draw_demo_13(doc: PDF) =
  let size = getSizeFromName("A1")
  doc.addPage(size, PGO_LANDSCAPE)
  doc.setUnit(PGU_MM)
  doc.setCoordinateMode(BOTTOM_UP)
  let img = doc.loadImage("abc.png")
  doc.drawImage(0,0, img)

proc createPDF(doc: PDF) =
  draw_demo_1(doc)
  draw_demo_2(doc)
  draw_demo_3(doc)
  draw_demo_4(doc)
  draw_demo_5(doc)
  draw_demo_6(doc)
  draw_demo_7(doc)
  draw_demo_8(doc)
  draw_demo_9(doc)
  draw_demo_10(doc)
  draw_demo_11(doc)
  draw_demo_12(doc)
  draw_demo_13(doc)

  doc.setInfo(DI_TITLE, "nimPDF Demo")
  doc.setInfo(DI_AUTHOR, "Andri Lim")
  doc.setInfo(DI_SUBJECT, "A-Z demo")

proc main(): bool {.discardable.} =
  #echo currentSourcePath()
  var fileName = "demo.pdf"
  var file = newFileStream(fileName, fmWrite)

  if file != nil:
    var opts = newPDFOptions()
    opts.addFontsPath("fonts")
    opts.addImagesPath("resources")
    opts.addImagesPath("pngsuite")
    opts.addResourcesPath("resources")

    var doc = newPDF(opts)
    doc.createPDF()
    doc.writePDF(file)
    file.close()
    echo "OK"
    return true

  echo "cannot open: ", fileName
  result = false

main()
