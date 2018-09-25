import objects, fontmanager, gstate, page, tables, image, strutils, basic2d

const
  FIELD_TYPE_BUTTON = "Btn"
  FIELD_TYPE_TEXT = "Tx"
  FIELD_TYPE_CHOICE = "Ch"

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

  ButtonFlags = enum
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
    fatMouseUp
    fatMouseDown
    fatMouseEnter
    fatMouseExit
    fatGetFocus
    fatLostFocus
    fatPageOpen
    fatPageClose
    fatPageVisible
    fatPageInvisible

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

  PushButtonLook* = enum
    pblCaptionOnly
    pblIconOnly
    pblCaptionBelowIcon
    pblCaptionAboveIcon
    pblCaptionRightToTheIcon
    pblCaptionLeftToTheIcon
    pblCaptionOverlaidIcon

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
      uri: string
      isMap: bool
    of fakResetForm:
      rfFields: seq[Widget]
      rfExclude: bool
    of fakSubmitForm:
      format: FormSubmitFormat
      url: string
      sfFields: seq[Widget]
      sfExclude: bool
    of fakEmailEntirePDF:
      to, cc, bcc, title, body: string
    of fakRunJS:
      jsScript: string
    of fakNamedAction:
      namedAction: NamedAction
    of fakGotoLocalPage:
      localDest: Destination
    of fakGotoAnotherPDF:
      remotePage: int
      path: string
    of fakLaunchApp:
      app, params, operation, defaultDir: string

  Border = ref object
    style: BorderStyle
    width: int
    dashPattern: seq[int]
    colorRGB: RGBColor
    colorCMYK: CMYKColor
    colorType: ColorType

  SpecialFormat* = enum
    sfZipCode
    sfZipCode4
    sfPhoneNumber
    sfSSN
    sfMask

  FormatKind = enum
    FormatNone
    FormatNumber
    FormatPercent
    FormatDate
    FormatTime
    FormatSpecial
    FormatCustom

  FormatTimeType* = enum
    FTT_0 # HH:MM
    FTT_1 # h:MM tt
    FTT_2 # HH:MM:ss
    FTT_3 # h:MM:ss tt

  FormatDateType* = enum
    FDT_0 # m/d
    FDT_1 # m/d/yy
    FDT_2 # m/d/yyyy
    FDT_3 # mm/dd/yy
    FDT_4 # mm/dd/yyyy
    FDT_5 # mm/yy
    FDT_6 # mm/yyyy
    FDT_7 # d-mmm
    FDT_8 # d-mmm-yy
    FDT_9 # d-mmm-yyyy
    FDT_10 # dd-mmm-yy
    FDT_11 # dd-mmm-yyy
    FDT_12 # yy-mm-dd
    FDT_13 # yyyy-mm-dd
    FDT_14 # mmm-yy
    FDT_15 # mmm-yyyy
    FDT_16 # mmmm-yy
    FDT_17 # mmmm-yyyy
    FDT_18 # mmm d, yyyy
    FDT_19 # mmmm d, yyyy
    FDT_20 # m/d/yy h:MM tt
    FDT_21 # m/d/yyyy h:MM tt
    FDT_22 # m/d/yy HH:MM
    FDT_23 # m/d/yyyy HH MM

  FormatObject = ref object
    case kind: FormatKind
    of FormatNone: discard
    of FormatNumber, FormatPercent:
      decimalNumber: int
      sepStyle: SepStyle
      negStyle: NegStyle
      strCurrency: string
      currencyPrepend: bool
    of FormatDate:
      formatDateType: FormatDateType
    of FormatTime:
      formatTimeType: FormatTimeType
    of FormatSpecial:
      special: SpecialFormat
    of FormatCustom:
      JSfmt, keyStroke: string

  HighLightMode* = enum
    hmNone
    hmInvert
    hmOutline
    hmPush
    hmToggle

  FieldFlags = enum
    ffReadOnly = 1
    ffRequired = 2
    ffNoExport = 3

  Widget = ref object of WidgetBase
    kind: WidgetKind
    id: string
    border: Border
    rect: Rectangle
    toolTip: string
    visibility: Visibility
    rotation: int
    fontFamily: string
    fontStyles: FontStyles
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
    highLightMode: HighLightMode
    fieldFlags: int
    normalAP: AppearanceStream
    rollOverAP: AppearanceStream
    downAP: AppearanceStream
    matrix: Matrix2d

  TextField* = ref object of Widget
    align: TextFieldAlignment
    maxChars: int
    defaultValue: string
    flags: set[TextFieldFlags]

  CheckBox* = ref object of Widget
    shape: string
    checkedByDefault: bool
    caption: string

  RadioButton* = ref object of Widget
    shape: string
    checkedByDefault: bool
    allowUnchecked: bool
    caption: string

  ComboBox* = ref object of Widget
    keyVal: Table[string, string]
    editable: bool
    sortItem: bool
    spellCheck: bool
    commitOnSelChange: bool

  ListBox* = ref object of Widget
    keyVal: Table[string, string]
    multipleSelect: bool
    sortItem: bool
    spellCheck: bool
    commitOnSelChange: bool

  IconScaleMode* = enum
    ismAlwaysScale
    ismScaleIfBigger
    ismScaleIfSmaller
    ismNeverScale

  IconScalingType* = enum
    istAnamorphic
    istProportional

  PushButton* = ref object of Widget
    look: PushButtonLook
    caption: string
    rollOverCaption: string
    alternateCaption: string
    icon: Image
    rollOverIcon: Image
    alternateIcon: Image
    iconScaleMode: IconScaleMode
    iconScalingType: IconScalingType
    iconFitToBorder: bool
    iconLeftOver: array[2, float64]

