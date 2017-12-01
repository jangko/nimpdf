type
  PDFOptions* = ref object
    resourcesPath: seq[string]
    fontsPath: seq[string]
    imagesPath: seq[string]

proc newPDFOptions*(): PDFOptions =
  new(result)
  result.resourcesPath = @[]
  result.fontsPath = @[]
  result.imagesPath = @[]

proc getFontsPath*(opt: PDFOptions): seq[string] =
  result = opt.fontsPath

proc getResourcesPath*(opt: PDFOptions): seq[string] =
  result = opt.resourcesPath

proc getImagesPath*(opt: PDFOptions): seq[string] =
  result = opt.imagesPath

proc addResourcesPath*(opt: PDFOptions, path: string) =
  opt.resourcesPath.add(path)

proc addImagesPath*(opt: PDFOptions, path: string) =
  opt.imagesPath.add(path)

proc addFontsPath*(opt: PDFOptions, path: string) =
  opt.fontsPath.add(path)

proc clearFontsPath*(opt: PDFOptions) =
  opt.fontsPath.setLen(0)

proc clearImagesPath*(opt: PDFOptions) =
  opt.imagesPath.setLen(0)

proc clearResourcesPath*(opt: PDFOptions) =
  opt.resourcesPath.setLen(0)

proc clearAllPath*(opt: PDFOptions) =
  opt.clearFontsPath()
  opt.clearImagesPath()
  opt.clearResourcesPath()
