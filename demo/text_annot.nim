import streams, nimPDF

proc createPDF(doc: Document) = 
    let size = getSizeFromName("A4")
    let pg1 = doc.addPage(size, PGO_PORTRAIT)
    let text = "Click Here"
    doc.drawText(15, 30, text)
    let w = doc.getTextWidth(text)
    #doc.drawRect(15, 25, w, 6)
    #doc.stroke()
 
    let r = initRect(15, 19, 10, 6)
    discard doc.textAnnot(r, pg1, "Hello There")
    
proc main(): bool {.discardable.} = 
    var fileName = "text_annot.pdf"
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