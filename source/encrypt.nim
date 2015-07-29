import md5, unsigned, strutils

const
  PDF_ID_LEN            =  16
  PDF_PASSWD_LEN        =  32
  PDF_ENCRYPT_KEY_MAX   =  16
  PDF_MD5_KEY_LEN       =  16
  PDF_PERMISSION_PAD    =  0xFFFFFFC0'u32
  PDF_RC4_BUF_SIZE      =  256

  PADDING_STRING = "\x28\xBF\x4E\x5E\x4E\x75\x8A\x41\x64\x00\x4E\x56\xFF\xFA\x01\x08" &
    "\x2E\x2E\x00\xB6\xD0\x68\x3E\x80\x2F\x0C\xA9\xFE\x64\x53\x69\x7A"

  PDF_ENABLE_READ     = 0'u32
  PDF_ENABLE_PRINT    = 4'u32
  PDF_ENABLE_EDIT_ALL = 8'u32
  PDF_ENABLE_COPY     = 16'u32
  PDF_ENABLE_EDIT     = 32'u32

type
  encryptMode* = enum
    ENCRYPT_R2 = 2,
    ENCRYPT_R3 = 3

  RC4ctx = object
    idx1, idx2: int
    state: array[0..PDF_RC4_BUF_SIZE-1, uint8]

  pdfEncrypt* = ref object
    mode*: encryptMode
    owner_passwd*: string #unencrypted
    user_passwd*: string  #unencrypted
    owner_key*: string  #encrypted
    user_key*: string  #encrypted
    key_len*: int
    permission*: uint32
    encrypt_id*: array[0..PDF_ID_LEN-1, uint8]
    encryption_key: array[0..PDF_MD5_KEY_LEN + 5 - 1, uint8]
    md5_key: MD5Digest
    rc4: RC4ctx

proc RC4Init(ctx: var RC4ctx, key: openarray[uint8], key_len: int) =
  var tmp: array[0..PDF_RC4_BUF_SIZE-1, uint8]
  var j = 0
  for i in 0..PDF_RC4_BUF_SIZE-1:
    ctx.state[i] = uint8(i)
    tmp[i] = key[i mod key_len]

  for i in 0..PDF_RC4_BUF_SIZE-1:
    j = (j + int(ctx.state[i]) + int(tmp[i])) mod 256
    swap(ctx.state[i], ctx.state[j])

  ctx.idx1 = 0
  ctx.idx2 = 0

proc RC4CryptBuf(ctx: var RC4ctx, input: string): string =
  result = newString(input.len)
  for i in 0..input.high:
    ctx.idx1 = (ctx.idx1 + 1) mod 256
    ctx.idx2 = (ctx.idx2 + int(ctx.state[ctx.idx1])) mod 256
    swap(ctx.state[ctx.idx1], ctx.state[ctx.idx2])
    let idx = int(ctx.state[ctx.idx1] + ctx.state[ctx.idx2]) mod 256
    let K = ctx.state[idx]
    result[i] = chr(uint8(input[i]) xor K)

proc newEncrypt*(): pdfEncrypt =
  new(result)
  result.mode = ENCRYPT_R2
  result.key_len = 5
  result.permission = PDF_ENABLE_PRINT or PDF_ENABLE_EDIT_ALL or
    PDF_ENABLE_COPY or PDF_ENABLE_EDIT or PDF_PERMISSION_PAD

proc encryptReset*(enc: pdfEncrypt) =
  let key_len = min(enc.key_len + 5, PDF_ENCRYPT_KEY_MAX)
  RC4Init(enc.rc4, enc.md5_key, key_len)

proc encryptCryptBuf*(enc: pdfEncrypt, input: string): string =
  result = RC4CryptBuf(enc.rc4, input)

proc encryptInitKey*(enc: pdfEncrypt, object_id, gen_no: int) =
  enc.encryption_key[enc.key_len + 0] = object_id and 0xFF
  enc.encryption_key[enc.key_len + 1] = (object_id shr 8) and 0xFF
  enc.encryption_key[enc.key_len + 2] = (object_id shr 16) and 0xFF
  enc.encryption_key[enc.key_len + 3] = gen_no and 0xFF
  enc.encryption_key[enc.key_len + 4] = (gen_no shr 8) and 0xFF

  var ctx: MD5Context
  ctx.md5Init()
  ctx.md5Update(cast[cstring](addr(enc.encryption_key[0])), enc.key_len + 5)
  ctx.md5Final(enc.md5_key)

  let key_len = min(enc.key_len + 5, PDF_ENCRYPT_KEY_MAX)
  RC4Init(enc.rc4, enc.md5_key, key_len)

proc padOrTruncatePasswd*(pwd: string): string =
  if pwd.len >= PDF_PASSWD_LEN:
    result = pwd.substr(0, PDF_PASSWD_LEN)
  else:
    result = pwd
    let len = PDF_PASSWD_LEN - pwd.len
    for i in 0..len-1: result.add PADDING_STRING[i]

