import nimPDF, streams

proc createPDF(doc: PDF) =
  let size = getSizeFromName("A4")
  var page = doc.addPage(size, PGO_PORTRAIT)

  const fontSize = 5.0
  doc.setFont("Times", {FS_REGULAR}, fontSize)

  let
    x = 10.0
    y = 70.0
    link = "https://www.google.com"
    wlink = doc.getTextWidth(link)
    #hlink = doc.getTextHeight(link) # ugh, getTextHeight doest include upper and lower parts
    r = initRect(x, y-fontSize, wlink, fontSize)

  doc.drawText(x, y, link)
  doc.setStrokeColor(initRGB("skyblue"))
  doc.drawLine(x, y, x+wlink, y)
  doc.drawRect(r.x, r.y, r.w, r.h)
  doc.stroke()

  # current r.y is text baseline position
  # probably should provide baseline offset API
  # for 'q', 'p', 'g', etc.
  discard doc.uriAnnot(r, page, link)

proc main() =
  var fileName = "uri_annot.pdf"
  var file = newFileStream(fileName, fmWrite)

  if file != nil:
    var doc = newPDF()
    doc.createPDF()
    doc.writePDF(file)
    file.close()
    echo "OK"
    return

  echo "cannot open: ", fileName

main()