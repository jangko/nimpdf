# Copyright (c) 2015 Andri Lim
#
# Distributed under the MIT license
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------
import FontIOStreams, strutils

const
  COPY_BUFFER_SIZE = 8192
  MAX_INT = high(int)

type
  ByteArray* = ref object of RootObj
    storageLength: int
    filledLength: int

  MemoryByteArray* = ref object of ByteArray
    b: ByteVector

  GrowableMemoryByteArray* = ref object of ByteArray
    b: ByteVector

method internalPut(ba: ByteArray, index: int, b: char) {.base.} = discard
method internalPut(ba: ByteArray, index: int, b: string, offset, length: int): int {.base.} = discard
method internalGet(ba: ByteArray, index: int): int {.base.} = discard
method internalGet(ba: ByteArray, index: int, b: var string, offset, length: int): int {.base.} = discard
method close*(ba: ByteArray) {.base.} = discard
method internalBuffer*(ba: ByteArray): ByteVector {.base.} = discard

proc setFilledLength*(ba: ByteArray, filledLength: int) =
  ba.filledLength = min(filledLength, ba.storageLength)

proc initByteArray*(ba: ByteArray, filledLength, storageLength: int) =
  ba.storageLength = storageLength
  ba.setFilledLength(filledLength)

method get*(ba: ByteArray, index: int): int {.base.} =
  if (index < 0 or index >= ba.filledLength): return -1
  result = ba.internalGet(index) and 0xff

method get*(ba: ByteArray, index: int, b: var string, offset, length: int): int {.base.} =
  if index < 0 or index >= ba.filledLength: return -1
  let actualLength = min(length, ba.filledLength - index)
  result = ba.internalGet(index, b, offset, actualLength)

method get*(ba: ByteArray, index: int, b: var string): int {.base.} =
  result = ba.get(index, b, 0, b.len)

proc length*(ba: ByteArray): int = ba.filledLength
proc size*(ba: ByteArray): int = ba.storageLength

method put*(ba: ByteArray, index: int, b: char) {.base.}  =
  if index < 0 or index >= ba.size():
    raise newException(ValueError, "Attempt to write outside the bounds of the data.")
  ba.internalPut(index, b)
  ba.filledLength = max(ba.filledLength, index + 1)

method put*(ba: ByteArray, index: int, b:string, offset, length: int): int {.base.} =
  if index < 0 or index >= ba.size():
    raise newException(ValueError, "Attempt to write outside the bounds of the data.")
  let actualLength = min(length, ba.size() - index)

  let bytesWritten = ba.internalPut(index, b, offset, actualLength)
  ba.filledLength = max(ba.filledLength, index + bytesWritten)
  result = bytesWritten

method put*(ba: ByteArray, index: int, b:string): int {.base.} =
  result = ba.put(index, b, 0, b.len)

method copyTo*(ba: ByteArray, dstOffset: int, target: ByteArray, srcOffset, len: int): int {.base.} =
  var b = newString(COPY_BUFFER_SIZE)
  var index = 0
  var length = len
  var bufferLength = min(b.len, length)
  var bytesRead = 0

  while true:
    bytesRead = ba.get(index + srcOffset, b, 0, bufferLength)
    if bytesRead <= 0: break
    discard target.put(index + dstOffset, b, 0, bytesRead)
    index += bytesRead
    length -= bytesRead
    bufferLength = min(b.len, length)

  result = index

method copyTo*(ba, target: ByteArray, offset, length: int): int {.base.} =
  result = ba.copyTo(0, target, offset, length)

method copyTo*(ba, target: ByteArray): int {.base.} =
  result = ba.copyTo(target, 0, ba.length())

method copyToOS*(ba: ByteArray, offset, length: int, os: OutputStream): int {.base.} =
  var b = newString(COPY_BUFFER_SIZE)
  var index = 0
  var bufferLength = min(b.len, length)
  var bytesRead = 0

  while true:
    bytesRead = ba.get(index + offset, b, 0, bufferLength)
    if bytesRead <= 0: break
    discard os.write(b, 0, bytesRead)
    index += bytesRead
    bufferLength = min(b.len, length - index)
  result = index

