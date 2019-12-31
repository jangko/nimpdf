import streams, nimPDF

proc createPDF(doc: PDF) =
  let size = getSizeFromName("A4")
  let pg1 = doc.addPage(size, PGO_PORTRAIT)
  let text = "Click Here"
  doc.drawText(15, 30, text)
  discard doc.getTextWidth(text)
  let r = initRect(15, 19, 10, 6)
  discard doc.textAnnot(r, pg1, "Hello There")

proc main(): bool {.discardable.} =
  var fileName = "text_annot.pdf"
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