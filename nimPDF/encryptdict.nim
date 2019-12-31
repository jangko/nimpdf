import encrypt, objects, times, md5, tables

const
  stdCFName = "StdCF"

type
  DocInfo* = enum
    DI_CREATOR, DI_PRODUCER, DI_TITLE, DI_SUBJECT, DI_AUTHOR, DI_KEYWORDS

  EncryptDict* = ref object of DictObj
    enc*: PdfEncrypt

proc newEncryptDict*(): EncryptDict =
  new(result)
  result.initDictObj()
  result.enc = newEncrypt()
  result.subclass = SUBCLASS_ENCRYPT

proc update(ctx: var MD5Context, info: Table[int, string], field: DocInfo) =
  var idx = int(field)
  if info.hasKey(idx):
    ctx.md5Update(cstring(info[idx]), info[idx].len)

proc createID(dict: EncryptDict, info: Table[int, string], xref: Pdfxref) =
  var enc = dict.enc
  var ctx: MD5Context

  ctx.md5Init()
  when true:
    var t = getTime()
    ctx.md5Update(cast[cstring](addr(t)), sizeof(t))
    # create File Identifier from elements of Into dictionary.
    ctx.update(info, DI_AUTHOR)
    ctx.update(info, DI_CREATOR)
    ctx.update(info, DI_PRODUCER)
    ctx.update(info, DI_TITLE)
    ctx.update(info, DI_SUBJECT)
    ctx.update(info, DI_KEYWORDS)

  var len = xref.numEntries()
  ctx.md5Update(cast[cstring](addr(len)), sizeof(len))
  ctx.md5Final(enc.encryptID)

proc makeCryptFilter(enc: PdfEncrypt, xref: Pdfxref): DictObj =
  result = newDictObj()
  #result.subclass = SUBCLASS_CRYPT_FILTERS
  result.subclass = SUBCLASS_ENCRYPT
  xref.add(result)

  var stdCF = newDictObj()
  #stdCF.subclass = SUBCLASS_CRYPT_FILTER
  stdCF.subclass = SUBCLASS_ENCRYPT
  stdCF.addName("Type", "CryptFilter")
  if enc.mode == ENCRYPT_R5:
    stdCF.addName("CFM", "AESV3")
  elif enc.mode == ENCRYPT_R4_AES:
    stdCF.addName("CFM", "AESV2")
  elif enc.mode == ENCRYPT_R4_ARC4:
    stdCF.addName("CFM", "V2")
  stdCF.addNumber("Length", enc.keyLen)
  stdCF.addName("AuthEvent", "DocOpen")
  xref.add(stdCF)

  result.addElement(stdCFName, stdCF)

proc saslprepFromUtf8(input: string): string =
  #TODO: stringprep with SALSprep profile
  if input.len > 127: result = input.substr(0, 127)
  else: result = input

proc prepare*(dict: EncryptDict, info: Table[int, string], xref: Pdfxref) =
  var enc = dict.enc
  dict.createID(info, xref)

  if enc.mode == ENCRYPT_R5:
    enc.ownerPasswd = saslprepFromUtf8(enc.ownerPasswd)
    enc.userPasswd = saslprepFromUtf8(enc.userPasswd)
    enc.computeEncryptionKeyR5()
    enc.computeUE()
    enc.computeOE()
    enc.computePerms()
  else:
    enc.ownerPasswd = padOrTruncatePasswd(enc.ownerPasswd)
    enc.userPasswd = padOrTruncatePasswd(enc.userPasswd)
    enc.createOwnerKey()
    enc.createEncryptionKey()
    enc.createUserKey()

  dict.addElement("O", newBinaryObj(enc.ownerKey))
  dict.addElement("U", newBinaryObj(enc.userKey))
  dict.addName("Filter", "Standard")

  if enc.mode == ENCRYPT_R2:
    dict.addNumber("V", 1)
    dict.addNumber("R", 2)
  elif enc.mode == ENCRYPT_R3:
    dict.addNumber("V", 2)
    dict.addNumber("R", 3)
    dict.addNumber("Length", enc.keyLen * 8)
  elif enc.mode in {ENCRYPT_R4_ARC4, ENCRYPT_R4_AES}:
    dict.addNumber("V", 4)
    dict.addNumber("R", 4)
  elif enc.mode == ENCRYPT_R5:
    dict.addNumber("V", 5)
    dict.addNumber("R", 5)

  if enc.mode in {ENCRYPT_R4_ARC4, ENCRYPT_R4_AES, ENCRYPT_R5}:
    dict.addName("StmF", stdCFName)
    dict.addName("StrF", stdCFName)
    var cryptFilter = enc.makeCryptFilter(xref)
    dict.addElement("CF", cryptFilter)
    dict.addBoolean("EncryptMetadata", enc.encryptMetadata)
    dict.addNumber("Length", enc.keyLen * 8)

  if enc.mode == ENCRYPT_R5:
    dict.addElement("OE", newBinaryObj(enc.OE))
    dict.addElement("UE", newBinaryObj(enc.UE))
    dict.addElement("Perms", newBinaryObj(enc.perms))

  dict.addNumber("P", cast[int](enc.permission))

proc setPassword*(dict: EncryptDict, ownerPass, userPass: string): bool =
  var enc = dict.enc
  if ownerPass.len <= 2: return false
  if ownerPass == userPass: return false
  enc.ownerPasswd = ownerPass
  enc.userPasswd = userPass
  result = true
