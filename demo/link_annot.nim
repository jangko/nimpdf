import streams, nimPDF

proc createPDF(doc: PDF) =
  let size = getSizeFromName("A4")
  let pg1 = doc.addPage(size, PGO_PORTRAIT)
  let text1 = "Click Here: Page 2"
  doc.drawText(15, 30, text1)
  let w1 = doc.getTextWidth(text1)

  let pg2 = doc.addPage(size, PGO_PORTRAIT)
  doc.drawText(15, 30, "Page 2")

  let dest = pg2.newXYZDest(0, 0, 0)
  let r1 = initRect(15,25,w1,6)
  discard doc.linkAnnot(r1, pg1, dest)

proc main(): bool {.discardable.} =
  var fileName = "link_annot.pdf"
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