import FontIOStreams, FontData

const
    kVersion = 0
    kXAvgCharWidth = 2
    kUsWeightClass = 4
    kUsWidthClass = 6
    kFsType = 8
    kYSubscriptXSize = 10
    kYSubscriptYSize = 12
    kYSubscriptXOffset = 14
    kYSubscriptYOffset = 16
    kYSuperscriptXSize = 18
    kYSuperscriptYSize = 20
    kYSuperscriptXOffset = 22
    kYSuperscriptYOffset = 24
    kYStrikeoutSize = 26
    kYStrikeoutPosition = 28
    kSFamilyClass = 30
    kPanose = 32
    kPanoseLength = 10  #Length of panose bytes.
    kUlUnicodeRange1 = 42
    kUlUnicodeRange2 = 46
    kUlUnicodeRange3 = 50
    kUlUnicodeRange4 = 54
    kAchVendId = 58
    kAchVendIdLength = 4  #Length of ach vend id bytes.
    kFsSelection = 62
    kUsFirstCharIndex = 64
    kUsLastCharIndex = 66
    
    kSTypoAscender = 68
    kSTypoDescender = 70
    kSTypoLineGap = 72
    kUsWinAscent = 74
    kUsWinDescent = 76
    kUlCodePageRange1 = 78
    kUlCodePageRange2 = 82
    
    kSxHeight = 68
    kSCapHeight = 70
    kUsDefaultChar = 72
    kUsBreakChar = 74
    kUsMaxContext = 76

type
    OS2Table* = ref object of FontTable

proc TableVersion*(t: OS2Table): int = t.data.ReadUShort(kVersion)
proc XAvgCharWidth*(t: OS2Table): int = t.data.ReadShort(kXAvgCharWidth)
proc UsWeightClass*(t: OS2Table): int = t.data.ReadUShort(kUsWeightClass)
proc UsWidthClass*(t: OS2Table): int = t.data.ReadUShort(kUsWidthClass)
proc FsType*(t: OS2Table): int = t.data.ReadShort(kFsType)
proc YSubscriptXSize*(t: OS2Table): int = t.data.ReadShort(kYSubscriptXSize)
proc YSubscriptYSize*(t: OS2Table): int = t.data.ReadShort(kYSubscriptYSize)
proc YSubscriptXOffset*(t: OS2Table): int = t.data.ReadShort(kYSubscriptXOffset)
proc YSubscriptYOffset*(t: OS2Table): int = t.data.ReadShort(kYSubscriptYOffset)
proc YSuperscriptXSize*(t: OS2Table): int = t.data.ReadShort(kYSuperscriptXSize)
proc YSuperscriptYSize*(t: OS2Table): int = t.data.ReadShort(kYSuperscriptYSize)
proc YSuperscriptXOffset*(t: OS2Table): int = t.data.ReadShort(kYSuperscriptXOffset)
proc YSuperscriptYOffset*(t: OS2Table): int = t.data.ReadShort(kYSuperscriptYOffset)
proc YStrikeoutSize*(t: OS2Table): int = t.data.ReadShort(kYStrikeoutSize)
proc YStrikeoutPosition*(t: OS2Table): int = t.data.ReadShort(kYStrikeoutPosition)
proc SFamilyClass*(t: OS2Table): int = t.data.ReadShort(kSFamilyClass)
proc Panose*(t: OS2Table): ByteVector =
    result = newString(10)
    discard t.data.ReadBytes(kPanose, result, 0, 10)
  
proc UlUnicodeRange1*(t: OS2Table): int64 = t.data.ReadULong(kUlUnicodeRange1)
proc UlUnicodeRange2*(t: OS2Table): int64 = t.data.ReadULong(kUlUnicodeRange2)
proc UlUnicodeRange3*(t: OS2Table): int64 = t.data.ReadULong(kUlUnicodeRange3)
proc UlUnicodeRange4*(t: OS2Table): int64 = t.data.ReadULong(kUlUnicodeRange4)
proc AchVendId*(t: OS2Table): ByteVector =
    result = newString(4)
    discard t.data.ReadBytes(kAchVendId, result, 0, 4)
  
