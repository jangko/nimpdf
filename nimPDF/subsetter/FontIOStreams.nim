# Copyright (c) 2015 Andri Lim
#
# Distributed under the MIT license
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------
import strutils

type
  size_t* = int
  ByteVector* = string
  InputStream* = ref object of RootObj

  FileInputStream* = ref object of InputStream
    f: File
    pos: size_t
    len: size_t

  MemoryInputStream* = ref object of InputStream
    buf: ByteVector
    pos: size_t
    len: size_t

  OutputStream* = ref object of RootObj
  MemoryOutputStream* = ref object of OutputStream
    store: ByteVector

  FileOutputStream* = ref object of OutputStream
    f: File
    len: size_t

  FontInputStream* = ref object of InputStream
    inp: InputStream
    pos: int64
    length: int64  #bound on length of data to read
    bounded: bool

  FontOutputStream* = ref object of OutputStream
    stream : OutputStream
    pos : size_t

proc newEIO*(msg: string): ref IOError =
  new(result)
  result.msg = msg

#----------------------------------------------------------
method available*(s: InputStream): int {.base.} = discard
method close*(s: InputStream) {.base.} = discard
method read*(s: InputStream): int {.base.} = discard
method read*(s: InputStream, b: var ByteVector): int {.base.} = discard
method read*(s: InputStream, b: var ByteVector, offset, length: int): int {.base.} = discard
method skip*(s: InputStream, n: int64): int64 {.base.} = discard

#-------------------------------------------------------
method available*(s: FileInputStream): int = s.len - s.pos

method close*(s: FileInputStream) =
  if s.f != nil:
    close(s.f)
    s.len = 0
    s.pos = 0
    s.f = nil

method read*(s: FileInputStream): int =
  if s.f == nil:
    raise newEIO("no opened file")

  if endOfFile(s.f):
    raise newEIO("eof reached")

  var value: char
  var length = readBuffer(s.f, addr(value), sizeof(value))
  inc(s.pos, length)
  result = ord(value)

method read*(s: FileInputStream, b: var ByteVector, offset, length: int): int =
  if s.f == nil:
    raise newEIO("no opened file")

  if endOfFile(s.f):
    return -1

  let readCount = min(s.len - s.pos, length)

  if b.len == 0: b = newString(offset + readCount)

  if b.len < (offset + readCount):
    let grow = (offset + readCount) - b.len
    b.add(repeat(chr(0), grow))

  let actualRead = readBuffer(s.f, addr(b[offset]), readCount)
  inc(s.pos, actualRead)
  result = actualRead

method read*(s: FileInputStream, b: var ByteVector): int =
  result = s.read(b, 0, b.len)

method skip*(s: FileInputStream, n: int64): int64 =
  if s.f == nil:
    raise newEIO("no opened file")

  var skip_count: int64 = 0
  if n < 0: #move backwards
    skip_count = max(0 - int64(s.pos), n)
    s.pos -= size_t(0 - skip_count)
    setFilePos(s.f, s.pos)
  else:
    skip_count = min(s.len - s.pos, n)
    s.pos += size_t(skip_count)
    setFilePos(s.f, s.pos)

  result = skip_count

proc newFileInputStream*(filePath: string): FileInputStream =
  var f: File

  result = nil
  if open(f, filePath, fmRead):
    new(result)
    result.len = size_t(getFileSize(f))
    result.pos = 0
    result.f = f

#---------------------------------------------------------------
method available*(s: MemoryInputStream): int = s.len - s.pos
method close*(s: MemoryInputStream) = discard

method read*(s: MemoryInputStream): int =
  if s.pos >= s.len:
    raise newEIO("eof reached")

  let value = s.buf[s.pos]
  inc(s.pos)
  result = ord(value)

method read*(s: MemoryInputStream, b: var ByteVector, offset, length: int): int =
  if s.pos >= s.len:
    raise newEIO("eof reached")

  let readCount = min(s.len - s.pos, length)
  if b.len < offset + readCount:
    let grow = (offset + readCount) - b.len
    b.add(repeat(chr(0), grow))

  copyMem(addr(b[offset]), addr(s.buf[s.pos]), readCount)

  inc(s.pos, readCount)
  result = readCount

