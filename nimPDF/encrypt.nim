import md5, strutils, nimSHA2, nimAES, math, random

const
  PDF_ID_LEN           =  16
  PDF_PASSWD_LEN       =  32
  PDF_ENCRYPT_KEY_MAX  =  16
  PDF_MD5_KEYLEN       =  16
  PDF_PERMISSION_PAD   =  0xFFFFFFC0'u32
  PDF_ARC4_BUF_SIZE    =  256

  PADDING_STRING = "\x28\xBF\x4E\x5E\x4E\x75\x8A\x41\x64\x00\x4E\x56\xFF\xFA\x01\x08" &
    "\x2E\x2E\x00\xB6\xD0\x68\x3E\x80\x2F\x0C\xA9\xFE\x64\x53\x69\x7A"

  #PDF_ENABLE_READ     = 0'u32
  PDF_ENABLE_PRINT    = 4'u32
  PDF_ENABLE_EDIT_ALL = 8'u32
  PDF_ENABLE_COPY     = 16'u32
  PDF_ENABLE_EDIT     = 32'u32

type
  EncryptMode* = enum
    ENCRYPT_R2,
    ENCRYPT_R3,
    ENCRYPT_R4_ARC4,
    ENCRYPT_R4_AES,
    ENCRYPT_R5

  ARC4Context = object
    idx1, idx2: int
    state: array[0..PDF_ARC4_BUF_SIZE-1, uint8]

  PdfEncrypt* = ref object
    mode*: EncryptMode
    ownerPasswd*: string #unencrypted
    userPasswd*: string  #unencrypted
    ownerKey*: string  #encrypted
    userKey*: string  #encrypted
    keyLen*: int
    permission*: uint32
    encryptID*: array[0..PDF_ID_LEN-1, uint8]
    encryptionKey: array[0..31, uint8]
    objectKey: array[0..31, uint8]
    ARC4Ctx: ARC4Context
    AESCtx: AESContext
    perms*: string
    OE*: string
    UE*: string
    encryptMetaData*: bool

proc ENCError(msg: string): ref Exception =
  new(result)
  result.msg = msg

proc ARC4Init(ctx: var ARC4Context, key: openarray[uint8], keyLen: int) =
  var tmp: array[0..PDF_ARC4_BUF_SIZE-1, uint8]
  var j = 0
  for i in 0..PDF_ARC4_BUF_SIZE-1:
    ctx.state[i] = uint8(i)
    tmp[i] = key[i mod keyLen]

  for i in 0..PDF_ARC4_BUF_SIZE-1:
    j = (j + int(ctx.state[i]) + int(tmp[i])) mod 256
    swap(ctx.state[i], ctx.state[j])

  ctx.idx1 = 0
  ctx.idx2 = 0

proc ARC4CryptBuf(ctx: var ARC4Context, input: string): string =
  result = newString(input.len)
  for i in 0..input.high:
    ctx.idx1 = (ctx.idx1 + 1) mod 256
    ctx.idx2 = (ctx.idx2 + int(ctx.state[ctx.idx1])) mod 256
    swap(ctx.state[ctx.idx1], ctx.state[ctx.idx2])
    let idx = int(ctx.state[ctx.idx1] + ctx.state[ctx.idx2]) mod 256
    let K = ctx.state[idx]
    result[i] = chr(uint8(input[i]) xor K)

proc newEncrypt*(): PdfEncrypt =
  new(result)
  result.mode = ENCRYPT_R2
  result.keyLen = 5
  result.permission = PDF_ENABLE_PRINT or PDF_ENABLE_EDIT_ALL or
    PDF_ENABLE_COPY or PDF_ENABLE_EDIT or PDF_PERMISSION_PAD
  result.encryptMetaData = false

proc toString[T](val: openArray[T], len: int): string =
  result = newString(len)
  for i in 0..len-1: result[i] = chr(val[i])

