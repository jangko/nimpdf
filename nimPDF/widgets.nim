import objects, fontmanager, gstate, page, tables

const
  FIELD_TYPE_BUTTON = "Btn"
  FIELD_TYPE_TEXT = "Tx"
  FIELD_TYPE_COMBO = "Ch"

type
  AnnotFlags = enum
    afInvisible = 1
    afHidden = 2
    afPrint = 3
    afNoZoom = 4
    afNoRotate = 5
    afNoView = 6
    afReadOnly = 7
    afLocked = 8
    afToggleNoView = 9
    afLockedContents = 10

  WidgetKind = enum
    wkTextField
    wkCheckBox
    wkRadioButton
    wkComboBox
    wkListBox
    wkPushButton

  BorderStyle* = enum
    bsSolid
    bsDashed
    bsBeveled
    bsInset
    bsUnderline

  Visibility* = enum
    Visible
    Hidden
    VisibleNotPrintable
    HiddenButPrintable

  ButtonFlags* = enum
    bfNoToggleToOff = 15
    bfRadio = 16
    bfPushButton = 17
    bfRadiosInUnison = 26

  TextFieldFlags* = enum
    tfMultiline = 13
    tfPassWord = 14
    tfFileSelect = 21
    tfDoNotSpellCheck = 23
    tfDoNoScroll = 24
    tfComb = 25
    tfRichText = 26

  TextFieldAlignment* = enum
    tfaLeft
    tfaCenter
    tfaRight

  ComboBoxFlags = enum
    cfCombo = 18
    cfEdit = 19
    cfSort = 20
    cfMultiSelect = 22
    cfDoNotSpellCheck = 23
    cfCommitOnSelChange = 27

  FormActionTrigger* = enum
    MouseUp
    MouseDown
    MouseEnter
    MouseExit
    GetFocus
    LostFocus

  FormSubmitFormat* = enum
    EmailFormData
    PDF_Format
    HTML_Format
    XFDF_Format

  NamedAction* = enum
    naFirstPage
    naNextPage
    naPrevPage
    naLastPage
    naPrintDialog

  SepStyle* = enum
    ssCommaDot   # 1,234.56
    ssDotOnly    # 1234.56
    ssDotComma   # 1.234,56
    ssCommaOnly  # 1234,56

  NegStyle* = enum
    nsDash       # '-'
    nsRedText
    nsParenBlack
    nsParenRed

  PushButtonFlags* = enum
    pbfCaptionOnly
    pbfIconOnly
    pbfCaptionBelowIcon
    pbfCaptionAboveIcon
    pbfCaptionRightToTheIcon
    pbfCaptionLeftToTheIcon
    pbfCaptionOverlaidIcon

  ColorType = enum
    ColorRGB
    ColorCMYK

  FormActionKind = enum
    fakOpenWebLink
    fakResetForm
    fakSubmitForm
    fakEmailEntirePDF
    fakRunJS
    fakNamedAction
    fakGotoLocalPage
    fakGotoAnotherPDF
    fakLaunchApp

  FormAction = ref object
    trigger: FormActionTrigger
    case kind: FormActionKind
    of fakOpenWebLink:
      url: string
    of fakResetForm:
      discard
    of fakSubmitForm:
      format: FormSubmitFormat
      uri: string
    of fakEmailEntirePDF:
      to, cc, bcc, title, body: string
    of fakRunJS:
      script: string
    of fakNamedAction:
      namedAction: NamedAction
    of fakGotoLocalPage:
      pageNo: int
      x,y,zoom: float64
    of fakGotoAnotherPDF:
      destinationPage: int
      path: string
    of fakLaunchApp:
      app, params, operation, defaultDir: string

  MapRoot = ref object of RootObj

  Border = ref object of MapRoot
    style: BorderStyle
    width: int
    dashPattern: seq[int]
    colorRGB: RGBColor
    colorCMYK: CMYKColor
    colorType: ColorType

  SpecialFormat = enum
    sfZipCode
    sfZipCode4
    sfPhoneNumber
    sfSSN
    sfMask

  FormatKind = enum
    FormatNone
    FormatNumber
    FormatCurrency
    FormatPercent
    FormatDate
    FormatTime
    FormatSpecial
    FormatCustom

  FormatObject = ref object
    case kind: FormatKind
    of FormatNone: discard
    of FormatNumber, FormatPercent:
      decimalNumber: int
      sepStyle: SepStyle
      negStyle: NegStyle
    of FormatCurrency:
      strCurrency: string
      currencyPrepend: bool
    of FormatDate, FormatTime:
      strFmt: string
    of FormatSpecial:
      style: SpecialFormat
      mask: string
    of FormatCustom:
      JSfmt, keyStroke: string

  Widget = ref object of MapRoot
    kind: WidgetKind
    border: Border
    rect: Rectangle
    toolTip: string
    visibility: Visibility
    rotation: float64
    readOnly: bool
    required: bool
    fontFamily: string
    fontStyle: FontStyles
    fontSize: float64
    fontEncoding: EncodingType
    fontColorRGB: RGBColor
    fontColorCMYK: CMYKColor
    fontColorType: ColorType
    fillColorRGB: RGBColor
    fillColorCMYK: CMYKColor
    fillColorType: ColorType
    actions: seq[FormAction]
    validateScript: string
    calculateScript: string
    format: FormatObject

  TextField = ref object of Widget
    align: TextFieldAlignment
    maxChars: int
    defaultValue: string
    flags: set[TextFieldFlags]

  CheckBox = ref object of Widget
    shape: string
    checkedByDefault: bool

  RadioButton = ref object of Widget
    shape: string
    checkedByDefault: bool
    allowUnchecked: bool

  ComboBox = ref object of Widget
    keyVal: Table[string, string]
    editable: bool

  ListBox = ref object of Widget
    keyVal: Table[string, string]
    multipleSelect: bool

  PushButton = ref object of Widget
    flags: set[PushButtonFlags]
    caption: string

