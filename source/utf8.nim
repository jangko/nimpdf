# Copyright (c) 2015 Andri Lim
#
# Distributed under the MIT license 
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------
# another port from C++ http://sourceforge.net/projects/utfcpp/
# then I realize actually nim also have unicode module
# anyway, I keep it here 

import unicode, strutils, streams, unsigned

const
  #Unicode constants
  #Leading (high) surrogates: 0xd800 - 0xdbff
  #Trailing (low) surrogates: 0xdc00 - 0xdfff 
  LEAD_SURROGATE_MIN  = 0x0000d800
  LEAD_SURROGATE_MAX  = 0x0000dbff
  TRAIL_SURROGATE_MIN = 0x0000dc00
  TRAIL_SURROGATE_MAX = 0x0000dfff
  LEAD_OFFSET     = LEAD_SURROGATE_MIN - 0x00000040
  SURROGATE_OFFSET  = 0x00010000'u32 - (LEAD_SURROGATE_MIN shl 10) - TRAIL_SURROGATE_MIN
  
  #Maximum valid value for a Unicode code point
  CODE_POINT_MAX    = 0x0010ffff'u32
  
  utf8_bom  = "\xEF\xBB\xBF"
  utf16be_bom = "\xFE\xFF"
  utf16le_bom = "\xFF\xFE"
  utf32be_bom = "\x00\x00\xFE\xFF"
  utf32le_bom = "\xFF\xFE\x00\x00"
  
type
  utf_error = enum
    UTF8_OK, NOT_ENOUGH_ROOM, INVALID_LEAD, INCOMPLETE_SEQUENCE, OVERLONG_SEQUENCE, INVALID_CODE_POINT
   
