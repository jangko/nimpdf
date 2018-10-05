import encrypt, tables, streams, strutils, nimPNG/nimz

const
  NeedEscape = {'\x00'..'\x20', '\\', '%', '#',
    '/', '(', ')', '<', '>', '[', ']', '{', '}', '\x7E'..'\xFF' }

  OTYPE_DIRECT    = 0x80000000'i32
  OTYPE_INDIRECT  = 0x40000000'i32
  OTYPE_HIDDEN    = 0x10000000'i32

  FREE_ENTRY   = 'f'
  IN_USE_ENTRY = 'n'
  MAX_GENERATION_NUM = 65535

  BYTE_OFFSET_LEN = 10
  GEN_NUMBER_LEN = 5

type
  ObjectClass* = enum
    CLASS_NULL
    CLASS_PLAIN
    CLASS_BOOLEAN
    CLASS_NUMBER
    CLASS_REAL
    CLASS_NAME
    CLASS_STRING
    CLASS_BINARY
    CLASS_ARRAY
    CLASS_DICT
    CLASS_PROXY

  ObjectSubclass* = enum
    SUBCLASS_FONT
    SUBCLASS_CATALOG
    SUBCLASS_PAGES
    SUBCLASS_PAGE
    SUBCLASS_XOBJECT
    SUBCLASS_OUTLINE
    SUBCLASS_DESTINATION
    SUBCLASS_ANNOTATION
    SUBCLASS_ENCRYPT
    SUBCLASS_EXT_GSTATE
    SUBCLASS_CRYPT_FILTERS
    SUBCLASS_CRYPT_FILTER
    SUBCLASS_NAMEDICT
    SUBCLASS_NAMETREE

  FilterMode = enum
    FILTER_ASCIIHEX
    FILTER_ASCII85
    FILTER_FLATE_DECODE
    FILTER_DCT_DECODE
    FILTER_CCITT_DECODE

  PdfObject* = ref object of RootObj
    objID*: int
    gen*: int
    class*: ObjectClass
    subclass*: ObjectSubclass

  NullObj* = ref object of PdfObject

  PlainObj* = ref object of PdfObject
    value: string

  BooleanObj* = ref object of PdfObject
    value: bool

  NumberObj* = ref object of PdfObject
    value : int

  RealObj* = ref object of PdfObject
    value: float64

  NameObj* = ref object of PdfObject
    value: string

  StringObj* = ref object of PdfObject
    value: string

  BinaryObj* = ref object of PdfObject
    value: string

  ArrayObj* = ref object of PdfObject
    value: seq[PdfObject]

  DictObj* = ref object of PdfObject
    value*: Table[string, PdfObject]
    filter*: set[FilterMode]
    filterParams*: DictObj
    stream*: string

  ProxyObj* = ref object of PdfObject
    value: PdfObject

  XrefEntry = ref object
    entryType: char # 'f' or 'n'
    byteOffset: int
    gen: int
    obj: PdfObject

  PdfXref* = ref object
    startOffset: int
    entries: seq[XrefEntry]
    address: int
    prev: PdfXref
    trailer: DictObj

proc zcompress*(data: string): string =
  var nz = nzDeflateInit(data)
  result = nz.zlib_compress()

method write*(obj: PdfObject, s: Stream, enc: PdfEncrypt) {.base.} =
  assert(false)

proc newNullObj*(): NullObj =
  new(result)
  result.class = CLASS_NULL
  result.objID = 0

proc newPlainObj*(val: string): PlainObj =
  new(result)
  result.class = CLASS_PLAIN
  result.value = val
  result.objID = 0

method write(obj: PlainObj, s: Stream, enc: PdfEncrypt) =
  s.write obj.value

proc newBooleanObj*(val: bool): BooleanObj =
  new(result)
  result.class = CLASS_BOOLEAN
  result.value = val
  result.objID = 0

method write(obj: BooleanObj, s: Stream, enc: PdfEncrypt) =
  if obj.value: s.write("true")
  else: s.write("false")

proc newNumberObj*(val: int): NumberObj =
  new(result)
  result.class = CLASS_NUMBER
  result.value = val
  result.objID = 0

method write(obj: NumberObj, s: Stream, enc: PdfEncrypt) =
  s.write($obj.value)

proc setValue(obj: NumberObj, val: int) =
  obj.value = val

proc newRealObj*(val: float64): RealObj =
  new(result)
  result.class = CLASS_REAL
  result.value = val
  result.objID = 0

