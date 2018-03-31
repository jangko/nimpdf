import streams, nimPDF

proc createPDF(doc: PDF) =
  let size = getSizeFromName("A4")
  let pg1 = doc.addPage(size, PGO_PORTRAIT)
  let text1 = "Your Name: "
  doc.drawText(15, 30, text1)
  let w1 = doc.getTextWidth(text1)

  let r1 = initRect(15+w1,25,50,6)
  doc.drawRect(15+w1,25,50,6)
  doc.stroke()
  discard doc.newTextField(r1.x,r1.y,r1.w,r1.h, "id")

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