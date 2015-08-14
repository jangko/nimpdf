import streams, sequtils, algorithm, strutils, unsigned

const
  FIRST_LENGTH_CODE_INDEX = 257
  LAST_LENGTH_CODE_INDEX = 285
  #256 literals, the end code, some length codes, and 2 unused codes
  NUM_DEFLATE_CODE_SYMBOLS = 288
  #the distance codes have their own symbols, 30 used, 2 unused
  NUM_DISTANCE_SYMBOLS = 32
  #the code length codes.
  #0-15: code lengths,
  #16: copy previous 3-6 times,
  #17: 3-10 zeros,
  #18: 11-138 zeros
  NUM_CODE_LENGTH_CODES = 19

  #the base lengths represented by codes 257-285
  LENGTHBASE = [3, 4, 5, 6, 7, 8, 9, 10,
    11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51,
    59, 67, 83, 99, 115, 131, 163, 195, 227, 258]

  #the extra bits used by codes 257-285 (added to base length)
  LENGTHEXTRA = [0, 0, 0, 0, 0, 0, 0, 0,
    1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3,
    4, 4, 4, 4, 5, 5, 5, 5, 0]

  #the base backwards distances
  #(the bits of distance codes appear after
  #length codes and use their own huffman tree)
  DISTANCEBASE = [1, 2, 3, 4, 5, 7, 9,
    13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513,
    769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577]

  #the extra bits of backwards distances (added to base)
  DISTANCEEXTRA = [0, 0, 0, 0, 1, 1, 2,
    2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8,
    8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13]

  #the order in which "code length alphabet code lengths" are stored,
  #out of this the huffman tree of the dynamic huffman tree lengths is generated
  CLCL_ORDER = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]

  #3 bytes of data get encoded into two bytes. The hash cannot use more than 3
  #bytes as input because 3 is the minimum match length for deflate
  HASH_NUM_VALUES = 65536
  HASH_BIT_MASK = HASH_NUM_VALUES - 1
  MAX_SUPPORTED_DEFLATE_LENGTH = 258

type
  HuffmanTree = object
    tree2d, tree1d: seq[int]
    lengths: seq[int] #the lengths of the codes of the 1d-tree
    maxbitlen: int    #maximum number of bits a single code can get
    numcodes: int     #number of symbols in the alphabet = number of codes

  BitStream = object
    bitpointer: int
    data: string
    databitlen: int

  NZError = ref object of Exception

  NZHash = object
    head: seq[int]   #hash value to head circular pos
                     #can be outdated if went around window
    chain: seq[int]  #circular pos to prev circular pos
    val: seq[int]    #circular pos to hash value

    #TODO: do this not only for zeros but for any repeated byte. However for PNG
    #it's always going to be the zeros that dominate, so not important for PNG

    headz: seq[int]  #similar to head, but for chainz
    chainz: seq[int] #those with same amount of zeros
    zeros: seq[int]  #length of zeros streak, used as a second hash chain

    #A coin, this is the terminology used for the package-merge algorithm and the
    #coin collector's problem. This is used to generate the huffman tree.
    #A coin can be multiple coins (when they're merged)

  Coin = ref object
    symbols: seq[int]
    weight: float #the sum of all weights in this coin

  Coins = seq[Coin]

  #Possible inflate modes between inflate() calls
  inflateMode = enum
    HEAD,       # i: waiting for magic header
    FLAGS,      # i: waiting for method and flags (gzip)
    TIME,       # i: waiting for modification time (gzip)
    OS,         # i: waiting for extra flags and operating system (gzip)
    EXLEN,      # i: waiting for extra length (gzip)
    EXTRA,      # i: waiting for extra bytes (gzip)
    NAME,       # i: waiting for end of file name (gzip)
    COMMENT,    # i: waiting for end of comment (gzip)
    HCRC,       # i: waiting for header crc (gzip)
    DICTID,     # i: waiting for dictionary check value
    DICT,       # waiting for inflateSetDictionary() call
    TYPE,         # i: waiting for type bits, including last-flag bit
    TYPEDO,       # i: same, but skip check to exit inflate on new block
    STORED,       # i: waiting for stored size (length and complement)
    COPY_FIRST,   # i/o: same as COPY below, but only first time in
    COPY,         # i/o: waiting for input or output to copy stored block
    TABLE,        # i: waiting for dynamic block table lengths
    LENLENS,      # i: waiting for code length code lengths
    CODELENS,     # i: waiting for length/lit and distance code lengths
    LEN_FIRST,       # i: same as LEN below, but only first time in
    LEN,             # i: waiting for length/lit/eob code
    LENEXT,          # i: waiting for length extra bits
    DIST,            # i: waiting for distance code
    DISTEXT,         # i: waiting for distance extra bits
    MATCH,           # o: waiting for output space to copy string
    LIT,             # o: waiting for output space to write literal
    CHECK,      # i: waiting for 32-bit check value
    LENGTH,     # i: waiting for 32-bit length (gzip)
    DONE,       # finished check, done -- remain here until reset
    BAD,        # got a data error -- remain here until reset
    MEM,        # got an inflate() memory error -- remain here until reset
    SYNC        # looking for synchronization bytes to restart inflate()

  nzStreamMode = enum
    nzsDeflate, nzsInflate

  nzStream* = ref object
    btype: range[0..3]
    use_lz77: bool
    windowsize: range[2..32768]
    minmatch: range[3..258]
    nicematch: range[3..358]
    lazymatching: bool
    bits: BitStream
    data: string
    mode: nzStreamMode

proc newNZError(msg: string): NZError =
  new(result)
  result.msg = msg

proc readBit(s: BitStream): int {.inline.} =
  result = (ord(s.data[s.bitpointer shr 3]) shr (s.bitpointer and 0x07)) and 0x01

proc readBitFromStream(s: var BitStream): int {.inline.} =
  result = s.readBit
  inc s.bitpointer

proc readBitsFromStream(s: var BitStream, nbits: int): int =
  for i in 0..nbits-1:
    inc(result, s.readBit shl i)
    inc s.bitpointer

proc readBitsSafe(s: var BitStream, nbits: int): int =
  if s.bitpointer + nbits > s.databitlen:
    raise newNZError("bit pointer jumps past memory")

  for i in 0..nbits-1:
    inc(result, s.readBit shl i)
    inc s.bitpointer

