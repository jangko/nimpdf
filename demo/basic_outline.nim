import streams, nimPDF

proc createPDF(doc: PDF) =
  let size = getSizeFromName("A4")
  var pg1 = doc.addPage(size, PGO_PORTRAIT)
  pg1.drawText(15, 30, "Page 1")

  var pg2 = doc.addPage(size, PGO_PORTRAIT)
  pg2.drawText(15, 30, "Page 2")

  var pg3 = doc.addPage(size, PGO_PORTRAIT)
  pg3.drawText(15, 30, "Page 3")

  var pg4 = doc.addPage(size, PGO_PORTRAIT)
  pg4.drawText(15, 30, "Page 4")

  let dest1 = pg1.newXYZDest( 0, 0, 0)
  let dest2 = pg2.newXYZDest( 0, 0, 0)
  let dest3 = pg3.newXYZDest( 0, 0, 0)
  let dest4 = pg4.newXYZDest( 0, 0, 0)

  discard doc.outline("Goto Page 1", dest1)
  discard doc.outline("Goto Page 2", dest2)
  discard doc.outline("Goto Page 3", dest3)
  discard doc.outline("Goto Page 4", dest4)

proc main(): bool {.discardable.} =
  var fileName = "basic_outline.pdf"
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