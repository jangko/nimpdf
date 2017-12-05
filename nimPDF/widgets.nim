import objects, fontmanager, gstate

const
  FIELD_TYPE_BUTTON = "Btn"
  FIELD_TYPE_TEXT = "Tx"
  FIELD_TYPE_COMBO = "Ch"

type
  MapRoot = ref object of RootObj

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
    wkButton
    wkTextField
    wkComboBox
    wkListBox
    wkRadio
    wkCheckBox

  BorderStyle = enum
    bsSolid
    bsDashed
    bsBeveled
    bsInset
    bsUnderline

  Border = ref object of MapRoot
    style: BorderStyle
    width: int
    dashPattern: seq[int]

  Visibility = enum
    Visible
    Hidden
    VisibleNotPrintable
    HiddenButPrintable

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

  TextField = ref object of Widget
  CheckBox = ref object of Widget
  RadioButton = ref object of Widget
  ComboBox = ref object of Widget
  ListBox = ref object of Widget
  PushButton = ref object of Widget

  ButtonFlags = enum
    bfNoToggleToOff = 15
    bfRadio = 16
    bfPushButton = 17
    bfRadiosInUnison = 26

  TextFieldFlags = enum
    tfMultiline = 13
    tfPassWord = 14
    tfFileSelect = 21
    tfDoNotSpellCheck = 23
    tfDoNoScroll = 24
    tfComb = 25
    tfRichText = 26

  ComboBoxFlags = enum
    cfCombo = 18
    cfEdit = 19
    cfSort = 20
    cfMultiSelect = 22
    cfDoNotSpellCheck = 23
    cfCommitOnSelChange = 27

method createObject(self: MapRoot): PdfObject {.base.} = discard

proc setWidth*(self: Border, w: int) =
  self.width = w

proc setStyle*(self: Border, s: BorderStyle) =
  self.style = s
  if s == bsDashed:
    self.dashPattern = @[1, 0]

proc setDash*(self: Border, dash: openArray[int]) =
  self.style = bsDashed
  self.dashPattern = @dash

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


proc setToolTip*(self: Widget, toolTip: string) =
  discard

proc setVisibility*(self: Widget, val: Visibility) =
  discard

proc setRotation*(self: Widget, angle: float64) =
  discard

proc setReadOnly*(self: Widget, readOnly: bool) =
  discard

proc setRequired*(self: Widget, required: bool) =
  discard

proc setFont*(self: Widget, family: string, style: FontStyles, size: float64, enc: EncodingType = ENC_STANDARD) =
  discard

proc setFontColor*(self: Widget, r,g,b: float64) =
  discard

proc setFontColor*(self: Widget, c,m,y,k: float64) =
  discard

proc setFontColor*(self: Widget, col: RGBColor) =
  discard

proc setFontColor*(self: Widget, col: CMYKColor) =
  discard

proc setFillColor*(self: Widget, r,g,b: float64) =
  discard

proc setFillColor*(self: Widget, c,m,y,k: float64) =
  discard

proc setFillColor*(self: Widget, col: RGBColor) =
  discard

proc setFillColor*(self: Widget, col: CMYKColor) =
  discard

proc setBorderColor*(self: Widget, r,g,b: float64) =
  discard

proc setBorderColor*(self: Widget, c,m,y,k: float64) =
  discard

proc setBorderColor*(self: Widget, col: RGBColor) =
  discard

proc setBorderColor*(self: Widget, col: CMYKColor) =
  discard

proc setBorderWidth*(self: Widget, w: float64) =
  discard

proc setBorderStyle*(self: Widget, style: BorderStyle) =
  discard

proc setBorderDash*(self: Widget, dash: openArray[int]) =
  discard

type
  FormActionTrigger = enum
    MouseUp
    MouseDown
    MouseEnter
    MouseExit
    GetFocus
    LostFocus

  FormSubmitFormat = enum
    EmailFormData
    PDF_Format
    HTML_Format
    XFDF_Format

  NamedAction = enum
    naFirstPage
    naNextPage
    naPrevPage
    naLastPage
    naPrintDialog

