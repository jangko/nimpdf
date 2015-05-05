import FontData, FontIOStreams, tables, algorithm, sequtils, math

import LOCATable, GLYPHTable, HEADTable, HDMXTable, NAMETable
import HHEATable, HMTXTable, MAXPTable, OS2Table, CMAPTable, POSTTable

const
    kSfntVersion = 0
    kNumTables = 4
    kSearchRange = 6
    kEntrySelector = 8
    kRangeShift = 10
    kTableRecordBegin = 12
    kSfntHeaderSize = 12

    #Offsets within a specific table record
    kTableTag = 0
    kTableCheckSum = 4
    kTableOffset = 8
    kTableLength = 12
    kTableRecordSize = 16
    
    kTTCTag = 0
    kVersion = 4
    kNumFonts = 8
    kOffsetTable = 12

    #TTC Version 2.0 extensions.
    #Offsets from end of OffsetTable.
    kulDsigTag = 0
    kulDsigLength = 4
    kulDsigOffset = 8

    SFNTVERSION_MAJOR = 1
    SFNTVERSION_MINOR = 0

type
    FontTableMap* = Table[TTag, FontTable]
    TableHeaderList = seq[Header]
    
    FontDef* = ref object
        checksum: int64
        tables: FontTableMap
        sfnt_version, num_tables, search_range, entry_selector, range_shift: int

    FontArray* = seq[FontDef]

    FontDescriptor* = ref object
        postscriptName*: string
        FirstChar*: int
        LastChar*: int
        fontFamily*: string
        Flags*:int
        BBox*: array[0..3, int]
        italicAngle*: float
        Ascent*: int
        Descent*: int
        capHeight*: int
        StemV*:int
        xHeight*:int
        MissingWidth*: int
        
proc GetTable(header: Header, data: FontData): FontTable =
    let tag = header.tag()
    
    case tag
    of TAG.head: result = makeHEADTable(header, data)
    of TAG.cmap: result = makeCMAPTable(header, data)
    of TAG.hhea: result = makeHHEATable(header, data)
    of TAG.hmtx: result = makeHMTXTable(header, data)
    of TAG.maxp: result = makeMAXPTable(header, data)
    of TAG.name: result = makeNAMETable(header, data)
    of TAG.OS_2: result = makeOS2Table(header, data)
    of TAG.glyf: result = makeGLYPHTable(header, data)
    of TAG.loca: result = makeLOCATable(header, data)
    #of Tag.EBDT, Tag.bdat:
        #result = makeEbdtTableBuilder(header, data)
    #of Tag.EBLC, Tag.bloc:
        #result = makeEblcTableBuilder(header, data)
    #of Tag.EBSC:
        #result = makeEbscTableBuilder(header, data)
    of TAG.bhed: result = makeHEADTable(header, data)
    of TAG.hdmx: result = makeHDMXTable(header, data)
    of TAG.post: result = makePOSTTable(header, data)
    else:
        new(result)
        initFontTable(result, header, data)
    
proc GetSfntVersion*(f: FontDef): int = f.sfnt_version
proc GetChecksum*(f: FontDef): int64 = f.checksum
proc GetNumTables*(f: FontDef): int = f.tables.len

proc HasTable*(f: FontDef, tag: TTag): bool = f.tables.hasKey(tag)

proc GetTable*(f: FontDef, tag: TTag): FontTable =
    if not f.HasTable(tag): return nil
    result = f.tables[tag]
  
proc GetTableMap*(f: FontDef): FontTableMap = f.tables

proc makeFont*(): FontDef =
    new(result)
    result.sfnt_version = Fixed1616Fixed(SFNTVERSION_MAJOR, SFNTVERSION_MINOR)

