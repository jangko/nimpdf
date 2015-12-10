import encrypt, tables, streams, strutils, image

const
  pdfNeedEscape = {'\x00'..'\x20', '\\', '%', '#',
    '/', '(', ')', '<', '>', '[', ']', '{', '}', '\x7E'..'\xFF' }

  OTYPE_DIRECT    = 0x80000000'i32
  OTYPE_INDIRECT  = 0x40000000'i32
  OTYPE_HIDDEN    = 0x10000000'i32

  FREE_ENTRY   = 'f'
  IN_USE_ENTRY = 'n'
  MAX_GENERATION_NUM = 65535

  BYTE_OFFSET_LEN = 10
  GEN_NO_LEN = 5

type
  objectClass* = enum
    CLASS_UNKNOWN,
    CLASS_NULL,
    CLASS_PLAIN,
    CLASS_BOOLEAN,
    CLASS_NUMBER,
    CLASS_REAL,
    CLASS_NAME,
    CLASS_STRING,
    CLASS_BINARY,
    CLASS_ARRAY,
    CLASS_DICT,
    CLASS_PROXY

  objectSubclass* = enum
    SUBCLASS_FONT,
    SUBCLASS_CATALOG,
    SUBCLASS_PAGES,
    SUBCLASS_PAGE,
    SUBCLASS_XOBJECT,
    SUBCLASS_OUTLINE,
    SUBCLASS_DESTINATION,
    SUBCLASS_ANNOTATION,
    SUBCLASS_ENCRYPT,
    SUBCLASS_EXT_GSTATE,
    SUBCLASS_CRYPT_FILTERS,
    SUBCLASS_CRYPT_FILTER,
    SUBCLASS_NAMEDICT,
    SUBCLASS_NAMETREE

  filterMode = enum
    FILTER_ASCIIHEX,
    FILTER_ASCII85,
    FILTER_FLATE_DECODE,
    FILTER_DCT_DECODE,
    FILTER_CCITT_DECODE

  pdfObj* = ref object of RootObj
    objID*: int
    gen*: int
    class*: objectClass
    subclass*: objectSubclass

  nullObj* = ref object of pdfObj

  plainObj* = ref object of pdfObj
    value: string

  booleanObj* = ref object of pdfObj
    value: bool

  numberObj* = ref object of pdfObj
    value : int

  realObj* = ref object of pdfObj
    value: float64

  nameObj* = ref object of pdfObj
    value: string

  stringObj* = ref object of pdfObj
    value: string

  binaryObj* = ref object of pdfObj
    value: string

  arrayObj* = ref object of pdfObj
    value: seq[pdfObj]

  dictObj* = ref object of pdfObj
    value*: Table[string, pdfObj]
    filter*: set[filterMode]
    filterParams*: dictObj
    stream*: string

  proxyObj* = ref object of pdfObj
    value: pdfObj

  xrefEntry = ref object
    entry_typ: char # 'f' or 'n'
    byte_offset: int
    gen: int
    obj: pdfObj

  pdfXref* = ref object
    start_offset: int
    entries: seq[xrefEntry]
    address: int
    prev: pdfXref
    trailer: dictObj

method write*(obj: pdfObj, s: Stream, enc: pdfEncrypt) {.base.} =
  assert(false)

proc nullObjNew*(): nullObj =
  new(result)
  result.class = CLASS_NULL
  result.objID = 0

proc plainObjNew*(val: string): plainObj =
  new(result)
  result.class = CLASS_PLAIN
  result.value = val
  result.objID = 0

method write(obj: plainObj, s: Stream, enc: pdfEncrypt) =
  s.write obj.value

proc booleanObjNew*(val: bool): booleanObj =
  new(result)
  result.class = CLASS_BOOLEAN
  result.value = val
  result.objID = 0

method write(obj: booleanObj, s: Stream, enc: pdfEncrypt) =
  if obj.value: s.write("true")
  else: s.write("false")

proc numberObjNew*(val: int): numberObj =
  new(result)
  result.class = CLASS_NUMBER
  result.value = val
  result.objID = 0