const
  FormatDateStr: array[FormatDateType, string] = [
    "m/d", "m/d/yy", "m/d/yyyy", "mm/dd/yy", "mm/dd/yyyy",
    "mm/yy", "mm/yyyy", "d-mmm", "d-mmm-yy", "d-mmm-yyyy",
    "dd-mmm-yy", "dd-mmm-yyy", "yy-mm-dd", "yyyy-mm-dd",
    "mmm-yy", "mmm-yyyy", "mmmm-yy", "mmmm-yyyy",
    "mmm d, yyyy", "mmmm d, yyyy", "m/d/yy h:MM tt",
    "m/d/yyyy h:MM tt", "m/d/yy HH:MM", "m/d/yyyy HH MM"]

proc newBorder(): Border =
  new(result)
  result.style = bsSolid
  result.width = 1
  result.dashPattern = @[]
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

proc createObject(self: Border): PdfObject =
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

proc newArray(c: RGBColor): ArrayObj =
  result = newArray(c.r, c.g, c.b)

proc newArray(c: CMYKColor): ArrayObj =
  result = newArray(c.c, c.m, c.y, c.k)

proc newColorArray(colorType: ColorType, rgb: RGBColor, cmyk: CMYKColor): ArrayObj =
  if colorType == ColorRGB: result = newArray(rgb)
  else: result = newArray(cmyk)

proc setBit[T: enum](x: var int, bit: T) =
  x = x or (1 shl (ord(bit) - 1))

proc removeBit[T: enum](x: var int, bit: T) =
  x = x and (not (1 shl (ord(bit) - 1)))

proc getJSCode(fmt: FormatObject, fn: string): string =
  case fmt.kind
  of FormatNone: result = ""
  of FormatPercent: result = "AFPercent_$1($2,$3);" % [fn, $fmt.decimalNumber, $ord(fmt.sepStyle)]
  of FormatNumber:
    result = "AFNumber_$1($2,$3,$4,0,\"$5\",$6);" % [fn, $fmt.decimalNumber, $ord(fmt.sepStyle),
      $ord(fmt.negStyle), fmt.strCurrency, $fmt.currencyPrepend]
  of FormatTime:
    result = "AFTime_$1($2);" % [fn, $ord(fmt.formatTimeType)]
  of FormatDate:
    result = "AFDate_$1Ex(\"$1\");" % [fn, FormatDateStr[fmt.formatDateType]]
  of FormatSpecial:
    result = "AFSpecial_$1(\"$1\");" % [fn, $ord(fmt.special)]
  of FormatCustom:
    if fn == "Keystroke": result = fmt.keyStroke
    else: result = fmt.JSfmt