proc ReadHeader(f: FontDef, fis: FontInputStream): TableHeaderList =
    result = @[]
    
    f.sfnt_version   = fis.ReadFixed()
    f.num_tables     = fis.ReadUShort()
    f.search_range   = fis.ReadUShort()
    f.entry_selector = fis.ReadUShort()
    f.range_shift    = fis.ReadUShort()

    for table_number in 0..f.num_tables-1:
        #Need to use temporary vars here.  C++ evaluates function parameters from
        #right to left and thus breaks the order of input stream.
        let tag      = TTag(fis.ReadULongAsInt())
        let checksum = fis.ReadULong()
        let offset   = fis.ReadULongAsInt()
        let length   = fis.ReadULongAsInt()
        var header   = makeHeader(tag, checksum, offset, length)
        result.add(header)
    
    result.sort(proc(x,y: Header): int = OffsetSortedComparator(x,y) )

proc ReadHeader(f: FontDef, fd: FontData, offset: int): TableHeaderList =
    result = @[]
    f.sfnt_version   = fd.ReadFixed(offset + kSfntVersion)
    f.num_tables     = fd.ReadUShort(offset + kNumTables)
    f.search_range   = fd.ReadUShort(offset + kSearchRange)
    f.entry_selector = fd.ReadUShort(offset + kEntrySelector)
    f.range_shift    = fd.ReadUShort(offset + kRangeShift)

    var table_offset = offset + kTableRecordBegin
    for table_number in 0..f.num_tables-1:
        let tag      = TTag(fd.ReadULongAsInt(table_offset + kTableTag))
        let checksum = fd.ReadULong(table_offset + kTableCheckSum)
        let offset   = fd.ReadULongAsInt(table_offset + kTableOffset)
        let length   = fd.ReadULongAsInt(table_offset + kTableLength)
        var header   = makeHeader(tag, checksum, offset, length)
        result.add(header)
        inc(table_offset, kTableRecordSize)
    
    result.sort(proc(x,y: Header): int = OffsetSortedComparator(x,y) )

proc LoadTable(headers: TableHeaderList, fis: FontInputStream): FontTableMap =
    result = initTable[TTag, FontTable]()
    for header in headers:
        discard fis.Skip(header.offset() - fis.Position())
        var data = makeFontData(header.length())
        #echo TagToString(header.tag()), " avail: ", $fis.Available(), " request: ", $header.length()
        data.CopyFrom(fis, header.length())
        result[header.tag()] = GetTable(header, data)

proc LoadTable(headers: TableHeaderList, fd: FontData): FontTableMap =
    result = initTable[TTag, FontTable]()
    for header in headers:
        var data = makeFontData(header.length())
        discard fd.CopyTo(data, 0, header.offset(), header.length())
        result[header.tag()] = GetTable(header, data)

proc InterRelateTables(f: FontDef) =
    var head = HEADTable(f.GetTable(TAG.head))
    var hhea = HHEATable(f.GetTable(TAG.hhea))
    var maxp = MAXPTable(f.GetTable(TAG.maxp))
    var loca = LOCATable(f.GetTable(TAG.loca))
    var hmtx = HMTXTable(f.GetTable(TAG.hmtx))
    var hdmx = HDMXTable(f.GetTable(TAG.hdmx))
    var glyf = GLYPHTable(f.GetTable(TAG.glyf))
    
    if hmtx != nil:
        if maxp != nil: hmtx.SetNumGlyphs(maxp.NumGlyphs())
        if hhea != nil: hmtx.SetNumberOfHMetrics(hhea.NumberOfHMetrics())

    if loca != nil:
        if maxp != nil: loca.SetNumGlyphs(maxp.NumGlyphs())
        if head != nil: loca.SetFormatVersion(head.GetIndexToLocFormat())
        if glyf != nil: glyf.SetLoca(loca)

    #Note: In C++, hdmx can be nil in a subsetter.
    if maxp != nil and hdmx != nil:
        hdmx.SetNumGlyphs(maxp.NumGlyphs())
 
proc LoadFont(f: FontDef, istream: InputStream) =
    var fis = makeFontInputStream(istream)
    var headers = f.ReadHeader(fis)
    f.tables = LoadTable(headers, fis)
    InterRelateTables(f)
    fis.Close()

