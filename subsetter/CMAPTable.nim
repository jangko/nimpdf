# Copyright (c) 2015 Andri Lim
#
# Distributed under the MIT license 
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------
import FontIOStreams, FontData, tables

const
    kTableVersion = 0
    kNumberOfEncodingTables = 2
    kHeaderSize = 4
    
    kSubtableEntryStart = 4
    kPlatformID = 0
    kEncodingID = 2
    kSubtableOffset = 4
    kSubtableEntrySize = 8
    
    kFormat = 0
    kLength = 2
    kVersion = 4
    
    kSegCountX2 = 6
    kSearchRange = 8
    kEntrySelector = 10
    kRangeShift = 12
    kSegmentStart = 14

type
    TONGID* = tuple[oldGID, newGID: int]
    CH2GIDMAP* = OrderedTable[int, TONGID]
    RANGES* = OrderedTable[int, seq[int]]
    
    CMAP* = ref object of RootObj
        data: FontData
    
    CMAP0* = ref object of CMAP
    CMAP4* = ref object of CMAP
    
    CMAPTable* = ref object of FontTable
        encodingcmap: CMAP
    
proc Format(t: CMAP): int =
    result = t.data.ReadUShort(kFormat)

proc Length(t: CMAP): int =
    result = t.data.ReadUShort(kLength)

proc Version(t: CMAP): int =
    result = t.data.ReadUShort(kVersion)

method GlyphIndex*(t: CMAP, char_code: int): int = 
    discard

method GlyphIndex*(t: CMAP0, char_code: int): int = 
    if char_code < 0 or char_code > 255: return 0
    result = t.data.ReadUByte(6 + char_code)

proc makeCMAP0(data: FontData): CMAP0 =
    new(result)
    result.data = data
    
proc SegCount(t: CMAP4): int =
    result = int(t.data.ReadUShort(kSegCountX2) div 2)
    
proc EndCode(t: CMAP4, index: int): int =
    result = t.data.ReadUShort(kSegmentStart + index * Datasize.kUSHORT)

proc StartCode(t: CMAP4, index: int): int =
    let segcount = t.SegCount()
    result = t.data.ReadUShort(kSegmentStart + segcount * DataSize.kUSHORT + index * Datasize.kUSHORT + Datasize.kUSHORT)

proc idDelta(t: CMAP4, index: int): int =
    let segcount = t.SegCount() * 2
    result = t.data.ReadUShort(kSegmentStart + segcount * DataSize.kUSHORT + index * Datasize.kUSHORT + Datasize.kUSHORT)

proc idRangeOffsetOffset(segcount, index: int): int =
    result = kSegmentStart + (segcount * 3 + 1) * DataSize.kUSHORT + index * Datasize.kUSHORT

proc idRangeOffset(t: CMAP4, index: int): int =
    let segcount = t.SegCount()
    result = t.data.ReadUShort(idRangeOffsetOffset(segcount, index))

proc GlyphIdArray(t: CMAP4, index: int): int =
    let segcount = t.SegCount() * 4
    result = t.data.ReadUShort(kSegmentStart + segcount * DataSize.kUSHORT + index * Datasize.kUSHORT + Datasize.kUSHORT)

proc GlyphIdArrayLength(t: CMAP4): int =
    let segcount = t.SegCount() * 4
    let offset = kSegmentStart + segcount * DataSize.kUSHORT + Datasize.kUSHORT
    result = int((t.Length() - offset) div 2)
    
#proc GlyphIndex1*(t: CMAP4, char_code: int): int = 
#    let segCount = t.SegCount()
#    if segCount == 0: return 0 #no glyph
#
#    var i = 0
#    while i < segCount:
#        if char_code <= t.EndCode(i): break
#        inc(i)
#    
#    let startCode = t.StartCode(i)
#    let idDelta = t.idDelta(i)
#    let idRangeOffset = t.idRangeOffset(i)
#    
#    if startCode > char_code: return 0 #missing glyph
#    if idRangeOffset == 0: return (char_code + idDelta) and 0xFFFF
#    
#    let idx = int(idRangeOffset div 2) + (char_code - startCode) - (segCount - i)
#    if idx >= t.GlyphIdArrayLength(): return 0
#    
#    let GlyphId = t.GlyphIdArray(idx)
#    if GlyphId == 0: return 0
#    result = (GlyphId + idDelta) and 0xFFFF

method GlyphIndex*(t: CMAP4, char_code: int): int = 
    let segCount = t.SegCount()
    if segCount == 0: return 0 #no glyph

    var i = 0
    while i < segCount:
        if char_code <= t.EndCode(i): break
        inc(i)
    
    let startCode = t.StartCode(i)
    let IdDelta = t.idDelta(i)
    let IdRangeOffsetOffset = idRangeOffsetOffset(segCount, i)
    let IdRangeOffset = t.data.ReadUShort(IdRangeOffsetOffset)
    
    if startCode > char_code: return 0 #missing glyph
    if IdRangeOffset == 0: return (char_code + IdDelta) and 0xFFFF
    
    #(idRangeOffset[i] / 2) + (char_code - StartCode) + &idRangeOffset[i]
    let offset = IdRangeOffset + Datasize.kUSHORT * (char_code - startCode) + IdRangeOffsetOffset
    if offset > (t.Length() - Datasize.kUSHORT): return 0
    
    let GlyphId = t.data.ReadUShort(offset)
    if GlyphId == 0: return 0
    result = (GlyphId + IdDelta) and 0xFFFF

