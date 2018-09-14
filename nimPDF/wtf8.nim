# Copyright(c) 2016 Andri Lim
#
# Distributed under the MIT license
# (See accompanying file LICENSE.txt)
#
# Nim version of wtf8 originally written by Bjoern Hoehrmann
#
# See http://bjoern.hoehrmann.de/utf-8/decoder/dfa/ for details.
#

const
  UTF8_ACCEPT = 0
  UTF8_REJECT = 12

  wtf8_utf8d = [
    # The first part of the table maps bytes to character classes that
    # to reduce the size of the transition table and create bitmasks.
    0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,
    0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,
    0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,
    0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,
    0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,
    0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,
    0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,
    0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,0'u8,
    1'u8,1'u8,1'u8,1'u8,1'u8,1'u8,1'u8,1'u8,1'u8,1'u8,1'u8,1'u8,1'u8,1'u8,1'u8,1'u8,
    9'u8,9'u8,9'u8,9'u8,9'u8,9'u8,9'u8,9'u8,9'u8,9'u8,9'u8,9'u8,9'u8,9'u8,9'u8,9'u8,
    7'u8,7'u8,7'u8,7'u8,7'u8,7'u8,7'u8,7'u8,7'u8,7'u8,7'u8,7'u8,7'u8,7'u8,7'u8,7'u8,
    7'u8,7'u8,7'u8,7'u8,7'u8,7'u8,7'u8,7'u8,7'u8,7'u8,7'u8,7'u8,7'u8,7'u8,7'u8,7'u8,
    8'u8,8'u8,2'u8,2'u8,2'u8,2'u8,2'u8,2'u8,2'u8,2'u8,2'u8,2'u8,2'u8,2'u8,2'u8,2'u8,
    2'u8,2'u8,2'u8,2'u8,2'u8,2'u8,2'u8,2'u8,2'u8,2'u8,2'u8,2'u8,2'u8,2'u8,2'u8,2'u8,
    10'u8,3'u8,3'u8,3'u8,3'u8,3'u8,3'u8,3'u8,3'u8,3'u8,3'u8,3'u8,3'u8,4'u8,3'u8,3'u8,
    11'u8,6'u8,6'u8,6'u8,5'u8,8'u8,8'u8,8'u8,8'u8,8'u8,8'u8,8'u8,8'u8,8'u8,8'u8,8'u8,

    # The second part is a transition table that maps a combination
    # of a state of the automaton and a character class to a state.
    0'u8,12'u8,24'u8,36'u8,60'u8,96'u8,84'u8,12'u8,12'u8,12'u8,48'u8,72'u8,
    12'u8,12'u8,12'u8,12'u8,12'u8,12'u8,12'u8,12'u8,12'u8,12'u8,12'u8,12'u8,
    12'u8, 0'u8,12'u8,12'u8,12'u8,12'u8,12'u8, 0'u8,12'u8, 0'u8,12'u8,12'u8,
    12'u8,24'u8,12'u8,12'u8,12'u8,12'u8,12'u8,24'u8,12'u8,24'u8,12'u8,12'u8,
    12'u8,12'u8,12'u8,12'u8,12'u8,12'u8,12'u8,24'u8,12'u8,12'u8,12'u8,12'u8,
    12'u8,24'u8,12'u8,12'u8,12'u8,12'u8,12'u8,12'u8,12'u8,24'u8,12'u8,12'u8,
    12'u8,12'u8,12'u8,12'u8,12'u8,12'u8,12'u8,36'u8,12'u8,36'u8,12'u8,12'u8,
    12'u8,36'u8,12'u8,12'u8,12'u8,12'u8,12'u8,36'u8,12'u8,36'u8,12'u8,12'u8,
    12'u8,36'u8,12'u8,12'u8,12'u8,12'u8,12'u8,12'u8,12'u8,12'u8,12'u8,12'u8,
  ]

