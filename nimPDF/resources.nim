import gstate, objects, fontmanager, image, "subsetter/Font"

proc putGradients*(xref: Pdfxref, gradients: seq[Gradient]): DictObj =
  if gradients.len > 0: result = newDictObj()
  for gd in gradients:
    let a = gd.a
    let b = gd.b

    var fn = newDictObj()
    fn.addNumber("FunctionType", 2)
    fn.addPlain("Domain", "[0.0 1.0]")
    fn.addElement("C0", newArray(a.r, a.g, a.b))
    fn.addElement("C1", newArray(b.r, b.g, b.b))
    fn.addNumber("N", 1)

    var grad = newDictObj()
    if gd.gradType == GDT_LINEAR:
      let cr = gd.axis
      grad.addNumber("ShadingType", 2)
      grad.addElement("Coords", newArray(cr.x1, cr.y1, cr.x2, cr.y2))
    elif gd.gradType == GDT_RADIAL:
      let cr = gd.radCoord
      grad.addNumber("ShadingType", 3)
      grad.addElement("Coords", newArray(cr.x1, cr.y1, cr.r1, cr.x2, cr.y2, cr.r2))
    grad.addName("ColorSpace", "DeviceRGB")
    grad.addElement("Function", fn)
    grad.addPlain("Extend", "[true true]")
    xref.add(grad)
    result.addElement("Sh" & $gd.ID, grad)

proc putExtGStates*(xref: Pdfxref, exts: seq[ExtGState]): DictObj =
  if exts.len > 0: result = newDictObj()
  for ex in exts:
    var ext = newDictObj()
    ext.addName("Type", "ExtGState")
    if ex.nonstrokingAlpha > 0.0: ext.addReal("ca", ex.nonstrokingAlpha)
    if ex.strokingAlpha > 0.0: ext.addReal("CA", ex.strokingAlpha)
    ext.addName("BM", ex.blendMode)
    xref.add(ext)
    result.addElement("GS" & $ex.ID, ext)

proc putImages*(xref: Pdfxref, images: seq[Image]): DictObj =
  if images.len > 0:  result = newDictObj()
  for img in images:
    var pic = xref.newDictStream(img.data)
    pic.addName("Type", "XObject")
    pic.addName("Subtype", "Image")
    pic.addNumber("Width", img.width)
    pic.addNumber("Height", img.height)
    pic.addName("ColorSpace", "DeviceRGB")
    pic.addNumber("BitsPerComponent", 8)
    result.addElement("I" & $img.ID, pic)
    img.dictObj = pic

    if img.haveMask():
      var mask = xref.newDictStream(img.mask)
      mask.addName("Type", "XObject")
      mask.addName("Subtype", "Image")
      mask.addNumber("Width", img.width)
      mask.addNumber("Height", img.height)
      mask.addName("ColorSpace", "DeviceGray")
      mask.addNumber("BitsPerComponent", 8)
      pic.addElement("SMask", mask)
      result.addElement("Im" & $img.ID, mask)

proc putBase14Fonts(xref: Pdfxref, font: Font): DictObj =
  let fon = Base14(font)
  var fn = newDictObj()
  xref.add(fn)

  fn.addName("Type", "Font")
  fn.addName("BaseFont", fon.baseFont)
  fn.addName("Subtype", "Type1")
  if (fon.baseFont != "Symbol") and (fon.baseFont != "ZapfDingbats"):
    if fon.encoding == ENC_STANDARD: fn.addName("Encoding", "StandardEncoding")
    elif fon.encoding == ENC_MACROMAN: fn.addName("Encoding", "MacRomanEncoding")
    elif fon.encoding == ENC_WINANSI: fn.addName("Encoding", "WinAnsiEncoding")
  result = fn

proc putTrueTypeFonts(xref: Pdfxref, font: Font, seed: int, renderMode: FontRenderMode): DictObj =
  let fon = TTFont(font)
  let subsetTag  = makeSubsetTag(seed)

  let widths   = fon.GenerateWidths(renderMode) #don't change this order
  let ranges   = fon.GenerateRanges() #cos they sort CH2GID differently
  let desc     = fon.GetDescriptor(renderMode)
  let buf      = fon.GetSubsetBuffer(subsetTag, renderMode)
  let Length1  = buf.len
  let psName   = subsetTag & desc.postscriptName

  var descriptor = newDictObj()
  xref.add(descriptor)
  descriptor.addName("Type", "FontDescriptor")
  descriptor.addName("FontName", psName)
  descriptor.addString("FontFamily", desc.fontFamily)
  descriptor.addNumber("Flags", desc.Flags)
  descriptor.addElement("FontBBox", newArray(desc.BBox[0], desc.BBox[1], desc.BBox[2], desc.BBox[3]))
  descriptor.addReal("ItalicAngle", desc.italicAngle)
  descriptor.addNumber("Ascent", desc.Ascent)
  descriptor.addNumber("Descent", desc.Descent)
  descriptor.addNumber("CapHeight", desc.capHeight)
  descriptor.addNumber("StemV", desc.stemV)
  descriptor.addNumber("XHeight", desc.xHeight)
  if renderMode == frmDefault:
    var fontFile = xref.newDictStream(buf)
    fontFile.addNumber("Length1", Length1)
    descriptor.addElement("FontFile2", fontFile)


  # Only embed font data when renderMode is frmEmbed
  if renderMode == frmEmbed:
    var fontFile = xref.newDictStream(buf)
    fontFile.addNumber("Length1", Length1)
    descriptor.addElement("FontFile2", fontFile)

  # CIDFontType2
  # A CIDFont whose glyph descriptions are based on TrueType font technology
  var descendant = newDictObj()
  xref.add(descendant)
  descendant.addName("Type", "Font")
  descendant.addName("Subtype", "CIDFontType2")
  descendant.addName("BaseFont", psName)
  descendant.addPlain("CIDSystemInfo", "<</Registry(Adobe)/Ordering(Identity)/Supplement 0>>")
  descendant.addElement("FontDescriptor", descriptor)
  descendant.addNumber("DW", desc.missingWidth)
  descendant.addPlain("W", widths)
  if renderMode == frmEmbed:
    descendant.addName("CIDToGIDMap", "Identity")

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

  var toUnicode: DictObj
  if renderMode == frmEmbed:
    let toUni2 = """
endcmap
CMapName currentdict /CMap defineresource pop
end
end"""

    let toUni = if ranges.len > 0: toUni1 & "\n" & ranges & toUni2 else: toUni1 & toUni2
    toUnicode = xref.newDictStream(toUni)
  else:
    let toUni2 = """\x0Aendcmap
CMapName currentdict /CMap defineresource pop
end
end"""

    let toUni = toUni1 & ranges & toUni2
    toUnicode = xref.newDictStream(toUni)

  var fn = newDictObj()
  xref.add(fn)

  var childs = newArrayObj()
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

proc putFonts*(xref: Pdfxref, fonts: seq[Font]): DictObj =
  var seed = fromBase26("NIMPDF")
  if fonts.len > 0: result = newDictObj()
  var fn: DictObj

  for fon in fonts:
    if fon.subType == FT_BASE14:
      fn = xref.putBase14Fonts(fon)
    if fon.subType == FT_TRUETYPE:
      fn = xref.putTrueTypeFonts(fon, seed, fon.renderMode)
    result.addElement("F" & $fon.ID, fn)
    inc(seed)