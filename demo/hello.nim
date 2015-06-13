import nimpdf

var doc = initPDF()
doc.addPage(getSizeFromName("A4"), PGO_PORTRAIT)
doc.drawText(15, 15, "Hello World!")
if not doc.writePDF("hello.pdf"):
  echo "cannot open: hello.pdf"