proc encryptReset*(enc: PdfEncrypt) =
  if enc.mode in {ENCRYPT_R2, ENCRYPT_R3, ENCRYPT_R4_ARC4}:
    let keyLen = min(enc.keyLen + 5, PDF_ENCRYPT_KEY_MAX)
    ARC4Init(enc.ARC4Ctx, enc.objectKey, keyLen)
  elif enc.mode in {ENCRYPT_R4_AES, ENCRYPT_R5}:
    var key = toString(enc.objectKey, enc.keyLen)
    if not setEncodeKey(enc.AESCtx, key):
      raise ENCError("wrong encryption key len")

proc createRandom16(input: string): string =
  var ctx: SHA256
  ctx.initSHA()
  ctx.update(input)
  let digest = ctx.final()
  random.randomize()
  result = newString(16)
  let r = random.rand(255)
  for i in 0..15:
    result[i] = chr(ord(digest[i]) xor ord(digest[i+15]))
    result[i] = chr(r xor ord(result[i]))

proc encryptCryptBuf*(enc: PdfEncrypt, input: string): string =
  if enc.mode in {ENCRYPT_R2, ENCRYPT_R3, ENCRYPT_R4_ARC4}:
    result = ARC4CryptBuf(enc.ARC4Ctx, input)
  elif enc.mode in {ENCRYPT_R4_AES, ENCRYPT_R5}:
    var iv = createRandom16(input)
    var pad = 16 - (input.len mod 16)
    var padding = repeat(chr(pad), pad)
    var newInput = input
    newInput.add padding
    result = iv
    result.add encryptCBC(enc.AESCtx, cstring(iv), newInput)

proc encryptInitKey*(enc: PdfEncrypt, object_id, gen_no: int) =
  if enc.mode == ENCRYPT_R5:
    copyMem(addr(enc.objectKey), addr(enc.encryptionKey), enc.keyLen)
    var key = toString(enc.objectKey, enc.keyLen)
    if not setEncodeKey(enc.AESCtx, key):
      raise ENCError("wrong encryption key len")
    return

  var msg: array[0..4, uint8]
  msg[0] = uint8(object_id and 0xFF)
  msg[1] = uint8((object_id shr 8) and 0xFF)
  msg[2] = uint8((object_id shr 16) and 0xFF)
  msg[3] = uint8(gen_no and 0xFF)
  msg[4] = uint8((gen_no shr 8) and 0xFF)

  var ctx: MD5Context
  ctx.md5Init()
  ctx.md5Update(cast[cstring](addr(enc.encryptionKey[0])), enc.keyLen)
  ctx.md5Update(cast[cstring](addr(msg[0])), 5)

  if enc.mode == ENCRYPT_R4_AES:
    let salt = "sAlT"
    ctx.md5Update(cstring(salt), 4)

  var digest: MD5Digest
  ctx.md5Final(digest)
  for i in 0..digest.high: enc.objectKey[i] = digest[i]

  let keyLen = min(enc.keyLen + 5, PDF_ENCRYPT_KEY_MAX)
  ARC4Init(enc.ARC4Ctx, enc.objectKey, keyLen)

proc padOrTruncatePasswd*(pwd: string): string =
  if pwd.len >= PDF_PASSWD_LEN:
    result = pwd.substr(0, PDF_PASSWD_LEN)
  else:
    result = pwd
    let len = PDF_PASSWD_LEN - pwd.len
    for i in 0..len-1: result.add PADDING_STRING[i]

proc createOwnerKey*(enc: PdfEncrypt) =
  var ARC4Ctx: ARC4Context
  var ctx: MD5Context
  var digest: MD5Digest

  # create md5-digest using the value of ownerPasswd
  # Algorithm 3.3 step 2
  ctx.md5Init()
  ctx.md5Update(cstring(enc.ownerPasswd), PDF_PASSWD_LEN)
  ctx.md5Final(digest)

  # Algorithm 3.3 step 3 (Revision 3 only)
  if enc.mode in {ENCRYPT_R3, ENCRYPT_R4_ARC4, ENCRYPT_R4_AES}:
    for i in 1..50:
      ctx.md5Init()
      ctx.md5Update(cast[cstring](addr(digest[0])), enc.keyLen)
      ctx.md5Final(digest)

  # Algorithm 3.3 step 4
  ARC4Ctx.ARC4Init(digest, enc.keyLen)

  # Algorithm 3.3 step 6
  var tmppwd = ARC4Ctx.ARC4CryptBuf(enc.userPasswd)

  # Algorithm 3.3 step 7
  if enc.mode in {ENCRYPT_R3, ENCRYPT_R4_ARC4, ENCRYPT_R4_AES}:
    for i in 1..19:
      var new_key: array[0..PDF_MD5_KEYLEN-1, uint8]
      for j in 0..enc.keyLen-1: new_key[j] = uint8(int(digest[j]) xor i)
      ARC4Ctx.ARC4Init(new_key, enc.keyLen)
      tmppwd = ARC4Ctx.ARC4CryptBuf(tmppwd)

  # Algorithm 3.3 step 8
  enc.ownerKey = tmppwd