method createDefaultAP*(self: Widget): AppearanceStream {.base.} =
  discard

proc createPDFObject(self: Widget): DictObj =
  const
    hmSTR: array[HighLightMode, char] = ['N', 'I', 'O', 'P', 'T']

  var dict = self.dictObj
  dict.addName("Type", "Annot")
  dict.addName("Subtype", "Widget")
  dict.addName("H", $hmSTR[self.highLightMode])
  dict.addString("T", self.id)
  if self.toolTip.len > 0:
    dict.addString("TU", self.toolTip)

  var annotFlags = 0

  case self.visibility:
  of Visible: annotFlags.setBit(afPrint)
  of Hidden: annotFlags.setBit(afHidden)
  of VisibleNotPrintable: discard
  of HiddenButPrintable:
    annotFlags.setBit(afPrint)
    annotFlags.setBit(afHidden)

  dict.addNumber("F", annotFlags)

  var mk = newDictObj()
  let bg = newColorArray(self.fillColorType, self.fillColorRGB, self.fillColorCMYK)
  mk.addElement("BG", bg)
  mk.addNumber("R", self.rotation)
  dict.addElement("MK", mk)

  if self.border != nil:
    let border = self.border
    let bs = border.createObject()
    let bc = newColorArray(border.colorType, border.colorRGB, border.colorCMYK)
    dict.addElement("BS", bs)
    mk.addElement("BC", bc)

  var rc = newArray(self.rect)
  dict.addElement("Rect", rc)

  var font = self.state.makeFont(self.fontFamily, self.fontStyles, self.fontEncoding)
  let fontID = $font.ID

  if self.fontColorType == ColorRGB:
    let c = self.fontColorRGB
    dict.addString("DA", "/F$1 $2 Tf $3 $4 $5 rg" % [fontID, f2s(self.fontSize), f2s(c.r), f2s(c.g), f2s(c.b)])
  else:
    let c = self.fontColorCMYK
    dict.addString("DA", "/F$1 $2 Tf $3 $4 $5 $6 k" % [fontID, f2s(self.fontSize), f2s(c.c), f2s(c.m), f2s(c.y), f2s(c.k)])

  var aa: DictObj

  if self.format != nil:
    var k = newDictObj()
    var f = newDictObj()
    if aa.isNil: aa = newDictObj()
    k.addName("S", "JavaScript")
    f.addName("S", "JavaScript")
    f.addString("JS", self.format.getJSCode("Keystroke"))
    k.addString("JS", self.format.getJSCode("Format"))
    aa.addElement("K", k)
    aa.addElement("F", f)

  if self.validateScript.len > 0:
    if aa.isNil: aa = newDictObj()
    var v = newDictObj()
    v.addName("S", "JavaScript")
    if self.validateScript.len > 80:
      v.addElement("JS", self.state.newDictStream(self.validateScript))
    else:
      v.addString("JS", self.validateScript)
    aa.addElement("V", v)

  if self.calculateScript.len > 0:
    if aa.isNil: aa = newDictObj()
    var c = newDictObj()
    c.addName("S", "JavaScript")
    if self.calculateScript.len > 80:
      c.addElement("JS", self.state.newDictStream(self.calculateScript))
    else:
      c.addString("JS", self.calculateScript)
    aa.addElement("C", c)

  if aa != nil: dict.addElement("AA", aa)
  result = self.dictObj

