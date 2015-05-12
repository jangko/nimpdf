import streams, nimpdf

proc createPDF(doc: Document) = 
    let size = getSizeFromName("A4")
    let pg1 = doc.addPage(size, PGO_PORTRAIT)
    let text = "Click Here"
    doc.drawText(15, 30, text)
    let w = doc.getTextWidth(text)
    #doc.drawRect(15, 25, w, 6)
    #doc.stroke()
        
    let pg2 = doc.addPage(size, PGO_PORTRAIT)
    doc.drawText(15, 30, "Page 2")
    
    let dest = doc.makeXYZDest(pg2, 0, 0, 0)
    let r = initRect(15,25,w,6)
    discard doc.makeLink(r, pg1, dest)
    
proc main(): bool {.discardable.} = 
    var fileName = "link_annot.pdf"
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