proc makeCMAP4(data: FontData): CMAP4 =
    new(result)
    result.data = data
    
proc TableVersion(t: CMAPTable): int =
    result = t.data.ReadUShort(kTableVersion)

proc NumberOfEncodingTables(t: CMAPTable): int =
    result = t.data.ReadUShort(kNumberOfEncodingTables)

proc PlatformID(t: CMAPTable, index: int): int =
    result = t.data.ReadUShort(kSubtableEntryStart + index * kSubtableEntrySize + kPlatformID)

proc EncodingID(t: CMAPTable, index: int): int =
    result = t.data.ReadUShort(kSubtableEntryStart + index * kSubtableEntrySize + kEncodingID)

proc SubtableOffset(t: CMAPTable, index: int): int =
    result = t.data.ReadULongAsInt(kSubtableEntryStart + index * kSubtableEntrySize + kSubtableOffset)

proc FindEncodingCMap(t: CMAPTable, filter: proc(platformID, encodingID, format: int): bool): CMAP =
    let numberOfEncodingTables = t.NumberOfEncodingTables()
    #echo "number of cmap ", $numberOfEncodingTables
    
    #echo "len ", $t.data.Length()
    for i in 0..numberOfEncodingTables-1:
        let platformID = t.PlatformID(i)
        let encodingID = t.EncodingID(i)
        let offsetx = t.SubtableOffset(i)
        let format = t.data.ReadUShort(offsetx + kFormat)
        let length = t.data.ReadUShort(offsetx + kLength)
        #echo "format ", $format, " offset ", $offsetx, " pid ", $platformID, " encid ", $encodingID, " len : ", $length
        
        if filter(platformID, encodingID, format):
            if format == 4: result = makeCMAP4(t.data.Slice(offsetx, length))
            if format == 0: result = makeCMAP0(t.data.Slice(offsetx, length))
            break

proc CMAPAvailable*(t: CMAPTable, filter: proc(platformID, encodingID, format: int): bool): bool =
    let numberOfEncodingTables = t.NumberOfEncodingTables()
    #echo "number of cmap ", $numberOfEncodingTables
    
    #echo "len ", $t.data.Length()
    for i in 0..numberOfEncodingTables-1:
        let platformID = t.PlatformID(i)
        let encodingID = t.EncodingID(i)
        let offsetx = t.SubtableOffset(i)
        let format = t.data.ReadUShort(offsetx + kFormat)
        let length = t.data.ReadUShort(offsetx + kLength)
        #echo "format ", $format, " offset ", $offsetx, " pid ", $platformID, " encid ", $encodingID, " len : ", $length
        
        if filter(platformID, encodingID, format):
            return true
            
    return false
    
proc makeCMAPTable*(header: Header, data: FontData): CMAPTable =
    new(result)
    initFontTable(result, header, data)
    result.encodingcmap = nil

proc GetEncodingCMAP*(t: CMAPTable): CMAP =
    if t.encodingcmap != nil: return t.encodingcmap
    
    t.encodingcmap = t.FindEncodingCMap(
        proc(platformID, encodingID, format: int): bool =
            result = (platformID == 3) and (encodingID == 1) and (format == 4) )
    if t.encodingcmap != nil: return t.encodingcmap
    
    t.encodingcmap = t.FindEncodingCMap(
        proc(platformID, encodingID, format: int): bool =
            result = (platformID == 0) and (format == 4) )
    if t.encodingcmap != nil: return t.encodingcmap

    t.encodingcmap = t.FindEncodingCMap(
        proc(platformID, encodingID, format: int): bool =
            result = (platformID == 1) and (format == 0) )
    if t.encodingcmap != nil: return t.encodingcmap
    
    result = nil
    
proc EncodeCMAP0(CH2GID: CH2GIDMAP): FontData =
    let size = 6 + 256
    var fd = makeFontData(size)
    discard fd.WriteUShort(kFormat, 0)
    discard fd.WriteUShort(kLength, size)
    discard fd.WriteUShort(kVersion, 0)
    for i in 0..255:
        if CH2GID.hasKey(i): 
            let id = CH2GID[i].newGID
            if id >= 0 and id <= 255: discard fd.WriteByte(6 + i, chr(id))
            else: discard fd.WriteByte(6 + i, chr(0))
        else: discard fd.WriteByte(6 + i, chr(0))
    result = fd

