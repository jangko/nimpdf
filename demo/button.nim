import nimPDF, streams

proc createPDF(doc: PDF, pageNo: int) =
  let size = getSizeFromName("A4")
  doc.addPage(size, PGO_PORTRAIT)

  let rc = initRect(10, 20, 50, 20)
  doc.setFont("Times", {FS_REGULAR}, 5.0)
  doc.drawText(10, 10, "Page: " & $pageNo)
  var btn = doc.newPushButton(rc.x, rc.y, rc.w, rc.h, "button1")
  btn.addActionNamed(fatMouseDown, naNextPage)

  let caption = "Hello World"
  let tw = doc.getTextWidth(caption)
  doc.drawText(rc.x + (rc.w - tw) / 2, rc.y + (5.0 + rc.h) / 2, caption)

  doc.setStrokeColor(initRGB("red"))
  doc.drawRect(rc.x, rc.y, rc.w, rc.h)
  doc.stroke()


  let
    x = 10.0
    y = 70.0
    link = "https://www.google.com"
    wlink = doc.getTextWidth(link)

  doc.drawText(x, y, link)
  doc.setStrokeColor(initRGB("skyblue"))
  doc.drawLine(x, y, x+wlink, y)
  doc.stroke()
  var pb = doc.newPushButton(x, y-5.0, wlink, 5.0, "PB1")
  pb.addActionOpenWebLink(fatMouseDown, link, false)

proc main() =
  var fileName = "button.pdf"
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