method write(obj: numberObj, s: Stream, enc: pdfEncrypt) =
  s.write($obj.value)

proc setValue(obj: numberObj, val: int) =
  obj.value = val

proc realObjNew*(val: float64): realObj =
  new(result)
  result.class = CLASS_REAL
  result.value = val
  result.objID = 0

method write(obj: realObj, s: Stream, enc: pdfEncrypt) =
  s.write formatFloat(obj.value, ffDecimal, 4)

proc setValue*(obj: realObj, val: float64) =
  obj.value = val

proc escapeName(name: string): string =
  result = "/"
  for c in name:
    if c in pdfNeedEscape:
      result.add '#' #toHex
      var xx = ord(c) shr 4
      if xx <= 9: xx += 0x30
      else: xx += 0x41 - 10
      result.add chr(xx)

      xx = ord(c) and 0x0f
      if xx <= 9: xx += 0x30
      else: xx += 0x41 - 10
      result.add chr(xx)
    else:
      result.add c

proc nameObjNew*(val: string): nameObj =
  new(result)
  result.class = CLASS_NAME
  result.value = val
  result.objID = 0

method write(obj: nameObj, s: Stream, enc: pdfEncrypt) =
  s.write escapeName(obj.value)

proc setValue*(obj: nameObj, val: string) =
  obj.value = val

proc getValue*(obj: nameObj): string =
  result = obj.value

proc escapeText(str: string): string =
  result = "("
  for c in str:
    if c in pdfNeedEscape:
      result.add '\\' #toOctal
      var xx = ord(c) shr 6
      xx += 0x30
      result.add chr(xx)

      xx = (ord(c) and 0x38) shr 3
      xx += 0x30
      result.add chr(xx)

      xx = ord(c) and 0x07
      xx += 0x30
      result.add chr(xx)
    else:
      result.add c

  result.add ')'

proc escapeBinary(input: string): string =
  result = ""
  for x in input:
    var c = ord(x) shr 4
    if c <= 9: c += 0x30
    else: c += 0x41 - 10
    result.add chr(c)

    c = ord(x) and 0x0f
    if c <= 9: c += 0x30
    else: c += 0x41 - 10
    result.add chr(c)

proc stringObjNew*(val: string): stringObj =
  new(result)
  result.class = CLASS_STRING
  result.value = val
  result.objID = 0

method write(obj: stringObj, s: Stream, enc: pdfEncrypt) =
  if enc != nil:
    enc.encryptReset
    s.write '<'
    s.write escapeBinary(enc.encryptCryptBuf(obj.value))
    s.write '>'
  else:
    s.write escapeText(obj.value)

proc setValue*(obj: stringObj, val: string) =
  obj.value = val

proc getValue*(obj: stringObj): string =
  result = obj.value

proc equal*(a, b: stringObj): bool =
  result = a.value == b.value

proc binaryObjNew*(val: string): binaryObj =
  new(result)
  result.class = CLASS_BINARY
  result.value = val
  result.objID = 0

method write(obj: binaryObj, s: Stream, enc: pdfEncrypt) =
  if obj.value.len == 0:
    s.write "<>"
    return

  var val: string

  if enc != nil:
    enc.encryptReset
    val = escapeBinary(enc.encryptCryptBuf(obj.value))
  else:
    val = escapeBinary(obj.value)

  s.write '<'
  s.write val
  s.write '>'

proc setValue*(obj: binaryObj, val: string) =
  obj.value = val

proc getValue*(obj: binaryObj): string =
  result = obj.value

proc proxyObjNew(obj: pdfObj): proxyObj =
  new(result)
  result.class = CLASS_PROXY
  result.value = obj
  result.objID = 0

method write(obj: proxyObj, s: Stream, enc: pdfEncrypt) =
  var indirect = $(obj.value.objID and 0x00FFFFFF) & " " & $obj.gen & " R"
  s.write indirect

proc arrayObjNew*(): arrayObj =
  new(result)
  result.class = CLASS_ARRAY
  result.value = @[]
  result.objID = 0

method write(obj: arrayObj, s: Stream, enc: pdfEncrypt) =
  s.write '['
  let len = obj.value.high
  for i in 0..len:
    obj.value[i].write(s, enc)
    if i < len: s.write ' '
  s.write ']'