proc putAP(self: Widget, ap: AppearanceStream, code: string, resourceDict: DictObj) =
  var currAP = ap.newDictStream()
  currAP.addName("Type", "XObject")
  currAP.addName("Subtype", "Form")
  currAP.addNumber("FormType", 1)
  currAP.addElement("Resources", resourceDict)
  var r = self.rect
  var rc = newArray(r.x, r.y, r.x+r.w, r.y+r.h)
  currAP.addElement("BBox", rc)
  var m = newArray(self.matrix.ax, self.matrix.ay, self.matrix.bx, self.matrix.by, self.matrix.tx, self.matrix.ty)
  currAP.addElement("Matrix", m)

  var apDict = newDictObj()
  apDict.addElement(code, currAP) # or APsubdir
  self.dictObj.addElement("AP", apDict)

method finalizeObject(self: Widget; page, parent, resourceDict: DictObj) =
  self.dictObj.addElement("DR", resourceDict)
  self.dictObj.addElement("P", page)
  self.dictObj.addElement("Parent", parent)

  var aa: DictObj

  const FormActionTriggerStr: array[FormActionTrigger, string] =
    ["U", "D", "E", "X", "Fo", "Bl", "PO", "PC", "PV", "PI"]

  const FormActionKindStr: array[FormActionKind, string] =
    ["URI", "ResetForm", "SubmitForm", "JavaScript", "JavaScript", "Named", "GoTo", "GoToR", "Launch"]

  if self.actions.len > 0:
    aa = DictObj(self.dictObj.getItem("AA", CLASS_DICT))
    if aa.isNil:
      aa = newDictObj()
      self.dictObj.addElement("AA", aa)

    for x in self.actions:
      var action = newDictObj()
      action.addName("S", FormActionKindStr[x.kind])
      aa.addElement(FormActionTriggerStr[x.trigger], action)

      case x.kind
      of fakOpenWebLink:
        action.addString("URI", x.uri)
        action.addBoolean("IsMap", x.isMap)
      of fakResetForm:
        if x.rfFields.len > 0:
          action.addNumber("Flags", int(x.rfExclude))
          var arr = newArrayObj()
          for c in x.rfFields:
            arr.add(c.dictObj)
          action.addElement("Fields", arr)
      of fakSubmitForm:
        action.addString("F", x.url)
        var flags: int = 0
        if x.sfFields.len > 0:
          if x.sfExclude: flags = flags and (1 shr 1)
          var arr = newArrayObj()
          for c in x.sfFields:
            arr.add(c.dictObj)
          action.addElement("Fields", arr)

        case x.format
        of EmailFormData: discard
        of PDF_Format: flags = flags and (1 shr 9)
        of HTML_Format: flags = flags and (1 shr 3)
        of XFDF_Format: flags = flags and (1 shr 6)

        action.addNumber("Flags", flags)
      of fakEmailEntirePDF:
        let js = "this.mailDoc(false, \"$1\", \"$2\", \"$3\", \"$4\", \"$5\");" %
          [x.to, x.cc, x.bcc, x.title, x.body]

        if js.len > 80:
          action.addElement("JS", self.state.newDictStream(js))
        else:
          action.addString("JS", js)
      of fakRunJS:
        if x.jsScript.len > 80:
          action.addElement("JS", self.state.newDictStream(x.jsScript))
        else:
          action.addString("JS", x.jsScript)
      of fakNamedAction:
        const NamedActionStr: array[NamedAction, string] = [
          "FirstPage", "NextPage", "PrevPage", "LastPage", "PrintDialog"]
        action.addName("N", NamedActionStr[x.namedAction])
      of fakGotoLocalPage:
        var arr = toObject(x.localDest)
        action.addElement("D", arr)
      of fakGotoAnotherPDF:
        var arr = newArrayObj()
        arr.addNumber(x.remotePage)
        arr.addName("Fit")
        action.addString("F", x.path)
        action.addElement("D", arr)
      of fakLaunchApp:
        var dict = newDictObj()
        dict.addString("F", x.app)
        dict.addString("P", x.params)
        dict.addString("O", x.operation)
        dict.addString("D", x.defaultDir)
        action.addElement("Win", dict)

  if self.normalAP.isNil:
    self.normalAP = self.createDefaultAP()
  self.putAP(self.normalAP, "N", resourceDict)

  if self.rollOverAP != nil:
    self.putAP(self.rollOverAP, "R", resourceDict)

  if self.downAP != nil:
    self.putAP(self.downAP, "D", resourceDict)

  self.dictObj.addNumber("Ff", self.fieldFlags)

