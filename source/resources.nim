import gstate, objects, fontmanager, image

proc putGradients*(xref: pdfXref, gradients: seq[Gradient]): dictObj =
  if gradients.len > 0: result = dictObjNew()
  for gd in gradients:
    let a = gd.a
    let b = gd.b

    var fn = dictObjNew()
    fn.addNumber("FunctionType", 2)
    fn.addPlain("Domain", "[0.0 1.0]")
    fn.addElement("C0", arrayNew(a.r, a.g, a.b))
    fn.addElement("C1", arrayNew(b.r, b.g, b.b))
    fn.addNumber("N", 1)

    var grad = dictObjNew()
    if gd.gradType == GDT_LINEAR:
      let cr = gd.axis
      grad.addNumber("ShadingType", 2)
      grad.addElement("Coords", arrayNew(cr.x1, cr.y1, cr.x2, cr.y2))
    elif gd.gradType == GDT_RADIAL:
      let cr = gd.radCoord
      grad.addNumber("ShadingType", 3)
      grad.addElement("Coords", arrayNew(cr.x1, cr.y1, cr.r1, cr.x2, cr.y2, cr.r2))
    grad.addName("ColorSpace", "DeviceRGB")
    grad.addElement("Function", fn)
    grad.addPlain("Extend", "[true true]")
    xref.add(grad)
    result.addElement("Sh" & $gd.ID, grad)

proc putExtGStates*(xref: pdfXref, exts: seq[ExtGState]): dictObj =
  if exts.len > 0: result = dictObjNew()
  for ex in exts:
    var ext = dictObjNew()
    ext.addName("Type", "ExtGState")
    if ex.nonstrokingAlpha > 0.0: ext.addReal("ca", ex.nonstrokingAlpha)
    if ex.strokingAlpha > 0.0: ext.addReal("CA", ex.strokingAlpha)
    ext.addName("BM", ex.blendMode)
    xref.add(ext)
    result.addElement("GS" & $ex.ID, ext)

proc putImages*(xref: pdfXref, images: seq[Image]): dictObj =
  if images.len > 0:  result = dictObjNew()
  for img in images:
    var pic = xref.dictStreamNew(img.data)
    pic.addName("Type", "XObject")
    pic.addName("Subtype", "Image")
    pic.addNumber("Width", img.width)
    pic.addNumber("Height", img.height)
    pic.addName("ColorSpace", "DeviceRGB")
    pic.addNumber("BitsPerComponent", 8)
    result.addElement("I" & $img.ID, pic)

    if img.haveMask():
      var mask = xref.dictStreamNew(img.mask)
      mask.addName("Type", "XObject")
      mask.addName("Subtype", "Image")
      mask.addNumber("Width", img.width)
      mask.addNumber("Height", img.height)
      mask.addName("ColorSpace", "DeviceGray")
      mask.addNumber("BitsPerComponent", 8)
      pic.addElement("SMask", mask)
      result.addElement("Im" & $img.ID, mask)

proc putBase14Fonts(xref: pdfXref, font: Font): dictObj =
  let fon = Base14(font)
  var fn = dictObjNew()
  xref.add(fn)

  fn.addName("Type", "Font")
  fn.addName("BaseFont", fon.baseFont)
  fn.addName("Subtype", "Type1")
  if (fon.baseFont != "Symbol") and (fon.baseFont != "ZapfDingbats"):
    if fon.encoding == ENC_STANDARD: fn.addName("Encoding", "StandardEncoding")
    elif fon.encoding == ENC_MACROMAN: fn.addName("Encoding", "MacRomanEncoding")
    elif fon.encoding == ENC_WINANSI: fn.addName("Encoding", "WinAnsiEncoding")
  result = fn

proc putTrueTypeFonts(xref: pdfXref, font: Font, seed: int): dictObj =
  let fon = TTFont(font)
  let subsetTag  = makeSubsetTag(seed)

  let widths   = fon.GenerateWidths() #don't change this order
  let ranges   = fon.GenerateRanges() #coz they sort CH2GID differently
  let desc     = fon.GetDescriptor()
  let buf      = fon.GetSubsetBuffer(subsetTag)
  let Length1  = buf.len
  let psName   = subsetTag & desc.postscriptName

  var fontFile = xref.dictStreamNew(buf)
  fontFile.addNumber("Length1", Length1)

  var descriptor = dictObjNew()
  xref.add(descriptor)
  descriptor.addName("Type", "FontDescriptor")
  descriptor.addName("FontName", psName)
  descriptor.addString("FontFamily", desc.fontFamily)
  descriptor.addNumber("Flags", desc.Flags)
  descriptor.addElement("FontBBox", arrayNew(desc.BBox[0], desc.BBox[1], desc.BBox[2], desc.BBox[3]))
  descriptor.addReal("ItalicAngle", desc.italicAngle)
  descriptor.addNumber("Ascent", desc.Ascent)
  descriptor.addNumber("Descent", desc.Descent)
  descriptor.addNumber("CapHeight", desc.capHeight)
  descriptor.addNumber("StemV", desc.stemV)
  descriptor.addNumber("XHeight", desc.xHeight)
  descriptor.addElement("FontFile2", fontFile)

  # CIDFontType2
  # A CIDFont whose glyph descriptions are based on TrueType font technology
  var descendant = dictObjNew()
  xref.add(descendant)
  descendant.addName("Type", "Font")
  descendant.addName("Subtype", "CIDFontType2")
  descendant.addName("BaseFont", psName)
  descendant.addPlain("CIDSystemInfo", "<</Registry(Adobe)/Ordering(Identity)/Supplement 0>>")
  descendant.addElement("FontDescriptor", descriptor)
  descendant.addNumber("DW", desc.missingWidth)
  descendant.addPlain("W", widths)

  # ToUnicode
  let toUni1 = """/CIDInit /ProcSet findresource begin
12 dict begin
begincmap
/CIDSystemInfo
<</Registry(Adobe)/Ordering(Identity)/Supplement 0>> def
/CMapName /Adobe-Identity-UCS def
/CMapType 2 def
1 begincodespacerange
<0000> <FFFF>
endcodespacerange"""

  let toUni2 = """\x0Aendcmap
CMapName currentdict /CMap defineresource pop
end
end"""

  let toUni = toUni1 & ranges & toUni2
  var toUnicode = xref.dictStreamNew(toUni)

  var fn = dictObjNew()
  xref.add(fn)

  var childs = arrayObjNew()
  childs.add(descendant)

  fn.addName("Type", "Font")
  fn.addName("BaseFont", psName)
  fn.addName("Subtype", "Type0")
  fn.addName("Encoding", "Identity-H")
  fn.addElement("DescendantFonts", childs)
  fn.addElement("ToUnicode", toUnicode)
  fn.addNumber("FirstChar", desc.firstChar)
  fn.addNumber("LastChar", desc.lastChar)

  result = fn

proc putFonts*(xref: pdfXref, fonts: seq[Font]): dictObj =
  var seed = fromBase26("NIMPDF")
  if fonts.len > 0: result = dictObjNew()
  var fn: dictObj
  for fon in fonts:
    if fon.subType == FT_BASE14: fn = xref.putBase14Fonts(fon)
    if fon.subType == FT_TRUETYPE: fn = xref.putTrueTypeFonts(fon, seed)
    result.addElement("F" & $fon.ID, fn)
    inc(seed)