proc add*(obj: arrayObj, val: pdfObj) =
  assert ((val.objID and OTYPE_DIRECT) == 0)
  if (val.objID and OTYPE_INDIRECT) != 0:
    var proxy = proxyObjNew(val)
    proxy.objID = proxy.objID or OTYPE_DIRECT
    obj.value.add proxy
  else:
    obj.objID = obj.objID or OTYPE_DIRECT
    obj.value.add val

proc addNumber*(obj: arrayObj, val: int) =
  obj.add numberObjNew(val)

proc addReal*(obj: arrayObj, val: float64) =
  obj.add realObjNew(val)

proc addName*(obj: arrayObj, val: string) =
  obj.add nameObjNew(val)

proc addPlain*(obj: arrayObj, val: string) =
  obj.add plainObjNew(val)

proc addNull*(obj: arrayObj) =
  obj.add nullObjNew()

proc addBinary*(obj: arrayObj, val: string) =
  obj.add binaryObjNew(val)

proc arrayNew*(args: varargs[float64]): arrayObj =
  new(result)
  result.class = CLASS_ARRAY
  result.value = @[]
  for i in args: result.addReal i
  result.objID = 0 #strange ???

proc arrayNew*(args: varargs[int]): arrayObj =
  new(result)
  result.class = CLASS_ARRAY
  result.value = @[]
  for i in args: result.addNumber i
  result.objID = 0 #strange ???

proc len*(obj: arrayObj): int = obj.value.len

proc getItem*(obj: arrayObj, index: int, class: objectClass): pdfObj =
  if index >= obj.value.len:
    return nil

  result = obj.value[index]
  if result.class == CLASS_PROXY:
    result = proxyObj(result).value

  assert result.class == class

proc insert[T](dest: var seq[T], obj: T, pos: int) =
  assert ((pos >= 0) and (pos <= dest.len))
  if pos == dest.len:
    dest.add obj
    return

  var i = dest.len
  dest.setLen(dest.len + 1)
  while i > pos:
    dest[i] = dest[i-1]
    dec i

  dest[pos] = obj

proc insert*(arr: arrayObj, target, val: pdfObj): bool =
  var obj = val
  assert ((obj.objID and OTYPE_DIRECT) == 0)
  if (obj.objID and OTYPE_INDIRECT) != 0:
    var proxy = proxyObjNew(val)
    proxy.objID = proxy.objID or OTYPE_DIRECT
    obj = proxy
  else:
    obj.objID = obj.objID or OTYPE_DIRECT

  #get the target-object from object-list
  #consider that the pointer contained in list may be proxy-object.

  var match: pdfObj
  var i = 0
  for c in arr.value:
    if c.class == CLASS_PROXY: match = proxyObj(c).value
    else: match = c
    if match == target:
      arr.value.insert(val, i)
      return true
    inc i

  result = false

proc clear*(obj: arrayObj) =
  obj.value = @[]

proc dictObjInit*(dict: dictObj) =
  dict.class = CLASS_DICT
  dict.value  = initTable[string, pdfObj]()
  dict.filter = {}
  dict.filterParams = nil
  dict.objID = 0

proc dictObjNew*(): dictObj =
  new(result)
  result.dictObjInit()

proc getKeyByObj*(d: dictObj, obj: pdfObj): string =
  for k, v in pairs(d.value):
    if v.class == CLASS_PROXY:
      if proxyObj(v).value == obj: return k
    else:
      if v == obj: return k
  return nil

proc removeElement*(d: dictObj, key: string): bool =
  if d.value.hasKey(key):
    d.value.del(key)
    return true
  result = false

proc getElement(d: dictObj, key: string): pdfObj =
  if d.value.hasKey(key):
    result = d.value[key]
    if result.class == CLASS_PROXY: return proxyObj(result).value
    return result
  result = nil

proc getItem*(d: dictObj, key: string, class: objectClass): pdfObj =
  result = d.getElement(key)
  if result != nil:
    assert(result.class == class)
    return result
  result = nil