method needCalculateOrder*(self: Widget): bool =
  result = self.calculateScript.len > 0

proc init(self: Widget, doc: DocState, id: string) =
  self.state = doc
  self.dictObj = newDictObj()
  self.id = id
  self.border = nil
  self.toolTip = ""
  self.visibility = Visible
  self.rotation = 0
  self.fontFamily = "Helvetica"
  self.fontStyles = {FS_REGULAR}
  self.fontSize = 10.0
  self.fontEncoding = ENC_STANDARD
  self.fontColorType = ColorRGB
  self.fontColorRGB = initRGB(0, 0, 0)
  self.fillColorType = ColorRGB
  self.fillColorRGB = initRGB(0, 0, 0)
  self.actions = @[]
  self.validateScript = ""
  self.calculateScript = ""
  self.format = nil
  self.highLightMode = hmNone
  self.fieldFlags = 0
  self.normalAP = nil
  self.rollOverAP = nil
  self.downAP = nil
  self.matrix = IDMATRIX

proc getNormalAP*(self: Widget): AppearanceStream =
  result = self.normalAP

proc setNormalAP*(self: Widget, ap: AppearanceStream) =
  self.normalAP = ap

proc setDownAP*(self: Widget, ap: AppearanceStream) =
  self.downAP = ap

proc setRollOverAP*(self: Widget, ap: AppearanceStream) =
  self.rollOverAP = ap

proc setTransformation*(self: Widget, m: Matrix2d) =
  self.matrix = m

proc setToolTip*(self: Widget, toolTip: string) =
  self.toolTip = toolTip

proc setVisibility*(self: Widget, val: Visibility) =
  self.visibility = val

# multiple of 90 degree
proc setRotation*(self: Widget, angle: int) =
  self.rotation = angle

proc setReadOnly*(self: Widget, val: bool) =
  if val: self.fieldFlags.setBit(ffReadOnly)
  else: self.fieldFlags.removeBit(ffReadOnly)

proc setRequired*(self: Widget, val: bool) =
  if val: self.fieldFlags.setBit(ffRequired)
  else: self.fieldFlags.removeBit(ffRequired)

proc setNoExport*(self: Widget, val: bool) =
  if val: self.fieldFlags.setBit(ffNoExport)
  else: self.fieldFlags.removeBit(ffNoExport)

proc setFont*(self: Widget, family: string) =
  self.fontFamily = family

proc setFontStyles*(self: Widget, styles: FontStyles) =
  self.fontStyles = styles

proc setFontSize*(self: Widget, size: float64) =
  self.fontSize = self.state.fromUser(size)

proc setFontEncoding*(self: Widget, enc: EncodingType) =
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

proc addActionOpenWebLink*(self: Widget, trigger: FormActionTrigger, uri: string, isMap: bool) =
  var action = new(FormAction)
  action.trigger = trigger
  action.kind = fakOpenWebLink
  action.uri = uri
  action.isMap = isMap
  self.actions.add action

proc addActionResetForm*(self: Widget, trigger: FormActionTrigger) =
  var action = new(FormAction)
  action.trigger = trigger
  action.kind = fakResetForm
  action.rfFields = @[]
  action.rfExclude = false
  self.actions.add action

proc addActionResetForm*(self: Widget, trigger: FormActionTrigger, fields: openArray[Widget], exclude: bool) =
  var action = new(FormAction)
  action.trigger = trigger
  action.kind = fakResetForm
  action.rfFields = @fields
  action.rfExclude = exclude
  self.actions.add action

proc addActionSubmitForm*(self: Widget, trigger: FormActionTrigger, format: FormSubmitFormat, url: string) =
  var action = new(FormAction)
  action.trigger = trigger
  action.kind = fakSubmitForm
  action.format = format
  action.sfFields = @[]
  action.url = url
  self.actions.add action