#the tree representation used by the decoder.
proc HuffmanTree_make2DTree(tree: var HuffmanTree) =
  var nodefilled = 0 #up to which node it is filled
  var treepos = 0    #position in the tree (1 of the numcodes columns)

  #32767 here means the tree2d isn't filled there yet
  tree.tree2d = newSeqWith(tree.numcodes * 2, 32767)

  #convert tree1d[] to tree2d[][]. In the 2D array, a value of 32767 means
  #uninited, a value >= numcodes is an address to another bit, a value < numcodes
  #is a code. The 2 rows are the 2 possible bit values (0 or 1), there are as
  #many columns as codes - 1.
  #A good huffmann tree has N * 2 - 1 nodes, of which N - 1 are internal nodes.
  #Here, the internal nodes are stored (what their 0 and 1 option point to).
  #There is only memory for such good tree currently, if there are more nodes
  #(due to too long length codes), error 55 will happen

  for n in 0..tree.numcodes-1: #the codes
    let len = tree.lengths[n]
    for i in 0..len-1: #the bits for this code
      let bit = (tree.tree1d[n] shr (len - i - 1)) and 1
      let branch = 2 * treepos + bit
      #oversubscribed, see comment in lodepng_error_text
      if treepos > 2147483647 or treepos + 2 > tree.numcodes:
          raise newNZError("oversubscribed")

      if tree.tree2d[branch] != 32767: #not yet filled in
        treepos = tree.tree2d[branch] - tree.numcodes
        continue

      if i + 1 < len:
        #put address of the next step in here, first that address has to be found of course
        #(it's just nodefilled + 1)...
        inc(nodefilled)
        #addresses encoded with numcodes added to it
        tree.tree2d[branch] = nodefilled + tree.numcodes
        treepos = nodefilled
        continue

      #last bit
      tree.tree2d[branch] = n #put the current code in it
      treepos = 0 #start from root again

  for it in mitems(tree.tree2d):
    if it == 32767: it = 0 #remove possible remaining 32767's

#Second step for the ...makeFromLengths and ...makeFromFrequencies functions.
#numcodes, lengths and maxbitlen must already be filled in correctly.
proc HuffmanTree_makeFromLengths2(tree: var HuffmanTree) =
  tree.tree1d = newSeq[int](tree.numcodes)
  var blcount = newSeqWith(tree.maxbitlen + 1, 0)
  var nextcode = newSeqWith(tree.maxbitlen + 1, 0)

  #step 1: count number of instances of each code length
  for len in tree.lengths: inc blcount[len]

  #step 2: generate the nextcode values
  for bits in 1..tree.maxbitlen:
    nextcode[bits] = (nextcode[bits - 1] + blcount[bits - 1]) shl 1

  #step 3: generate all the codes
  for n in 0..tree.numcodes-1:
    let len = tree.lengths[n]
    if len != 0:
      tree.tree1d[n] = nextcode[len]
      inc nextcode[len]

#given the code lengths (as stored in the compressed data),
#generate the tree as defined by Deflate.
#maxbitlen is the maximum bits that a code in the tree can have.
proc HuffmanTree_makeFromLengths(tree: var HuffmanTree, bitlen: openarray[int], maxbitlen: int) =
  tree.lengths = @bitlen
  tree.numcodes = bitlen.len #number of symbols
  tree.maxbitlen = maxbitlen
  HuffmanTree_makeFromLengths2(tree)
  HuffmanTree_make2DTree(tree)

proc make_coin(): Coin =
  new(result)
  result.symbols = @[]

proc coin_copy(c1, c2: Coin) =
  c1.weight = c2.weight
  c1.symbols = c2.symbols

proc add_coins(c1, c2: Coin) =
  for sym in c2.symbols: c1.symbols.add sym
  c1.weight += c2.weight

proc init_coins(c: var Coins, num: int) =
  for i in 0..num-1: c[i] = make_coin()

proc cleanup_coins(c: var Coins, num: int) =
  for i in 0..num-1: c[i].symbols = @[]

proc coin_compare(a, b: Coin): int =
  var wa = a.weight
  var wb = b.weight
  if wa > wb: result = 1
  elif wa < wb: result = -1
  else: result = 0

proc append_symbol_coins(coins: Coins, start: int, frequencies: openarray[int], numcodes, sum: int) =
  var j = start #index of present symbols
  for i in 0..numcodes-1:
    if frequencies[i] != 0:  #only include symbols that are present
      coins[j].weight = frequencies[i] / sum
      coins[j].symbols.add i
      inc j

proc placePivot[T](a: var openArray[T], lo, hi: int, cmp: proc(x, y: T): int): int =
  var pivot = lo #set pivot
  var switch_i = lo + 1

  for i in lo+1..hi: #run on array
    if cmp(a[i], a[pivot]) <= 0:        #compare pivot and i
      swap(a[i], a[switch_i])      #swap i and i to switch
      swap(a[pivot], a[switch_i])  #swap pivot and i to switch
      inc pivot    #set current location of pivot
      inc switch_i #set location for i to switch with pivot
  result = pivot #return pivot location

proc quickSort[T](a: var openArray[T], lo, hi: int, cmp: proc(x, y: T): int) =
  if lo >= hi: return #stop condition
  #set pivot location
  var pivot = placePivot(a, lo, hi, cmp)
  quickSort(a, lo, pivot-1, cmp) #sort bottom half
  quickSort(a, pivot+1, hi, cmp) #sort top half

proc quickSort[T](a: var openArray[T], cmp: proc(x, y: T): int, length = -1) =
  var lo = 0
  var hi = if length < 0: a.high else: length-1
  quickSort(a, lo, hi, cmp)

type
  c_coin {.pure, final.} = object
    w: float
    idx: int

proc c_coin_cmp(a, b: pointer): int {.exportc, procvar, cdecl.} =
  var aa = cast[ptr c_coin](a)
  var bb = cast[ptr c_coin](b)

  if aa[].w > bb[].w: result = 1
  elif aa[].w < bb[].w: result = -1
  else: result = 0

proc huffman_code_lengths(frequencies: openarray[int], numcodes, maxbitlen: int): seq[int] =
  var
    lengths = newSeqWith(numcodes, 0)
    sum = 0
    numpresent = 0
    coins: Coins #the coins of the currently calculated row
    prev_row: Coins #the previous row of coins
    coinmem, numcoins: int

  if numcodes == 0:
    raise newNZError("a tree of 0 symbols is not supposed to be made")

  for i in 0..numcodes-1:
    if frequencies[i] > 0:
      inc numpresent
      inc(sum, frequencies[i])

  #ensure at least two present symbols. There should be at least one symbol
  #according to RFC 1951 section 3.2.7. To decoders incorrectly require two. To
  #make these work as well ensure there are at least two symbols. The
  #Package-Merge code below also doesn't work correctly if there's only one
  #symbol, it'd give it the theoritical 0 bits but in practice zlib wants 1 bit

  if numpresent == 0:
    lengths[0] = 1
    lengths[1] = 1 #note that for RFC 1951 section 3.2.7, only lengths[0] = 1 is needed
  elif numpresent == 1:
    for i in 0..numcodes-1:
      if frequencies[i] != 0:
        lengths[i] = 1
        lengths[if i == 0: 1 else: 0] = 1
        break
  else:
    #Package-Merge algorithm represented by coin collector's problem
    #For every symbol, maxbitlen coins will be created
    coinmem = numpresent * 2 #max amount of coins needed with the current algo
    coins = newSeq[Coin](coinmem)
    prev_row = newSeq[Coin](coinmem)

    coins.init_coins(coinmem)
    prev_row.init_coins(coinmem)

    #first row, lowest denominator
    append_symbol_coins(coins, 0, frequencies, numcodes, sum)
    numcoins = numpresent

    coins.quickSort(coin_compare, numcoins)

    var numprev = 0
    for j in 1..maxbitlen: #each of the remaining rows
      swap(prev_row, coins)
      swap(numprev, numcoins)

      coins.cleanup_coins(numcoins)
      coins.init_coins(numcoins)
      numcoins = 0

      #fill in the merged coins of the previous row
      var i = 0
      while i + 1 < numprev:
        #merge prev_row[i] and prev_row[i + 1] into new coin
        var coin = coins[numcoins]
        coin_copy(coin, prev_row[i])
        add_coins(coin, prev_row[i + 1])
        inc numcoins
        inc(i, 2)

      #fill in all the original symbols again
      if j < maxbitlen:
        append_symbol_coins(coins, numcoins, frequencies, numcodes, sum)
        inc(numcoins, numpresent)

      coins.quickSort(coin_compare, numcoins)

  #calculate the lengths of each symbol, as the amount of times a coin of each symbol is used
  var i = 0
  while i + 1 < numpresent:
    var coin = coins[i]
    for j in 0..coin.symbols.high: inc lengths[coin.symbols[j]]
    inc i
  result = lengths