#[ Decode utf8 codepoint a byte at a time. Uses explictly user provided state variable,
   that should be initialized to zero before first use. Places the result to codep
   @return Returns UTF8_ACCEPT when a full codepoint achieved ]#
proc wtf8_decode_state(state, codep: var int,  byte: int): int =
  let utype = wtf8_utf8d[byte]

  codep = if state != UTF8_ACCEPT:
      ((byte and 0x3f) or (codep shl 6))
    else:
      ((0xff shr utype.int) and (byte))

  state = wtf8_utf8d[256 + state + utype.int].int
  result = state

#[ Decode a utf8 codepoint from a byte array. Reads maximum of maxbytes from str.
   Places the result to result
   @return The start of next codepoint sequence ]#
proc wtf8_decode*(str: cstring, maxbytes: int, codep: var int): cstring =
  var state = 0
  var i = 0
  while i < maxbytes:
    let res = wtf8_decode_state(state, codep, str[i].ord)
    inc i
    if res == UTF8_ACCEPT: return str[i].unsafeAddr
    elif res == UTF8_REJECT: break

  codep = 0xFFFD
  result = str[i].unsafeAddr

iterator wtf8_decode*(str: string): int =
  var state = 0
  var i = 0
  let maxBytes = str.len
  var codepoint = 0
  while i < maxBytes:
    let res = wtf8_decode_state(state, codepoint, str[i].ord)
    inc i
    if res == UTF8_ACCEPT: yield codepoint
    elif res == UTF8_REJECT: yield codepoint

proc wtf8_encode*(codepoint: int, str: var cstring): cstring =
  if codepoint <= 0x7f:
    str[0] = codepoint.chr
    result = str[1].addr
  elif codepoint <= 0x7ff:
    str[0] = chr(0xc0 + (codepoint shr 6))
    str[1] = chr(0x80 + (codepoint and 0x3f))
    result = str[2].addr
  elif codepoint <= 0xffff:
    str[0] = chr(0xe0 + (codepoint shr 12))
    str[1] = chr(0x80 + ((codepoint shr 6) and 63))
    str[2] = chr(0x80 + (codepoint and 63))
    result = str[3].addr
  elif codepoint <= 0x1fffff:
    str[0] = chr(0xf0 + (codepoint shr 18))
    str[1] = chr(0x80 + ((codepoint shr 12) and 0x3f))
    str[2] = chr(0x80 + ((codepoint shr 6) and 0x3f))
    str[3] = chr(0x80 + (codepoint and 0x3f))
    result = str[4].addr

proc wtf8_encode*(codepoint: int, str: var string) =
  if codepoint <= 0x7f:
    str.add codepoint.chr
  elif codepoint <= 0x7ff:
    str.add chr(0xc0 + (codepoint shr 6))
    str.add chr(0x80 + (codepoint and 0x3f))
  elif codepoint <= 0xffff:
    str.add chr(0xe0 + (codepoint shr 12))
    str.add chr(0x80 + ((codepoint shr 6) and 63))
    str.add chr(0x80 + (codepoint and 63))
  elif codepoint <= 0x1fffff:
    str.add chr(0xf0 + (codepoint shr 18))
    str.add chr(0x80 + ((codepoint shr 12) and 0x3f))
    str.add chr(0x80 + ((codepoint shr 6) and 0x3f))
    str.add chr(0x80 + (codepoint and 0x3f))

proc wtf8_strlen*(str: string): int =
  var count = 0
  var state = 0
  var tmp: int
  for c in str:
    let res = wtf8_decode_state(state, tmp, c.ord)
    if res == UTF8_ACCEPT: inc count
    elif res == UTF8_REJECT: inc count

  result = count

proc wtf8_is_continuation_byte*(byte: char): bool =
  result = (byte.ord and 0xc0) == 0x80

proc wtf8_is_initial_byte*(byte: char): bool =
  result = (byte.ord and 0x80) == 0 or (byte.ord and 0xc0) == 0xc0