proc addActionSubmitForm*(self: Widget, trigger: FormActionTrigger, format: FormSubmitFormat, url: string, fields: openArray[Widget], exclude: bool) =
  var action = new(FormAction)
  action.trigger = trigger
  action.kind = fakSubmitForm
  action.format = format
  action.sfFields = @fields
  action.sfExclude = exclude
  action.url = url
  self.actions.add action

proc addActionEmailEntirePDF*(self: Widget, trigger: FormActionTrigger; to, cc, bcc, title, body: string) =
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
  var action = new(FormAction)
  action.trigger = trigger
  action.kind = fakRunJS
  action.jsScript = script
  self.actions.add action

proc addActionNamed*(self: Widget, trigger: FormActionTrigger, name: NamedAction) =
  var action = new(FormAction)
  action.trigger = trigger
  action.kind = fakNamedAction
  action.namedAction = name
  self.actions.add action

proc addActionGotoLocalPage*(self: Widget, trigger: FormActionTrigger, dest: Destination) =
  var action = new(FormAction)
  action.trigger = trigger
  action.kind = fakGotoLocalPage
  action.localDest = dest
  self.actions.add action

proc addActionGotoAnotherPDF*(self: Widget, trigger: FormActionTrigger, path: string, pageNo: int) =
  var action = new(FormAction)
  action.trigger = trigger
  action.kind = fakGotoAnotherPDF
  action.remotePage = pageNo
  action.path = path
  self.actions.add action

proc addActionLaunchApp*(self: Widget, trigger: FormActionTrigger; app, params, operation, defaultDir: string) =
  var action = new(FormAction)
  action.trigger = trigger
  action.kind = fakLaunchApp
  action.app = app
  action.params = params
  action.operation = operation
  action.defaultDir = defaultDir
  self.actions.add action

proc formatNumber*(self: Widget, decimalNumber: int, sepStyle: SepStyle, negStyle: NegStyle, strCurrency: string = "", currencyPrepend: bool = false) =
  var fmt = new(FormatObject)
  fmt.kind = FormatNumber
  fmt.decimalNumber = decimalNumber
  fmt.sepStyle = sepStyle
  fmt.negStyle = negStyle
  fmt.strCurrency = strCurrency
  fmt.currencyPrepend = currencyPrepend
  self.format = fmt

proc formatPercent*(self: Widget, decimalNumber: int, sepStyle: SepStyle) =
  var fmt = new(FormatObject)
  fmt.kind = FormatPercent
  fmt.decimalNumber = decimalNumber
  fmt.sepStyle = sepStyle
  self.format = fmt

proc formatDate*(self: Widget, formatType: FormatDateType) =
  var fmt = new(FormatObject)
  fmt.kind = FormatDate
  fmt.formatDateType = formatType
  self.format = fmt

proc formatTime*(self: Widget, formatType: FormatTimeType) =
  var fmt = new(FormatObject)
  fmt.kind = FormatTime
  fmt.formatTimeType = formatType
  self.format = fmt

proc formatSpecial*(self: Widget, special: SpecialFormat) =
  var fmt = new(FormatObject)
  fmt.kind = FormatSpecial
  fmt.special = special
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

proc setHighLightMode*(self: Widget, mode: HighLightMode) =
  self.highLightMode = mode

#----------------------TEXT FIELD
proc newTextField*(doc: DocState, x,y,w,h: float64, id: string): TextField =
  new(result)
  result.init(doc, id)
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

method createObject(self: TextField): PdfObject =
  var dict = self.createPDFObject()
  dict.addName("FT", FIELD_TYPE_TEXT)
  for c in low(TextFieldFlags)..high(TextFieldFlags):
    if c in self.flags:
      self.fieldFlags.setBit(c)
    else:
      self.fieldFlags.removeBit(c)
  result = dict

method createDefaultAP*(self: TextField): AppearanceStream =
  discard

#----------------------CHECK BOX
proc newCheckBox*(doc: DocState, x,y,w,h: float64, id: string): CheckBox =
  new(result)
  result.init(doc, id)
  result.rect = initRect(x,y,w,h)
  result.kind = wkCheckBox
  result.shape = "\x35"
  result.checkedByDefault = false
  result.caption = ""