method createObject(self: MapRoot): PdfObject {.base.} = discard

proc newBorder(): Border =
  new(result)
  result.style = bsSolid
  result.width = 1
  result.dashPattern = nil
  result.colorRGB = initRGB(0,0,0)
  result.colorType = ColorRGB

proc setWidth(self: Border, w: int) =
  self.width = w

proc setStyle(self: Border, s: BorderStyle) =
  self.style = s
  if s == bsDashed:
    self.dashPattern = @[1, 0]

proc setDash(self: Border, dash: openArray[int]) =
  self.style = bsDashed
  self.dashPattern = @dash

proc setColor(self: Border, col: RGBColor) =
  self.colorType = ColorRGB
  self.colorRGB = col

proc setColor(self: Border, col: CMYKColor) =
  self.colorType = ColorCMYK
  self.colorCMYK = col

method createObject(self: Border): PdfObject =
  var dict = newDictObj()
  dict.addNumber("W", self.width)
  case self.style
  of bsSolid: dict.addName("S", "S")
  of bsDashed:
    dict.addName("S", "D")
    var arr = newArray(self.dashPattern)
    dict.addElement("D", arr)
  of bsBeveled: dict.addName("S", "B")
  of bsInset: dict.addName("S", "I")
  of bsUnderline: dict.addName("S", "U")
  result = dict

method createObject(self: Widget): PdfObject =
  discard

proc init(self: Widget) =
  self.toolTip = ""
  self.visibility = Visible
  self.rotation = 0.0
  self.readOnly = false
  self.required = true
  self.fontFamily = "Helvetica"
  self.fontStyle = {FS_REGULAR}
  self.fontSize = 10.0
  self.fontEncoding = ENC_STANDARD
  self.fontColorType = ColorRGB
  self.fontColorRGB = initRGB(0, 0, 0)
  self.fillColorType = ColorRGB
  self.fillColorRGB = initRGB(0, 0, 0)
  self.actions = nil
  self.validateScript = nil
  self.calculateScript = nil
  self.format = nil

proc setToolTip*(self: Widget, toolTip: string) =
  self.toolTip = toolTip

proc setVisibility*(self: Widget, val: Visibility) =
  self.visibility = val

proc setRotation*(self: Widget, angle: float64) =
  self.rotation = angle

proc setReadOnly*(self: Widget, readOnly: bool) =
  self.readOnly = readOnly

proc setRequired*(self: Widget, required: bool) =
  self.required = required

proc setFont*(self: Widget, family: string) =
  self.fontFamily = family

proc setFontStyle*(self: Widget, style: FontStyles) =
  self.fontStyle = style

proc setFontSize*(self: Widget, size: float64) =
  self.fontSize = size