proc LoadFont(f: FontDef, fd: FontData, offset_to_offset_table: int) =
    var headers = f.ReadHeader(fd, offset_to_offset_table)
    f.tables = LoadTable(headers, fd)
    InterRelateTables(f)
    
#-------------------------------------------------------------
proc IsCollection(istream: InputStream): bool =
    var tag = newString(4)
    discard istream.Read(tag)
    discard istream.Skip(-4)
    result = TAG.ttcf == GenerateTag(tag)
  
proc IsCollection(fd: FontData): bool =
    var tag = newString(4)
    discard fd.ReadBytes(0, tag, 0, tag.len)
    result = TAG.ttcf == GenerateTag(tag)

proc LoadSingleOTF*(istream: InputStream): FontDef =
    result = makeFont()
    LoadFont(result, istream)
  
proc LoadSingleOTF*(fd: FontData): FontDef =
    result = makeFont()
    LoadFont(result, fd, 0)
    
proc LoadCollection*(fd: FontData): FontArray =
    result = @[]
    
    discard fd.ReadULongAsInt(kTTCTag)
    discard fd.ReadFixed(kVersion)
    let num_fonts = fd.ReadULongAsInt(kNumFonts)
    
    var offset_table_offset = kOffsetTable
    for i in 0..num_fonts-1:
        let offset = fd.ReadULongAsInt(offset_table_offset)
        var font = makeFont()
        LoadFont(font, fd, offset)
        result.add(font)
        offset_table_offset += DataSize.kULONG

proc LoadCollection*(istream: InputStream): FontArray =
    var fd = makeFontData(istream.Available())
    fd.CopyFrom(istream)
    result = LoadCollection(fd)
    
proc LoadFonts*(istream: InputStream): FontArray =
    if IsCollection(istream):
        return LoadCollection(istream)
    
    var font = LoadSingleOTF(istream)
    if font != nil: 
        return @[font]
        
    result = @[]

proc LoadFonts*(b: ByteVector): FontArray =
    var fd = makeFontData(b)
    if IsCollection(fd):
        return LoadCollection(fd)
    
    var font = LoadSingleOTF(fd)
    if font != nil:
        return @[font]
        
    result = @[]

proc LoadTTF*(fileName: string): FontDef =
    var fis = makeFileInputStream(fileName)
    if fis == nil:
        echo "cannot open ", fileName
        return nil
    result = LoadSingleOTF(fis)

proc LoadTTC*(fileName: string, fontIndex: int): FontDef =
    var fis = makeFileInputStream(fileName)
    if fis == nil:
        echo "cannot open ", fileName
        return nil
    let fonts = LoadCollection(fis)
    if fontIndex < 0 or fontIndex >= fonts.len:
        echo "LoadTTC out of bound"
        return nil
    result = fonts[fontIndex]
    
