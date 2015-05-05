import FontIOStreams, FontData

const
    kFormatType  = 0
    kItalicAngle = 4
    kUnderlinePosition = 8
    kUnderlineThickness = 10
    kIsFixedPitch = 12
    kMinMemType42 = 16
    kMaxMemType42 = 20
    kMinMemType1  = 24
    kMaxMemType1  = 28
    
type
    POSTTable* = ref object of FontTable

proc FormatType*(t: POSTTable): int = t.data.ReadFixed(kFormatType)
proc ItalicAngle*(t: POSTTable): int = t.data.ReadFixed(kItalicAngle)
proc UnderlinePosition*(t: POSTTable): int = t.data.ReadFWord(kUnderlinePosition)
proc UnderlineThickness*(t: POSTTable): int = t.data.ReadFWord(kUnderlineThickness)
proc IsFixedPitch*(t: POSTTable): int64 = t.data.ReadUlong(kIsFixedPitch)
proc MinMemType42*(t: POSTTable): int64 = t.data.ReadUlong(kMinMemType42)
proc MaxMemType42*(t: POSTTable): int64 = t.data.ReadUlong(kMaxMemType42)
proc MinMemType1*(t: POSTTable): int64 = t.data.ReadUlong(kMinMemType1)
proc MaxMemType1*(t: POSTTable): int64 = t.data.ReadUlong(kMaxMemType1)
    
proc makePOSTTable*(header: Header, data: FontData): POSTTable =
    new(result)
    initFontTable(result, header, data)

proc EncodePOSTTable*(t: POSTTable): POSTTable =
    let size = 4 + 12 + 16
    var fd = makeFontData(size)
    discard fd.WriteFixed(kFormatType, Fixed1616Fixed(3, 0))
    discard t.data.CopyTo(fd, 4, 4, 12)
    for i in 0..15:
        discard fd.WriteByte(i + 16, chr(0))
        
    result = makePOSTTable(makeHeader(TAG.post, checksum(fd, fd.Length()), 0, fd.Length()), fd)