method write(obj: RealObj, s: Stream, enc: PdfEncrypt) =
  s.write formatFloat(obj.value, ffDecimal, 4)

proc setValue*(obj: RealObj, val: float64) =
  obj.value = val

proc escapeName(name: string): string =
  result = "/"
  for c in name:
    if c in NeedEscape:
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

proc newNameObj*(val: string): NameObj =
  new(result)
  result.class = CLASS_NAME
  result.value = val
  result.objID = 0

method write(obj: NameObj, s: Stream, enc: PdfEncrypt) =
  s.write escapeName(obj.value)

proc setValue*(obj: NameObj, val: string) =
  obj.value = val

proc getValue*(obj: NameObj): string =
  result = obj.value

proc escapeText(str: string): string =
  result = "("
  for c in str:
    if c in NeedEscape:
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

proc newStringObj*(val: string): StringObj =
  new(result)
  result.class = CLASS_STRING
  result.value = val
  result.objID = 0

method write(obj: StringObj, s: Stream, enc: PdfEncrypt) =
  if enc != nil:
    enc.encryptReset
    s.write '<'
    s.write escapeBinary(enc.encryptCryptBuf(obj.value))
    s.write '>'
  else:
    s.write escapeText(obj.value)

proc setValue*(obj: StringObj, val: string) =
  obj.value = val

proc getValue*(obj: StringObj): string =
  result = obj.value

proc equal*(a, b: StringObj): bool =
  result = a.value == b.value

proc newBinaryObj*(val: string): BinaryObj =
  new(result)
  result.class = CLASS_BINARY
  result.value = val
  result.objID = 0

method write(obj: BinaryObj, s: Stream, enc: PdfEncrypt) =
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

proc setValue*(obj: BinaryObj, val: string) =
  obj.value = val

proc getValue*(obj: BinaryObj): string =
  result = obj.value

proc newProxyObj(obj: PdfObject): ProxyObj =
  new(result)
  result.class = CLASS_PROXY
  result.value = obj
  result.objID = 0

method write(obj: ProxyObj, s: Stream, enc: PdfEncrypt) =
  var indirect = $(obj.value.objID and 0x00FFFFFF) & " " & $obj.gen & " R"
  s.write indirect

proc newArrayObj*(): ArrayObj =
  new(result)
  result.class = CLASS_ARRAY
  result.value = @[]
  result.objID = 0

method write(obj: ArrayObj, s: Stream, enc: PdfEncrypt) =
  s.write '['
  let len = obj.value.high
  for i in 0..len:
    obj.value[i].write(s, enc)
    if i < len: s.write ' '
  s.write ']'

proc add*(obj: ArrayObj, val: PdfObject) =
  assert((val.objID and OTYPE_DIRECT) == 0)
  if (val.objID and OTYPE_INDIRECT) != 0:
    var proxy = newProxyObj(val)
    proxy.objID = proxy.objID or OTYPE_DIRECT
    obj.value.add proxy
  else:
    val.objID = val.objID or OTYPE_DIRECT
    obj.value.add val

proc addNumber*(obj: ArrayObj, val: int) =
  obj.add newNumberObj(val)

proc addReal*(obj: ArrayObj, val: float64) =
  obj.add newRealObj(val)

proc addName*(obj: ArrayObj, val: string) =
  obj.add newNameObj(val)

proc addPlain*(obj: ArrayObj, val: string) =
  obj.add newPlainObj(val)

proc addNull*(obj: ArrayObj) =
  obj.add newNullObj()

proc addBinary*(obj: ArrayObj, val: string) =
  obj.add newBinaryObj(val)

proc newArray*(args: varargs[float64]): ArrayObj =
  new(result)
  result.class = CLASS_ARRAY
  result.value = @[]
  for i in args: result.addReal i
  result.objID = 0 #strange ???

proc newArray*(args: varargs[int]): ArrayObj =
  new(result)
  result.class = CLASS_ARRAY
  result.value = @[]
  for i in args: result.addNumber i
  result.objID = 0 #strange ???

proc len*(obj: ArrayObj): int = obj.value.len

proc getItem*(obj: ArrayObj, index: int, class: ObjectClass): PdfObject =
  if index >= obj.value.len:
    return nil

  result = obj.value[index]
  if result.class == CLASS_PROXY:
    result = ProxyObj(result).value

  assert(result.class == class)

