import nimPDF, streams

proc createPDF(doc: PDF, pageNo: int) =
  let size = getSizeFromName("A4")
  doc.addPage(size, PGO_PORTRAIT)

  doc.setUnit(PGU_PT)
  doc.setCoordinateMode(BOTTOM_UP)
  doc.setFont("Times", {FS_REGULAR}, 10.0)
  doc.drawText(10, 100, "Page: " & $pageNo)
  var btn = doc.newPushButton(10, 50, 50, 20, "button1")
  btn.addActionNamed(fatMouseDown, naNextPage)
  btn.setCaption("Hello World")
  btn.setBorderWidth(1)
  btn.setBorderColor(initRGB("red"))

proc main() =
  var fileName = "pushButton.pdf"
  var file = newFileStream(fileName, fmWrite)

  if file != nil:
    var doc = newPDF()
    for i in 0..5:
      doc.createPDF(i)
    doc.writePDF(file)
    file.close()
    echo "OK"
    return

  echo "cannot open: ", fileName

main()