#Create the Huffman tree given the symbol frequencies
proc HuffmanTree_makeFromFrequencies(
  tree: var HuffmanTree, frequencies: openarray[int], mincodes, maxbitlen: int) =
    var numcodes = frequencies.len
    while(frequencies[numcodes - 1] == 0) and (numcodes > mincodes):
       dec numcodes #trim zeroes

    tree.maxbitlen = maxbitlen
    tree.numcodes  = numcodes #number of symbols
    tree.lengths   = huffman_code_lengths(frequencies, numcodes, maxbitlen)
    HuffmanTree_makeFromLengths2(tree)

#get the literal and length code tree of a deflated block with fixed tree,
#as per the deflate specification
proc generateFixedLitLenTree(tree: var HuffmanTree) =
  var bitlen: array[0..NUM_DEFLATE_CODE_SYMBOLS-1, int]

  #288 possible codes:
  #0-255=literals, 256=endcode, 257-285=lengthcodes, 286-287=unused
  for i in   0..143: bitlen[i] = 8
  for i in 144..255: bitlen[i] = 9
  for i in 256..279: bitlen[i] = 7
  for i in 280..287: bitlen[i] = 8

  HuffmanTree_makeFromLengths(tree, bitlen, 15)

proc generateFixedDistanceTree(tree: var HuffmanTree) =
  var bitlen: array[0..NUM_DISTANCE_SYMBOLS-1, int]

  #there are 32 distance codes, but 30-31 are unused
  for i in 0..bitlen.len-1: bitlen[i] = 5
  HuffmanTree_makeFromLengths(tree, bitlen, 15)

proc readInt16(s: var BitStream): int =
  #go to first boundary of byte
  while (s.bitpointer and 0x7) != 0: inc s.bitpointer
  var p = s.bitpointer div 8 #byte position
  if p + 2 >= s.data.len: raise newNZError("bit pointer will jump past memory")
  result = ord(s.data[p]) + 256 * ord(s.data[p + 1])
  inc(s.bitpointer, 16)

proc getBytePosition(s: var BitStream): int =
  result = s.bitpointer div 8 #byte position

proc readByte(s: var BitStream): int =
  while (s.bitpointer and 0x7) != 0: inc s.bitpointer
  var p = s.bitpointer div 8 #byte position
  if p + 1 >= s.data.len: raise newNZError("bit pointer will jump past memory")
  result = ord(s.data[p])
  inc(s.bitpointer, 8)

proc inflateNoCompression(nz: nzStream) =
  let inlength = nz.bits.data.len

  #read LEN (2 bytes) and NLEN (2 bytes)
  let LEN  = nz.bits.readInt16
  let NLEN = nz.bits.readInt16

  #check if 16-bit NLEN is really the one's complement of LEN
  if LEN + NLEN != 65535:
    raise newNZError("NLEN is not one's complement of LEN")

  #read the literal data: LEN bytes are now stored in the out buffer
  var p = nz.bits.getBytePosition
  if p + LEN > inlength:
    raise newNZError("reading outside of input buffer")

  var pos = nz.data.len
  nz.data.setLen(pos + LEN)
  for i in 0..LEN-1:
    nz.data[pos] = nz.bits.data[p]
    inc pos
    inc p

  nz.bits.bitpointer = p * 8

#get the tree of a deflated block with fixed tree,
#as specified in the deflate specification
proc getTreeInflateFixed(tree_ll, tree_d: var HuffmanTree) =
  generateFixedLitLenTree(tree_ll)
  generateFixedDistanceTree(tree_d)

#returns the code, or (unsigned)(-1) if error happened
#inbitlength is the length of the complete buffer, in bits (so its byte length times 8)

proc huffmanDecodeSymbol(s: var BitStream, codetree: HuffmanTree, inbitlength: int): int =
  var treepos = 0

  while true:
    if s.bitpointer >= inbitlength:
      return -1 #end of input memory reached without endcode

    #decode the symbol from the tree. The "readBitFromStream" code is inlined in
    #the expression below because this is the biggest bottleneck while decoding
    let ct = codetree.tree2d[(treepos shl 1) + s.readBit]
    inc s.bitpointer
    if ct < codetree.numcodes: return ct #the symbol is decoded, return it
    else: treepos = ct - codetree.numcodes #symbol not yet decoded, instead move tree position

    if treepos >= codetree.numcodes: return -1 #it appeared outside the codetree

