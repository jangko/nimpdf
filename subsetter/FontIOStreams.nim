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
        position: int64
        length: int64  #bound on length of data to read
        bounded: bool
    
    FontOutputStream* = ref object of OutputStream
        stream : OutputStream
        position : size_t

proc newEIO*(msg: string): ref IOError =
    new(result)
    result.msg = msg

proc newIndexError*(msg: string): ref IndexError =
    new(result)
    result.msg = msg

proc newArithErr*(msg: string): ref ArithmeticError =
    new(result)
    result.msg = msg

proc newAssertionError*(msg: string): ref AssertionError =
    new(result)
    result.msg = msg

#----------------------------------------------------------
method Available*(s: InputStream): int = discard
method Close*(s: InputStream) = discard
method Read*(s: InputStream): int = discard
method Read*(s: InputStream, b: var ByteVector): int = discard
method Read*(s: InputStream, b: var ByteVector, offset, length: int): int = discard
method Skip*(s: InputStream, n: int64): int64 = discard

#-------------------------------------------------------
method Available*(s: FileInputStream): int = s.len - s.pos

method Close*(s: FileInputStream) = 
    if s.f != nil:
        close(s.f)
        s.len = 0
        s.pos = 0
        s.f = nil
  
method Read*(s: FileInputStream): int = 
    if s.f == nil:
        raise newEIO("no opened file")

    if endOfFile(s.f):
        raise newEIO("eof reached")

    var value: char
    var length = readBuffer(s.f, addr(value), sizeof(value))
    inc(s.pos, length)
    result = ord(value)

method Read*(s: FileInputStream, b: var ByteVector, offset, length: int): int =
    if s.f == nil:
        raise newEIO("no opened file")
        
    if endOfFile(s.f):
        #echo "avail ", $s.Available(), " offset: " , $offset, " length : ",  $length
        #raise newEIO("eof reached")
        return -1
        
    let read_count = min(s.len - s.pos, length)
    
    if b == nil: b = newString(offset + read_count)
    
    if b.len < (offset + read_count):
        let grow = (offset + read_count) - b.len
        b.add(repeatChar(grow, chr(0)))
        
    let actual_read = readBuffer(s.f, addr(b[offset]), read_count)
    inc(s.pos, actual_read)
    result = actual_read
        
method Read*(s: FileInputStream, b: var ByteVector): int = 
    result = s.Read(b, 0, b.len)

method Skip*(s: FileInputStream, n: int64): int64 =
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

proc makeFileInputStream*(filePath: string): FileInputStream =
    var f: File
    
    result = nil
    if open(f, filePath, fmRead):
        new(result)
        result.len = size_t(getFileSize(f))
        result.pos = 0
        result.f = f

#---------------------------------------------------------------
method Available*(s: MemoryInputStream): int = s.len - s.pos
method Close*(s: MemoryInputStream) = discard

method Read*(s: MemoryInputStream): int = 
    if s.pos >= s.len:
        raise newEIO("eof reached")
    
    let value = s.buf[s.pos]
    inc(s.pos)
    result = ord(value)

method Read*(s: MemoryInputStream, b: var ByteVector, offset, length: int): int =
    if s.pos >= s.len:
        raise newEIO("eof reached")
        
    let read_count = min(s.len - s.pos, length)
    if b.len < offset + read_count:
        let grow = (offset + read_count) - b.len
        b.add(repeatChar(grow, chr(0)))
  
    copyMem(addr(b[offset]), addr(s.buf[s.pos]), read_count)
    
    inc(s.pos, read_count)
    result = read_count
  
method Read*(s: MemoryInputStream, b: var ByteVector): int = 
    result = s.Read(b, 0, b.len)
 
method Skip*(s: MemoryInputStream, n: int64): int64 = 
    var skip_count: int64 = 0
    if n < 0:  #move backwards
        skip_count = max(0 - int64(s.pos), n)
        s.pos -= size_t(0 - skip_count)
    else:
        skip_count = min(s.len - s.pos, size_t(n))
        s.pos += size_t(skip_count)
    result = skip_count