proc insert[T](dest: var seq[T], obj: T, pos: int) =
  assert((pos >= 0) and (pos <= dest.len))
  if pos == dest.len:
    dest.add obj
    return

  var i = dest.len
  dest.setLen(dest.len + 1)
  while i > pos:
    dest[i] = dest[i-1]
    dec i

  dest[pos] = obj

proc insert*(arr: ArrayObj, target, val: PdfObject): bool =
  var obj = val
  assert((obj.objID and OTYPE_DIRECT) == 0)
  if (obj.objID and OTYPE_INDIRECT) != 0:
    var proxy = newProxyObj(val)
    proxy.objID = proxy.objID or OTYPE_DIRECT
    obj = proxy
  else:
    obj.objID = obj.objID or OTYPE_DIRECT

  #get the target-object from object-list
  #consider that the pointer contained in list may be proxy-object.

  var match: PdfObject
  var i = 0
  for c in arr.value:
    if c.class == CLASS_PROXY: match = ProxyObj(c).value
    else: match = c
    if match == target:
      arr.value.insert(val, i)
      return true
    inc i

  result = false

proc clear*(obj: ArrayObj) =
  obj.value = @[]

proc initDictObj*(dict: DictObj) =
  dict.class = CLASS_DICT
  dict.value  = initTable[string, PdfObject]()
  dict.filter = {}
  dict.filterParams = nil
  dict.objID = 0

proc newDictObj*(): DictObj =
  new(result)
  result.initDictObj()

proc getKeyByObj*(d: DictObj, obj: PdfObject): string =
  for k, v in pairs(d.value):
    if v.class == CLASS_PROXY:
      if ProxyObj(v).value == obj: return k
    else:
      if v == obj: return k
  result = ""

proc removeElement*(d: DictObj, key: string): bool =
  if d.value.hasKey(key):
    d.value.del(key)
    return true
  result = false

proc getElement(d: DictObj, key: string): PdfObject =
  if d.value.hasKey(key):
    result = d.value[key]
    if result.class == CLASS_PROXY: return ProxyObj(result).value
    return result
  result = nil

proc getItem*(d: DictObj, key: string, class: ObjectClass): PdfObject =
  result = d.getElement(key)
  if result != nil:
    assert(result.class == class)
    return result
  result = nil

proc addElement*(d: DictObj, key: string, val: PdfObject) =
  assert((val.objID and OTYPE_DIRECT) == 0)

  if (val.objID and OTYPE_INDIRECT) != 0:
    var proxy = newProxyObj(val)
    d.value[key] = proxy
    proxy.objID = proxy.objID or OTYPE_DIRECT
  else:
    d.value[key] = val
    val.objID = val.objID or OTYPE_DIRECT

proc addBoolean*(d: DictObj, key: string, val: bool) =
  d.addElement(key, newBooleanObj(val))

proc addReal*(d: DictObj, key: string, val: float64) =
  d.addElement(key, newRealObj(val))

proc addNumber*(d: DictObj, key: string, val: int) =
  d.addElement(key, newNumberObj(val))

proc addPlain*(d: DictObj, key: string, val: string) =
  d.addElement(key, newPlainObj(val))

proc addName*(d: DictObj, key: string, val: string) =
  d.addElement(key, newNameObj(val))

proc addString*(d: DictObj, key: string, val: string) =
  d.addElement(key, newStringObj(val))

proc addFilterParam*(d: DictObj, filterParam: DictObj) =
  var paramArray = ArrayObj(d.getItem("DecodeParms", CLASS_ARRAY))
  if paramArray == nil:
    paramArray = newArrayObj()
    d.addElement("DecodeParms", paramArray)
  paramArray.add filterParam

method beforeWrite(d: DictObj) {.base.} = discard
method onWrite(d: DictObj, s: Stream) {.base.} = discard
method afterWrite(d: DictObj) {.base.} = discard

proc writeToStream(src: string, dst: Stream, filter: set[FilterMode], enc: PdfEncrypt) =
  # initialize input stream
  if src.len == 0: return

  var data = if FILTER_FLATE_DECODE in filter: zcompress(src) else: src
  if enc != nil:
    enc.encryptReset()
    dst.write enc.encryptCryptBuf(data)
  else: dst.write data