const
  LEAD_SURROGATE_MIN  = 0x0000d800
  LEAD_SURROGATE_MAX  = 0x0000dbff
  TRAIL_SURROGATE_MIN = 0x0000dc00
  #TRAIL_SURROGATE_MAX = 0x0000dfff
  LEAD_OFFSET         = LEAD_SURROGATE_MIN - 0x00000040
  SURROGATE_OFFSET    = 0x00010000 - (LEAD_SURROGATE_MIN shl 10) - TRAIL_SURROGATE_MIN

proc utf8to16*(str: string): seq[uint16] =
  result = @[]

  for codepoint in wtf8_decode(str):
    if codepoint > 0xffff:
      #make a surrogate pair
      let cp = codepoint - 0x10000
      result.add(uint16((cp shr 10) + LEAD_OFFSET))
      result.add(uint16((cp and 0x3ff) + TRAIL_SURROGATE_MIN))
    else:
      result.add(uint16(codepoint))

proc is_lead_surrogate(cp: int): bool {.inline.} = cp >= LEAD_SURROGATE_MIN and cp <= LEAD_SURROGATE_MAX

proc utf16to8*(se: openArray[uint16]): string =
  result = ""
  var it = 0
  while it < se.len:
    var cp = se[it].int
    inc it
    #Take care of surrogate pairs first
    if is_lead_surrogate(cp):
      let trail_surrogate = se[it].int
      inc it
      cp = (cp shl 10) + trail_surrogate + SURROGATE_OFFSET

    wtf8_encode(cp, result)

proc utf8to32*(str: string): seq[uint32] =
  result = @[]
  for codepoint in wtf8_decode(str):
    result.add(uint32(codepoint))

proc utf32to8*(se: openArray[uint32]): string =
  result = ""
  for cp in se:
    wtf8_encode(cp.int, result)

proc replace_invalid*(src: string): string =
  result = ""
  for codepoint in wtf8_decode(src):
    wtf8_encode(codepoint, result)