proc getTreeInflateDynamic(s: var BitStream, tree_ll, tree_d: var HuffmanTree) =
  #make sure that length values that aren't filled in will be 0,
  #or a wrong tree will be generated
  let inlength = s.data.len
  let inbitlength = inlength * 8

  #see comments in deflateDynamic for explanation
  #of the context and these variables, it is analogous
  var bitlen_ll = newSeqWith(NUM_DEFLATE_CODE_SYMBOLS, 0) #lit,len code lengths
  var bitlen_d = newSeqWith(NUM_DISTANCE_SYMBOLS, 0) #dist code lengths

  #code length code lengths ("clcl"),
  #the bit lengths of the huffman tree
  #used to compress bitlen_ll and bitlen_d
  var bitlen_cl = newSeq[int](NUM_CODE_LENGTH_CODES)

  #the code tree for code length codes
  #(the huffman tree for compressed huffman trees)
  var tree_cl: HuffmanTree

  if s.bitpointer + 14 > inbitlength:
    raise newNZError("the bit pointer is or will go past the memory")

  #number of literal/length codes + 257.
  #Unlike the spec, the value 257 is added to it here already
  let HLIT =  s.readBitsFromStream(5) + 257
  #number of distance codes.
  #Unlike the spec, the value 1 is added to it here already
  let HDIST = s.readBitsFromStream(5) + 1

  #number of code length codes.
  #Unlike the spec, the value 4 is added to it here already
  let HCLEN = s.readBitsFromStream(4) + 4

  if s.bitpointer + HCLEN * 3 > inbitlength:
    raise newNZError("the bit pointer is or will go past the memory")

  #read the code length codes out of 3 * (amount of code length codes) bits
  for i in 0..NUM_CODE_LENGTH_CODES-1:
    if i < HCLEN: bitlen_cl[CLCL_ORDER[i]] = s.readBitsFromStream(3)
    else: bitlen_cl[CLCL_ORDER[i]] = 0 #if not, it must stay 0

  HuffmanTree_makeFromLengths(tree_cl, bitlen_cl, 7)
  #now we can use this tree to read the lengths
  #for the tree that this function will return

  #i is the current symbol we're reading in the part
  #that contains the code lengths of lit/len and dist codes
  var i = 0
  while i < HLIT + HDIST:
    let code = s.huffmanDecodeSymbol(tree_cl, inbitlength)
    if code <= 15: #a length code
      if i < HLIT: bitlen_ll[i] = code
      else: bitlen_d[i - HLIT] = code
      inc(i)
    elif code == 16: #repeat previous
      var replength = 3 #read in the 2 bits that indicate repeat length (3-6)
      var value = 0 #set value to the previous code

      if i == 0: raise newNZError("can't repeat previous if i is 0")
      replength += s.readBitsSafe(2)

      if i < HLIT + 1: value = bitlen_ll[i - 1]
      else: value = bitlen_d[i - HLIT - 1]

      #repeat this value in the next lengths
      for n in 0..replength-1:
        if i >= HLIT + HDIST: raise newNZError("i is larger than the amount of codes")
        if i < HLIT: bitlen_ll[i] = value
        else: bitlen_d[i - HLIT] = value
        inc(i)
    elif code == 17: #repeat "0" 3-10 times
      var replength = 3 #read in the bits that indicate repeat length
      replength += s.readBitsSafe(3)

      #repeat this value in the next lengths
      for n in 0..replength-1:
        if i >= HLIT + HDIST: raise newNZError("i is larger than the amount of codes")
        if i < HLIT: bitlen_ll[i] = 0
        else: bitlen_d[i - HLIT] = 0
        inc(i)
    elif code == 18: #repeat "0" 11-138 times
      var replength = 11 #read in the bits that indicate repeat length
      replength += s.readBitsSafe(7)

      #repeat this value in the next lengths
      for n in 0..replength-1:
        if i >= HLIT + HDIST: raise newNZError("i is larger than the amount of codes")
        if i < HLIT: bitlen_ll[i] = 0
        else: bitlen_d[i - HLIT] = 0
        inc(i)
    else: #if(code == -1) huffmanDecodeSymbol returns -1 in case of error
      if code == -1:
        #return error code 10 or 11 depending on the situation that happened in huffmanDecodeSymbol
        #(10=no endcode, 11=wrong jump outside of tree)
        if s.bitpointer > inbitlength: raise newNZError("no endcode")
        else: raise newNZError("wrong jump outside of tree")
      else:
        raise newNZError("unexisting code, this can never happen")
      break

  if bitlen_ll[256] == 0:
    raise newNZError("the length of the end code 256 must be larger than 0")

  #now we've finally got HLIT and HDIST,
  #so generate the code trees, and the function is done
  HuffmanTree_makeFromLengths(tree_ll, bitlen_ll, 15)
  HuffmanTree_makeFromLengths(tree_d, bitlen_d, 15)

#inflate a block with dynamic or fixed Huffman tree
proc inflateHuffmanBlock(nz: nzStream, blockType: int) =
  var tree_ll: HuffmanTree #the huffman tree for literal and length codes
  var tree_d: HuffmanTree #the huffman tree for distance codes
  let inlength = nz.bits.data.len
  let inbitlength = inlength * 8

  if blockType == 1: getTreeInflateFixed(tree_ll, tree_d)
  elif blockType == 2: nz.bits.getTreeInflateDynamic(tree_ll, tree_d)

  #decode all symbols until end reached, breaks at end code
  #code_ll is literal, length or end code
  while true:
    let code_ll = nz.bits.huffmanDecodeSymbol(tree_ll, inbitlength)
    if code_ll <= 255: #literal symbol
      nz.data.add chr(code_ll)
    elif code_ll >= FIRST_LENGTH_CODE_INDEX and code_ll <= LAST_LENGTH_CODE_INDEX: #length code
      #part 1: get length base
      var length = LENGTHBASE[code_ll - FIRST_LENGTH_CODE_INDEX]

      #part 2: get extra bits and add the value of that to length
      let numextrabits_l = LENGTHEXTRA[code_ll - FIRST_LENGTH_CODE_INDEX]
      length += nz.bits.readBitsSafe(numextrabits_l)

      #part 3: get distance code
      let code_d = nz.bits.huffmanDecodeSymbol(tree_d, inbitlength)
      if code_d > 29:
        if code_ll == -1: #huffmanDecodeSymbol returns -1 in case of error
          #return error code 10 or 11 depending on the situation that happened in huffmanDecodeSymbol
          #(10=no endcode, 11=wrong jump outside of tree)
          if nz.bits.bitpointer > inbitlength: raise newNZError("no endcode")
          else: raise newNZError("wrong jump outside of tree")
        else:
           raise newNZError("invalid distance code (30-31 are never used)")
        break
      var distance = DISTANCEBASE[code_d]

      #part 4: get extra bits from distance
      let numextrabits_d = DISTANCEEXTRA[code_d]
      distance += nz.bits.readBitsSafe(numextrabits_d)

      #part 5: fill in all the out[n] values based on the length and dist
      let start = nz.data.len
      if distance > start:
        raise newNZError("too long backward distance")
      var backward = start - distance

      nz.data.setLen(start + length)
      for pos in 0..length-1:
        nz.data[pos+start] = nz.data[backward]
        inc backward
        if backward >= start: backward = start - distance
    elif code_ll == 256:
      break #end code, break the loop
    else: #if(code == -1) huffmanDecodeSymbol returns -1 in case of error
      #return error code 10 or 11 depending on the situation that happened in huffmanDecodeSymbol
      #(10=no endcode, 11=wrong jump outside of tree)
      if nz.bits.bitpointer > inbitlength: raise newNZError("no endcode")
      else: raise newNZError("wrong jump outside of tree")
      break

proc nzInflate(nz: nzStream) =
  var finalBlock = false
  var streamLen = nz.bits.databitlen

  while not finalBlock:
    if nz.bits.bitpointer + 2 >= streamLen: break
      #error, bit pointer will jump past memory

    finalBlock = nz.bits.readBitFromStream != 0
    let blockType = nz.bits.readBitFromStream + 2 * nz.bits.readBitFromStream

    if blockType == 3: raise newNZError("invalid blockType")
    elif blockType == 0: nz.inflateNoCompression #no compression
    else: nz.inflateHuffmanBlock(blockType) #compression, blockType 01 or 10