proc setFontEncoding(self: Widget, enc: EncodingType) =
  self.fontEncoding = enc

proc setFontColor*(self: Widget, r,g,b: float64) =
  self.fontColorType = ColorRGB
  self.fontColorRGB = initRGB(r,g,b)

proc setFontColor*(self: Widget, c,m,y,k: float64) =
  self.fontColorType = ColorCMYK
  self.fontColorCMYK = initCMYK(c,m,y,k)

proc setFontColor*(self: Widget, col: RGBColor) =
  self.fontColorType = ColorRGB
  self.fontColorRGB = col

proc setFontColor*(self: Widget, col: CMYKColor) =
  self.fontColorType = ColorCMYK
  self.fontColorCMYK = col

proc setFillColor*(self: Widget, r,g,b: float64) =
  self.fillColorType = ColorRGB
  self.fillColorRGB = initRGB(r,g,b)

proc setFillColor*(self: Widget, c,m,y,k: float64) =
  self.fillColorType = ColorCMYK
  self.fillColorCMYK = initCMYK(c,m,y,k)

proc setFillColor*(self: Widget, col: RGBColor) =
  self.fillColorType = ColorRGB
  self.fillColorRGB = col

proc setFillColor*(self: Widget, col: CMYKColor) =
  self.fillColorType = ColorCMYK
  self.fillColorCMYK = col

proc setBorderColor*(self: Widget, r,g,b: float64) =
  if self.border.isNil: self.border = newBorder()
  self.border.setColor(initRGB(r,g,b))

proc setBorderColor*(self: Widget, c,m,y,k: float64) =
  if self.border.isNil: self.border = newBorder()
  self.border.setColor(initCMYK(c,m,y,k))

proc setBorderColor*(self: Widget, col: RGBColor) =
  if self.border.isNil: self.border = newBorder()
  self.border.setColor(col)

proc setBorderColor*(self: Widget, col: CMYKColor) =
  if self.border.isNil: self.border = newBorder()
  self.border.setColor(col)

proc setBorderWidth*(self: Widget, w: int) =
  if self.border.isNil: self.border = newBorder()
  self.border.setWidth(w)

proc setBorderStyle*(self: Widget, style: BorderStyle) =
  if self.border.isNil: self.border = newBorder()
  self.border.setStyle(style)

proc setBorderDash*(self: Widget, dash: openArray[int]) =
  if self.border.isNil: self.border = newBorder()
  self.border.setDash(dash)

proc addActionOpenWebLink*(self: Widget, trigger: FormActionTrigger, url: string) =
  if self.actions.isNil: self.actions = @[]
  var action = new(FormAction)
  action.trigger = trigger
  action.kind = fakOpenWebLink
  action.url = url
  self.actions.add action

proc addActionResetForm*(self: Widget, trigger: FormActionTrigger) =
  if self.actions.isNil: self.actions = @[]
  var action = new(FormAction)
  action.trigger = trigger
  action.kind = fakResetForm
  self.actions.add action

proc addActionSubmitForm*(self: Widget, trigger: FormActionTrigger, format: FormSubmitFormat, uri: string) =
  if self.actions.isNil: self.actions = @[]
  var action = new(FormAction)
  action.trigger = trigger
  action.kind = fakSubmitForm
  action.uri = uri
  self.actions.add action

proc addActionEmailEntirePDF*(self: Widget, trigger: FormActionTrigger; to, cc, bcc, title, body: string) =
  if self.actions.isNil: self.actions = @[]
  var action = new(FormAction)
  action.trigger = trigger
  action.kind = fakEmailEntirePDF
  action.to = to
  action.cc = cc
  action.bcc = bcc
  action.title = title
  action.body = body
  self.actions.add action

proc addActionRunJS*(self: Widget, trigger: FormActionTrigger, script: string) =
  if self.actions.isNil: self.actions = @[]
  var action = new(FormAction)
  action.trigger = trigger
  action.kind = fakRunJS
  action.script = script
  self.actions.add action

proc addActionNamed*(self: Widget, trigger: FormActionTrigger, name: NamedAction) =
  if self.actions.isNil: self.actions = @[]
  var action = new(FormAction)
  action.trigger = trigger
  action.kind = fakNamedAction
  action.namedAction = name
  self.actions.add action