proc mask8[T](oc: T): uint8 {.inline.} = cast[uint8](0xff'u8 and uint8(oc))
proc mask16[T](oc: T): uint16 {.inline.} = cast[uint16](0xffff'u16 and uint16(oc))
proc is_trail[T](oc: T): bool {.inline.} = (mask8(oc) shr 6) == 0x02
proc is_lead_surrogate[T](cp: T): bool {.inline.} = (cp >= uint32(LEAD_SURROGATE_MIN) and cp <= uint32(LEAD_SURROGATE_MAX))
proc is_trail_surrogate[T](cp: T): bool {.inline.} = (cp >= TRAIL_SURROGATE_MIN and cp <= TRAIL_SURROGATE_MAX)
proc is_surrogate(cp: uint32): bool {.inline.} = (cp >= uint32(LEAD_SURROGATE_MIN) and cp <= uint32(TRAIL_SURROGATE_MAX))
proc is_code_point_valid(cp: uint32) : bool {.inline.} = (cp <= CODE_POINT_MAX and not is_surrogate(cp))

proc sequence_length[T](se: T, it: int): int =
  let lead = mask8(se[it])
  if lead < 0x80:      return 1
  elif (lead shr 5) == 0x6: return 2
  elif (lead shr 4) == 0xe: return 3
  elif (lead shr 3) == 0x1e: return 4
  else:            return 0

proc is_overlong_sequence(cp: uint32, length: int): bool =
  if cp < 0x80:
    if length != 1: return true
  elif cp < 0x800:
    if length != 2: return true
  elif cp < 0x10000:
    if length != 3: return true
  result = false
  
proc increase_safely[T](se: T, it: var int): utf_error =
  inc(it)
  if it == se.len(): return NOT_ENOUGH_ROOM
  if not is_trail(se[it]): return INCOMPLETE_SEQUENCE
  result = UTF8_OK

template UTF8_CPP_INCREASE_AND_RETURN_ON_ERROR(se: expr, it: expr): expr =
  let ret = increase_safely(se, it)
  if ret != UTF8_OK: return ret

#get_sequence_x functions decode utf-8 sequences of the length x
proc get_sequence_1[T](se: T, it: var int, code_point: var uint32): utf_error =
  if it == se.len(): return NOT_ENOUGH_ROOM
  code_point = mask8(se[it])
  result = UTF8_OK

proc get_sequence_2[T](se: T, it: var int, code_point: var uint32): utf_error =
  if it == se.len(): return NOT_ENOUGH_ROOM
  code_point = mask8(se[it])
  UTF8_CPP_INCREASE_AND_RETURN_ON_ERROR(se, it)
  code_point = ((code_point shl 6) and 0x7ff)
  code_point += uint32(uint8(se[it]) and 0x3f)
  result = UTF8_OK

proc get_sequence_3[T](se: T, it: var int, code_point: var uint32): utf_error =
  if it == se.len(): return NOT_ENOUGH_ROOM
  code_point = mask8(se[it])
  UTF8_CPP_INCREASE_AND_RETURN_ON_ERROR(se, it)
  code_point = ((code_point shl 12) and 0xffff) 
  code_point += (uint16(mask8(se[it]) shl 6) and 0xfff)
  UTF8_CPP_INCREASE_AND_RETURN_ON_ERROR(se, it)
  code_point += uint8(se[it]) and 0x3f
  result = UTF8_OK

proc get_sequence_4[T](se: T, it: var int, code_point: var uint32): utf_error =
  if it == se.len(): return NOT_ENOUGH_ROOM
  code_point = mask8(se[it])
  UTF8_CPP_INCREASE_AND_RETURN_ON_ERROR(se, it)
  code_point = ((code_point shl 18) and 0x1fffff) 
  code_point += (uint32(mask8(se[it]) shl 12) and 0x3ffff)
  UTF8_CPP_INCREASE_AND_RETURN_ON_ERROR(se, it)
  code_point += uint16(mask8(se[it]) shl 6) and 0xfff
  UTF8_CPP_INCREASE_AND_RETURN_ON_ERROR(se, it)
  code_point += uint8(se[it]) and 0x3f
  result = UTF8_OK

proc validate_next[T](se: T, it: var int, code_point: var uint32): utf_error =
  #Save the original value of it so we can go back in case of failure
  #Of course, it does not make much sense with i.e. stream iterators
  let original_it = it
  var cp: uint32 = 0
  
  #Determine the sequence length based on the lead octet
  let length = sequence_length(se, it)

  #Get trail octets and calculate the code point
  result = UTF8_OK
  case length
    of 1: result = get_sequence_1(se, it, cp)
    of 2: result = get_sequence_2(se, it, cp)
    of 3: result = get_sequence_3(se, it, cp)
    of 4: result = get_sequence_4(se, it, cp)
    else: return INVALID_LEAD
  
  if result == UTF8_OK:
    #Decoding succeeded. Now, security checks...
    if is_code_point_valid(cp):
      if not is_overlong_sequence(cp, length):
        #Passed! Return here.
        code_point = cp
        inc(it)
        return UTF8_OK
      else: result = OVERLONG_SEQUENCE
    else: result = INVALID_CODE_POINT

  #Failure branch - restore the original value of the iterator
  it = original_it

proc validate_next[T](se: T, it: var int): utf_error {.inline.} =
  var ignored: uint32
  result = validate_next(se, it, ignored)

proc unchecked_append(res: var string, cp: uint32) =
  if cp < 0x80:    # one octet
    res.add(cast[char](cp))
  elif cp < 0x800:  # two octets
    res.add(cast[char]((cp shr 6)      or 0xc0))
    res.add(cast[char]((cp and 0x3f)     or 0x80))
  elif cp < 0x10000: # three octets
    res.add(cast[char]((cp shr 12)       or 0xe0))
    res.add(cast[char](((cp shr 6) and 0x3f) or 0x80))
    res.add(cast[char]((cp and 0x3f)     or 0x80))
  else:        # four octets
    res.add(cast[char]((cp shr 18)       or 0xf0))
    res.add(cast[char](((cp shr 12) and 0x3f)or 0x80))
    res.add(cast[char](((cp shr 6) and 0x3f) or 0x80))
    res.add(cast[char]((cp and 0x3f)     or 0x80))
  
proc unchecked_next[T](se: T, it: var int): uint32 =
  var cp: uint32 = mask8(se[it])
  let length = sequence_length(se, it)
  
  if length == 2:
    inc(it)
    cp = ((cp xor 0xC0) shl 6) 
    cp += (uint32(se[it]) xor 0x80)
  elif length == 3:
    inc(it)
    cp = ((cp xor 0xE0) shl 12) 
    cp += (uint32(mask8(se[it]) xor 0x80) shl 6)
    inc(it)
    cp += uint32(se[it]) xor 0x80
  elif length == 4:
    inc(it)
    cp = ((cp xor 0xF0) shl 18) 
    cp += (uint32(uint8(se[it]) xor 0x80) shl 12)
    inc(it)
    cp += uint32(mask8(se[it]) xor 0x80) shl 6
    inc(it)
    cp += uint32(se[it]) xor 0x80
    
  inc(it)
  result = cp
 
proc unchecked_peek_next[T](se: T, it: int): uint32 = 
  let gone = it
  result = unchecked_next(se, gone)

proc unchecked_prior[T](se: T, it: var int): uint32 = 
  while is_trail(se[it]): it -= 1
  let temp = it
  result = unchecked_next(se, temp)

#Deprecated in versions that include prior, but only for the sake of consistency (see utf8::previous)
proc unchecked_previous[T](se: T, it: var int): uint32 = unchecked_prior(se, it)

proc unchecked_advance[T](se: T, it: var int, n: int) =
  for i in 0..n-1: unchecked_next(se, it)

proc unchecked_distance[T](se: T, first: int, last: int) : int =
  result = 0
  var it = first
  while it < last:
    unchecked_next(se, it)
    inc(result)
  
proc unchecked_utf16to8*[T](se: T, start: int, the_end: int): string = 
  var it = start
  result = ""
  while it != the_end:
    var cp : uint32 = mask16(se[it])
    inc(it)
    
    #Take care of surrogate pairs first
    if is_lead_surrogate(cp):
      let trail_surrogate = mask16(se[it])
      inc(it)
      cp = (cp shl 10) + trail_surrogate + SURROGATE_OFFSET
    
    unchecked_append(result, cp)
  
proc unchecked_utf16to8*[T](se: T): string =
  result = unchecked_utf16to8(se, 0, se.len())
  
proc unchecked_utf8to16*[T](se: T, start: int, the_end: int): seq[uint16] = 
  var it = start
  result = @[]

  while it < the_end:
    var cp : uint32 = unchecked_next(se, it)
    if cp > 0xffff'u32:
      #make a surrogate pair
      cp -= 0x10000
      result.add(cast[uint16]((cp shr 10) + LEAD_OFFSET))
      result.add(cast[uint16]((cp and 0x3ff) + TRAIL_SURROGATE_MIN))
    else:
      result.add(cast[uint16](cp))

proc unchecked_utf8to16*[T](se: T): seq[uint16] =
  result = unchecked_utf8to16(se, 0, se.len())

proc unchecked_utf32to8*[T](se: T, start: int, the_end: int): string = 
  result = ""
  var it = start
  while it != the_end:
    unchecked_append(result, se[it])
    inc(it)

proc unchecked_utf8to32*[T](se: T, start: int, the_end: int): seq[uint32] = 
  var it = start
  result = @[]

  while it < the_end:
    result.add(unchecked_next(se, it))

proc replace_invalid*(txt: string, replacement: uint32 = 0xFFFD): string = 
  result = ""
  var start = 0
  let the_end = txt.len()
  while start != the_end:
    let sequence_start = start
    let err = validate_next(txt, start)
    if err == UTF8_OK:
      var it = sequence_start
      while it != start:
        result.add(txt[it])
        inc(it)
        
    if err == INVALID_LEAD:
      unchecked_append(result, replacement)
      inc(start)
        
    if err == INCOMPLETE_SEQUENCE or err == OVERLONG_SEQUENCE or err == INVALID_CODE_POINT:
      unchecked_append(result, replacement)
      inc(start)
      #just one replacement mark for the sequence
      while start != the_end and is_trail(txt[start]):
        inc(start)
        
    if err == NOT_ENOUGH_ROOM:
      break

proc is_valid*(txt: string): bool = 
  result = true
  var start = 0
  let the_end = txt.len()
  while start != the_end:
    if validate_next(txt, start) != UTF8_OK:
      result = false
      break

proc isASCII*(txt:string): bool =
  for x in txt:
    if (ord(x) and 0x80) != 0: return false
  result = true

proc u16BE*(utf16: seq[uint16], bom: bool = true) : string =
  result = "" #utf16be_bom
  for x in items(utf16):
    result.add(chr(x shr 8))
    result.add(chr(int(x) and 0xFF))

proc u16LE*(utf16: seq[uint16], bom: bool = true) : string =
  result = "" #utf16le_bom
  for x in items(utf16):
    result.add(chr(int(x) and 0xFF))
    result.add(chr(x shr 8))
         
when isMainModule:
  var txt = "我爱你 你要去哪里？\n あじのもと　여름 열매"
  
  let rep = replace_invalid(txt)
  var utf16 = unchecked_utf8to16(rep)
  var res = u16LE(utf16)
  var file = newFileStream("utf16.txt", fmWrite)
  file.write(res)
  file.close()
  
  var back = unchecked_utf16to8(utf16)
  var utf8 = newFileStream("utf8.txt", fmWrite)
  utf8.write(back)
  utf8.close()
    
  
  
  
  