proc nimzHashInit(hash: var NZHash, windowsize: int) =
  hash.head   = newSeqWith(HASH_NUM_VALUES, -1)
  hash.val    = newSeqWith(windowsize, -1)
  hash.chain  = newSeq[int](windowsize)
  hash.zeros  = newSeq[int](windowsize)
  hash.headz  = newSeqWith(MAX_SUPPORTED_DEFLATE_LENGTH + 1, -1)
  hash.chainz = newSeq[int](windowsize)
  for i in 0..windowsize-1:
    hash.chain[i] = i
    hash.chainz[i] = i

proc deflateNoCompression(nz: nzStream) =
  #non compressed deflate block data:
  #1 bit BFINAL,2 bits BTYPE,(5 bits): it jumps to start of next byte,
  #2 bytes LEN, 2 bytes NLEN, LEN bytes literal DATA

  let datasize = nz.data.len
  let numdeflateblocks = (datasize + 65534) div 65535
  var datapos = 0

  for i in 0..numdeflateblocks-1:
    let finalBlock = (i == numdeflateblocks - 1)
    nz.bits.data.add chr(if finalBlock: 1 else: 0)

    var LEN = 65535
    if datasize - datapos < 65535: LEN = datasize - datapos
    let NLEN = 65535 - LEN

    nz.bits.data.add chr(LEN mod 256)
    nz.bits.data.add chr(LEN div 256)
    nz.bits.data.add chr(NLEN mod 256)
    nz.bits.data.add chr(NLEN div 256)

    #Decompressed data
    var j = 0
    while j < 65535 and datapos < datasize:
      nz.bits.data.add nz.data[datapos]
      inc datapos
      inc j

proc `|=`(a: var char, b: char) {.inline.} =
  a = chr(ord(a) or ord(b))

proc addBitToStream(s: var BitStream, bit: int) =
  #add a new byte at the end
  if (s.bitpointer and 0x07) == 0: s.data.add chr(0)
  #earlier bit of huffman code is in a lesser significant bit of an earlier byte
  s.data[s.data.len - 1] |= chr(bit shl (s.bitpointer and 0x07))
  inc s.bitpointer

proc addBitsToStream(s: var BitStream, value: int, nbits: int) =
  for i in 0..nbits-1:
    s.addBitToStream ((value shr i) and 1)

proc addBitsToStreamReversed(s: var BitStream, value: int, nbits: int) =
  for i in 0..nbits-1:
    s.addBitToStream ((value shr (nbits - 1 - i)) and 1)

proc HuffmanTree_getCode(tree: HuffmanTree, index: int): int =
  result = tree.tree1d[index]

proc HuffmanTree_getLength(tree: HuffmanTree, index: int): int =
  result = tree.lengths[index]

proc addHuffmanSymbol(s: var BitStream, tree: HuffmanTree, val: int) {.inline.} =
  s.addBitsToStreamReversed(
    HuffmanTree_getCode(tree, val),
    HuffmanTree_getLength(tree, val))

#write the lz77-encoded data, which has lit, len and dist codes, to compressed stream using huffman trees.
#tree_ll: the tree for lit and len codes.
#tree_d: the tree for distance codes.
proc writeLZ77data(s: var BitStream, input: seq[int], tree_ll, tree_d: HuffmanTree) =
  var i = 0
  while i < input.len:
    let val = input[i]
    s.addHuffmanSymbol(tree_ll, val)
    if val > 256: #for a length code, 3 more things have to be added
      let length_index = val - FIRST_LENGTH_CODE_INDEX
      let n_length_extra_bits = LENGTHEXTRA[length_index]
      let length_extra_bits = input[i+1]
      let distance_code = input[i+2]
      let n_distance_extra_bits = DISTANCEEXTRA[distance_code]
      let distance_extra_bits = input[i+3]
      inc(i, 3)

      s.addBitsToStream(length_extra_bits, n_length_extra_bits)
      s.addHuffmanSymbol(tree_d, distance_code)
      s.addBitsToStream(distance_extra_bits, n_distance_extra_bits)
    inc i

proc `^=`(a: var int, b: int) =
  a = a xor b

proc getHash(nz: nzStream, size, pos: int): int =
  if pos + 2 < size:
    #simple shift and xor hash is used. Since the data of PNGs is dominated
    #by zeroes due to the filters, a better hash does not have a significant
    #effect on speed in traversing the chain, and causes more time spend on
    #calculating the hash.
    result ^= (ord(nz.data[pos + 0]) shl 0)
    result ^= (ord(nz.data[pos + 1]) shl 4)
    result ^= (ord(nz.data[pos + 2]) shl 8)
  else:
    if pos >= size: return 0
    let amount = size - pos
    for i in 0..amount-1: result ^= (ord(nz.data[pos + i]) shl (i * 8))

  result = result and HASH_BIT_MASK

proc countZeros(nz: nzStream, size, pos: int): int =
  var datapos = pos
  var dataend = min(datapos + MAX_SUPPORTED_DEFLATE_LENGTH, datapos + size)
  while datapos < dataend and nz.data[datapos] == chr(0): inc datapos
  #subtracting two addresses returned as 32-bit number (max value is MAX_SUPPORTED_DEFLATE_LENGTH)
  result = datapos - pos

#wpos = pos & (windowsize - 1)
proc updateHashChain(hash: var NZHash, wpos, hashval, numzeros: int) =
  hash.val[wpos] = hashval
  if hash.head[hashval] != -1: hash.chain[wpos] = hash.head[hashval]
  hash.head[hashval] = wpos

  hash.zeros[wpos] = numzeros
  if hash.headz[numzeros] != -1: hash.chainz[wpos] = hash.headz[numzeros]
  hash.headz[numzeros] = wpos

proc getMaxChainLen(nz: nzStream): int =
  result = if nz.windowsize >= 8192: nz.windowsize else: nz.windowsize div 8

proc getMaxLazyMatch(nz:nzStream): int =
  result = if nz.windowsize >= 8192: MAX_SUPPORTED_DEFLATE_LENGTH else: 64

#search the index in the array, that has the largest value smaller than or equal to the given value,
#given array must be sorted (if no value is smaller, it returns the size of the given array)
proc searchCodeIndex(input: openarray[int], value: int): int =
  #linear search implementation
  #for i in 1..high(input):
    #if input[i] > value: return i - 1
  #return input.len - 1

  #binary search implementation (not that much faster) (precondition: array_size > 0)
  var left  = 1
  var right = input.len - 1
  while left <= right:
    let mid = (left + right) div 2
    if input[mid] <= value: left = mid + 1 #the value to find is more to the right
    elif input[mid - 1] > value: right = mid - 1 #the value to find is more to the left
    else: return mid - 1
  result = input.len - 1

proc addLengthDistance(values: var seq[int], length, distance: int) =
  #values in encoded vector are those used by deflate:
  #0-255: literal bytes
  #256: end
  #257-285: length/distance pair
  #(length code, followed by extra length bits, distance code, extra distance bits)
  #286-287: invalid

  let length_code    = searchCodeIndex(LENGTHBASE, length)
  let extra_length   = length - LENGTHBASE[length_code]
  let dist_code      = searchCodeIndex(DISTANCEBASE, distance)
  let extra_distance = distance - DISTANCEBASE[dist_code]

  values.add(length_code + FIRST_LENGTH_CODE_INDEX)
  values.add extra_length
  values.add dist_code
  values.add extra_distance