method read*(s: MemoryInputStream, b: var ByteVector): int =
  result = s.read(b, 0, b.len)

method skip*(s: MemoryInputStream, n: int64): int64 =
  var skip_count: int64 = 0
  if n < 0:  #move backwards
    skip_count = max(0 - int64(s.pos), n)
    s.pos -= size_t(0 - skip_count)
  else:
    skip_count = min(s.len - s.pos, size_t(n))
    s.pos += size_t(skip_count)
  result = skip_count

proc newMemoryInputStream*(length: size_t): MemoryInputStream =
  new(result)
  result.len = length
  result.pos = 0
  result.buf = newString(length)

proc newMemoryInputStream*(b: ByteVector, length: size_t): MemoryInputStream =
  new(result)
  result.len = length
  result.pos = 0
  result.buf = b

#---------------------------------------------------------------
method close*(s:OutputStream) {.base.} = discard
method flush*(s:OutputStream) {.base.} = discard
method write*(s:OutputStream, b: ByteVector): int {.base.} = discard
method write*(s:OutputStream, b: ByteVector, offset, length:int): int{.base.} = discard
method write*(s:OutputStream, b: char): int {.base.} = discard

#---------------------------------------------------------------
method close*(s:MemoryOutputStream) = discard
method flush*(s:MemoryOutputStream) = discard

method write*(s:MemoryOutputStream, b: ByteVector): int =
  s.store.add(b)
  result = b.len

method write*(s:MemoryOutputStream, b: ByteVector, offset, length: int): int =
  if offset >= 0 and length > 0:
    s.store.add(b.substr(offset, offset + length))
    result = length
  else:
    raise newException(ValueError, "Attempt to write outside the bounds of the data.")

method write*(s:MemoryOutputStream, b: char): int =
  s.store.add(b)
  result = 1

proc Get*(s: MemoryOutputStream): ByteVector =
  result = s.store

proc Size*(s: MemoryOutputStream): size_t =
  result = s.store.len

proc newMemoryOutputStream*(): MemoryOutputStream =
  new(result)
  result.store = ""

#------------------------------------------------------------
method close*(s:FileOutputStream) =
  if s.f != nil:
    close(s.f)
    s.len = 0
    s.f = nil

method flush*(s:FileOutputStream) =
  flushFile(s.f)

method write*(s:FileOutputStream, b: ByteVector): int =
  write(s.f, b)
  s.len += b.len
  result = b.len

method write*(s:FileOutputStream, b: ByteVector, offset, length: int): int =
  if offset >= 0 and length > 0:
    write(s.f, b.substr(offset, offset + length))
    s.len += length
    result = length
  else:
    raise newException(ValueError, "Attempt to write outside the bounds of the data.")

method write*(s:FileOutputStream, b: char): int =
  write(s.f, b)
  inc(s.len)
  result = 1

proc Size*(s: FileOutputStream): size_t =
  result = s.len

proc newFileOutputStream*(filePath: string): FileOutputStream =
  var f: File

  result = nil
  if open(f, filePath, fmWrite):
    new(result)
    result.len = 0
    result.f = f
#--------------------------------------------------------------
proc newFontInputStream*(inp: InputStream, length: int): FontInputStream =
  new(result)
  result.inp = inp
  result.pos = 0
  result.length   = length
  result.bounded  = true

proc newFontInputStream*(inp: InputStream): FontInputStream =
  new(result)
  result.inp = inp
  result.pos = 0
  result.length   = 0
  result.bounded  = false

method available*(s: FontInputStream): int =
  result = 0
  if s.inp != nil: result = s.inp.available()

method close*(s: FontInputStream) =
  if s.inp != nil: s.inp.close()

method read*(s: FontInputStream): int =
  if s.bounded and s.pos >= s.length:
    return -1

  let b = ord(s.inp.read())
  if b >= 0:
    inc(s.pos)

  result = b

method read*(s: FontInputStream, b: var ByteVector, offset, length: int): int =
  if s.bounded and s.pos >= s.length:
    return -1

  var bytesToRead = length
  if s.bounded:
    bytesToRead = min(length, int(s.length - s.pos))

  let bytesRead = s.inp.read(b, offset, bytesToRead)
  inc(s.pos, bytesRead)
  result = bytesRead