proc addElement*(d: dictObj, key: string, val: pdfObj) =
  assert((val.objID and OTYPE_DIRECT) == 0)

  if (val.objID and OTYPE_INDIRECT) != 0:
    var proxy = proxyObjNew(val)
    d.value[key] = proxy
    proxy.objID = proxy.objID or OTYPE_DIRECT
  else:
    d.value[key] = val
    val.objID = val.objID or OTYPE_DIRECT

proc addBoolean*(d: dictObj, key: string, val: bool) =
  d.addElement(key, booleanObjNew(val))

proc addReal*(d: dictObj, key: string, val: float64) =
  d.addElement(key, realObjNew(val))

proc addNumber*(d: dictObj, key: string, val: int) =
  d.addElement(key, numberObjNew(val))

proc addPlain*(d: dictObj, key: string, val: string) =
  d.addElement(key, plainObjNew(val))

proc addName*(d: dictObj, key: string, val: string) =
  d.addElement(key, nameObjNew(val))

proc addString*(d: dictObj, key: string, val: string) =
  d.addElement(key, stringObjNew(val))

proc addFilterParam*(d: dictObj, filterParam: dictObj) =
  var paramArray = arrayObj(d.getItem("DecodeParms", CLASS_ARRAY))
  if paramArray == nil:
    paramArray = arrayObjNew()
    d.addElement("DecodeParms", paramArray)
  paramArray.add filterParam

method beforeWrite(d: dictObj) {.base.} = discard
method onWrite(d: dictObj, s: Stream) {.base.} = discard
method afterWrite(d: dictObj) {.base.} = discard

proc writeToStream(src: string, dst: Stream, filter: set[filterMode], enc: pdfEncrypt) =
  # initialize input stream
  if src.len == 0: return

  var data = if FILTER_FLATE_DECODE in filter: zcompress(src) else: src
  if enc != nil:
    enc.encryptReset()
    dst.write enc.encryptCryptBuf(data)
  else: dst.write data

method write(dict: dictObj, s: Stream, encryptor: pdfEncrypt) =
  s.write "<<"
  dict.beforeWrite()

  # encrypt-dict must not be encrypted.
  var enc = encryptor
  if (dict.class == CLASS_DICT) and (dict.subclass == SUBCLASS_ENCRYPT): enc = pdfEncrypt(nil)

  if dict.stream != nil:
    # set filter element
    if dict.filter == {}:
      discard dict.removeElement("Filter")
    else:
      var filter = arrayObj(dict.getItem("Filter", CLASS_ARRAY))
      if filter == nil:
        filter = arrayObj()
        dict.addElement("Filter", filter)
        filter.clear()
      if FILTER_FLATE_DECODE in dict.filter: filter.addName("FlateDecode")
      if FILTER_DCT_DECODE in dict.filter: filter.addName("DCTDecode")
      if FILTER_CCITT_DECODE in dict.filter: filter.addName("CCITTFaxDecode")
      if FILTER_ASCII85 in dict.filter: filter.addName("ASCII85Decode")
      if FILTER_ASCIIHEX in dict.filter: filter.addName("ASCIIHexDecode")
      if dict.filterParams != nil: dict.addFilterParam(dict.filterParams)

  for key, val in dict.value:
    if (val.objID and OTYPE_HIDDEN) != 0: continue
    s.write escapeName(key)
    if val.class in {CLASS_NUMBER, CLASS_REAL, CLASS_BOOLEAN, CLASS_PLAIN, CLASS_PROXY}: s.write ' '
    val.write(s, enc)
    #s.write '\x0A'

  dict.onWrite(s)
  s.write ">>"

  if dict.stream != nil:
    # get "length" element
    let length = numberObj(dict.getItem("Length", CLASS_NUMBER))
    # "length" element must be indirect-object
    assert((length.objID and OTYPE_INDIRECT) != 0)
    # Acrobat 8.15 requires both \r and \n here
    s.write "\x0Astream\x0D\x0A"
    let pos = s.getPosition()
    dict.stream.writeToStream(s, dict.filter, enc)
    length.setValue(s.getPosition() - pos)
    s.write "\x0Aendstream"

  dict.afterWrite()