proc addActionOpenWebLink*(self: Widget, trigger: FormActionTrigger, url: string) =
  discard

proc addActionResetForm*(self: Widget, trigger: FormActionTrigger) =
  discard

proc addActionSubmitForm*(self: Widget, trigger: FormActionTrigger, format: FormSubmitFormat, url: string) =
  discard

proc addActionEmailEntirePDF*(self: Widget, trigger: FormActionTrigger; to, cc, bcc, title, body: string) =
  discard

proc addActionRunJS*(self: Widget, trigger: FormActionTrigger, script: string) =
  discard

proc addActionNamed*(self: Widget, trigger: FormActionTrigger, name: NamedAction) =
  discard

proc addActionGotoLocalPage*(self: Widget, trigger: FormActionTrigger, pageNo: int, x, y, zoom: float64) =
  discard

proc addActionGotoAnotherPDF*(self: Widget, trigger: FormActionTrigger, pageNo: int, path: string) =
  discard

proc addActionLaunchApp*(self: Widget, trigger: FormActionTrigger; app, params, operation, defaultDir: string) =
  discard

type
  SepStyle = enum
    ssCommaDot   # 1,234.56
    ssDotOnly    # 1234.56
    ssDotComma   # 1.234,56
    ssCommaOnly  # 1234,56

  NegStyle = enum
    nsDash       # '-'
    nsRedText
    nsParenBlack
    nsParenRed

proc formatNumber*(self: Widget, decimalNumber: int, sepStyle: SepStyle, negStyle: NegStyle) =
  discard

proc formatCurrency*(self: Widget, strCurrency: string, currencyPrepend: bool) =
  discard

proc formatPercent*(self: Widget, decimalNumber: int, sepStyle: SepStyle) =
  discard

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
  discard

#[
HH:MM
h:MM tt
HH:MM:ss
h:MM:ss tt
]#

proc formatTime*(self: Widget, strFmt: string) =
  discard

type
  SpecialFormat = enum
    sfZipCode
    sfZipCode4
    sfPhoneNumber
    sfSSN
    sfMask

proc formatSpecial*(self: Widget, style: SpecialFormat, mask: string = nil) =
  discard

proc formatCustom*(self: Widget, JSfmt, keyStroke: string) =
  discard

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
  discard

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
  discard

type
  TextFieldAlignment = enum
    tfaLeft
    tfaCenter
    tfaRight

proc setAlignment*(self: TextField, align: TextFieldAlignment) =
  discard

proc setMaxChars*(self: TextField, maxChars: int) =
  discard

proc setDefaultValue*(self: TextField, val: string) =
  discard

proc setFlags*(self: TextField, flags: TextFieldFlags) =
  discard

proc setShape*(self: CheckBox, val: string) =
  discard

proc setExportValue*(self: CheckBox, val: string) =
  discard

proc setCheckedByDefault*(self: CheckBox, val: bool) =
  discard

proc setShape*(self: RadioButton, val: string) =
  discard

proc setExportValue*(self: RadioButton, val: string) =
  discard

proc setCheckedByDefault*(self: RadioButton, val: bool) =
  discard

proc setAllowUnchecked*(self: RadioButton, val: bool) =
  discard

proc addKeyVal*(self: ComboBox, key, val: string) =
  discard

proc setEditable*(self: ComboBox, val: bool) =
  discard

proc setDefaultExportValue*(self: ComboBox, val: string) =
  discard

proc addKeyVal*(self: ListBox, key, val: string) =
  discard

proc setMultipleSelect*(self: ComboBox, val: bool) =
  discard

proc setDefaultExportValue*(self: ListBox, val: string) =
  discard

proc setCaption*(self: PushButton, val: string) =
  discard
