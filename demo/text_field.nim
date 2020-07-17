import streams, nimPDF

proc createPDF(doc: PDF) =
  let size = getSizeFromName("A4")
  let pg1 = doc.addPage(size, PGO_PORTRAIT)

  let text1 = "Your Name: "
  doc.drawText(15, 30, text1)
  let w1 = doc.getTextWidth(text1)

  let
    x = 15.0 + w1
    y = 25.0
    w = 50.0
    h = 6.0

  doc.drawRect(x,y,w,h)
  doc.stroke()
  discard doc.newTextField(x,y,w,h, "TextField1")

proc main(): bool {.discardable.} =
  var fileName = "text_field.pdf"
  var file = newFileStream(fileName, fmWrite)

  if file != nil:
    var doc = newPDF()
    doc.createPDF()
    doc.writePDF(file)
    file.close()
    echo "OK"
    return true

  echo "cannot open: ", fileName
  result = false

main()