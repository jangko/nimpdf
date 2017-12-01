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
  
  let dest1 = doc.makeXYZDest(pg1, 0, 0, 3)
  let dest2 = doc.makeFitDest(pg2)
  let dest3 = doc.makeFitHDest(pg3, 30)
  let dest4 = doc.makeFitVDest(pg4, 15)
  
  discard doc.makeOutline("Mode XYZ Zoom 300%", dest1)
  discard doc.makeOutline("Mode Fit", dest2)
  discard doc.makeOutline("Mode FitH", dest3)
  discard doc.makeOutline("Mode FitV", dest4)
  
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