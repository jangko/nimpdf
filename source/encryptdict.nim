import encrypt, objects, times, md5, tables, strutils

type
  DocInfo* = enum
    DI_CREATOR, DI_PRODUCER, DI_TITLE, DI_SUBJECT, DI_AUTHOR, DI_KEYWORDS

  encryptDict* = ref object of dictObj
    enc*: pdfEncrypt

proc newEncryptDict*(): encryptDict =
  new(result)
  result.dictObjInit()
  result.enc = newEncrypt()
  result.subclass = SUBCLASS_ENCRYPT

proc update(ctx: var MD5Context, info: Table[int, string], field: DocInfo) =
  var idx = int(field)
  if info.hasKey(idx):
    ctx.md5Update(cstring(info[idx]), info[idx].len)

proc createID(dict: encryptDict, info: Table[int, string], xref: pdfXref) =
  var enc = dict.enc
  var ctx: MD5Context

  ctx.md5Init()
  when false:
    var t = getTime()
    ctx.md5Update(cast[cstring](addr(t)), sizeof(t))
    # create File Identifier from elements of Into dictionary.
    ctx.update(info, DI_AUTHOR)
    ctx.update(info, DI_CREATOR)
    ctx.update(info, DI_PRODUCER)
    ctx.update(info, DI_TITLE)
    ctx.update(info, DI_SUBJECT)
    ctx.update(info, DI_KEYWORDS)

  #var len = xref.numEntries()
  var len = 10
  ctx.md5Update(cast[cstring](addr(len)), sizeof(len))
  ctx.md5Final(enc.encrypt_id)

proc prepare*(dict: encryptDict, info: Table[int, string], xref: pdfXref) =
  var enc = dict.enc
  dict.createID(info, xref)
  enc.createOwnerKey()
  enc.createEncryptionKey()
  enc.createUserKey()

  dict.addElement("O", binaryObjNew(enc.owner_key))
  dict.addElement("U", binaryObjNew(enc.user_key))
  dict.addName("Filter", "Standard")

  if enc.mode == ENCRYPT_R2:
    dict.addNumber("V", 1)
    dict.addNumber("R", 2)
  elif enc.mode == ENCRYPT_R3:
    dict.addNumber("V", 2)
    dict.addNumber("R", 3)
    dict.addNumber("Length", enc.key_len * 8)

  dict.addNumber("P", cast[int](enc.permission))

proc setPassword*(dict: encryptDict, owner_pass, user_pass): bool =
  var enc = dict.enc
  if owner_pass.len <= 2: return false
  if owner_pass == user_pass: return false
  enc.owner_passwd = padOrTruncatePasswd(owner_pass)
  enc.user_passwd = padOrTruncatePasswd(user_pass)
  result = true
