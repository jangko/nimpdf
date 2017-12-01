import streams, nimPDF

proc createPDF(doc: PDF) =
  let size = getSizeFromName("A4")
  let pg1 = doc.addPage(size, PGO_PORTRAIT)
  doc.drawText(15, 30, "Page 1")

  let pg2 = doc.addPage(size, PGO_PORTRAIT)
  doc.drawText(15, 30, "Page 2")

  let pg3 = doc.addPage(size, PGO_PORTRAIT)
  doc.drawText(15, 30, "Page 3")

  let pg4 = doc.addPage(size, PGO_PORTRAIT)
  doc.drawText(15, 30, "Page 4")

  let dest1 = pg1.newXYZDest(0, 0, 3)
  let dest2 = pg2.newFitDest()
  let dest3 = pg3.newFitHDest(30)
  let dest4 = pg4.newFitVDest(15)

  discard doc.outline("Mode XYZ Zoom 300%", dest1)
  discard doc.outline("Mode Fit", dest2)
  discard doc.outline("Mode FitH", dest3)
  discard doc.outline("Mode FitV", dest4)

proc main(): bool {.discardable.} =
  var fileName = "destination_outline.pdf"
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