proc FsSelection*(t: OS2Table): int = t.data.ReadUShort(kFsSelection)
proc UsFirstCharIndex*(t: OS2Table): int = t.data.ReadUShort(kUsFirstCharIndex)
proc UsLastCharIndex*(t: OS2Table): int = t.data.ReadUShort(kUsLastCharIndex)

proc STypoAscender*(t: OS2Table): int = 
    result = 0
    if t.TableVersion() == 1: 
        result = t.data.ReadUShort(kSTypoAscender)
proc STypoDescender*(t: OS2Table): int = 
    result = 0
    if t.TableVersion() == 1: 
        result = t.data.ReadUShort(kSTypoDescender)
proc STypoLineGap*(t: OS2Table): int = 
    result = 0
    if t.TableVersion() == 1: 
        result = t.data.ReadUShort(kSTypoLineGap)
proc UsWinAscent*(t: OS2Table): int = 
    result = 0
    if t.TableVersion() == 1: 
        result = t.data.ReadUShort(kUsWinAscent)
proc UsWinDescent*(t: OS2Table): int = 
    result = 0
    if t.TableVersion() == 1: 
        result = t.data.ReadUShort(kUsWinDescent)

proc UlCodePageRange1*(t: OS2Table): int64 = 
    result = 0
    if t.TableVersion() == 1:
        result = t.data.ReadULong(kUlCodePageRange1)
        
proc UlCodePageRange2*(t: OS2Table): int64 = 
    result = 0
    if t.TableVersion() == 1: 
        result = t.data.ReadULong(kUlCodePageRange2)

proc IsSymbolCharSet*(t: OS2Table): bool =
    result = (t.UlCodePageRange1() and 0x80000000) != 0
    
proc SxHeight*(t: OS2Table): int = 
    result = 0
    if t.TableVersion() == 0: result = t.data.ReadShort(kSxHeight)
proc SCapHeight*(t: OS2Table): int = 
    result = 0
    if t.TableVersion() == 0: result = t.data.ReadShort(kSCapHeight)
proc UsDefaultChar*(t: OS2Table): int = 
    result = 0
    if t.TableVersion() == 0: result = t.data.ReadUShort(kUsDefaultChar)
proc UsBreakChar*(t: OS2Table): int = 
    result = 0
    if t.TableVersion() == 0: result = t.data.ReadUShort(kUsBreakChar)
proc UsMaxContext*(t: OS2Table): int = 
    result = 0
    if t.TableVersion() == 0: result = t.data.ReadUShort(kUsMaxContext)

proc makeOS2Table*(header: Header, data: FontData): OS2Table =
    new(result)
    initFontTable(result, header, data)

#------------------------------------
proc SetTableVersion*(t: OS2Table, version: int) = discard t.data.WriteUShort(kVersion, version)
proc SetXAvgCharWidth*(t: OS2Table, width: int) = discard t.data.WriteShort(kXAvgCharWidth, width)
proc SetUsWeightClass*(t: OS2Table, weight: int) = discard t.data.WriteUShort(kUsWeightClass, weight)
proc SetUsWidthClass*(t: OS2Table, width: int) = discard t.data.WriteUShort(kUsWidthClass, width)
proc SetFsType*(t: OS2Table, fs_type: int) = discard t.data.WriteShort(kFsType, fs_type)
proc SetYSubscriptXSize*(t: OS2Table, size: int) = discard t.data.WriteShort(kYSubscriptXSize, size)
proc SetYSubscriptYSize*(t: OS2Table, size: int) = discard t.data.WriteShort(kYSubscriptYSize, size)
proc SetYSubscriptXOffset*(t: OS2Table, offset: int) = discard t.data.WriteShort(kYSubscriptXOffset, offset)
proc SetYSubscriptYOffset*(t: OS2Table, offset: int) = discard t.data.WriteShort(kYSubscriptYOffset, offset)
proc SetYSuperscriptXSize*(t: OS2Table, size: int) = discard t.data.WriteShort(kYSuperscriptXSize, size)
proc SetYSuperscriptYSize*(t: OS2Table, size: int) = discard t.data.WriteShort(kYSuperscriptYSize, size)
proc SetYSuperscriptXOffset*(t: OS2Table, offset: int) = discard t.data.WriteShort(kYSuperscriptXOffset, offset)
proc SetYSuperscriptYOffset*(t: OS2Table, offset: int) = discard t.data.WriteShort(kYSuperscriptYOffset, offset)
proc SetYStrikeoutSize*(t: OS2Table, size: int) = discard t.data.WriteShort(kYStrikeoutSize, size)
proc SetYStrikeoutPosition*(t: OS2Table, position: int) = discard t.data.WriteShort(kYStrikeoutPosition, position)
proc SetSFamilyClass*(t: OS2Table, family: int) = discard t.data.WriteShort(kSFamilyClass, family)
proc SetPanose*(t: OS2Table, panose: ByteVector) =
    if panose.len != kPanoseLength:
        raise newAssertionError("Panose bytes must be exactly 10 in length")
    discard t.data.WriteBytes(kPanose, panose)
  
