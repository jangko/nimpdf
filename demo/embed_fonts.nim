import streams, nimPDF, unittest

proc draw_title(doc: PDF, text:string) =
  let size = getSizeFromName("A4")

  doc.setFont("KaiTi", {FS_BOLD}, 5)#, embedFont = true)
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

  doc.setFont("Calligrapher", {FS_REGULAR}, 10)#, embedFont = false)
  doc.drawText(15, 30, "Calligrapher")

  doc.setFont("Eunjin", {FS_REGULAR}, 10)#, embedFont = false)
  doc.drawText(15, 50, "Eunjin")

  doc.setFont("KaiTi", {FS_REGULAR}, 10)#, embedFont = false)
  doc.drawText(15, 70, "KaiTi")

  doc.setFont("Calligrapher", {FS_REGULAR}, 4)#, embedFont = false)
  doc.drawText(15, 90, SAMP_TEXT)

  doc.setInfo(DI_TITLE, "TTF DEMO")
  doc.setInfo(DI_AUTHOR, "Andri Lim")
  doc.setInfo(DI_SUBJECT, "TTF Font Demo")


proc main(): bool {.discardable.} =
  #echo currentSourcePath()
  var fileName = "embed_fonts.pdf"
  var file = newFileStream(fileName, fmWrite)

  if file != nil:
    var opts = newPDFOptions()
    opts.addFontsPath("fonts")
    opts.setEmbedFont(true)
    var doc = newPDF(opts)
    doc.createPDF()
    doc.writePDF(file)
    file.close()
    echo "OK"
    return true

  echo "cannot open: ", fileName
  result = false

main()