method copyToOS*(ba: ByteArray, os: OutputStream): int {.base.} =
  result = ba.copyToOS(0, ba.length(), os)

method copyFrom*(ba: ByteArray, inp: InputStream, len: int) {.base.} =
  var b = newString(COPY_BUFFER_SIZE)
  var index = 0
  var length = len
  var bufferLength = min(b.len, length)
  var bytesRead = 0

  while true:
    bytesRead = inp.read(b, 0, bufferLength)
    if bytesRead <= 0: break
    if ba.put(index, b, 0, bytesRead) != bytesRead:
      raise newEIO("Error writing bytes.")
    index += bytesRead
    length -= bytesRead
    bufferLength = min(b.len, length)

method copyFrom*(ba: ByteArray, inp: InputStream) {.base.} =
  var b = newString(COPY_BUFFER_SIZE)
  var index = 0
  var bufferLength = b.len
  var bytesRead = 0

  while true:
    bytesRead = inp.read(b, 0, bufferLength)
    if bytesRead <= 0: break
    if ba.put(index, b, 0, bytesRead) != bytesRead:
      raise newEIO("Error writing bytes.")
    index += bytesRead

#----------------------------------------------------------
method copyToOS*(ba: MemoryByteArray, offset, length: int, os: OutputStream) : int =
  result = os.write(ba.b, offset, length)

method internalPut(ba: MemoryByteArray, index: int, b: char) =
  ba.b[index] = b

method internalPut(ba: MemoryByteArray, index: int, b: string, offset, length: int): int =
  for i in 0..length-1:
    ba.b[index + i] = b[i + offset]
  result = length

method internalGet(ba: MemoryByteArray, index: int): int =
  result = ord(ba.b[index])

method internalGet(ba: MemoryByteArray, index: int, b: var string, offset, length: int): int =
  copyMem(addr(b[offset]), addr(ba.b[index]), length)
  result = length

method close*(ba: MemoryByteArray) =
  ba.b = ""

method internalBuffer*(ba: MemoryByteArray): ByteVector = ba.b

proc newMemoryByteArray*(length: int): MemoryByteArray =
  new(result)
  initByteArray(result, 0, length)
  result.b = repeat(chr(0), length)

proc newMemoryByteArray*(b: ByteVector, filled_length: int): MemoryByteArray =
  new(result)
  initByteArray(result, filled_length, filled_length)
  result.b = b

#---------------------------------------------------------

method copyTo*(ba: GrowableMemoryByteArray, offset, length: int, os: OutputStream) : int {.base.} =
  os.write(ba.b, offset, length)

method internalPut(ba: GrowableMemoryByteArray, index: int, b: char) =
  if index >= ba.b.len:
    let grow = index - ba.b.len
    ba.b.add(repeat(chr(0), grow + 1))
  ba.b[index] = b

method internalPut(ba: GrowableMemoryByteArray, index: int, b: string, offset, length: int): int =
  if (index + length) >= ba.b.len:
    let grow = (index + length) - ba.b.len
    ba.b.add(repeat(chr(0), grow + 1))

  for i in 0..length-1:
    ba.b[index + i] = b[offset + i]

  result = length

method internalGet(ba: GrowableMemoryByteArray, index: int): int =
  result = ord(ba.b[index])

method internalGet(ba: GrowableMemoryByteArray, index: int, b: var string, offset, length: int): int =
  copyMem(addr(b[offset]), addr(ba.b[index]), length)
  result = length

method close*(ba: GrowableMemoryByteArray) =
  ba.b = ""

method internalBuffer*(ba: GrowableMemoryByteArray): ByteVector = ba.b

proc newGrowableMemoryByteArray*(): GrowableMemoryByteArray =
  new(result)
  initByteArray(result, 0, MAX_INT)
  result.b = ""