when isMainModule:
  proc single_octet() =
    let str1 = "\x01"
    let str2 = "\x32"
    let str3 = "\x7f"
    let str_er = "\x80"

    var codepoint = 0
    var res = wtf8_decode(str1, 1, codepoint)
    doAssert(codepoint == 1)
    doAssert(res == str1[1].unsafeAddr)

    codepoint = 0
    res = wtf8_decode(str2, 1, codepoint)
    doAssert(codepoint == 0x32)
    doAssert(res == str2[1].unsafeAddr)

    codepoint = 0
    res = wtf8_decode(str3, 1, codepoint)
    doAssert(codepoint == 0x7f)
    doAssert(res == str3[1].unsafeAddr)

    codepoint = 0
    res = wtf8_decode(str_er, 1, codepoint)
    doAssert(codepoint == 0xfffd)
    doAssert(res == str_er[1].unsafeAddr)

  proc two_octet() =
    let str1 = "\xc2\x80"
    let str2 = "\xc4\x80"
    let str3 = "\xdf\xbf"
    let str_er =  "\xdfu\xc0"
    let str_er2 = "\xdf"

    var codepoint = 0
    var res = wtf8_decode(str1, 2, codepoint)
    doAssert(codepoint == 0x80)
    doAssert(res == str1[2].unsafeAddr)

    codepoint = 0
    res = wtf8_decode(str2, 2, codepoint)
    doAssert(codepoint == 0x100)
    doAssert(res == str2[2].unsafeAddr)

    codepoint = 0
    res = wtf8_decode(str3, 2, codepoint)
    doAssert(codepoint == 0x7ff)
    doAssert(res == str3[2].unsafeAddr)

    codepoint = 0
    res = wtf8_decode(str_er, 2, codepoint)
    doAssert(codepoint == 0xfffd)
    doAssert(res == str_er[2].unsafeAddr)

    codepoint = 0
    res = wtf8_decode(str_er2, 1, codepoint)
    doAssert(codepoint == 0xfffd)
    doAssert(res == str_er2[1].unsafeAddr)

  proc three_octet() =
    let str1   = "\xe0\xa0\x80"
    let str2   = "\xe1\x80\x80"
    let str3   = "\xef\xbf\xbf"
    let str_er = "\xef\xbf\xc0"
    let str_er2= "\xef\xbf"

    var codepoint = 0
    var res = wtf8_decode(str1, 3, codepoint)
    doAssert(codepoint == 0x800)
    doAssert(res == str1[3].unsafeAddr)

    codepoint = 0
    res = wtf8_decode(str2, 3, codepoint)
    doAssert(codepoint == 0x1000)
    doAssert(res == str2[3].unsafeAddr)

    codepoint = 0
    res = wtf8_decode(str3, 3, codepoint)
    doAssert(codepoint == 0xffff)
    doAssert(res == str3[3].unsafeAddr)

    codepoint = 0
    res = wtf8_decode(str_er, 3, codepoint)
    doAssert(codepoint == 0xfffd)
    doAssert(res == str_er[3].unsafeAddr)

    codepoint = 0
    res = wtf8_decode(str_er2, 2, codepoint)
    doAssert(codepoint == 0xfffd)
    doAssert(res == str_er2[2].unsafeAddr)

  proc four_octet() =
    let str1    = "\xf0\x90\x80\x80"
    let str2    = "\xf0\x92\x80\x80"
    let str3    = "\xf0\x9f\xbf\xbf"
    let str_er  = "\xf0\x9f\xbf\xc0"
    let str_er2 = "\xf0\x9f\xbf"

    var codepoint = 0
    var res = wtf8_decode(str1, 4, codepoint)
    doAssert(codepoint == 0x10000)
    doAssert(res == str1[4].unsafeAddr)

    codepoint = 0
    res = wtf8_decode(str2, 4, codepoint)
    doAssert(codepoint == 0x12000)
    doAssert(res == str2[4].unsafeAddr)

    codepoint = 0
    res = wtf8_decode(str3, 4, codepoint)
    doAssert(codepoint == 0x1ffff)
    doAssert(res == str3[4].unsafeAddr)

    codepoint = 0
    res = wtf8_decode(str_er, 4, codepoint)
    doAssert(codepoint == 0xfffd)
    doAssert(res == str_er[4].unsafeAddr)

    codepoint = 0
    res = wtf8_decode(str_er2, 3, codepoint)
    doAssert(codepoint == 0xfffd)
    doAssert(res == str_er2[3].unsafeAddr)

  proc should_not_allow_overlong() =
    let str1 = "\xc0\xaf"
    let str2 = "\xe0\x80\xaf"
    let str3 = "\xf0\x80\x80\xaf"
    let str4 = "\xf8\x80\x80\x80\xaf"
    let str5 = "\xfc\x80\x80\x80\x80\xaf"

    var codepoint = 0
    discard wtf8_decode(str1, 2, codepoint)
    doAssert(codepoint == 0xfffd)

    codepoint = 0
    discard wtf8_decode(str2, 3, codepoint)
    doAssert(codepoint == 0xfffd)

    codepoint = 0
    discard wtf8_decode(str3, 4, codepoint)
    doAssert(codepoint == 0xfffd)

    codepoint = 0
    discard wtf8_decode(str4, 5, codepoint)
    doAssert(codepoint == 0xfffd)

    codepoint = 0
    discard wtf8_decode(str5, 6, codepoint)
    doAssert(codepoint == 0xfffd)

  proc should_not_allow_max_overlong() =
    let str1 = "\xc1\xbf"
    let str2 = "\xe0\x9f\xbf"
    let str3 = "\xf0\x8f\xbf\xbf"
    let str4 = "\xf8\x87\xbf\xbf\xbf"
    let str5 = "\xfc\x83\xbf\xbf\xbf\xbf"

    var codepoint = 0
    var res = wtf8_decode(str1, 2, codepoint)
    doAssert(codepoint == 0xfffd)

    codepoint = 0
    discard wtf8_decode(str2, 3, codepoint)
    doAssert(codepoint == 0xfffd)

    codepoint = 0
    discard wtf8_decode(str3, 4, codepoint)
    doAssert(codepoint == 0xfffd)

    codepoint = 0
    discard wtf8_decode(str4, 5, codepoint)
    doAssert(codepoint == 0xfffd)

    codepoint = 0
    discard wtf8_decode(str5, 6, codepoint)
    doAssert(codepoint == 0xfffd)


  proc should_not_allow_surrogate() =
    var str1 = newString(3)
    for i in 0xa0..0xbf:
      for j in 0x80..0xbf:
        str1[0] = 0xed.chr
        str1[1] = i.chr
        str1[2] = j.chr
        var codepoint = 0
        discard wtf8_decode(str1, 3, codepoint)
        doAssert(codepoint == 0xfffd)

  proc encode_all_valid_codepoint() =
    var str = newString(8)
    var buf = str.cstring
    for i in 0.. <0x1ffff:
      # skip surrogates, as they are not allowed in utf8
      if  i >= 0xd800 and i <= 0xdfff: continue
      zeroMem(buf, 8)
      let ret1 = wtf8_encode(i, buf)
      var res = 0
      let ret2 = wtf8_decode(buf, 7, res)
      doAssert(i == res)
      doAssert(ret1 == ret2)

  proc distinct_codepoint() =
    let str1 = "foobar"
    let str2 = "foob\xc3\xa6r"
    let str3 = "foob\xf0\x9f\x99\x88r"

    doAssert(wtf8_strlen(str1) == 6)
    doAssert(wtf8_strlen(str2) == 6)
    doAssert(wtf8_strlen(str3) == 6)

  proc is_continuation() =
    let str1 = "f"
    let str2 = "f\xc3\xa6r"
    let str3 = "f\xf0\x9f\x99\x88r"
    doAssert(wtf8_is_continuation_byte( str1[0] ) == false)

    doAssert(wtf8_is_continuation_byte( str2[0] ) == false)
    doAssert(wtf8_is_continuation_byte( str2[1] ) == false)
    doAssert(wtf8_is_continuation_byte( str2[2] ) == true)

    doAssert(wtf8_is_continuation_byte( str3[0] ) == false)
    doAssert(wtf8_is_continuation_byte( str3[1] ) == false)
    doAssert(wtf8_is_continuation_byte( str3[2] ) == true)
    doAssert(wtf8_is_continuation_byte( str3[3] ) == true)
    doAssert(wtf8_is_continuation_byte( str3[4] ) == true)

  proc is_initial_byte() =
    let str1 = "f"
    let str2 = "f\xc3\xa6r"
    let str3 = "f\xf0\x9f\x99\x88r"
    doAssert( wtf8_is_initial_byte( str1[0] ) == true)

    doAssert( wtf8_is_initial_byte( str2[0] ) == true)
    doAssert( wtf8_is_initial_byte( str2[1] ) == true)
    doAssert( wtf8_is_initial_byte( str2[2] ) == false)

    doAssert( wtf8_is_initial_byte( str3[0] ) == true)
    doAssert( wtf8_is_initial_byte( str3[1] ) == true)
    doAssert( wtf8_is_initial_byte( str3[2] ) == false)
    doAssert( wtf8_is_initial_byte( str3[3] ) == false)
    doAssert( wtf8_is_initial_byte( str3[4] ) == false)

  single_octet()
  two_octet()
  three_octet()
  four_octet()
  should_not_allow_overlong()
  should_not_allow_max_overlong()
  should_not_allow_surrogate()
  encode_all_valid_codepoint()
  distinct_codepoint()
  is_continuation()
  is_initial_byte()