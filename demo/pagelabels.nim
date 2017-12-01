import streams, nimPDF

proc createPDF(doc: PDF) = 
  let size = getSizeFromName("A4")

  doc.setLabel(LS_UPPER_ROMAN)
  doc.addPage(size, PGO_PORTRAIT)
  doc.drawText(15, 30, "Page I")
  doc.addPage(size, PGO_PORTRAIT)
  doc.drawText(15, 30, "Page II")
  doc.addPage(size, PGO_PORTRAIT)
  doc.drawText(15, 30, "Page III")
  
  
  doc.setLabel(LS_LOWER_ROMAN)
  doc.addPage(size, PGO_PORTRAIT)
  doc.drawText(15, 30, "Page i")
  
  doc.setLabel(LS_UPPER_LETTER)
  doc.addPage(size, PGO_PORTRAIT)
  doc.drawText(15, 30, "Page A")
  
  doc.setLabel(LS_LOWER_LETTER)
  doc.addPage(size, PGO_PORTRAIT)
  doc.drawText(15, 30, "Page a")
  
  doc.setLabel(LS_DECIMAL)
  doc.addPage(size, PGO_PORTRAIT)
  doc.drawText(15, 30, "Page 1")
  
  doc.setLabel(LS_DECIMAL, "PG-")
  doc.addPage(size, PGO_PORTRAIT)
  doc.drawText(15, 30, "Page PG-1")
  doc.addPage(size, PGO_PORTRAIT)
  doc.drawText(15, 30, "Page PG-2")

  doc.setLabel(LS_DECIMAL, "PG-", 12)
  doc.addPage(size, PGO_PORTRAIT)
  doc.drawText(15, 30, "Page PG-12")
  doc.addPage(size, PGO_PORTRAIT)
  doc.drawText(15, 30, "Page PG-13")

  doc.setLabel(LS_LOWER_LETTER, "PX-", 3)
  doc.addPage(size, PGO_PORTRAIT)
  doc.drawText(15, 30, "Page PX-c")
  doc.addPage(size, PGO_PORTRAIT)
  doc.drawText(15, 30, "Page PX-d")
  
  doc.setLabel(LS_LOWER_ROMAN, "PR-", 7)
  doc.addPage(size, PGO_PORTRAIT)
  doc.drawText(15, 30, "Page PR-vii")
  doc.addPage(size, PGO_PORTRAIT)
  doc.drawText(15, 30, "Page PR-viii")
  
proc main(): bool {.discardable.} = 
  var fileName = "pagelabels.pdf"
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