proc setShape*(self: CheckBox, val: string) =
  self.shape = val

proc setCheckedByDefault*(self: CheckBox, val: bool) =
  self.checkedByDefault = val

proc setCaption*(self: CheckBox, val: string) =
  self.caption = val

method createObject(self: CheckBox): PdfObject =
  var dict = self.createPDFObject()
  dict.addName("FT", FIELD_TYPE_BUTTON)
  result = dict

method createDefaultAP*(self: CheckBox): AppearanceStream =
  discard

#----------------------RADIO BUTTON
proc newRadioButton*(doc: DocState, x,y,w,h: float64, id: string): RadioButton =
  new(result)
  result.init(doc, id)
  result.rect = initRect(x,y,w,h)
  result.kind = wkRadioButton
  result.shape = "\6C"
  result.checkedByDefault = false
  result.allowUnchecked = false
  result.caption = ""

proc setShape*(self: RadioButton, val: string) =
  self.shape = val

proc setCheckedByDefault*(self: RadioButton, val: bool) =
  self.checkedByDefault = val

proc setAllowUnchecked*(self: RadioButton, val: bool) =
  self.allowUnchecked = val

proc setCaption*(self: RadioButton, val: string) =
  self.caption = val

method createObject(self: RadioButton): PdfObject =
  var dict = self.createPDFObject()
  dict.addName("FT", FIELD_TYPE_BUTTON)
  self.fieldFlags.setBit(bfRadio)
  self.fieldFlags.setBit(bfNoToggleToOff)
  result = dict

method createDefaultAP*(self: RadioButton): AppearanceStream =
  discard

#---------------------COMBO BOX
proc newComboBox*(doc: DocState, x,y,w,h: float64, id: string): ComboBox =
  new(result)
  result.init(doc, id)
  result.rect = initRect(x,y,w,h)
  result.kind = wkComboBox
  result.editable = false
  result.sortItem = false
  result.spellCheck = false
  result.commitOnSelChange = false
  result.keyVal = initTable[string, string]()

proc addKeyVal*(self: ComboBox, key, val: string) =
  self.keyVal[key] = val

proc setEditable*(self: ComboBox, val: bool) =
  self.editable = val

method createObject(self: ComboBox): PdfObject =
  var dict = self.createPDFObject()
  dict.addName("FT", FIELD_TYPE_CHOICE)
  self.fieldFlags.setBit(cfCombo)
  if self.editable: self.fieldFlags.setBit(cfEdit)
  if self.sortItem: self.fieldFlags.setBit(cfSort)
  if not self.spellCheck: self.fieldFlags.setBit(cfDoNotSpellCheck)
  if self.commitOnSelChange: self.fieldFlags.setBit(cfCommitOnSelChange)
  result = dict

method createDefaultAP*(self: ComboBox): AppearanceStream =
  discard

#---------------------LIST BOX
proc newListBox*(doc: DocState, x,y,w,h: float64, id: string): ListBox =
  new(result)
  result.init(doc, id)
  result.rect = initRect(x,y,w,h)
  result.kind = wkListBox
  result.multipleSelect = false
  result.sortItem = false
  result.spellCheck = false
  result.commitOnSelChange = false
  result.keyVal = initTable[string, string]()

proc addKeyVal*(self: ListBox, key, val: string) =
  self.keyVal[key] = val

proc setMultipleSelect*(self: ListBox, val: bool) =
  self.multipleSelect = val

method createObject(self: ListBox): PdfObject =
  var dict = self.createPDFObject()
  dict.addName("FT", FIELD_TYPE_CHOICE)
  if self.multipleSelect: self.fieldFlags.setBit(cfMultiSelect)
  if self.sortItem: self.fieldFlags.setBit(cfSort)
  if not self.spellCheck: self.fieldFlags.setBit(cfDoNotSpellCheck)
  if self.commitOnSelChange: self.fieldFlags.setBit(cfCommitOnSelChange)
  result = dict

