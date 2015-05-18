import streams, nimpdf

proc main(): bool {.discardable.} = 
  var fileName = "hello.pdf"
  var file = newFileStream(fileName, fmWrite)

  if file != nil:
    var doc = initPDF()
    let size = getSizeFromName("A4")
    doc.addPage(size, PGO_PORTRAIT)
    doc.drawText(15, 15, "Hello World!")
    doc.writePDF(file)
    file.close()
    return true

  echo "cannot open: ", fileName
  result = false

main()