#LZ77-encode the data. Return value is error code. The input are raw bytes, the output
#is in the form of unsigned integers with codes representing for example literal bytes, or
#length/distance pairs.
#It uses a hash table technique to let it encode faster. When doing LZ77 encoding, a
#sliding window (of windowsize) is used, and all past bytes in that window can be used as
#the "dictionary". A brute force search through all possible distances would be slow, and
#this hash technique is one out of several ways to speed this up.
proc encodeLZ77(nz: nzStream, hash: var NZHash, inpos, insize: int): seq[int] =
  #for large window lengths, assume the user wants no compression loss.
  #Otherwise, max hash chain length speedup.
  result = @[]

  var maxchainlength = nz.getMaxChainLen
  var maxlazymatch = nz.getMaxLazyMatch

  #not sure if setting it to false for windowsize < 8192 is better or worse
  var
    usezeros = true
    numzeros = 0
    lazy = 0
    lazylength = 0
    lazyoffset = 0
    hashval: int
    offset, length: int
    hashpos: int
    lastptr, foreptr, backptr: int
    prev_offset: int
    current_offset, current_length: int

  if (nz.windowsize == 0) or (nz.windowsize > 32768):
    raise newNZError("windowsize smaller/larger than allowed")
  if (nz.windowsize and (nz.windowsize - 1)) != 0:
    raise newNZError("must be power of two")

  var nicematch = min(nz.nicematch, MAX_SUPPORTED_DEFLATE_LENGTH)
  var pos = inpos

  while pos < insize:
    var wpos = pos and (nz.windowsize - 1) #position for in 'circular' hash buffers
    var chainlength = 0
    hashval = getHash(nz, insize, pos)

    if usezeros and hashval == 0:
      if numzeros == 0: numzeros = countZeros(nz, insize, pos)
      elif (pos + numzeros > insize) or (nz.data[pos + numzeros - 1] != chr(0)): dec numzeros
    else: numzeros = 0

    updateHashChain(hash, wpos, hashval, numzeros)

    #the length and offset found for the current position
    length = 0
    offset = 0
    hashpos = hash.chain[wpos]
    lastptr = min(insize, pos + MAX_SUPPORTED_DEFLATE_LENGTH)

    #search for the longest string
    prev_offset = 0
    while true:
      if chainlength >= maxchainlength: break
      inc chainlength
      current_offset = if hashpos <= wpos: wpos - hashpos else: wpos - hashpos + nz.windowsize

      #stop when went completely around the circular buffer
      if current_offset < prev_offset: break
      prev_offset = current_offset
      if current_offset > 0:
        #test the next characters
        foreptr = pos
        backptr = pos - current_offset

        #common case in PNGs is lots of zeros. Quickly skip over them as a speedup
        if numzeros >= 3:
          let skip = min(numzeros, hash.zeros[hashpos])
          inc(backptr, skip)
          inc(foreptr, skip)

        #maximum supported length by deflate is max length
        while foreptr < lastptr:
          if nz.data[backptr] != nz.data[foreptr]: break
          inc backptr
          inc foreptr

        current_length = foreptr - pos

        if current_length > length:
          length = current_length #the longest length
          offset = current_offset #the offset that is related to this longest length
          #jump out once a length of max length is found (speed gain). This also jumps
          #out if length is MAX_SUPPORTED_DEFLATE_LENGTH
          if current_length >= nicematch: break

      if hashpos == hash.chain[hashpos]: break

      if (numzeros >= 3) and (length > numzeros):
        hashpos = hash.chainz[hashpos]
        if hash.zeros[hashpos] != numzeros: break
      else:
        hashpos = hash.chain[hashpos]
        #outdated hash value, happens if particular
        #value was not encountered in whole last window
        if hash.val[hashpos] != hashval: break

    if nz.lazymatching:
      if (lazy==0) and (length >= 3) and (length <= maxlazymatch) and (length < MAX_SUPPORTED_DEFLATE_LENGTH):
        lazy = 1
        lazylength = length
        lazyoffset = offset
        inc pos
        continue #try the next byte

      if lazy != 0:
        lazy = 0
        if pos == 0: raise newNZError("lazy matching at pos 0 is impossible")
        if length > lazylength + 1:
          #push the previous character as literal
          result.add ord(nz.data[pos - 1])
        else:
          length = lazylength
          offset = lazyoffset
          hash.head[hashval] = -1 #the same hashchain update will be done, this ensures no wrong alteration*
          hash.headz[numzeros] = -1 #idem
          dec pos

    if(length >= 3) and (offset > nz.windowsize):
      raise newNZError("too big (or overflown negative) offset")

    #encode it as length/distance pair or literal value
    if length < 3: #only lengths of 3 or higher are supported as length/distance pair
      result.add ord(nz.data[pos])
    elif(length < nz.minmatch) or ((length == 3) and (offset > 4096)):
      #compensate for the fact that longer offsets have more extra bits, a
      #length of only 3 may be not worth it then
      result.add ord(nz.data[pos])
    else:
      result.addLengthDistance(length, offset)
      for i in 1..length-1:
        inc pos
        wpos = pos and (nz.windowsize - 1)
        hashval = getHash(nz, insize, pos)
        if usezeros and (hashval == 0):
          if numzeros == 0: numzeros = countZeros(nz, insize, pos)
          elif (pos + numzeros > insize) or (nz.data[pos + numzeros - 1] != chr(0)): dec numzeros
        else: numzeros = 0
        updateHashChain(hash, wpos, hashval, numzeros)
    inc pos

proc deflateFixed(nz: nzStream, hash: var NZHash, datapos, dataend: int, final: bool) =
  var tree_ll: HuffmanTree #tree for literal values and length codes
  var tree_d: HuffmanTree  #tree for distance codes

  generateFixedLitLenTree(tree_ll)
  generateFixedDistanceTree(tree_d)

  nz.bits.addBitToStream(if final: 1 else: 0)
  nz.bits.addBitToStream(1)  #first bit of BTYPE
  nz.bits.addBitToStream(0)  #second bit of BTYPE

  if nz.use_lz77: #LZ77 encoded
    var lz77 = nz.encodeLZ77(hash, datapos, dataend)
    nz.bits.writeLZ77data(lz77, tree_ll, tree_d)
  else: #no LZ77, but still will be Huffman compressed
    for i in datapos..dataend-1:
      nz.bits.addHuffmanSymbol(tree_ll, ord(nz.data[i]))
  nz.bits.addHuffmanSymbol(tree_ll, 256) #add END code