#-------------------------------------------------------
proc SerializeFont*(tables: var seq[FontTable]): FontData =
    keepItIf(tables, it != nil)

    let numTables = tables.len
    var offset = kSfntHeaderSize + kTableRecordSize * numTables
    
    tables.sort(proc(x,y: FontTable): int = cmp( int(x.HeaderTag()), int(y.HeaderTag()) ) )
        
    var headoffset = 0
    for i in 0..tables.len-1:
        if tables[i] == nil: continue
        if tables[i].HeaderTag() == TAG.head:
            HEADTable(tables[i]).SetChecksumAdjustment(0)
            headoffset = offset
            
        discard tables[i].CalculatedChecksum()    
        #if chk != tables[i].HeaderChecksum():
            #echo "checksum error ", TagToString(tables[i].HeaderTag()), " " , $chk, " ", $tables[i].HeaderChecksum()
        tables[i].SetTableOffset(offset)        
        offset += ((tables[i].DataLength() + 3) and not 3) 
    
    var fd = makeFontData(offset)
    #echo "data length ", $fd.Length()
    
    discard fd.WriteFixed(kSfntVersion, Fixed1616Fixed(SFNTVERSION_MAJOR, SFNTVERSION_MINOR))
    discard fd.WriteUShort(kNumTables, numTables)
    
    let log2_of_max_power_of_2 = Log2(numTables)
    let search_range = 2 shl (log2_of_max_power_of_2 - 1 + 4)
    
    discard fd.WriteUShort(kSearchRange, search_range)
    discard fd.WriteUShort(kEntrySelector, log2_of_max_power_of_2)
    discard fd.WriteUShort(kRangeShift, (numTables * kTableRecordSize) - search_range)
    
    var table_offset = kTableRecordBegin
    for i in 0..tables.len-1:
        if tables[i] == nil: continue
        let header = tables[i].GetHeader()
        #echo "table offset ", $table_offset
        discard fd.WriteULong(table_offset + kTableTag, int(header.tag()))
        discard fd.WriteULong(table_offset + kTableCheckSum, header.checksum())
        discard fd.WriteULong(table_offset + kTableOffset, header.offset())
        discard fd.WriteULong(table_offset + kTableLength, header.length())
        table_offset += kTableRecordSize
    
    for i in 0..tables.len-1:
        if tables[i] == nil: continue
        discard tables[i].Serialize(fd, table_offset)
        let table_size = tables[i].DataLength()
        let filler_size = ((table_size + 3) and not 3) - table_size
        table_offset += table_size
        for i in 0..filler_size-1:
            discard fd.WriteByte(table_offset, chr(0))
            inc(table_offset)

    var checksum = checksum(fd, fd.Length())
    discard fd.WriteULong(headoffset + 8, 0xB1B0AFBA - checksum)
    result = fd

proc Subset*(font: FontDef, CH2GID: CH2GIDMAP, newTag: string): FontData =
    var cmap = CMAPTable(font.GetTable(TAG.cmap))
    var maxp = MAXPTable(font.GetTable(TAG.maxp))
    var glyf = GLYPHTable(font.GetTable(TAG.glyf))
    var head = HEADTable(font.GetTable(TAG.head))
    var hhea = HHEATable(font.GetTable(TAG.hhea))
    var hmtx = HMTXTable(font.GetTable(TAG.hmtx))
    var loca = LOCATable(font.GetTable(TAG.loca))
    var name = NAMETable(font.GetTable(TAG.name))
    var post = POSTTable(font.GetTable(TAG.post))
    var os2  = OS2Table(font.GetTable(TAG.OS_2))
    var cvt  = font.GetTable(TAG.cvt)
    var fpgm = font.GetTable(TAG.fpgm)
    var prep = font.GetTable(TAG.prep)
    var gasp = font.GetTable(TAG.gasp)
 
    var isSymbol = false
    if os2 != nil:
        isSymbol = os2.IsSymbolCharSet() and
            cmap.CMAPAvailable(proc(platformID, encodingID, format: int): bool =
                result = (platformID == 3) and (encodingID == 0) )
            
    var GID2GID = initOrderedTable[int, int](math.nextPowerOfTwo(CH2GID.len))
    GID2GID[0] = 0
    for key, val in pairs(CH2GID):
        if not GID2GID.hasKey(val.oldGID):
            GID2GID[val.oldGID] = val.newGID
    
    GID2GID.sort(proc(x,y: tuple[key,val: int] ):int = cmp(x.val, y.val) )

    var newglyf = EncodeGLYPHTable(glyf, GID2GID) #GID2GID maybe larger than before after this line
    var newloca = newglyf.GetLoca()
    head.SetIndexToLocFormat(newLoca.GetFormatVersion())
    hhea.SetNumberOfHMetrics(GID2GID.len)
    maxp.SetNumGlyphs(GID2GID.len)
    var newhmtx = EncodeHMTXTable(hmtx, GID2GID)
    var newcmap = EncodeCMAPTable(CH2GID, isSymbol)
    var newname = EncodeNAMETable(name, newTag)
    var newpost = EncodePOSTTable(post)

    #echo "numGlyphs: ", $GID2GID.len
    #cmap, glyf, head, hhea, hmtx, loca, maxp, name, post, os/2
    var tables = @[newcmap, newglyf, head, hhea, newhmtx, newloca, maxp, newname, os2, newpost, prep, cvt, fpgm, gasp]
    result = SerializeFont(tables)