proc createEncryptionKey*(enc: PdfEncrypt) =
  var ctx: MD5Context
  var tmp: array[0..3, uint8]

  # Algorithm3.2 step2
  ctx.md5Init()
  ctx.md5Update(cstring(enc.userPasswd), PDF_PASSWD_LEN)

  # Algorithm3.2 step3
  ctx.md5Update(cstring(enc.ownerKey), PDF_PASSWD_LEN)

  # Algorithm3.2 step4
  tmp[0] = uint8(enc.permission and 0xFF)
  tmp[1] = uint8((enc.permission shr 8) and 0xFF)
  tmp[2] = uint8((enc.permission shr 16) and 0xFF)
  tmp[3] = uint8((enc.permission shr 24) and 0xFF)

  # Algorithm3.2 step5
  var digest: MD5Digest
  ctx.md5Update(cast[cstring](addr(tmp[0])), 4)
  ctx.md5Update(cast[cstring](addr(enc.encryptID[0])), PDF_ID_LEN)

  if (enc.mode in {ENCRYPT_R4_ARC4, ENCRYPT_R4_AES}) and (not enc.encryptMetaData):
    tmp[0] = 0xFF
    tmp[1] = 0xFF
    tmp[2] = 0xFF
    tmp[3] = 0xFF
    ctx.md5Update(cast[cstring](addr(tmp[0])), 4)

  ctx.md5Final(digest)
  copyMem(addr(enc.encryptionKey[0]), addr(digest[0]), sizeof(digest))

  # Algorithm 3.2 step6 (Revision 3 only)
  if enc.mode in {ENCRYPT_R3, ENCRYPT_R4_ARC4, ENCRYPT_R4_AES}:
    for i in 1..50:
      ctx.md5Init()
      ctx.md5Update(cast[cstring](addr(enc.encryptionKey[0])), enc.keyLen)
      ctx.md5Final(digest)
      copyMem(addr(enc.encryptionKey[0]), addr(digest[0]), sizeof(digest))

proc createUserKey*(enc: PdfEncrypt) =
  var ARC4Ctx: ARC4Context
  # Algorithm 3.4/5 step1

  # Algorithm 3.4 step2
  ARC4Ctx.ARC4Init(enc.encryptionKey, enc.keyLen)
  enc.userKey = ARC4Ctx.ARC4CryptBuf(PADDING_STRING)

  if enc.mode in {ENCRYPT_R3, ENCRYPT_R4_ARC4, ENCRYPT_R4_AES}:
    var ctx: MD5Context
    # Algorithm 3.5 step2 (same as Algorithm3.2 step2)
    ctx.md5Init()
    ctx.md5Update(cstring(PADDING_STRING), PDF_PASSWD_LEN)

    # Algorithm 3.5 step3
    var digest: MD5Digest
    ctx.md5Update(cast[cstring](addr(enc.encryptID[0])), PDF_ID_LEN)
    ctx.md5Final(digest)

    # Algorithm 3.5 step4
    var digest2 = newString(digest.len)
    ARC4Ctx.ARC4Init(enc.encryptionKey, enc.keyLen)
    for i in 0..digest.high: digest2[i] = chr(digest[i])
    digest2 = ARC4Ctx.ARC4CryptBuf(digest2)

    # Algorithm 3.5 step5
    for i in 1..19:
      var new_key: array[0..PDF_MD5_KEYLEN-1, uint8]
      for j in 0..enc.keyLen-1: new_key[j] = uint8(int(enc.encryptionKey[j]) xor i)
      ARC4Ctx.ARC4Init(new_key, enc.keyLen)
      digest2 = ARC4Ctx.ARC4CryptBuf(digest2)

    # use the result of Algorithm 3.4 as 'arbitrary padding' */
    enc.userKey = repeat('\x00', PDF_PASSWD_LEN)
    for i in 0..PDF_MD5_KEYLEN-1:
      enc.userKey[i] = digest2[i]