method read*(s: FontInputStream, b: var ByteVector): int =
  result = s.read(b, 0, b.len)

method position*(s: FontInputStream): int64 {.base.} =
  result = s.pos

method readChar*(s: FontInputStream): int {.base.} =
  result = s.read()

method readUShort*(s: FontInputStream): int {.base.} =
  result = 0xffff and (s.read() shl 8 or s.read())

method readShort*(s: FontInputStream): int {.base.} =
  result = ((s.read() shl 8 or s.read()) shl 16) shr 16

method readUInt24*(s: FontInputStream): int {.base.} =
  result = 0xffffff and (s.read() shl 16 or s.read() shl 8 or s.read())

method readLong*(s: FontInputStream): int {.base.} =
  result = s.read() shl 24 or s.read() shl 16 or s.read() shl 8 or s.read()

method readULong*(s: FontInputStream): int64 {.base.} =
  let val = s.readLong()
  return 0xffffffff and int64(cast[uint32](val))

method readULongAsInt*(s: FontInputStream): int {.base.} =
  let ulong = s.readULong()
  if (ulong and 0x80000000) == 0x80000000:
    raise newException(ValueError, "Long value too large to fit into an integer.")

  result = int(ulong) and not 0x80000000'i32

method readFixed*(s: FontInputStream): int {.base.} =
  result = s.readLong()

method readDateTimeAsLong*(s: FontInputStream): int64 {.base.} =
  result = s.readULong() shl 32 or s.readULong()

method skip*(s: FontInputStream, n: int64): int64 =
  result = 0
  if s.inp != nil:
    let skipped = s.inp.skip(n)
    s.pos += skipped
    result = skipped

#--------------------------------------------------------------

proc newFontOutputStream*(os: OutputStream): FontOutputStream =
  new(result)
  result.stream = os
  result.pos = 0

method close*(s:FontOutputStream) =
  if s.stream != nil:
    s.stream.flush()
    s.stream.close()
    s.pos = 0

method flush*(s:FontOutputStream) =
  if s.stream != nil:
    s.stream.flush()

method write*(s:FontOutputStream, b: ByteVector, offset, length:int): int =
  assert(s.stream != nil)
  if (offset < 0 or length < 0 or (offset + length) < 0 or (offset + length) > b.len):
    raise newException(ValueError, "Attempt to write outside the bounds of the data.")

  result = s.stream.write(b, offset, length)
  s.pos += length

method write*(s:FontOutputStream, b: ByteVector): int =
  result = s.write(b, 0, b.len)
  s.pos += b.len

method write*(s:FontOutputStream, b: char): int =
  if s.stream != nil:
    result = s.stream.write(b)
    inc(s.pos)

method writeChar*(s:FontOutputStream, c: char) {.base.} =
  discard s.write(c)

method writeUShort*(s:FontOutputStream, us: int) {.base.} =
  discard s.write(chr((us shr 8) and 0xff))
  discard s.write(chr(us and 0xff))

method writeShort*(s:FontOutputStream, sh: int) {.base.} =
  s.writeUShort(sh)

method writeUInt24*(s:FontOutputStream, ui: int) {.base.} =
  discard s.write(chr((ui shr 16) and 0xff))
  discard s.write(chr((ui shr 8) and 0xff))
  discard s.write(chr(ui and 0xff))

method writeULong*(s:FontOutputStream, ul: int64) {.base.} =
  discard s.write(chr(int((ul shr 24) and 0xff)))
  discard s.write(chr(int((ul shr 16) and 0xff)))
  discard s.write(chr(int((ul shr 8) and 0xff)))
  discard s.write(chr(int(ul and 0xff)))

method writeLong*(s:FontOutputStream, lg: int64) {.base.} =
  s.writeULong(lg)

method writeFixed*(s:FontOutputStream, lg: int) {.base.} =
  s.writeULong(lg)

method writeDateTime*(s:FontOutputStream, date: int64) {.base.} =
  s.writeULong((date shr 32) and 0xffffffff)
  s.writeULong(date and 0xffffffff)
