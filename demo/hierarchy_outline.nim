import streams, nimPDF

proc createPDF(doc: Document) = 
  let size = getSizeFromName("A4")
  let pg1 = doc.addPage(size, PGO_PORTRAIT)
  doc.drawText(15, 30, "Page 1")
  
  let pg2 = doc.addPage(size, PGO_PORTRAIT)
  doc.drawText(15, 30, "Page 2")
  
  let pg3 = doc.addPage(size, PGO_PORTRAIT)
  doc.drawText(15, 30, "Page 3")
  
  let pg4 = doc.addPage(size, PGO_PORTRAIT)
  doc.drawText(15, 30, "Page 4")
  
  let pg5 = doc.addPage(size, PGO_PORTRAIT)
  doc.drawText(15, 30, "Page 5")
  
  let pg6 = doc.addPage(size, PGO_PORTRAIT)
  doc.drawText(15, 30, "Page 6")
  
  let dest1 = doc.makeXYZDest(pg1, 0, 0, 0)
  let dest2 = doc.makeFitDest(pg2)
  let dest3 = doc.makeFitHDest(pg3, 30)
  let dest4 = doc.makeFitVDest(pg4, 15)
  let dest5 = doc.makeXYZDest(pg5, 0, 0, 0)
  let dest6 = doc.makeXYZDest(pg6, 0, 0, 0)
  
  let ot1 = doc.makeOutline("Goto Page 1", dest1)
  discard ot1.makeOutline("Goto Page 2", dest2)
  
  let ot2 = doc.makeOutline("Goto Page 3", dest3)
  let ot3 = ot2.makeOutline("Goto Page 4", dest4)
  discard ot2.makeOutline("Goto Page 5", dest5)
  discard ot3.makeOutline("Goto Page 6", dest6)
        
proc main(): bool {.discardable.} = 
  var fileName = "hierarchy_outline.pdf"
  var file = newFileStream(fileName, fmWrite)
  
  if file != nil:
    var doc = initPDF()        
    doc.createPDF()
    doc.writePDF(file)
    file.close()
    echo "OK"
    return true
  
  echo "cannot open: ", fileName
  result = false

main()