proc computeEncryptionKeyR5*(enc: PdfEncrypt) =
  let r = createRandom16(enc.userPasswd & enc.ownerPasswd)
  let hash = $computeSHA256(r)
  let key  = hash.substr(0, enc.keyLen)
  for i in 0..enc.keyLen-1: enc.encryptionKey[i] = uint8(key[i])

proc computeUE*(enc: PdfEncrypt) =
  # Algorithm 3.8 step 1
  var seed = enc.userPasswd
  seed.add enc.ownerPasswd
  let r = createRandom16(seed)
  let validationSalt = r.substr(0, 7)
  let keySalt = r.substr(8, 15)
  var rawKey = enc.userPasswd
  rawKey.add validationSalt
  enc.userKey = $computeSHA256(rawKey)
  enc.userKey.add r
  assert enc.userKey.len == 48

  # Algorithm 3.8 step 2
  seed = enc.userPasswd
  seed.add keySalt
  let key = $computeSHA256(seed)
  var iv = repeat(chr(0), 16)
  let ok = setEncodeKey(enc.AESCtx, key)
  assert ok == true
  var encKey = toString(enc.encryptionKey, enc.keyLen)
  enc.UE = encryptCBC(enc.AESCtx, cstring(iv), encKey)
  assert enc.UE.len == 32

proc computeOE*(enc: PdfEncrypt) =
  # Algorithm 3.9 step 1
  var seed = enc.userPasswd
  seed.add enc.ownerPasswd
  let r = createRandom16(seed)
  let validationSalt = r.substr(0, 7)
  let keySalt = r.substr(8, 15)
  var rawKey = enc.ownerPasswd
  rawKey.add(validationSalt)
  rawKey.add(enc.userKey)
  enc.ownerKey = $computeSHA256(rawKey)
  enc.ownerKey.add r
  assert enc.ownerKey.len == 48

  # Algorithm 3.9 step 2
  seed = enc.ownerPasswd
  seed.add keySalt
  seed.add enc.userKey
  let key = $computeSHA256(seed)
  var iv = repeat(chr(0), 16)
  let ok = setEncodeKey(enc.AESCtx, key)
  assert ok == true
  var encKey = toString(enc.encryptionKey, enc.keyLen)
  enc.OE = encryptCBC(enc.AESCtx, cstring(iv), encKey)
  assert enc.OE.len == 32

proc computePerms*(enc: PdfEncrypt) =
  var perms: array[0..15, char]
  perms[3] = chr(int((enc.permission shr 24) and 0xff))
  perms[2] = chr(int((enc.permission shr 16) and 0xff))
  perms[1] = chr(int((enc.permission shr 8) and 0xff))
  perms[0] = chr(int(enc.permission and 0xff))

  # if EncryptMetadata is false, this value should be set to 'F'
  perms[8] = if enc.encryptMetadata: 'T' else: 'F'

  # Next 3 bytes are mandatory
  perms[9]  = 'a'
  perms[10] = 'd'
  perms[11] = 'b'

  # Next 4 bytes are ignored
  perms[12] = chr(0)
  perms[13] = chr(0)
  perms[14] = chr(0)
  perms[15] = chr(0)

  var encKey = toString(enc.encryptionKey, enc.keyLen)
  let ok = setEncodeKey(enc.AESCtx, encKey)
  assert ok == true
  enc.perms = newString(16)
  var output = cstring(enc.perms)
  encryptECB(enc.AESCtx, cast[cstring](addr(perms[0])), output)