proc addActionGotoLocalPage*(self: Widget, trigger: FormActionTrigger, pageNo: int, x, y, zoom: float64) =
  if self.actions.isNil: self.actions = @[]
  var action = new(FormAction)
  action.trigger = trigger
  action.kind = fakGotoLocalPage
  action.pageNo = pageNo
  action.x = x
  action.y = y
  action.zoom = zoom
  self.actions.add action

proc addActionGotoAnotherPDF*(self: Widget, trigger: FormActionTrigger, pageNo: int, path: string) =
  if self.actions.isNil: self.actions = @[]
  var action = new(FormAction)
  action.trigger = trigger
  action.kind = fakGotoAnotherPDF
  action.destinationPage = pageNo
  action.path = path
  self.actions.add action

proc addActionLaunchApp*(self: Widget, trigger: FormActionTrigger; app, params, operation, defaultDir: string) =
  if self.actions.isNil: self.actions = @[]
  var action = new(FormAction)
  action.trigger = trigger
  action.kind = fakLaunchApp
  action.app = app
  action.params = params
  action.operation = operation
  action.defaultDir = defaultDir
  self.actions.add action

proc formatNumber*(self: Widget, decimalNumber: int, sepStyle: SepStyle, negStyle: NegStyle) =
  var fmt = new(FormatObject)
  fmt.kind = FormatNumber
  fmt.decimalNumber = decimalNumber
  fmt.sepStyle = sepStyle
  fmt.negStyle = negStyle
  self.format = fmt

proc formatCurrency*(self: Widget, strCurrency: string, currencyPrepend: bool) =
  var fmt = new(FormatObject)
  fmt.kind = FormatCurrency
  fmt.strCurrency = strCurrency
  fmt.currencyPrepend = currencyPrepend
  self.format = fmt

proc formatPercent*(self: Widget, decimalNumber: int, sepStyle: SepStyle) =
  var fmt = new(FormatObject)
  fmt.kind = FormatPercent
  fmt.decimalNumber = decimalNumber
  fmt.sepStyle = sepStyle
  self.format = fmt

#[
m/d
m/d/yy
m/d/yyyy
mm/dd/yy
mm/dd/yyyy
mm/yy
mm/yyyy
d-mmm
d-mmm-yy
d-mmm-yyyy
dd-mmm-yy
dd-mmm-yyy
yy-mm-dd
yyyy-mm-dd
mmm-yy
mmm-yyyy
mmmm-yy
mmmm-yyyy
mmm d, yyyy
mmmm d, yyyy
m/d/yy h:MM tt
m/d/yyyy h:MM tt
m/d/yy HH:MM
m/d/yyyy HH MM
]#

proc formatDate*(self: Widget, strFmt: string) =
  var fmt = new(FormatObject)
  fmt.kind = FormatDate
  fmt.strFmt = strFmt
  self.format = fmt

#[
HH:MM
h:MM tt
HH:MM:ss
h:MM:ss tt
]#

proc formatTime*(self: Widget, strFmt: string) =
  var fmt = new(FormatObject)
  fmt.kind = FormatTime
  fmt.strFmt = strFmt
  self.format = fmt

proc formatSpecial*(self: Widget, style: SpecialFormat, mask: string = nil) =
  var fmt = new(FormatObject)
  fmt.kind = FormatSpecial
  fmt.style = style
  fmt.mask = mask
  self.format = fmt

proc formatCustom*(self: Widget, JSfmt, keyStroke: string) =
  var fmt = new(FormatObject)
  fmt.kind = FormatCustom
  fmt.JSfmt = JSfmt
  fmt.keyStroke = keyStroke
  self.format = fmt

#[
// 0 <= N <= 100
AFRange_Validate(true, 0, true, 100);


// Keep the Text2 field grayed out and read only
// until an amount greater than 100 is entered in the ActiveValue field
var f = this.getField("Text2");
f.readonly = (event.value < 100);
f.textColor = (event.value < 100) ? color.gray : color.black;

//N<=100
if(event.value >100)
{
   app.alert('N<=100');
   event.value = 100;
}
]#

proc setValidateScript*(self: Widget, script: string) =
  self.validateScript = script

#[
//Please add and update the field names
AFSimple_Calculate("AVG", new Array (  "Text1",  "Text2" ));

//Please add and update the field names
AFSimple_Calculate("SUM", new Array (  "Text1",  "Text2" ));