proc makeMemoryInputStream*(length: size_t): MemoryInputStream =
    new(result)
    result.len = length
    result.pos = 0
    result.buf = newString(length)

proc makeMemoryInputStream*(b: ByteVector, length: size_t): MemoryInputStream =
    new(result)
    result.len = length
    result.pos = 0
    result.buf = b

#---------------------------------------------------------------
method Close*(s:OutputStream) = discard
method Flush*(s:OutputStream) = discard
method Write*(s:OutputStream, b: ByteVector): int = discard
method Write*(s:OutputStream, b: ByteVector, offset, length:int): int = discard
method Write*(s:OutputStream, b: char): int = discard

#---------------------------------------------------------------
method Close*(s:MemoryOutputStream) = discard
method Flush*(s:MemoryOutputStream) = discard

method Write*(s:MemoryOutputStream, b: ByteVector): int = 
    s.store.add(b)
    result = b.len
    
method Write*(s:MemoryOutputStream, b: ByteVector, offset, length: int): int =
    if offset >= 0 and length > 0:
        s.store.add(b.substr(offset, offset + length))
        result = length
    else:
        raise newIndexError("Attempt to write outside the bounds of the data.")
  
method Write*(s:MemoryOutputStream, b: char): int = 
    s.store.add(b)
    result = 1

proc Get*(s: MemoryOutputStream): ByteVector =
    result = s.store

proc Size*(s: MemoryOutputStream): size_t =
    result = s.store.len

proc makeMemoryOutputStream*(): MemoryOutputStream =
    new(result)
    result.store = ""

#------------------------------------------------------------
method Close*(s:FileOutputStream) = 
    if s.f != nil:
        close(s.f)
        s.len = 0
        s.f = nil
  
method Flush*(s:FileOutputStream) = 
    flushFile(s.f)
    
method Write*(s:FileOutputStream, b: ByteVector): int = 
    write(s.f, b)
    s.len += b.len
    result = b.len
    
method Write*(s:FileOutputStream, b: ByteVector, offset, length: int): int =
    if offset >= 0 and length > 0:
        write(s.f, b.substr(offset, offset + length))
        s.len += length
        result = length
    else:
        raise newIndexError("Attempt to write outside the bounds of the data.")
  
method Write*(s:FileOutputStream, b: char): int = 
    write(s.f, b)
    inc(s.len)
    result = 1

proc Size*(s: FileOutputStream): size_t =
    result = s.len

proc makeFileOutputStream*(filePath: string): FileOutputStream =
    var f: File
    
    result = nil
    if open(f, filePath, fmWrite):
        new(result)
        result.len = 0
        result.f = f
#--------------------------------------------------------------
proc makeFontInputStream*(inp: InputStream, length: int): FontInputStream =
    new(result)
    result.inp = inp
    result.position = 0
    result.length   = length
    result.bounded  = true

proc makeFontInputStream*(inp: InputStream): FontInputStream =
    new(result)
    result.inp = inp
    result.position = 0
    result.length   = 0
    result.bounded  = false

method Available*(s: FontInputStream): int = 
    result = 0
    if s.inp != nil: result = s.inp.Available()
    
method Close*(s: FontInputStream) = 
    if s.inp != nil: s.inp.Close()
    
method Read*(s: FontInputStream): int =
    if s.bounded and s.position >= s.length:
        return -1
    
    let b = ord(s.inp.Read())
    if b >= 0:
        inc(s.position)
    
    result = b
  
method Read*(s: FontInputStream, b: var ByteVector, offset, length: int): int =
    if s.bounded and s.position >= s.length:
        return -1
    
    var bytesToRead = length
    if s.bounded: 
        bytesToRead = min(length, int(s.length - s.position))
        
    let bytesRead = s.inp.Read(b, offset, bytesToRead)
    inc(s.position, bytesRead)
    result = bytesRead
  
method Read*(s: FontInputStream, b: var ByteVector): int =
    result = s.Read(b, 0, b.len)

