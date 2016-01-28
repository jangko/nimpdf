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

import nimBMP, os, strutils, nimPNG, nimz

#{.deadCodeElim: on.}
#{.passC: "-D LODEPNG_NO_COMPILE_CPP".}
#{.passL: "-lstdc++" .}
#{.compile: "lodepng.c".}
{.compile: "ujpeg.c".}

type
  Image* = ref object
    width*, height*, ID*: int
    data*, mask*: string
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
  if bmp != nil:
    new(result)
    result.width = bmp.width
    result.height = bmp.height
    result.data = bmp.data
    result.mask = ""
  else:
    result = nil

proc loadImage*(fileName:string): Image =
  let path = splitFile(fileName)
  if path.ext.len() > 0:
    let ext = toLower(path.ext)
    if ext == ".png": return loadImagePNG(fileName)
    if ext == ".bmp": return loadImageBMP(fileName)
    if ext == ".jpg" or ext == ".jpeg": return loadImageJPG(fileName)
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

proc zcompress*(data: string): string =
  var nz = nzDeflateInit(data)
  result = nz.zlib_compress()

when isMainModule:
  var img = loadImage("pngbar.png")
  var x = loadImage("24bit.bmp")
  if img != nil : echo "width: ", img.width
  if x != nil : echo "width: ", x.width
  let sss = "mau kemana dong? engk ink engk? weleh weleh mmmmmm sangkamu aku mau kemana sih gitu aja ngedumel, weleh weleh, sinting"
  var res = zcompress(sss)
  echo "ori: ", sss.len(), " len: ", res.len()