//Please add and update the field names
AFSimple_Calculate("PRD", new Array (  "Text1",  "Text2" ));

//Please add and update the field names
AFSimple_Calculate("MIN", new Array (  "Text1",  "Text2" ));

//Please add and update the field names
AFSimple_Calculate("MAX", new Array (  "Text1",  "Text2" ));

//Please add and update the field names
var a = this.getField( "Text1" ).value;
var b = this.getField( "Text2" ).value;
this.getField( "Text3" ).value = 10 * a - b /10;
]#

proc setCalculateScript*(self: Widget, script: string) =
  self.calculateScript = script

#----------------------TEXT FIELD
proc newTextField*(x,y,w,h: float64): TextField =
  new(result)
  result.init()
  result.rect = initRect(x,y,w,h)
  result.kind = wkTextField
  result.align = tfaLeft
  result.maxChars = 0
  result.defaultValue = ""
  result.flags = {}

proc setAlignment*(self: TextField, align: TextFieldAlignment) =
  self.align = align

proc setMaxChars*(self: TextField, maxChars: int) =
  self.maxChars = maxChars

proc setDefaultValue*(self: TextField, val: string) =
  self.defaultValue = val

proc setFlag*(self: TextField, flag: TextFieldFlags) =
  self.flags.incl flag

proc setFlags*(self: TextField, flags: set[TextFieldFlags]) =
  self.flags.incl flags

proc removeFlag*(self: TextField, flag: TextFieldFlags) =
  self.flags.excl flag

proc removeFlags*(self: TextField, flags: set[TextFieldFlags]) =
  self.flags.excl flags

#----------------------CHECK BOX
proc newCheckBox*(x,y,w,h: float64): CheckBox =
  new(result)
  result.init()
  result.rect = initRect(x,y,w,h)
  result.kind = wkCheckBox
  result.shape = "\x35"
  result.checkedByDefault = false

proc setShape*(self: CheckBox, val: string) =
  self.shape = val

proc setCheckedByDefault*(self: CheckBox, val: bool) =
  self.checkedByDefault = val

#----------------------RADIO BUTTON
proc newRadioButton*(x,y,w,h: float64): RadioButton =
  new(result)
  result.init()
  result.rect = initRect(x,y,w,h)
  result.kind = wkRadioButton
  result.shape = "\6C"
  result.checkedByDefault = false
  result.allowUnchecked = false

proc setShape*(self: RadioButton, val: string) =
  self.shape = val

proc setCheckedByDefault*(self: RadioButton, val: bool) =
  self.checkedByDefault = val

proc setAllowUnchecked*(self: RadioButton, val: bool) =
  self.allowUnchecked = val

#---------------------COMBO BOX
proc newComboBox*(x,y,w,h: float64): ComboBox =
  new(result)
  result.init()
  result.rect = initRect(x,y,w,h)
  result.kind = wkComboBox
  result.editable = false
  result.keyVal = initTable[string, string]()

proc addKeyVal*(self: ComboBox, key, val: string) =
  self.keyVal[key] = val

proc setEditable*(self: ComboBox, val: bool) =
  self.editable = val

#---------------------LIST BOX
proc newListBox*(x,y,w,h: float64): ListBox =
  new(result)
  result.init()
  result.rect = initRect(x,y,w,h)
  result.kind = wkListBox
  result.multipleSelect = false
  result.keyVal = initTable[string, string]()

proc addKeyVal*(self: ListBox, key, val: string) =
  self.keyVal[key] = val

proc setMultipleSelect*(self: ListBox, val: bool) =
  self.multipleSelect = val

#---------------------PUSH BUTTON
proc newPushButton*(x,y,w,h: float64): PushButton =
  new(result)
  result.init()
  result.rect = initRect(x,y,w,h)
  result.kind = wkPushButton
  result.caption = ""
  result.flags = {}

proc setCaption*(self: PushButton, val: string) =
  self.caption = val

proc setFlag*(self: PushButton, flag: PushButtonFlags) =
  self.flags.incl flag

proc setFlags*(self: PushButton, flags: set[PushButtonFlags]) =
  self.flags.incl flags

proc removeFlag*(self: PushButton, flag: PushButtonFlags) =
  self.flags.excl flag

proc removeFlags*(self: PushButton, flags: set[PushButtonFlags]) =
  self.flags.excl flags
