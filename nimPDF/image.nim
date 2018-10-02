# Copyright (c) 2015 Andri Lim
#
# Distributed under the MIT license
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------
#
# this module act as an incomplete wrapper for LodePNG and uJPEG
# also provide zcompress to compress nimPDF streams
# currently, identify file format only by it's file name extension
# eg: .png, .jpg, .jpeg, .bmp

import nimBMP, os, strutils, nimPNG, nimPNG/nimz, objects

# William Whitacre - 2018/01/19 - Fallback
import stb_image/read as stbi
import stb_image/write as stbiw

#{.deadCodeElim: on.}
#{.passC: "-D LODEPNG_NO_COMPILE_CPP".}
#{.passL: "-lstdc++" .}
#{.compile: "lodepng.c".}
{.compile: "ujpeg.c".}

type
  Image* = ref object
    width*, height*, ID*: int
    data*, mask*: string
    dictObj*: DictObj
  ujImage = pointer

proc ujCreate() : ujImage {.cdecl, importc: "ujCreate".}
#proc ujDecode(img: ujImage, data: ptr cuchar, size: int) : ujImage {.cdecl, importc: "ujDecode".}
proc ujDecodeFile(img: ujImage, filename: cstring) : ujImage {.cdecl, importc: "ujDecodeFile".}
proc ujGetWidth(img: ujImage) : int {.cdecl, importc: "ujGetWidth".}
proc ujGetHeight(img: ujImage) : int {.cdecl, importc: "ujGetHeight".}
proc ujGetImageSize(img: ujImage) : int {.cdecl, importc: "ujGetImageSize".}
proc ujGetImage(img: ujImage, dest: cstring) : cstring {.cdecl, importc: "ujGetImage".}
proc ujDestroy(img: ujImage) {.cdecl, importc: "ujDestroy".}

proc loadImagePNG(fileName: string): Image =
  var png = loadPNG32(fileName)
  if png == nil: return nil
  new(result)
  let size = png.width*png.height
  result.width = png.width
  result.height = png.height
  result.data = newString(size * 3)
  result.mask = newString(size)
  for i in 0..size-1:
    result.data[i * 3]     = png.data[i*4]
    result.data[i * 3 + 1] = png.data[i*4 + 1]
    result.data[i * 3 + 2] = png.data[i*4 + 2]
    result.mask[i] = png.data[i*4 + 3]

proc loadImageJPG(fileName:string): Image =
  var jpg = ujCreate()
  if jpg == nil: return nil

  if ujDecodeFile(jpg, cstring(fileName)) != nil:
    new(result)
    let size = ujGetImageSize(jpg)
    result.width = ujGetWidth(jpg)
    result.height = ujGetHeight(jpg)
    result.data = newString(size * 3)
    result.mask = ""
    discard ujGetImage(jpg, cstring(result.data))
    ujDestroy(jpg)
  else:
    result = nil

proc loadImageBMP(fileName:string): Image =
  var bmp = loadBMP24(fileName)
  if bmp.width != 0 and bmp.height != 0:
    new(result)
    result.width = bmp.width
    result.height = bmp.height
    result.data = bmp.data
    result.mask = ""
  else:
    result = nil

# William Whitacre - 2018/01/19
template initImageData(dat, siz: untyped): untyped =
  if dat.len == 0: dat = newString(siz) else: dat.setLen(siz)

# William Whitacre - 2018/01/19
template setChannels(odat, i, r, g, b: untyped): untyped =
  odat[i * 3] = cast[char](r)
  odat[i * 3 + 1] = cast[char](g)
  odat[i * 3 + 2] = cast[char](b)

# William Whitacre - 2018/01/19
proc mapImageData(indata: seq[byte]; siz, ch: int; outdata, outmask: var string, nomask: bool): void =
  initImageData(outdata, siz * 3)
  if nomask: outmask = ""
  case ch:
    of 1:
      outmask = ""
      for i in 0..siz-1:
        setChannels(outdata, i, indata[i], indata[i], indata[i])
    of 2:
      initImageData(outmask, siz)
      for i in 0..siz-1:
        setChannels(outdata, i, indata[i*2], indata[i*2], indata[i*2])
        if not nomask: outmask[i] = indata[i * 2 + 1].char
    of 3:
      outmask = ""
      for i in 0..siz-1:
        setChannels(outdata, i, indata[i*3], indata[i*3+1], indata[i*3+2])
    of 4:
      initImageData(outmask, siz)
      for i in 0..siz-1:
        setChannels(outdata, i, indata[i*4], indata[i*4+1], indata[i*4+2])
        if not nomask: outmask[i] = indata[i * 4 + 3].char
    else:
      raise newException(Exception, "Bad image channel count " & $ch)

# William Whitacre - 2018/01/19
proc loadImageFallbackSTBI(filename: string, nomask: bool): Image =
  var
    img: Image
    numChannels: int

  new(img)

  result = nil
  try:
    let
      bytes = stbi.load(fileName, img.width, img.height, numChannels, if nomask: 3 else: 4)

    if not (bytes.len == 0):
      bytes.mapImageData(img.width * img.height, numChannels, img.data, img.mask, nomask)
      result = img
  except:
    echo(getCurrentExceptionMsg() & " " & filename)
    result = nil

proc loadImage*(fileName:string): Image =
  let path = splitFile(fileName)
  var nomask = false
  if path.ext.len() > 0:
    let ext = toLowerAscii(path.ext)
    if ext == ".png":
      result = loadImagePNG(fileName)
    elif ext == ".bmp":
      nomask = true
      result = loadImageBMP(fileName)
    elif ext == ".jpg" or ext == ".jpeg":
      nomask = true
      result = loadImageJPG(fileName)

    if result.isNil: # try fallback
      echo "before it's ", fileName, " falling back!"
      result = loadImageFallbackSTBI(fileName, nomask)
  else:
    result = nil

proc haveMask*(img: Image): bool =
  result = img.mask.len() > 0

proc clone*(img: Image): Image =
  new(result)
  result.width = img.width
  result.height = img.height
  result.data = img.data
  result.mask = img.mask

proc adjustTransparency*(img: Image, alpha:float) =
  if img.haveMask():
    for i in 0..high(img.mask):
      img.mask[i] = char(float(img.mask[i]) * alpha)
  else:
    img.mask = newString(img.width*img.height)
    for i in 0..high(img.mask):
      img.mask[i] = char(255.0 * alpha)