proc deflateDynamic(nz: nzStream, hash: var NZHash, datapos, dataend: int, final: bool) =
  #A block is compressed as follows: The PNG data is lz77 encoded, resulting in
  #literal bytes and length/distance pairs. This is then huffman compressed with
  #two huffman trees. One huffman tree is used for the lit and len values ("ll"),
  #another huffman tree is used for the dist values ("d"). These two trees are
  #stored using their code lengths, and to compress even more these code lengths
  #are also run-length encoded and huffman compressed. This gives a huffman tree
  #of code lengths "cl". The code lenghts used to describe this third tree are
  #the code length code lengths ("clcl").

  #The lz77 encoded data, represented with integers
  #since there will also be length and distance codes in it

  var
    tree_ll: HuffmanTree #tree for lit,len values
    tree_d: HuffmanTree #tree for distance codes
    tree_cl: HuffmanTree #tree for encoding the code lengths representing tree_ll and tree_d

    frequencies_cl: seq[int] #frequency of code length codes
    bitlen_lld: seq[int]     #lit,len,dist code lenghts (int bits), literally (without repeat codes).
    bitlen_lld_e: seq[int]   #bitlen_lld encoded with repeat codes (this is a rudemtary run length compression)
    #bitlen_cl is the code length code lengths ("clcl"). The bit lengths of codes to represent tree_cl
    #(these are written as is in the file, it would be crazy to compress these using yet another huffman
    #tree that needs to be represented by yet another set of code lengths)
    bitlen_cl: seq[int]
    datasize = dataend - datapos

  #Due to the huffman compression of huffman tree representations ("two levels"), there are some anologies:
  #bitlen_lld is to tree_cl what data is to tree_ll and tree_d.
  #bitlen_lld_e is to bitlen_lld what lz77_encoded is to data.
  #bitlen_cl is to bitlen_lld_e what bitlen_lld is to lz77_encoded.

  var lz77: seq[int]

  if nz.use_lz77:
    lz77 = nz.encodeLZ77(hash, datapos, dataend)
  else:
    #no LZ77, but still will be Huffman compressed
    lz77 = newSeq[int](datasize)
    for i in datapos..dataend-1: lz77[i] = ord(nz.data[i])

  var frequencies_ll = newSeqWith(286, 0) #frequency of lit,len codes
  var frequencies_d = newSeqWith(30, 0) #frequency of dist codes

  #Count the frequencies of lit, len and dist codes
  var i = 0
  while i < lz77.len:
    let symbol = lz77[i]
    inc frequencies_ll[symbol]
    if symbol > 256:
      let dist = lz77[i + 2]
      inc frequencies_d[dist]
      inc(i, 3)
    inc i

  frequencies_ll[256] = 1 #there will be exactly 1 end code, at the end of the block

  #Make both huffman trees, one for the lit and len codes, one for the dist codes
  HuffmanTree_makeFromFrequencies(tree_ll, frequencies_ll, 257, 15)

  #2, not 1, is chosen for mincodes: some buggy PNG decoders require at least 2 symbols in the dist tree
  HuffmanTree_makeFromFrequencies(tree_d, frequencies_d, 2, 15)

  var numcodes_ll = min(tree_ll.numcodes, 286)
  var numcodes_d  = min(tree_d.numcodes, 30)

  #store the code lengths of both generated trees in bitlen_lld
  bitlen_lld = newSeq[int](numcodes_ll + numcodes_d)
  for i in 0..numcodes_ll-1: bitlen_lld[i] = HuffmanTree_getLength(tree_ll, i)
  for i in 0..numcodes_d-1: bitlen_lld[i+numcodes_ll] = HuffmanTree_getLength(tree_d, i)

  #run-length compress bitlen_ldd into bitlen_lld_e by using repeat codes 16 (copy length 3-6 times),
  #17 (3-10 zeroes), 18 (11-138 zeroes)
  i = 0
  bitlen_lld_e = @[]
  while i < bitlen_lld.len:
    var j = 0 #amount of repetitions
    while(i + j + 1 < bitlen_lld.len) and (bitlen_lld[i + j + 1] == bitlen_lld[i]): inc j

    if (bitlen_lld[i] == 0) and (j >= 2): #repeat code for zeroes
      inc j #include the first zero
      if j <= 10: #repeat code 17 supports max 10 zeroes
        bitlen_lld_e.add 17
        bitlen_lld_e.add(j - 3)
      else: #repeat code 18 supports max 138 zeroes
        if j > 138: j = 138
        bitlen_lld_e.add 18
        bitlen_lld_e.add(j - 11)
      i += (j - 1)
    elif j >= 3: #repeat code for value other than zero
      var num  = j div 6
      var rest = j mod 6
      bitlen_lld_e.add bitlen_lld[i]
      for k in 0..num-1:
        bitlen_lld_e.add 16
        bitlen_lld_e.add(6 - 3)
      if rest >= 3:
        bitlen_lld_e.add 16
        bitlen_lld_e.add(rest - 3)
      else: j -= rest
      i += j
    else: #too short to benefit from repeat code
      bitlen_lld_e.add bitlen_lld[i]
    inc i

  #generate tree_cl, the huffmantree of huffmantrees
  frequencies_cl = newSeqWith(NUM_CODE_LENGTH_CODES, 0)
  i = 0
  while i < bitlen_lld_e.len:
    inc frequencies_cl[bitlen_lld_e[i]]
    #after a repeat code come the bits that specify the number of repetitions,
    #those don't need to be in the frequencies_cl calculation
    if bitlen_lld_e[i] >= 16: inc i
    inc i

  HuffmanTree_makeFromFrequencies(tree_cl, frequencies_cl, frequencies_cl.len, 7)

  bitlen_cl = newSeq[int](tree_cl.numcodes)
  for i in 0..tree_cl.numcodes-1:
    #lenghts of code length tree is in the order as specified by deflate*/
    bitlen_cl[i] = HuffmanTree_getLength(tree_cl, CLCL_ORDER[i])

  while(bitlen_cl[bitlen_cl.high] == 0) and (bitlen_cl.len > 4):
    #remove zeros at the end, but minimum size must be 4
    bitlen_cl.setLen(bitlen_cl.high)

  #Write everything into the output
  #After the BFINAL and BTYPE, the dynamic block consists out of the following:
  #- 5 bits HLIT, 5 bits HDIST, 4 bits HCLEN
  #- (HCLEN+4)*3 bits code lengths of code length alphabet
  #- HLIT + 257 code lenghts of lit/length alphabet (encoded using the code length
  #  alphabet, + possible repetition codes 16, 17, 18)
  #- HDIST + 1 code lengths of distance alphabet (encoded using the code length
  #  alphabet, + possible repetition codes 16, 17, 18)
  #- compressed data
  #- 256 (end code)

  #Write block type
  nz.bits.addBitToStream(if final: 1 else: 0)
  nz.bits.addBitToStream(0) #first bit of BTYPE "dynamic"
  nz.bits.addBitToStream(1) #second bit of BTYPE "dynamic"

  #write the HLIT, HDIST and HCLEN values
  var HLIT  = (numcodes_ll - 257)
  var HDIST = (numcodes_d - 1)
  var HCLEN = bitlen_cl.len - 4

  #trim zeroes for HCLEN. HLIT and HDIST were already trimmed at tree creation
  while(bitlen_cl[HCLEN + 4 - 1] == 0) and (HCLEN > 0): dec HCLEN
  nz.bits.addBitsToStream(HLIT, 5)
  nz.bits.addBitsToStream(HDIST, 5)
  nz.bits.addBitsToStream(HCLEN, 4)

  #write the code lenghts of the code length alphabet
  for i in 0..HCLEN + 4 - 1: nz.bits.addBitsToStream(bitlen_cl[i], 3)

  #write the lenghts of the lit/len AND the dist alphabet
  i = 0
  while i < bitlen_lld_e.len:
    nz.bits.addHuffmanSymbol(tree_cl, bitlen_lld_e[i])
    #extra bits of repeat codes
    if bitlen_lld_e[i] == 16:
      inc i
      nz.bits.addBitsToStream(bitlen_lld_e[i], 2)
    elif bitlen_lld_e[i] == 17:
      inc i
      nz.bits.addBitsToStream(bitlen_lld_e[i], 3)
    elif bitlen_lld_e[i] == 18:
      inc i
      nz.bits.addBitsToStream(bitlen_lld_e[i], 7)
    inc i

  #write the compressed data symbols
  nz.bits.writeLZ77data(lz77, tree_ll, tree_d)

  if HuffmanTree_getLength(tree_ll, 256) == 0:
    raise newNZError("the length of the end code 256 must be larger than 0")

  #write the end code
  nz.bits.addHuffmanSymbol(tree_ll, 256)

