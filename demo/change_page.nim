import streams, nimPDF

proc newPage(doc: PDF, size: PageSize) =
  doc.addPage(size, PGO_PORTRAIT)
  doc.setFont("fonts/TimesNewRoman.ttf", {FS_REGULAR}, 4, ENC_UTF8)

proc createPDF(doc: PDF) =
  let size = getSizeFromName("A4")

  for i in 1..4:
    newPage(doc, size)
    doc.drawText(15, 30, "Page " & $i)

  doAssert doc.pages.len() == 4

  # Add text to page 1 (index - 1)
  doc.curPage = doc.pages[1]
  doc.drawText(15, 40, "More text to page 2")

  # Return to newest page
  doc.curPage = doc.pages[doc.pages.len() - 1]
  doc.drawText(15, 40, "Final page")

proc main(): bool {.discardable.} =
  var fileName = "change_page.pdf"
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