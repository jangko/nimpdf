import streams, nimPDF

proc newPage(doc: PDF, size: PageSize) =
  doc.addPage(size, PGO_PORTRAIT)
  doc.setFont("fonts/TimesNewRoman.ttf", {FS_REGULAR}, 4, ENC_UTF8)

proc createPDF(doc: PDF) =
  let size = getSizeFromName("A4")

  for i in 1..4:
    newPage(doc, size)
    doc.drawText(15, 30, "Page " & $i)

  doAssert doc.numPages() == 4
  doAssert doc.currentPage() == 4
  doc.drawText(15, 40, "There are " & $doc.numPages() & " pages and this is page " & $doc.currentPage())

  # Goto page 2 and add some more text
  doc.gotoPage(2)
  doc.drawText(15, 40, "[Page 2] Goto page 2 and add some more text")
  doAssert doc.currentPage() == 2

  # Goto to previous page and add some more text
  doc.prevPage()
  doc.drawText(15, 40, "[Page 1] Goto to previous page and add some more text")
  doAssert doc.currentPage() == 1

  # Goto the last page and add some more text
  doc.gotoLastPage()
  doc.drawText(15, 50, "[Page 4] Goto the last page and add some more text")
  doAssert doc.currentPage() == 4

  # Goto the first page and add some more text
  doc.gotoFirstPage()
  doc.drawText(15, 50, "[Page 1] Goto the first page and add some more text")
  doAssert doc.currentPage() == 1

  # Goto the next page and add some more text
  doc.nextPage()
  doc.drawText(15, 50, "[Page 2] Goto the next page and add some more text")
  doAssert doc.currentPage() == 2


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