proc xrefNew*(offset: int = 0): pdfXref =
  new(result)
  result.start_offset = offset
  result.entries = @[]
  result.address = 0
  result.trailer = dictObjNew()

  if result.start_offset == 0:
    var en: xrefEntry
    new(en)
    # add first entry which is free entry and whose generation number is 0
    en.entry_typ = FREE_ENTRY
    en.byte_offset = 0
    en.gen = MAX_GENERATION_NUM
    en.obj = nil
    result.entries.add en

proc add*(x: pdfXref, obj: pdfObj) =
  assert ((obj.objID and OTYPE_DIRECT) == 0)
  assert ((obj.objID and OTYPE_INDIRECT) == 0)

  var en: xrefEntry
  new(en)
  en.entry_typ = IN_USE_ENTRY
  en.byte_offset = 0
  en.gen = 0
  en.obj = obj
  x.entries.add en

  obj.objID = (x.start_offset + x.entries.len - 1) or OTYPE_INDIRECT
  obj.gen = en.gen

proc getEntry(x: pdfXref, index: int): xrefEntry =
  result = x.entries[index]

proc numEntries*(x: pdfXref): int = x.entries.len

proc getEntryObjectById*(x: pdfXref, objID: int): xrefEntry =
  var tmp = x
  while tmp != nil:
    assert ((tmp.entries.len + tmp.start_offset) <= objID)
    if tmp.start_offset < objID:
      tmp = tmp.prev
      continue

    for i in 0..tmp.entries.high:
      if (tmp.start_offset + i) == objID: return tmp.getEntry(i)

    tmp = tmp.prev

proc i2string(val: int, len: int) : string =
  let s = $val
  let blank = len - s.len()
  if blank >= 0:
    result = repeat('0', blank)
    result.add(s)
  else:
    result = s

proc writeTrailer(x: pdfXref, s: Stream) =
  var max_objID = x.entries.len + x.start_offset
  x.trailer.addNumber("Size", max_objID)
  if x.prev != nil: x.trailer.addNumber("Prev", x.prev.address)

  s.write "trailer\x0A"
  x.trailer.write(s, pdfEncrypt(nil))
  s.write "\x0Astartxref\x0A"
  s.write($x.address)
  s.write "\x0A%%EOF\x0A"

proc writeToStream*(x: pdfXref, s: Stream, enc: pdfEncrypt) =
  var tmp = x
  var str_idx: int

  while tmp != nil:
    if tmp.start_offset == 0: str_idx = 1
    else: str_idx = 0

    for i in str_idx..tmp.entries.high:
      var entry = tmp.entries[i]
      let objID = tmp.start_offset + i
      let gen = entry.gen
      entry.byte_offset = s.getPosition()
      let buf = $objID & " " & $gen & " obj\x0A"
      s.write buf

      if enc != nil: enc.encryptInitKey(objID, gen)
      entry.obj.write(s, enc)
      s.write "\x0Aendobj\x0A"

    tmp = tmp.prev

  # start to write cross-reference table
  tmp = x
  while tmp != nil:
    tmp.address = s.getPosition()
    s.write "xref\x0A"
    s.write($tmp.start_offset & " " & $tmp.entries.len)
    s.write "\x0A"

    for en in tmp.entries:
      s.write i2string(en.byte_offset, BYTE_OFFSET_LEN)
      s.write " "
      s.write i2string(en.gen, GEN_NO_LEN)
      s.write " "
      s.write en.entry_typ
      s.write "\x0D\x0A" # Acrobat 8.15 requires both \r and \n here

    tmp = tmp.prev

  # write trailer dictionary
  writeTrailer(x, s)

proc dictStreamNew*(xref: pdfXref, data: string): dictObj =
  result = dictObjNew()
  # only stream object is added to xref automatically
  xref.add(result)
  var length = numberObjNew(0)
  xref.add(length)
  result.addElement("Length", length)
  result.stream = data
  result.filter.incl FILTER_FLATE_DECODE

proc getTrailer*(xref: pdfXref): dictObj =
  result = xref.trailer