proc makeDescriptor*(font: FontDef, CH2GID: CH2GIDMAP): FontDescriptor =
    var fd: FontDescriptor
    new(fd)
    
    var name = NAMETable(font.GetTable(TAG.name))
    var post = POSTTable(font.GetTable(TAG.post))
    var os2  = OS2Table(font.GetTable(TAG.OS_2))
    var head = HEADTable(font.GetTable(TAG.head))
    var hhea = HHEATable(font.GetTable(TAG.hhea))
    var hmtx = HMTXTable(font.GetTable(TAG.hmtx))
    var cmap = CMAPTable(font.GetTable(TAG.cmap))
    
    fd.postscriptName = name.GetPostscriptName()
    fd.fontFamily = name.GetFontFamily()
    
    var Ascent = hhea.Ascender()
    var Descent = hhea.Descender()
    var LineGap = hhea.LineGap()
    var isSymbol = false
        
    if os2 != nil and os2.TableVersion() == 1:
        Ascent = os2.STypoAscender()
        Descent = os2.STypoDescender()
        LineGap = os2.STypoLineGap()
        isSymbol = os2.IsSymbolCharSet() and
            cmap.CMAPAvailable(proc(platformID, encodingID, format: int): bool =
                result = (platformID == 3) and (encodingID == 0) )
        
    fd.capHeight = Ascent
    fd.xHeight = 0
    if os2 != nil and os2.TableVersion() == 0:
        fd.capHeight = os2.SCapHeight()
        fd.xHeight = os2.SxHeight()
        
    var usWeightClass = 500
    var familyClass = 0

    if os2 != nil:
        usWeightClass = os2.UsWeightClass()
        familyClass = os2.SFamilyClass() shr 8

    let scaleFactor = 1000 / head.UnitsPerEm()
    fd.BBox[0] = math.round(float(head.XMin()) * scaleFactor)
    fd.BBox[1] = math.round(float(head.YMin()) * scaleFactor)
    fd.BBox[2] = math.round(float(head.XMax()) * scaleFactor)
    fd.BBox[3] = math.round(float(head.YMax()) * scaleFactor)
    
    fd.MissingWidth = math.round(float(hmtx.AdvanceWidth(0)) * scaleFactor)
    fd.StemV = 50 + int(math.pow(float(usWeightClass) / 65.0, 2))
    
    fd.Ascent = math.round(float(Ascent) * scaleFactor)
    fd.Descent = math.round(float(Descent) * scaleFactor)
        
    let isSerif  = familyClass in {1,2,3,4,5,7}
    let isScript = familyClass == 10
    
    if post != nil:
        let raw = post.ItalicAngle()
        var hi = raw shr 16
        var lo = raw and 0xFFFF
        if (hi and 0x8000) != 0: hi = -((hi xor 0xFFFF) + 1) 
        fd.italicAngle = toFloat(hi) + (toFloat(lo) / 65536)
    else:
        fd.italicAngle = 0.0
      
    fd.Flags = 0
    if post.IsFixedPitch() != 0: fd.Flags = fd.Flags or 1  
    if isSerif: fd.Flags = fd.Flags or (1 shl 1)
    if isScript: fd.Flags = fd.Flags or (1 shl 3)
    if fd.italicAngle != 0: fd.Flags = fd.Flags or (1 shl 6)
    
    if isSymbol:
        fd.Flags = fd.Flags or (1 shl 2)
    else:
        fd.Flags = fd.Flags or (1 shl 5) # assume the font is nonsymbolic...

    var i = 0
    for ch in keys(CH2GID):
        if i == 0:
            fd.FirstChar = ch
            fd.LastChar = ch
        fd.FirstChar = min(fd.FirstChar, ch)
        fd.LastChar = max(fd.LastChar, ch)
        inc(i)
        
    result = fd