proc makeRanges*(CH2GID: CH2GIDMAP): RANGES =
    var rangeid = 0
    var ranger = initOrderedTable[int, seq[int]]()
    var prevcid = -2
    var prevglidx = -1
    # for each character
    var glidx = 0
    for cid, gid in pairs(CH2GID):
        glidx = gid.newGID
        if (cid == (prevcid + 1) and glidx == (prevglidx + 1)):
            ranger.mget(rangeid).add(glidx)
        else:
            # new range
            rangeid = cid
            ranger[rangeid] = @[]
            ranger.mget(rangeid).add(glidx)
        prevcid = cid
        prevglidx = glidx

    ranger.sort(proc(x,y: tuple[key: int, val: seq[int]] ):int = cmp(x.key,y.key) )
    result = ranger
    
proc EncodeCMAP4(CH2GID: CH2GIDMAP): FontData =
    let ranger = makeRanges(CH2GID)
    
    var segCount = ranger.len + 1
    var endCode, startCode, idDelta, idRangeOffsets: seq[int]
    newSeq(endCode, segCount)
    newSeq(startCode, segCount)
    newSeq(idDelta, segCount)
    newSeq(idRangeOffsets, segCount)
    var glyphIDs: seq[int] = @[]
    
    var i = 0
    for start, subrange in ranger:
        #echo "start: ", $start, " subrange: ", $subrange
        startCode[i] = start
        endCode[i] = start + (len(subrange)-1)
        
        let startGlyph = subrange[0]
        if start - startGlyph >= 0x8000:
            idDelta[i] = 0
            idRangeOffsets[i] = 2 * (glyphIDs.len + segCount - i)
            for id in subrange: glyphIDs.add(id)
        else:
            idDelta[i] = -(start-subrange[0])
            idRangeOffsets[i] = 0
            
        inc(i)
    
    startCode[i] = 0xFFFF
    endCode[i] = 0xFFFF
    idDelta[i] = 1
    idRangeOffsets[i] = 0

    var searchRange = 1
    var entrySelector = 0
    while (searchRange * 2 <= segCount ):
        searchRange = searchRange * 2
        entrySelector = entrySelector + 1
        
    searchRange = searchRange * 2
    var rangeShift = segCount * 2 - searchRange
        
    var size = 16 + (8 * segCount) + glyphIDs.len * 2
    var fd = makeFontData(size)
    
    discard fd.WriteUShort(kFormat, 4)
    discard fd.WriteUShort(kLength, size)
    discard fd.WriteUShort(kVersion, 0)
    discard fd.WriteUShort(kSegCountX2, segCount * 2)
    discard fd.WriteUShort(kSearchRange, searchRange)
    discard fd.WriteUShort(kEntrySelector, entrySelector)
    discard fd.WriteUShort(kRangeShift, rangeShift)
    
    var offset = kSegmentStart
    for i in endCode: 
        discard fd.WriteUShort(offset, i)
        inc(offset, DataSize.kUSHORT)
    
    #reserved pad
    discard fd.WriteUShort(offset, 0)
    inc(offset, DataSize.kUSHORT)
    
    for i in startCode: 
        discard fd.WriteUShort(offset, i)
        inc(offset, DataSize.kUSHORT)
    
    for i in idDelta: 
        discard fd.WriteUShort(offset, i)
        inc(offset, DataSize.kUSHORT)
    
    for i in idRangeOffsets: 
        discard fd.WriteUShort(offset, i)
        inc(offset, DataSize.kUSHORT)
    
    for i in glyphIDs: 
        discard fd.WriteUShort(offset, i)
        inc(offset, DataSize.kUSHORT)
    
    result = fd

proc EncodeCMAPTable*(CH2GID: CH2GIDMAP, isSymbol: bool): CMAPTable =
    var tables = [EncodeCMAP0(CH2GID), EncodeCMAP4(CH2GID)]
    let tableStart = kHeaderSize + kSubtableEntrySize * tables.len
    var encID = 1
    if isSymbol: encID = 0
    
    #echo "isSymbol ", $isSymbol
    
    let platformID = [1, 3]
    let encodingID = [0, encID]

    var size = tableStart
    for t in tables: size += t.Length()
    var fd = makeFontData(size)
    
    discard fd.WriteUShort(kTableVersion, 0)
    discard fd.WriteUShort(kNumberOfEncodingTables, tables.len)
    
    var subTableOffset = tableStart
    var offset = kHeaderSize
    var i = 0
    for t in tables:
        discard fd.WriteUShort(offset + kPlatformID, platformID[i])
        discard fd.WriteUShort(offset + kEncodingID, encodingID[i])
        discard fd.WriteULong(offset + kSubtableOffset, subTableOffset)
        discard t.CopyTo(fd, subTableOffset)
        inc(i)
        inc(subTableOffset, t.Length())
        inc(offset, kSubtableEntrySize)
    
    result = makeCMAPTable(makeHeader(TAG.cmap, checksum(fd, fd.Length()), 0, fd.Length()), fd)