method Position*(s: FontInputStream): int64 =
    result = s.position
  
method ReadChar*(s: FontInputStream): int =
    result = s.Read()

method ReadUShort*(s: FontInputStream): int =
    result = 0xffff and (s.Read() shl 8 or s.Read())
  
method ReadShort*(s: FontInputStream): int =
    result = ((s.Read() shl 8 or s.Read()) shl 16) shr 16

method ReadUInt24*(s: FontInputStream): int =
    result = 0xffffff and (s.Read() shl 16 or s.Read() shl 8 or s.Read())

method ReadLong*(s: FontInputStream): int =
    result = s.Read() shl 24 or s.Read() shl 16 or s.Read() shl 8 or s.Read()
    
method ReadULong*(s: FontInputStream): int64 =
    let val = s.ReadLong()
    return 0xffffffff and int64(cast[uint32](val))
    
method ReadULongAsInt*(s: FontInputStream): int =
    let ulong = s.ReadULong()
    if (ulong and 0x80000000) == 0x80000000:
        raise newArithErr("Long value too large to fit into an integer.")
    
    result = int(ulong) and not 0x80000000'i32

method ReadFixed*(s: FontInputStream): int =
    result = s.ReadLong()

method ReadDateTimeAsLong*(s: FontInputStream): int64 =
    result = s.ReadULong() shl 32 or s.ReadULong()

method Skip*(s: FontInputStream, n: int64): int64 =
    result = 0
    if s.inp != nil:
        let skipped = s.inp.Skip(n)
        s.position += skipped
        result = skipped

#--------------------------------------------------------------

proc makeFontOutputStream*(os: OutputStream): FontOutputStream =
    new(result)
    result.stream = os
    result.position = 0
  
method Close*(s:FontOutputStream) = 
    if s.stream != nil:
        s.stream.Flush()
        s.stream.Close()
        s.position = 0
    
method Flush*(s:FontOutputStream) = 
    if s.stream != nil:
        s.stream.Flush()

method Write*(s:FontOutputStream, b: ByteVector, offset, length:int): int = 
    assert(s.stream != nil)
    if (offset < 0 or length < 0 or (offset + length) < 0 or (offset + length) > b.len):
        raise newIndexError("Attempt to write outside the bounds of the data.")
    
    result = s.stream.Write(b, offset, length)
    s.position += length
    
method Write*(s:FontOutputStream, b: ByteVector): int = 
    result = s.Write(b, 0, b.len)
    s.position += b.len
  
method Write*(s:FontOutputStream, b: char): int = 
    if s.stream != nil:
        result = s.stream.Write(b)
        inc(s.position)
  
method WriteChar*(s:FontOutputStream, c: char) =
    discard s.Write(c)
    
method WriteUShort*(s:FontOutputStream, us: int) =
    discard s.Write(chr((us shr 8) and 0xff))
    discard s.Write(chr(us and 0xff))
  
method WriteShort*(s:FontOutputStream, sh: int) =
    s.WriteUShort(sh)
    
method WriteUInt24*(s:FontOutputStream, ui: int) =
    discard s.Write(chr((ui shr 16) and 0xff))
    discard s.Write(chr((ui shr 8) and 0xff))
    discard s.Write(chr(ui and 0xff))
  
method WriteULong*(s:FontOutputStream, ul: int64) =
    discard s.Write(chr(int((ul shr 24) and 0xff)))
    discard s.Write(chr(int((ul shr 16) and 0xff)))
    discard s.Write(chr(int((ul shr 8) and 0xff)))
    discard s.Write(chr(int(ul and 0xff)))
  
method WriteLong*(s:FontOutputStream, lg: int64) =
    s.WriteULong(lg)

method WriteFixed*(s:FontOutputStream, lg: int) =
    s.WriteULong(lg)

method WriteDateTime*(s:FontOutputStream, date: int64) =
    s.WriteULong((date shr 32) and 0xffffffff)
    s.WriteULong(date and 0xffffffff)
  