proc nzDeflate(nz: nzStream) =
  var hash: NZHash
  var blocksize = 0
  var insize = nz.data.len

  if   nz.btype  > 2: raise newNZError("invalid block type")
  elif nz.btype == 0:
    nz.deflateNoCompression
    return
  elif nz.btype == 1: blocksize = insize
  else: blocksize = max(insize div 8 + 8, 65535) #if(nz.btype == 2)
    #if blocksize < 65535: blocksize = 65535

  var numdeflateblocks = (insize + blocksize - 1) div blocksize
  if numdeflateblocks == 0: numdeflateblocks = 1
  nimzHashInit(hash, nz.windowsize)

  for i in 0..numdeflateblocks-1:
    let final = (i == numdeflateblocks - 1)
    let datapos = i * blocksize
    let dataend = min(datapos + blocksize, insize)

    if nz.btype == 1: nz.deflateFixed(hash, datapos, dataend, final)
    elif nz.btype == 2: nz.deflateDynamic(hash, datapos, dataend, final)

proc nzInit(nz: nzStream) =
  const DEFAULT_WINDOWSIZE = 2048

  #compress with dynamic huffman tree
  #(not in the mathematical sense, just not the predefined one)
  nz.btype = 2
  nz.use_lz77 = true
  nz.windowsize = DEFAULT_WINDOWSIZE
  nz.minmatch = 3
  nz.nicematch = 128
  nz.lazymatching = true

proc nzDeflateInit*(input: string): nzStream =
  var nz : nzStream
  new(nz)
  nz.nzInit
  nz.data = input
  nz.bits.data = ""
  nz.bits.bitpointer = 0
  nz.mode = nzsDeflate
  result = nz

proc nzInflateInit*(input: string): nzStream =
  var nz : nzStream
  new(nz)
  nz.nzInit
  nz.data = ""
  nz.bits.data = input
  nz.bits.bitpointer = 0
  nz.bits.databitlen = input.len * 8
  nz.mode = nzsInflate
  result = nz

proc nzGetResult(nz: nzStream): string =
  if nz.mode == nzsInflate: return nz.data
  result = nz.bits.data

proc nzAdler32(adler: uint32, data: string): uint32 =
  var s1 = adler and 0xffff
  var s2 = (adler shr 16) and 0xffff
  var len = data.len
  var i = 0

  while len > 0:
    #at least 5550 sums can be done before the sums overflow
    #saving a lot of module divisions

    var amount = min(len, 5550)
    dec(len, amount)
    while amount > 0:
      s1 += cast[uint32](ord(data[i]))
      s2 += s1
      dec(amount)
      inc(i)

    s1 = s1 mod 65521'u32
    s2 = s2 mod 65521'u32

  result = (s2 shl 16'u32) or s1

proc add32bitInt(s: var BitStream, val: uint32) =
  s.data.add chr(cast[int](val shr 24) and 0xff)
  s.data.add chr(cast[int](val shr 16) and 0xff)
  s.data.add chr(cast[int](val shr  8) and 0xff)
  s.data.add chr(cast[int](val       ) and 0xff)

proc zlib_compress*(nz: nzStream): string =
  #zlib data: 1 byte CMF (CM+CINFO),
  #1 byte FLG, deflate data,
  #4 byte ADLER32 checksum of the Decompressed data

  let
    CMF = 120 #0b01111000: CM 8, CINFO 7. With CINFO 7, any window size up to 32768 can be used.
    FLEVEL = 0
    FDICT = 0
  var
    CMFFLG = 256 * CMF + FDICT * 32 + FLEVEL * 64
    FCHECK = 31 - CMFFLG mod 31

  CMFFLG += FCHECK

  nz.bits.data.add chr(CMFFLG div 256)
  nz.bits.data.add chr(CMFFLG mod 256)
  nz.bits.bitpointer += 16

  nz.nzDeflate
  nz.bits.add32bitInt nzAdler32(1, nz.data)
  result = nz.nzGetResult

proc readInt32(input: string): uint32 =
  assert input.len == 4
  result  = cast[uint32](ord(input[0])) shl 24
  result += cast[uint32](ord(input[1])) shl 16
  result += cast[uint32](ord(input[2])) shl 8
  result += cast[uint32](ord(input[3]))

proc zlib_decompress*(nz: nzStream): string =
  var insize = nz.bits.data.len

  if insize < 2: raise newNZError("size of zlib data too small")

  #read information from zlib header
  let CMF = nz.bits.readByte
  let FLG = nz.bits.readByte

  if ((CMF * 256 + FLG) mod 31) != 0:
    raise newNZError(" zlib header must be a multiple of 31")
    #the FCHECK value is supposed to be made that way

  #let CM    = CMF and 15
  #let CINFO = (CMF shr 4) and 15
  #FCHECK = FLG and 31 #FCHECK is already tested above
  #let FDICT = (FLG shr 5) and 1
  #FLEVEL = (FLG shr 6) and 3 #FLEVEL is not used here

  #if(CM != 8 || CINFO > 7)
    #/*error: only compression method 8: inflate with sliding window of 32k is supported by the PNG spec*/
    #return 25;
  #if(FDICT != 0)
    #/*error: the specification of PNG says about the zlib stream:
    #"The additional flags shall not specify a preset dictionary."*/
    #return 26;

  let checksum = nz.bits.data.substr(insize-4, insize).readInt32
  nz.bits.data.setLen(insize-4)

  nz.nzInflate
  let adler32 = nzAdler32(1, nz.data)
  if checksum != adler32:
    raise newNZError("adler checksum not correct, data must be corrupted")

  result = nz.nzGetResult