method write(dict: DictObj, s: Stream, encryptor: PdfEncrypt) =
  s.write "<<"
  dict.beforeWrite()

  # encrypt-dict must not be encrypted.
  var enc = encryptor
  if (dict.class == CLASS_DICT) and (dict.subclass == SUBCLASS_ENCRYPT): enc = PdfEncrypt(nil)

  if dict.stream.len != 0:
    # set filter element
    if dict.filter == {}:
      discard dict.removeElement("Filter")
    else:
      var filter = ArrayObj(dict.getItem("Filter", CLASS_ARRAY))
      if filter == nil:
        filter = ArrayObj()
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

  if dict.stream.len > 0:
    # get "length" element
    let length = NumberObj(dict.getItem("Length", CLASS_NUMBER))
    # "length" element must be indirect-object
    assert((length.objID and OTYPE_INDIRECT) != 0)
    # Acrobat 8.15 requires both \r and \n here
    s.write "\x0Astream\x0D\x0A"
    let pos = s.getPosition()
    dict.stream.writeToStream(s, dict.filter, enc)
    length.setValue(s.getPosition() - pos)
    s.write "\x0Aendstream"

  dict.afterWrite()

proc newPdfxref*(offset: int = 0): PdfXref =
  new(result)
  result.startOffset = offset
  result.entries = @[]
  result.address = 0
  result.trailer = newDictObj()

  if result.startOffset == 0:
    var en: XrefEntry
    new(en)
    # add first entry which is free entry and whose generation number is 0
    en.entryType = FREE_ENTRY
    en.byteOffset = 0
    en.gen = MAX_GENERATION_NUM
    en.obj = nil
    result.entries.add en

proc add*(x: PdfXref, obj: PdfObject) =
  assert((obj.objID and OTYPE_DIRECT) == 0)
  assert((obj.objID and OTYPE_INDIRECT) == 0)

  var en: XrefEntry
  new(en)
  en.entryType = IN_USE_ENTRY
  en.byteOffset = 0
  en.gen = 0
  en.obj = obj
  x.entries.add en

  obj.objID = (x.startOffset + x.entries.len - 1) or OTYPE_INDIRECT
  obj.gen = en.gen

proc getEntry(x: PdfXref, index: int): XrefEntry =
  result = x.entries[index]

proc numEntries*(x: PdfXref): int = x.entries.len

proc getEntryObjectById*(x: PdfXref, objID: int): XrefEntry =
  var tmp = x
  while tmp != nil:
    assert((tmp.entries.len + tmp.startOffset) <= objID)
    if tmp.startOffset < objID:
      tmp = tmp.prev
      continue

    for i in 0..tmp.entries.high:
      if (tmp.startOffset + i) == objID: return tmp.getEntry(i)

    tmp = tmp.prev

proc i2string(val: int, len: int) : string =
  let s = $val
  let blank = len - s.len()
  if blank >= 0:
    result = repeat('0', blank)
    result.add(s)
  else:
    result = s

proc writeTrailer(x: PdfXref, s: Stream) =
  var max_objID = x.entries.len + x.startOffset
  x.trailer.addNumber("Size", max_objID)
  if x.prev != nil: x.trailer.addNumber("Prev", x.prev.address)

  s.write "trailer\x0A"
  x.trailer.write(s, PdfEncrypt(nil))
  s.write "\x0Astartxref\x0A"
  s.write($x.address)
  s.write "\x0A%%EOF\x0A"

proc writeToStream*(x: PdfXref, s: Stream, enc: PdfEncrypt) =
  var tmp = x
  var str_idx: int

  while tmp != nil:
    if tmp.startOffset == 0: str_idx = 1
    else: str_idx = 0

    for i in str_idx..tmp.entries.high:
      var entry = tmp.entries[i]
      let objID = tmp.startOffset + i
      let gen = entry.gen
      entry.byteOffset = s.getPosition()
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
    s.write($tmp.startOffset & " " & $tmp.entries.len)
    s.write "\x0A"

    for en in tmp.entries:
      s.write i2string(en.byteOffset, BYTE_OFFSET_LEN)
      s.write " "
      s.write i2string(en.gen, GEN_NUMBER_LEN)
      s.write " "
      s.write en.entryType
      s.write "\x0D\x0A" # Acrobat 8.15 requires both \r and \n here

    tmp = tmp.prev

  # write trailer dictionary
  writeTrailer(x, s)

proc newDictStream*(xref: PdfXref, data: string): DictObj =
  result = newDictObj()
  # only stream object is added to xref automatically
  xref.add(result)
  var length = newNumberObj(0)
  xref.add(length)
  result.addElement("Length", length)
  result.stream = data
  result.filter.incl FILTER_FLATE_DECODE

proc getTrailer*(xref: PdfXref): DictObj =
  result = xref.trailer