proc createOwnerKey*(enc: pdfEncrypt) =
  var rc4: RC4ctx
  var ctx: MD5Context
  var digest: MD5Digest

  # create md5-digest using the value of owner_passwd
  # Algorithm 3.3 step 2
  ctx.md5Init()
  ctx.md5Update(cstring(enc.owner_passwd), PDF_PASSWD_LEN)
  ctx.md5Final(digest)

  # Algorithm 3.3 step 3 (Revision 3 only)
  if enc.mode == ENCRYPT_R3:
    for i in 1..50:
      ctx.md5Init()
      ctx.md5Update(cast[cstring](addr(digest[0])), enc.key_len)
      ctx.md5Final(digest)

  # Algorithm 3.3 step 4
  rc4.RC4Init(digest, enc.key_len)

  # Algorithm 3.3 step 6
  var tmppwd = rc4.RC4CryptBuf(enc.user_passwd)

  # Algorithm 3.3 step 7
  if enc.mode == ENCRYPT_R3:
    for i in 1..19:
      var new_key: array[0..PDF_MD5_KEY_LEN-1, uint8]
      for j in 0..enc.key_len-1: new_key[j] = uint8(int(digest[j]) xor i)
      rc4.RC4Init(new_key, enc.key_len)
      tmppwd = rc4.RC4CryptBuf(tmppwd)

  # Algorithm 3.3 step 8
  enc.owner_key = tmppwd

proc createEncryptionKey*(enc: pdfEncrypt) =
  var ctx: MD5Context
  var tmp_flg: array[0..3, uint8]

  # Algorithm3.2 step2
  ctx.md5Init()
  ctx.md5Update(cstring(enc.user_passwd), PDF_PASSWD_LEN)

  # Algorithm3.2 step3
  ctx.md5Update(cstring(enc.owner_key), PDF_PASSWD_LEN)

  # Algorithm3.2 step4
  tmp_flg[0] = enc.permission and 0xFF
  tmp_flg[1] = (enc.permission shr 8) and 0xFF
  tmp_flg[2] = (enc.permission shr 16) and 0xFF
  tmp_flg[3] = (enc.permission shr 24) and 0xFF

  # Algorithm3.2 step5
  var digest: MD5Digest
  ctx.md5Update(cast[cstring](addr(tmp_flg[0])), 4)
  ctx.md5Update(cast[cstring](addr(enc.encrypt_id[0])), PDF_ID_LEN)
  ctx.md5Final(digest)
  copyMem(addr(enc.encryption_key[0]), addr(digest[0]), sizeof(digest))

  # Algorithm 3.2 step6 (Revision 3 only)
  if enc.mode == ENCRYPT_R3:
    for i in 1..50:
      ctx.md5Init()
      ctx.md5Update(cast[cstring](addr(enc.encryption_key[0])), enc.key_len)
      ctx.md5Final(digest)
      copyMem(addr(enc.encryption_key[0]), addr(digest[0]), sizeof(digest))

proc createUserKey*(enc: pdfEncrypt) =
  var rc4: RC4ctx
  # Algorithm 3.4/5 step1

  # Algorithm 3.4 step2
  rc4.RC4Init(enc.encryption_key, enc.key_len)
  enc.user_key = rc4.RC4CryptBuf(PADDING_STRING)

  if enc.mode == ENCRYPT_R3:
    var ctx: MD5Context
    # Algorithm 3.5 step2 (same as Algorithm3.2 step2)
    ctx.md5Init()
    ctx.md5Update(cstring(PADDING_STRING), PDF_PASSWD_LEN)

    # Algorithm 3.5 step3
    var digest: MD5Digest
    ctx.md5Update(cast[cstring](addr(enc.encrypt_id[0])), PDF_ID_LEN)
    ctx.md5Final(digest)

    # Algorithm 3.5 step4
    var digest2 = newString(digest.len)
    rc4.RC4Init(enc.encryption_key, enc.key_len)
    for i in 0..digest.high: digest2[i] = chr(digest[i])
    digest2 = rc4.RC4CryptBuf(digest2)

    # Algorithm 3.5 step5
    for i in 1..19:
      var new_key: array[0..PDF_MD5_KEY_LEN-1, uint8]
      for j in 0..enc.key_len-1: new_key[j] = uint8(int(enc.encryption_key[j]) xor i)
      rc4.RC4Init(new_key, enc.key_len)
      digest2 = rc4.RC4CryptBuf(digest2)

    # use the result of Algorithm 3.4 as 'arbitrary padding' */
    enc.user_key = repeat('\x00', PDF_PASSWD_LEN)
    for i in 0..PDF_MD5_KEY_LEN-1:
      enc.user_key[i] = digest2[i]