proc SetUlUnicodeRange1*(t: OS2Table, range: int64) = discard t.data.WriteULong(kUlUnicodeRange1, range)
proc SetUlUnicodeRange2*(t: OS2Table, range: int64) = discard t.data.WriteULong(kUlUnicodeRange2, range)
proc SetUlUnicodeRange3*(t: OS2Table, range: int64) = discard t.data.WriteULong(kUlUnicodeRange3, range)
proc SetUlUnicodeRange4*(t: OS2Table, range: int64) = discard t.data.WriteULong(kUlUnicodeRange4, range)
proc SetAchVendId*(t: OS2Table, b: ByteVector) = discard t.data.WriteBytesPad(kAchVendId, b, 0, min(kAchVendIdLength, b.len), ' ')
proc SetFsSelection*(t: OS2Table, fs_selection: int) = discard t.data.WriteUShort(kFsSelection, fs_selection)
proc SetUsFirstCharIndex*(t: OS2Table, first_index: int) = discard t.data.WriteUShort(kUsFirstCharIndex, first_index)
proc SetUsLastCharIndex*(t: OS2Table, last_index: int) = discard t.data.WriteUShort(kUsLastCharIndex, last_index)
proc SetSTypoAscender*(t: OS2Table, ascender: int) = discard t.data.WriteUShort(kSTypoAscender, ascender)
proc SetSTypoDescender*(t: OS2Table, descender: int) = discard t.data.WriteUShort(kSTypoDescender, descender)
proc SetSTypoLineGap*(t: OS2Table, line_gap: int) = discard t.data.WriteUShort(kSTypoLineGap, line_gap)
proc SetUsWinAscent*(t: OS2Table, ascent: int) = discard t.data.WriteUShort(kUsWinAscent, ascent)
proc SetUsWinDescent*(t: OS2Table, descent: int) = discard t.data.WriteUShort(kUsWinDescent, descent)
proc SetUlCodePageRange1*(t: OS2Table, range: int64) = discard t.data.WriteULong(kUlCodePageRange1, range)
proc SetUlCodePageRange2*(t: OS2Table, range: int64) = discard t.data.WriteULong(kUlCodePageRange2, range)
proc SetSxHeight*(t: OS2Table, height: int) = discard t.data.WriteShort(kSxHeight, height)
proc SetSCapHeight*(t: OS2Table, height: int) = discard t.data.WriteShort(kSCapHeight, height)
proc SetUsDefaultChar*(t: OS2Table, default_char: int) = discard t.data.WriteUShort(kUsDefaultChar, default_char)
proc SetUsBreakChar*(t: OS2Table, break_char: int) = discard t.data.WriteUShort(kUsBreakChar, break_char)
proc SetUsMaxContext*(t: OS2Table, max_context: int) = discard t.data.WriteUShort(kUsMaxContext, max_context)
