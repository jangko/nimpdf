# Copyright (c) 2015 Andri Lim
#
# Distributed under the MIT license 
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------
#

import streams, math, basic2d
import nimPDF, spline

type
  Canvas = ref object
    width, height: float64
    cright, cleft, ctop, cbottom: float64
    XTransform, YTransform: TFunction
    doc: Document
    
proc draw_title(doc: Document, text:string) = 
  let size = doc.getSize()
  
  doc.setFont("Helvetica", {FS_BOLD}, 5)
  let tw = doc.getTextWidth(text)
  let x = size.width.toMM/2 - tw/2
  
  doc.setRGBFill(0,0,0)
  doc.drawText(x, 10.0, text)
  doc.setRGBStroke(0,0,0)
  doc.drawRect(10,15,size.width.toMM - 20, size.height.toMM-25)
  doc.stroke()
 
proc makeCanvas(doc: Document): Canvas =
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

proc Transform(cnv: Canvas, p: TPoint2d): TPoint2d =
  result = point2d(cnv.XTransform.Val(p.x), cnv.YTransform.Val(p.y))
  
proc drawBBox(doc:Document, p: Path) =
  let bounds = p.calculateBounds()
  doc.setDash([3], 1)
  doc.setRGBStroke(makeRGB("skyblue"))
  doc.drawRect(bounds.xmin, bounds.ymin, bounds.xmax - bounds.xmin, bounds.ymax - bounds.ymin)  
  doc.stroke()
  doc.setDash([], 0)
  
proc addCurve(cnv: Canvas, curve: Curve, fstart, fend: float64, segments: int) =
  let tf = TransformedCurve(curve, cnv.XTransform, cnv.YTransform)
  var path = CubicBezierGeometry(tf, fstart, fend, segments)
  cnv.doc.executePath(path)
  cnv.doc.stroke()
  cnv.doc.drawBBox(path)

proc addCyclicCurve(cnv: Canvas, curve: CyclicCurve, segments:int) =
  let tf = TransformedCurve(curve, cnv.XTransform, cnv.YTransform)
  var path = CubicBezierGeometry(tf, curve.CycleStart, curve.CycleEnd, segments)
  cnv.doc.executePath(path)
  cnv.doc.stroke()
  cnv.doc.drawBBox(path)
  
proc addFunction(cnv: Canvas, f: TFunction, fstart, fend: float64, segments: int) =
  let tf = makeTransformedFunction(f, cnv.XTransform, cnv.YTransform)
  var path = CubicBezierGeometry(tf, fstart, fend, segments)
  cnv.doc.executePath(path)
  cnv.doc.stroke()
  cnv.doc.drawBBox(path)
  
proc drawCurve(cnv:Canvas, c: CyclicCurve, x, y: float64) =
  cnv.doc.saveState()
  cnv.doc.move(x,y)
  cnv.doc.setRGBStroke(makeRGB("pink"))
  cnv.addCyclicCurve(c, 60)
  cnv.doc.restoreState()

proc drawFunction(cnv:Canvas, c: TFunction, x, y: float64) =
  cnv.doc.saveState()
  cnv.doc.move(x,y)
  cnv.doc.setRGBStroke(makeRGB("pink"))
  cnv.addFunction(c, 0, degree_to_radian(360), 50)
  cnv.doc.restoreState()
  
proc createPDF(doc: Document) = 
  let size = getSizeFromName("A4")
  doc.addPage(size, PGO_PORTRAIT)
  draw_title(doc, "Bezier Bounding Box Demo")
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

  cnv.drawCurve(rose, 10, 20)
  cnv.drawCurve(lisa, 70, 20)
  cnv.drawCurve(epic, 140, 20)
  cnv.drawCurve(epit, 10, 90)
  cnv.drawCurve(farris, 70, 90)
  cnv.drawCurve(hipoc, 140, 90)
  cnv.drawCurve(hipot, 10, 150)
  
  cnv.cleft = -5
  cnv.cright = 5
  cnv.drawFunction(sine, 70, 150)

  doc.addPage(size, PGO_PORTRAIT)
  draw_title(doc, "Gradient Demo")
   
  var coord = makeCoord(0,0,1,0)
  var gd = makeLinearGradient(makeRGB("red"), makeRGB("blue"), coord)
  doc.setGradientFill(gd)
  doc.drawCircle(50, 50, 30)
  doc.roundRect(50, 50, 30, 30, 10)
  doc.fill()

  coord = makeCoord(0,0,0,1)
  gd = makeLinearGradient(makeRGB("yellow"), makeRGB("pink"), coord)
  doc.setGradientFill(gd)
  doc.roundRect(150, 50, 30, 30, 10)
  doc.drawEllipse(100, 90, 30, 10)
  doc.fill()

  coord = makeCoord(0,0,1,1)
  gd = makeLinearGradient(makeRGB("green"), makeRGB("yellow"), coord)
  doc.setGradientFill(gd)
  doc.roundRect(10, 70, 30, 30, 10)
  doc.drawEllipse(70, 100, 30, 10)
  doc.fillAndStroke()

proc main(): bool {.discardable.} = 
  var fileName = "curve.pdf"
  var file = newFileStream(fileName, fmWrite)
  
  if file != nil:
    var doc = initPDF()
    doc.createPDF()
    doc.writePDF(file)
    file.close()
    echo "OK"
    return true
  
  echo "cannot open: ", fileName
  result = false

main()