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
    
method internalPut(ba: ByteArray, index: int, b: char) = discard
method internalPut(ba: ByteArray, index: int, b: string, offset, length: int): int = discard
method internalGet(ba: ByteArray, index: int): int = discard
method internalGet(ba: ByteArray, index: int, b: var string, offset, length: int): int = discard
method Close*(ba: ByteArray) = discard
method InternalBuffer*(ba: ByteArray): ByteVector = discard

proc SetFilledLength*(ba: ByteArray, filledLength: int) =
  ba.filledLength = min(filledLength, ba.storageLength)
    
proc initByteArray*(ba: ByteArray, filledLength, storageLength: int) =
  ba.storageLength = storageLength
  ba.SetFilledLength(filledLength)

method Get*(ba: ByteArray, index: int): int =
  if (index < 0 or index >= ba.filledLength): return -1
  result = ba.internalGet(index) and 0xff
  
method Get*(ba: ByteArray, index: int, b: var string, offset, length: int): int =
  if index < 0 or index >= ba.filledLength: return -1
  let actualLength = min(length, ba.filledLength - index)
  result = ba.internalGet(index, b, offset, actualLength)
  
method Get*(ba: ByteArray, index: int, b: var string): int =
  result = ba.Get(index, b, 0, b.len)

proc Length*(ba: ByteArray): int = ba.filledLength
proc Size*(ba: ByteArray): int = ba.storageLength

method Put*(ba: ByteArray, index: int, b: char) = 
  if index < 0 or index >= ba.Size():
    raise newIndexError("Attempt to write outside the bounds of the data.")
  ba.internalPut(index, b)
  ba.filledLength = max(ba.filledLength, index + 1)

method Put*(ba: ByteArray, index: int, b:string, offset, length: int): int =
  if index < 0 or index >= ba.Size():
    raise newIndexError("Attempt to write outside the bounds of the data.")
  let actualLength = min(length, ba.Size() - index)
  
  let bytesWritten = ba.internalPut(index, b, offset, actualLength)
  ba.filledLength = max(ba.filledLength, index + bytesWritten)
  result = bytesWritten
 
method Put*(ba: ByteArray, index: int, b:string): int =
  result = ba.Put(index, b, 0, b.len)

method CopyTo*(ba: ByteArray, dstOffset: int, target: ByteArray, srcOffset, len: int): int =
  var b = newString(COPY_BUFFER_SIZE)
  var index = 0
  var length = len
  var bufferLength = min(b.len, length)
  var bytesRead = 0

  while true:
    bytesRead = ba.Get(index + srcOffset, b, 0, bufferLength)
    if bytesRead <= 0: break
    discard target.Put(index + dstOffset, b, 0, bytesRead)
    index  += bytesRead
    length -= bytesRead
    bufferLength = min(b.len, length)
    
  result = index
   
method CopyTo*(ba, target: ByteArray, offset, length: int): int =
  result = ba.CopyTo(0, target, offset, length) 
   
method CopyTo*(ba, target: ByteArray): int =
  result = ba.CopyTo(target, 0, ba.Length())

method CopyTo*(ba: ByteArray, os: OutputStream, offset, length: int) : int =
  var b = newString(COPY_BUFFER_SIZE)
  var index = 0
  var bufferLength = min(b.len, length)
  var bytesRead = 0

  while true:
    bytesRead = ba.Get(index + offset, b, 0, bufferLength)
    if bytesRead <= 0: break
    discard os.Write(b, 0, bytesRead)
    index += bytesRead
    bufferLength = min(b.len, length - index)
  result = index
  
method CopyTo*(ba: ByteArray, os: OutputStream): int =
  result = ba.CopyTo(os, 0, ba.Length())

method CopyFrom*(ba: ByteArray, inp: InputStream, len: int) =
  var b = newString(COPY_BUFFER_SIZE)
  var index = 0
  var length = len
  var bufferLength = min(b.len, length)
  var bytesRead = 0
    
  while true:
    bytesRead = inp.Read(b, 0, bufferLength)
    if bytesRead <= 0: break
    if ba.Put(index, b, 0, bytesRead) != bytesRead:
      raise newEIO("Error writing bytes.")
    index  += bytesRead
    length -= bytesRead
    bufferLength = min(b.len, length)

method CopyFrom*(ba: ByteArray, inp: InputStream) =
  var b = newString(COPY_BUFFER_SIZE)
  var index = 0
  var bufferLength = b.len
  var bytesRead = 0
  
  while true:
    bytesRead = inp.Read(b, 0, bufferLength)
    if bytesRead <= 0: break
    if ba.Put(index, b, 0, bytesRead) != bytesRead:
      raise newEIO("Error writing bytes.")
    index += bytesRead

#----------------------------------------------------------
method CopyTo*(ba: MemoryByteArray, os: OutputStream, offset, length: int) : int =
  result = os.Write(ba.b, offset, length)

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

method Close*(ba: MemoryByteArray) =
  ba.b = ""

method InternalBuffer*(ba: MemoryByteArray): ByteVector = ba.b

proc makeMemoryByteArray*(length: int): MemoryByteArray =
  new(result)
  initByteArray(result, 0, length)
  result.b = repeatChar(length, chr(0))

proc makeMemoryByteArray*(b: ByteVector, filled_length: int): MemoryByteArray =
  new(result)
  initByteArray(result, filled_length, filled_length)
  result.b = b
  
#---------------------------------------------------------

method CopyTo*(ba: GrowableMemoryByteArray, os: OutputStream, offset, length: int) : int =
  os.Write(ba.b, offset, length)

method internalPut(ba: GrowableMemoryByteArray, index: int, b: char) =
  if index >= ba.b.len:
    let grow = index - ba.b.len
    ba.b.add(repeatChar(grow + 1, chr(0)))
  ba.b[index] = b

method internalPut(ba: GrowableMemoryByteArray, index: int, b: string, offset, length: int): int =
  if (index + length) >= ba.b.len:
    let grow = (index + length) - ba.b.len
    ba.b.add(repeatChar(grow + 1, chr(0)))
  
  for i in 0..length-1:
    ba.b[index + i] = b[offset + i]
    
  result = length
  
method internalGet(ba: GrowableMemoryByteArray, index: int): int =
  result = ord(ba.b[index])

method internalGet(ba: GrowableMemoryByteArray, index: int, b: var string, offset, length: int): int =
  copyMem(addr(b[offset]), addr(ba.b[index]), length)
  result = length

method Close*(ba: GrowableMemoryByteArray) =
  ba.b = ""

method InternalBuffer*(ba: GrowableMemoryByteArray): ByteVector = ba.b

proc makeGrowableMemoryByteArray*(): GrowableMemoryByteArray =
  new(result)
  initByteArray(result, 0, MAX_INT)
  result.b = ""