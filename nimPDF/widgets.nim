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
    
    
 #Widget = ref object
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
    
 #streamobject
 #  |-----xobject
 #  |-----Pages
 #  |-----appearance stream
 #acroform fonts
 
method 