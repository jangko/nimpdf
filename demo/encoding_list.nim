import streams, nimPDF, strutils

const
  PGSIZE = getSizeFromName("A4")
  CELL_WIDTH  = 10.0
  CELL_HEIGHT = 10.0
  LEFT = (PGSIZE.width.toMM/2) - ((CELL_WIDTH * 17)/2)
  TOP = 20.0

  encodings = [
    "StandardEncoding",
    "MacRomanEncoding",
    "WinAnsiEncoding",
    "Symbol-Set",
    "ZapfDingbats-Set"]

proc draw_title(doc: PDF, text:string) =
  doc.setFont("Helvetica", {FS_BOLD}, 5)
  let tw = doc.getTextWidth(text)
  let x = PGSIZE.width.toMM/2 - tw/2

  doc.setFillColor(0,0,0)
  doc.drawText(x, 10.0, text)
  doc.setStrokeColor(0,0,0)
  doc.drawRect(10,15,PGSIZE.width.toMM - 20, PGSIZE.height.toMM-25)
  doc.stroke()

proc draw_grid(doc: PDF) =
  #Draw 16 X 15 cells

  #Draw vertical lines.
  doc.setLineWidth(0.2)

  for i in 0..17:
    let x = float(i) * CELL_WIDTH + LEFT
    doc.moveTo(x, TOP)
    doc.lineTo(x, CELL_HEIGHT * 15 + TOP)
    doc.stroke

    if (i > 0 and i <= 16):
      doc.drawText(x + 3, TOP + 6, toHex(i - 1, 1))

  #Draw horizontal lines.
  for i in 0..15:
    let y = float(i) * CELL_HEIGHT + TOP
    doc.moveTo(LEFT, y)
    doc.lineTo(CELL_WIDTH * 17 + LEFT, y);
    doc.stroke

    if (i > 1):
      doc.drawText(LEFT + 3, y - 3, toHex(i, 1))

proc draw_fonts(doc: PDF, enc: string) =
  #Draw all character from 0x20 to 0xFF to the canvas. */

  case enc:
  of "StandardEncoding":
    doc.setFont("Helvetica", {FS_REGULAR}, 5, ENC_STANDARD)
  of "MacRomanEncoding":
    doc.setFont("Helvetica", {FS_REGULAR}, 5, ENC_MACROMAN)
  of "WinAnsiEncoding":
    doc.setFont("Helvetica", {FS_REGULAR}, 5, ENC_WINANSI)
  of "Symbol-Set":
    doc.setFont("Symbol", {FS_REGULAR}, 5)
  of "ZapfDingbats-Set":
    doc.setFont("ZapfDingbats", {FS_REGULAR}, 5)

  for i in 1..16:
    for j in 1..16:
      let y = float(i - 1) * CELL_HEIGHT + TOP - (CELL_HEIGHT/2) + 2
      let x = float(j) * CELL_WIDTH + LEFT + (CELL_WIDTH/2)

      let ch = (i - 1) * 16 + (j - 1)
      if ch >= 32:
        let str = $chr(ch)
        let xx = x - doc.getTextWidth(str) / 2
        doc.drawText(xx, y, str)

proc createPDF(doc: PDF) =
  for enc in encodings:
    let page = doc.addPage(PGSIZE, PGO_PORTRAIT)
    draw_title(doc, enc)
    draw_grid(doc)
    draw_fonts(doc, enc)
    let dest = page.newXYZDest(0, 0, 0)
    discard doc.outline(enc, dest)

proc main(): bool {.discardable.} =
  var fileName = "encoding_list.pdf"
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