method createDefaultAP*(self: ListBox): AppearanceStream =
  discard

#---------------------PUSH BUTTON
proc newPushButton*(doc: DocState, x,y,w,h: float64, id: string): PushButton =
  new(result)
  result.init(doc, id)
  result.rect = initRect(x,y,w,h)
  result.kind = wkPushButton
  result.caption = ""
  result.rollOverCaption = ""
  result.alternateCaption = ""
  result.look = pblCaptionOnly
  result.icon = nil
  result.rollOverIcon = nil
  result.alternateIcon = nil
  result.iconScaleMode = ismAlwaysScale
  result.iconScalingType = istProportional
  result.iconFitToBorder = false
  result.iconLeftOver = [0.5, 0.5]

proc setCaption*(self: PushButton, val: string) =
  self.caption = val

proc setRollOverCaption*(self: PushButton, val: string) =
  self.rollOverCaption = val

proc setAlternateCaption*(self: PushButton, val: string) =
  self.alternateCaption = val

proc setIcon*(self: PushButton, img: Image) =
  self.icon = img

proc setRollOverIcon*(self: PushButton, img: Image) =
  self.rollOverIcon = img

proc setAlternateIcon*(self: PushButton, img: Image) =
  self.alternateIcon = img

proc setIconScaleMode*(self: PushButton, mode: IconScaleMode) =
  self.iconScaleMode = mode

proc setIconScalingType*(self: PushButton, mode = IconScalingType) =
  self.iconScalingType = mode

proc setIconFitBorder*(self: PushButton, mode: bool) =
  self.iconFitToBorder = mode

proc setIconLeftOver*(self: PushButton, left, bottom: float64) =
  self.iconLeftOver = [left, bottom]

proc setFlag*(self: PushButton, look: PushButtonLook) =
  self.look = look

method createObject(self: PushButton): PdfObject =
  var dict = self.createPDFObject()
  dict.addName("FT", FIELD_TYPE_BUTTON)
  self.fieldFlags.setBit(bfPushButton)

  var mk = DictObj(self.dictObj.getItem("MK", CLASS_DICT))

  mk.addString("CA", self.caption)
  if self.rollOverCaption.len > 0:
    mk.addString("RC", self.rollOverCaption)
  if self.alternateCaption.len > 0:
    mk.addString("AC", self.alternateCaption)

  mk.addNumber("TP", ord(self.look))

  if self.icon != nil:
    mk.addElement("I", self.icon.dictObj)

  if self.rollOverIcon != nil:
    mk.addElement("RI", self.rollOverIcon.dictObj)

  if self.alternateIcon != nil:
    mk.addElement("IX", self.alternateIcon.dictObj)

  if self.icon != nil or self.rollOverIcon != nil or self.alternateIcon != nil:
    const
      IconScaleModeStr: array[IconScaleMode, string] = ["A", "B", "S", "N"]
      IconScaleTypeStr: array[IconScalingType, string] = ["A", "P"]

    var dict = newDictObj()
    dict.addName("SW", IconScaleModeStr[self.iconScaleMode])
    dict.addName("S", IconScaleTypeStr[self.iconScalingType])
    dict.addBoolean("FB", self.iconFitToBorder)
    var arr = newArray(self.iconLeftOver)
    dict.addElement("A", arr)
    mk.addElement("IF", dict)

  result = dict

method createDefaultAP*(self: PushButton): AppearanceStream =
  var ap = newAppearanceStream(self.state)

  ap.saveState()
  ap.setCoordinateMode(BOTTOM_UP)
  ap.setUnit(PGU_PT)
  ap.setFont(self.fontFamily, self.fontStyles, self.fontSize)

  var r = self.rect
  let textWidth = ap.getTextWidth(self.caption)
  ap.drawText(r.x + (r.w - textWidth) / 2, r.y + (r.h - self.fontSize) / 2, self.caption)

  ap.setLineWidth(0.2)
  ap.drawRect(r.x, r.y, r.w, r.h)
  ap.stroke()
  ap.restoreState()

  result = ap
