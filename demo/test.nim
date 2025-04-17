import
  std/[streams, strutils],
  nimPDF,
  unittest

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

proc createPDF(doc: PDF) =
  let size = getSizeFromName("A4")
  let SAMP_TEXT = "The Quick Brown Fox Jump Over The Lazy Dog"

  doc.addPage(size, PGO_PORTRAIT)
  draw_title(doc, "TRUE TYPE FONT DEMO")

  doc.setFont("Eunjin", {FS_REGULAR}, 10)
  doc.drawText(15, 50, "헬로우 월드")

  doc.setFont("KaiTi", {FS_REGULAR}, 10)
  doc.drawText(15, 70, "你好世界")

  doc.setFont("Calligrapher", {FS_REGULAR}, 10)
  doc.drawText(15, 30, "Hello World!")

  doc.setFont("Calligrapher", {FS_REGULAR}, 4)
  doc.drawText(15, 90, SAMP_TEXT)

  doc.setInfo(DI_TITLE, "TTF DEMO")
  doc.setInfo(DI_AUTHOR, "Andri Lim")
  doc.setInfo(DI_SUBJECT, "TTF Font Demo")

proc test(doc: PDF) =
  let text = "Hello"
  test "getTextWidth and GetTextHeight base14":
    doc.setFont("Helvetica", {FS_REGULAR}, 5)
    var tw = doc.getTextWidth(text)
    var th = doc.getTextHeight(text)
    check:
      tw.formatFloat(ffDecimal, 2) == "11.39"
      th.formatFloat(ffDecimal, 2) == "3.59"

  test "getTextWidth and GetTextHeight TTF":
    doc.setFont("FreeMono", {FS_REGULAR}, 5)
    var tw = doc.getTextWidth(text)
    var th = doc.getTextHeight(text)
    check:
      tw.formatFloat(ffDecimal, 2) == "15.00"
      th.formatFloat(ffDecimal, 2) == "3.02"

  test "getVTextWidth and GetVTextHeight base14":
    doc.setFont("Helvetica", {FS_REGULAR}, 5)
    var tw = doc.getVTextWidth(text)
    var th = doc.getVTextHeight(text)
    check:
      tw.formatFloat(ffDecimal, 2) == "3.61"
      th.formatFloat(ffDecimal, 2) == "14.05"

  test "getTextWidth and GetTextHeight TTF":
    doc.setFont("FreeMono", {FS_REGULAR}, 5)
    var tw = doc.getVTextWidth(text)
    var th = doc.getVTextHeight(text)
    check:
      tw.formatFloat(ffDecimal, 2) == "3.00"
      th.formatFloat(ffDecimal, 3) == "13.325"

proc main() =
  var fileName = "test.pdf"
  var file = newFileStream(fileName, fmWrite)

  if file != nil:
    var opts = newPDFOptions()
    opts.addFontsPath("fonts")
    var doc = newPDF(opts)
    doc.createPDF()
    doc.writePDF(file)
    doc.test()
    file.close()
    echo "OK"
    return

  echo "cannot open: ", fileName

main()