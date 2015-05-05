import streams, math, basic2d
import benalu, image, arc, gstate, fontmanager
import spline, path

proc draw_title(doc: Document, text:string) = 
    let size = getSizeFromName("A4")
    
    doc.setFont("Helvetica", {FS_BOLD}, 5)
    let tw = doc.getTextWidth(text)
    let x = size.width/2 - tw/2
    
    doc.setRGBFill(0,0,0)
    doc.drawText(x, 10.0, text)
    doc.setRGBStroke(0,0,0)
    doc.drawRect(10,15,size.width - 20, size.height-25)
    doc.stroke()

proc createPDF(doc: Document) = 
    let size = getSizeFromName("A4")
    let SAMP_TEXT = "The Quick Brown Fox Jump Over The Lazy Dog"
        
    doc.addPage(size, PGO_PORTRAIT)
    draw_title(doc, "TRUE TYPE FONT DEMO")
    
    doc.setFont("Eunjin", {FS_REGULAR}, 10)
    doc.drawText(15, 50, "헬로우 월드")
  
    doc.setFont("KaiTi", {FS_REGULAR}, 10)
    doc.drawText(15, 70, "你好世界")
    
    doc.setFont("Purisa", {FS_REGULAR}, 10)
    doc.drawText(15, 30, "Hello World Purisa")
    
    doc.setFont("Purisa", {FS_REGULAR}, 4)
    doc.drawText(15, 90, SAMP_TEXT)
    
    doc.setInfo(DI_TITLE, "TTF DEMO")
    doc.setInfo(DI_AUTHOR, "Andri Lim")
    doc.setInfo(DI_SUBJECT, "TTF Font Demo")

proc main(): bool {.discardable.} = 
    #echo currentSourcePath()
    var fileName = "test.pdf"
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