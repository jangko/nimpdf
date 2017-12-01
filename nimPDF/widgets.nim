import objects

const
  FIELD_TYPE_BUTTON = "Btn"
  FIELD_TYPE_TEXT = "Tx"

type
  MapRoot = ref object of RootObj


  ANNOT_FLAGS = enum
    Invisible = 1
    Hidden = 2
    Print = 3
    NoZoom = 4
    NoRotate = 5
    NoView = 6
    ReadOnly = 7
    Locked = 8
    ToggleNoView = 9
    LockedContents = 10

  WidgetKind = enum
    wkButton
    wkTextField
    wkComboBox
    wkListBox
    wkRadio
    wkCheckBox

  BorderStyle = enum
    BS_SOLID
    BS_DASHED
    BS_BEVELED
    BS_INSET
    BS_UNDERLINE

  Border = ref object of MapRoot
    style: BorderStyle
    width: int
    dashPattern: seq[int]

  Widget = ref object of MapRoot
    kind: WidgetKind
    border: Border

 #  dict: dictObj
 #  appearanceStream: proxyObj
 #  appearanceState: string
 #  bordeStyle: dictObj
 #  name: string
 #  value: string
 #  opt: arrayObj
 #  kind: nameObj
 #  defaultAppearance: string
 #  parent: proxyObj
 #  fieldType: nameObj
 #  subType: nameObj
 #  defaultValue: string
 #  rect: arrayObj
 #  page: proxyObj
 #  annotationFlags: ANNOT_FLAGS

  BUTTON_FLAGS = enum
    NoToggleToOff = 15
    Radio = 16
    PushButton = 17
    RadiosInUnison = 26

  TEXT_FIELD_FLAGS = enum
    Multiline = 13
    PassWord = 14
    FileSelect = 21
    DoNotSpellCheck = 23
    DoNoScroll = 24
    Comb = 25
    RichText = 26


 #streamobject
 #  |-----xobject
 #  |-----Pages
 #  |-----appearance stream
 #acroform fonts

method createObject(self: MapRoot): PdfObject {.base.} = discard

proc setWidth*(self: Border, w: int) =
  self.width = w

proc setStyle*(self: Border, s: BorderStyle) =
  self.style = s
  if s == BS_DASHED:
    self.dashPattern = @[1, 0]

proc setDash*(self: Border, dash: openArray[int]) =
  self.style = BS_DASHED
  self.dashPattern = @dash

method createObject(self: Border): PdfObject =
  var dict = newDictObj()
  dict.addNumber("W", self.width)
  case self.style
  of BS_SOLID: dict.addName("S", "S")
  of BS_DASHED:
    dict.addName("S", "D")
    var arr = newArray(self.dashPattern)
    dict.addElement("D", arr)
  of BS_BEVELED: dict.addName("S", "B")
  of BS_INSET: dict.addName("S", "I")
  of BS_UNDERLINE: dict.addName("S", "U")
  result = dict

method createObject(self: Widget): PdfObject =
  discard