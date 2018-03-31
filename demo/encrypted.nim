import nimPDF, strutils, random

include names

proc drawTitle(doc: PDF, text:string) =
  let size = getSizeFromName("A4")

  doc.setFont("Helvetica", {FS_BOLD}, 5)
  let tw = doc.getTextWidth(text)
  let x = size.width.toMM/2 - tw/2

  doc.setFillColor(0,0,0)
  doc.drawText(x, 10.0, text)
  doc.setStrokeColor(0,0,0)
  doc.drawRect(10,15,size.width.toMM - 20, size.height.toMM-25)
  doc.stroke()

proc rndlen(len: int): string =
  result = ""
  for i in 1..len: result.add($rand(10))

proc random(a, b: int): int =
  result = rand(b-a) + a

proc i2a(val: int): string =
  if val < 10: result = "0" & $val
  else: result = $val

proc i2a(val: int, len: int) : string =
  let s = $val
  let blank = len - s.len()
  if blank >= 0:
    result = repeat('0', blank)
    result.add(s)
  else:
    result = s

proc createPDF(doc: PDF) =
  let size = getSizeFromName("A4")
  discard doc.addPage(size, PGO_PORTRAIT)
  let text = "TOP SECRET"
  doc.setFont("Helvetica", {FS_BOLD}, 40)

  doc.saveState()
  doc.setFillColor(initRGB("lightgray"))
  var y = size.height.toMM / 2.0
  doc.rotate(45, size.width.toMM/2.0, y)
  doc.drawText((size.width.toMM-doc.getTextWidth(text))/2.0 + 10, y, text)
  doc.restoreState()

  var bank = doc.loadImage("greedybank.png")
  var bush = doc.loadImage("GWBush-signature.png")
  var secret = doc.loadImage("topsecret.png")
  doc.drawTitle("TOP 50 Clients")
  doc.saveState()
  doc.scale(0.6, 10, 20)
  doc.drawImage(10, 20, bank)
  doc.restoreState()

  y = 25
  doc.setFont("Helvetica", {FS_BOLD}, 4)
  doc.drawText(20, y,"Name")
  doc.drawText(80, y,"Account Nr.")
  doc.drawText(120, y,"Opened")
  doc.drawText(170, y,"Balance")

  let clients = split(names, "\n")
  let len = min(50, clients.len)

  doc.setFont("Courier", {FS_REGULAR}, 3.5)
  randomize()
  for i in 1..len:
    y += 4.5
    doc.drawText(11, y, $i)
    doc.drawText(20, y, clients[i - 1])
    doc.drawText(80, y, rndlen(10))
    let date = $random(1980, 2008) & "-" & i2a(random(1, 12)) & "-" & i2a(random(1, 28))
    doc.drawText(120, y, date)
    let balance = "$" & $random(0, 999) & "." & i2a(random(0, 999), 3) & "." & i2a(random(0, 999), 3)
    doc.drawText(170, y, balance)

  doc.saveState()
  doc.scale(0.4, 130, 280)
  doc.drawImage(130, 280, bush)
  doc.restoreState()

  doc.saveState()
  doc.scale(0.6, 160, 280)
  doc.rotate(30, 160, 280)
  doc.drawImage(160, 280, secret)
  doc.restoreState()
  discard doc.setPassword("owner", "user")
  doc.setEncryptionMode(ENCRYPT_R4_AES)

proc main() =
  var opts = newPDFOptions()
  opts.addImagesPath("resources")

  var doc = newPDF(opts)
  doc.createPDF()
  if not doc.writePDF("encrypted.pdf"):
    echo "failed"

main()
