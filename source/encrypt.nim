
const
  PDF_ID_LEN            =  16
  PDF_PASSWD_LEN        =  32
  PDF_ENCRYPT_KEY_MAX   =  16
  PDF_MD5_KEY_LEN       =  16
  PDF_PERMISSION_PAD    =  0xFFFFFFC0
  PDF_ARC4_BUF_SIZE     =  256

type
  encryptMode = enum
    ENCRYPT_R2 = 2,
    ENCRYPT_R3 = 3

  pdf_password = array[0..PDF_PASSWD_LEN-1, char]

  arc4_ctx = object
    idx1, idx2: char
    state: array[0..PDF_ARC4_BUF_SIZE-1, char]

  MD5_ctx = object
    buf: array[0..3, uint32]
    bits: array[0..1, uint32]
    input: array[0..63, char]

  pdfEncrypt* = ref object
    mode: encryptMode
    owner_password: pdf_password #unencrypted
    user_password: pdf_password  #unencrypted
    owner_key: pdf_password  #encrypted
    user_key: pdf_password  #encrypted
    key_len: int
    encrypt_id: array[0..PDF_ID_LEN-1, char]
    encryption_key: array[0..PDF_MD5_KEY_LEN + 5 - 1, char]
    md5_encryption_key: array[0..PDF_MD5_KEY_LEN-1, char]
    arc4: arc4_ctx

proc encryptReset*(enc: pdfEncrypt) =
  discard

proc encryptCryptBuf*(enc: pdfEncrypt, input: string): string =
  result = input

proc encryptInitKey*(enc: pdfEncrypt, object_id, gen_no: int) =
  discard
