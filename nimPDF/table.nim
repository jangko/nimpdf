#-----------------------------------------
# Table support for nimPDF added By Duncan Clarke
# Support for auto fit, shrink to fit, styles,
# auto new pages with optional duplicated headers 
# for long tables.

import gstate, page, fontmanager
import strutils, math

type
  CellAlignment* = enum
    ALIGN_LEFT, ALIGN_CENTER, ALIGN_RIGHT, ALIGN_TOP, ALIGN_MIDDLE, ALIGN_BOTTOM

  CellBorder* = object
    left*, right*, top*, bottom*: bool
    width*: float64
    color*: RGBColor

  CellStyle* = object
    backgroundColor*: RGBColor
    textColor*: RGBColor
    border*: CellBorder
    padding*: tuple[left, right, top, bottom: float64]
    horizontalAlign*: CellAlignment
    verticalAlign*: CellAlignment
    fontFamily*: string
    fontSize*: float64
    fontBold*: bool
    fontItalic*: bool
    scaleToFit*: bool      # If true, scale text to fit without wrapping
    minFontSize*: float64  # Minimum font size for auto-shrinking (0 = no limit)

  Cell* = ref object
    content*: string
    style*: CellStyle
    colspan*: int
    rowspan*: int
    width*: float64  # Calculated width
    height*: float64 # Calculated height
    wrappedLines*: seq[string] # Text wrapped into multiple lines
    actualFontSize*: float64 # Actual font size used after auto-sizing

  Row* = ref object
    cells*: seq[Cell]
    height*: float64
    minHeight*: float64

  Table* = ref object
    rows*: seq[Row]
    columnWidths*: seq[float64]
    totalWidth*: float64
    x*, y*: float64
    defaultCellStyle*: CellStyle
    headerStyle*: CellStyle
    autoFit*: bool

proc initCellBorder*(width: float64 = 0.5, color: RGBColor = initRGB(0, 0, 0)): CellBorder =
  result.left = true
  result.right = true
  result.top = true
  result.bottom = true
  result.width = width
  result.color = color

proc initCellBorder*(left, right, top, bottom: bool, width: float64 = 0.5, 
                     color: RGBColor = initRGB(0, 0, 0)): CellBorder =
  result.left = left
  result.right = right
  result.top = top
  result.bottom = bottom
  result.width = width
  result.color = color

proc initCellStyle*(): CellStyle =
  result.backgroundColor = initRGB(1.0, 1.0, 1.0)
  result.textColor = initRGB(0, 0, 0)
  result.border = initCellBorder()
  result.padding = (left: 2.0, right: 2.0, top: 2.0, bottom: 2.0)
  result.horizontalAlign = ALIGN_LEFT
  result.verticalAlign = ALIGN_MIDDLE
  result.fontFamily = ""  # Empty means use page default
  result.fontSize = 0.0   # 0 means use page default
  result.fontBold = false
  result.fontItalic = false
  result.scaleToFit = false
  result.minFontSize = 0.0  # No minimum by default

proc initHeaderStyle*(): CellStyle =
  result = initCellStyle()
  result.backgroundColor = initRGB(0.9, 0.9, 0.9)
  result.textColor = initRGB(0, 0, 0)
  result.horizontalAlign = ALIGN_CENTER
  result.verticalAlign = ALIGN_MIDDLE

proc newCell*(content: string, style: CellStyle = initCellStyle(), 
              colspan: int = 1, rowspan: int = 1): Cell =
  new(result)
  result.content = content
  result.style = style
  result.colspan = colspan
  result.rowspan = rowspan
  result.width = 0.0
  result.height = 0.0
  result.actualFontSize = 0.0

proc newRow*(cells: varargs[Cell]): Row =
  new(result)
  result.cells = @cells
  result.height = 0.0
  result.minHeight = 0.0

proc newTable*(x, y: float64, autoFit: bool = true): Table =
  new(result)
  result.rows = @[]
  result.columnWidths = @[]
  result.totalWidth = 0.0
  result.x = x
  result.y = y
  result.defaultCellStyle = initCellStyle()
  result.headerStyle = initHeaderStyle()
  result.autoFit = autoFit

proc addRow*(table: Table, row: Row) =
  table.rows.add(row)

proc addHeaderRow*(table: Table, headers: varargs[string]) =
  var cells: seq[Cell] = @[]
  for header in headers:
    cells.add(newCell(header, table.headerStyle))
  table.addRow(newRow(cells))

proc addDataRow*(table: Table, data: varargs[string]) =
  var cells: seq[Cell] = @[]
  for item in data:
    cells.add(newCell(item, table.defaultCellStyle))
  table.addRow(newRow(cells))

proc measureText(page: ContentBase, text: string): tuple[width, height: float64] =
  # Use the page's built-in text measurement
  let width = page.getTextWidth(text)
  let height = page.getTextHeight(text)
  result = (width: width, height: height)

proc wrapText(text: string, maxWidth: float64, page: ContentBase): seq[string] =
  # Word wrapping algorithm with proper width checking
  result = @[]
  if text.len == 0:
    return @[""]
  
  # Split into words
  var words = text.split(' ')
  var currentLine = ""
  
  for i, word in words:
    # Build test line
    let testLine = if currentLine.len > 0: currentLine & " " & word else: word
    let testWidth = page.getTextWidth(testLine)
    
    if testWidth <= maxWidth:
      # Fits on current line
      currentLine = testLine
    else:
      # Doesn't fit
      if currentLine.len > 0:
        # Save current line and start new one with this word
        result.add(currentLine)
        currentLine = word
      else:
        # Even single word doesn't fit - force it anyway
        result.add(word)
        currentLine = ""
  
  # Add remaining text
  if currentLine.len > 0:
    result.add(currentLine)
  
  if result.len == 0:
    result.add("")

proc calculateColumnWidths*(table: Table, page: ContentBase, maxWidth: float64) =
  if table.rows.len == 0:
    return
  
  # Find max number of columns
  var numColumns = 0
  for row in table.rows:
    if row.cells.len > numColumns:
      numColumns = row.cells.len
  
  if numColumns == 0:
    return
  
  # Initialize column widths array
  table.columnWidths = newSeq[float64](numColumns)
  
  # CRITICAL: Enforce absolute maximum width  
  # Units are typically in MM (nimPDF default)
  # A4 is 210mm wide, safe area is about 190mm (210 - 20 margin)
  let effectiveMaxWidth = if maxWidth > 0 and maxWidth < 210.0: maxWidth else: 150.0
  
  # Calculate minimum width per column based on longest single word
  var minWidths = newSeq[float64](numColumns)
  for i in 0 ..< numColumns:
    minWidths[i] = 20.0  # Absolute bare minimum
  
  # Find minimum required width for each column
  for row in table.rows:
    for i, cell in row.cells:
      if i < numColumns and cell.colspan == 1 and cell.content.len > 0:
        let words = cell.content.split(' ')
        var maxWordWidth = 0.0
        for word in words:
          let wordWidth = page.getTextWidth(word)
          if wordWidth > maxWordWidth:
            maxWordWidth = wordWidth
        
        # Minimum = longest word + padding
        let minRequired = maxWordWidth + cell.style.padding.left + cell.style.padding.right + 2.0
        if minRequired > minWidths[i]:
          minWidths[i] = minRequired
  
  # Check total minimum width needed
  let totalMinWidth = minWidths.sum()
  
  if totalMinWidth > effectiveMaxWidth:
    # We MUST compress - scale everything down proportionally
    let compressionRatio = effectiveMaxWidth / totalMinWidth
    for i in 0 ..< numColumns:
      table.columnWidths[i] = minWidths[i] * compressionRatio * 0.98  # 98% to be safe
  else:
    # We have space - use equal distribution for simplicity
    let equalWidth = effectiveMaxWidth / float64(numColumns)
    for i in 0 ..< numColumns:
      table.columnWidths[i] = equalWidth
  
  # Final safety check - absolutely ensure we don't exceed max
  let actualTotal = table.columnWidths.sum()
  if actualTotal > effectiveMaxWidth:
    let safetyScale = (effectiveMaxWidth * 0.98) / actualTotal
    for i in 0 ..< numColumns:
      table.columnWidths[i] = table.columnWidths[i] * safetyScale
  
  table.totalWidth = table.columnWidths.sum()

proc calculateRowHeights*(table: Table, page: ContentBase) =
  for rowIdx, row in table.rows:
    var maxHeight = 0.0
    for colIdx, cell in row.cells:
      if cell.rowspan == 1 and colIdx < table.columnWidths.len:
        # Calculate available width for text (accounting for padding)
        var availableWidth = table.columnWidths[colIdx] - cell.style.padding.left - cell.style.padding.right
        
        # Handle colspan
        if cell.colspan > 1:
          for j in 1 ..< cell.colspan:
            if colIdx + j < table.columnWidths.len:
              availableWidth += table.columnWidths[colIdx + j]
        
        # Get base font size
        let baseFontSize = if cell.style.fontSize > 0: cell.style.fontSize 
                           else: page.toUser(page.state.gState.fontSize)
        cell.actualFontSize = baseFontSize
        
        # Handle scaleToFit mode
        if cell.style.scaleToFit:
          # In scaleToFit mode, keep text on original lines (respect \n)
          let lines = if "\n" in cell.content: cell.content.split('\n') else: @[cell.content]
          cell.wrappedLines = lines
          
          # Temporarily set the cell's font to measure accurately
          page.saveState()
          if cell.style.fontFamily.len > 0:
            var fontStyle: set[FontStyle] = {}
            if cell.style.fontBold and cell.style.fontItalic:
              fontStyle = {FS_BOLD, FS_ITALIC}
            elif cell.style.fontBold:
              fontStyle = {FS_BOLD}
            elif cell.style.fontItalic:
              fontStyle = {FS_ITALIC}
            else:
              fontStyle = {FS_REGULAR}
            page.setFont(cell.style.fontFamily, fontStyle, baseFontSize)
          elif baseFontSize != page.toUser(page.state.gState.fontSize):
            # Just set the size if different
            let savedFont = page.state.gState.font
            if savedFont != nil:
              page.setFont("Helvetica", {FS_REGULAR}, baseFontSize)
          
          # Find the longest line and calculate scale factor
          var maxLineWidth = 0.0
          for line in lines:
            let lineWidth = page.getTextWidth(line)
            if lineWidth > maxLineWidth:
              maxLineWidth = lineWidth
          
          page.restoreState()
          
          # Calculate scale factor if text is too wide
          if maxLineWidth > availableWidth:
            # Use 98% safety margin to ensure text definitely fits
            let scaleFactor = (availableWidth * 0.98) / maxLineWidth
            cell.actualFontSize = baseFontSize * scaleFactor
            
            # Apply minimum font size if specified
            if cell.style.minFontSize > 0 and cell.actualFontSize < cell.style.minFontSize:
              cell.actualFontSize = cell.style.minFontSize
              
              # Check if text still fits at minimum size, if not, wrap it
              page.saveState()
              if cell.style.fontFamily.len > 0:
                var fontStyle: set[FontStyle] = {}
                if cell.style.fontBold and cell.style.fontItalic:
                  fontStyle = {FS_BOLD, FS_ITALIC}
                elif cell.style.fontBold:
                  fontStyle = {FS_BOLD}
                elif cell.style.fontItalic:
                  fontStyle = {FS_ITALIC}
                else:
                  fontStyle = {FS_REGULAR}
                page.setFont(cell.style.fontFamily, fontStyle, cell.actualFontSize)
              else:
                page.setFont("Helvetica", {FS_REGULAR}, cell.actualFontSize)
              
              # Re-measure at minimum font size
              maxLineWidth = 0.0
              for line in cell.wrappedLines:
                let lineWidth = page.getTextWidth(line)
                if lineWidth > maxLineWidth:
                  maxLineWidth = lineWidth
              
              # If still doesn't fit, wrap the text
              if maxLineWidth > availableWidth:
                cell.wrappedLines = wrapText(cell.content, availableWidth, page)
              
              page.restoreState()
          
          let lineHeight = page.getTextHeight("Ag") * 1.2  # 1.2x for comfortable line spacing
          let requiredHeight = float64(cell.wrappedLines.len) * lineHeight + 
                              cell.style.padding.top + cell.style.padding.bottom
          
          if requiredHeight > maxHeight:
            maxHeight = requiredHeight
        else:
          # Normal wrapping mode
          # Temporarily set the cell's font to measure accurately
          page.saveState()
          if cell.style.fontFamily.len > 0:
            var fontStyle: set[FontStyle] = {}
            if cell.style.fontBold and cell.style.fontItalic:
              fontStyle = {FS_BOLD, FS_ITALIC}
            elif cell.style.fontBold:
              fontStyle = {FS_BOLD}
            elif cell.style.fontItalic:
              fontStyle = {FS_ITALIC}
            else:
              fontStyle = {FS_REGULAR}
            page.setFont(cell.style.fontFamily, fontStyle, baseFontSize)
          elif baseFontSize != page.toUser(page.state.gState.fontSize):
            let savedFont = page.state.gState.font
            if savedFont != nil:
              page.setFont("Helvetica", {FS_REGULAR}, baseFontSize)
          
          cell.wrappedLines = wrapText(cell.content, availableWidth, page)
          
          # Check if any line still overflows (single word too long)
          var needsAutoShrink = false
          var maxOverflowRatio = 1.0
          for line in cell.wrappedLines:
            let lineWidth = page.getTextWidth(line)
            if lineWidth > availableWidth:
              needsAutoShrink = true
              let ratio = lineWidth / availableWidth
              if ratio > maxOverflowRatio:
                maxOverflowRatio = ratio
          
          page.restoreState()
          
          # Auto-shrink if needed
          if needsAutoShrink:
            # Use 98% safety margin to ensure text definitely fits
            cell.actualFontSize = (baseFontSize * 0.98) / maxOverflowRatio
            
            # Apply minimum font size if specified
            if cell.style.minFontSize > 0 and cell.actualFontSize < cell.style.minFontSize:
              cell.actualFontSize = cell.style.minFontSize
            
            # Re-wrap text with the new font size to ensure accurate line breaks
            page.saveState()
            if cell.style.fontFamily.len > 0:
              var fontStyle: set[FontStyle] = {}
              if cell.style.fontBold and cell.style.fontItalic:
                fontStyle = {FS_BOLD, FS_ITALIC}
              elif cell.style.fontBold:
                fontStyle = {FS_BOLD}
              elif cell.style.fontItalic:
                fontStyle = {FS_ITALIC}
              else:
                fontStyle = {FS_REGULAR}
              page.setFont(cell.style.fontFamily, fontStyle, cell.actualFontSize)
            else:
              page.setFont("Helvetica", {FS_REGULAR}, cell.actualFontSize)
            
            cell.wrappedLines = wrapText(cell.content, availableWidth, page)
            page.restoreState()
          
          let lineHeight = page.getTextHeight("Ag") * 1.2  # 1.2x for comfortable line spacing
          let requiredHeight = float64(cell.wrappedLines.len) * lineHeight + 
                              cell.style.padding.top + cell.style.padding.bottom
          
          if requiredHeight > maxHeight:
            maxHeight = requiredHeight
    
    # Use explicit minHeight if set, otherwise add 2mm margin to text bounds
    let effectiveMinHeight = if row.minHeight > 0: row.minHeight else: maxHeight + 2.0
    row.height = max(maxHeight, effectiveMinHeight)

proc drawCell(page: ContentBase, cell: Cell, x, y, width, height: float64) =
  # Draw background
  if cell.style.backgroundColor.r != 1.0 or cell.style.backgroundColor.g != 1.0 or 
     cell.style.backgroundColor.b != 1.0:
    page.saveState()
    page.setFillColor(cell.style.backgroundColor)
    page.drawRect(x, y, width, height)
    page.fill()
    page.restoreState()
  
  # Draw borders
  page.saveState()
  page.setStrokeColor(cell.style.border.color)
  page.setLineWidth(cell.style.border.width)
  
  if cell.style.border.left:
    page.drawLine(x, y, x, y + height)
  if cell.style.border.right:
    page.drawLine(x + width, y, x + width, y + height)
  if cell.style.border.top:
    page.drawLine(x, y, x + width, y)
  if cell.style.border.bottom:
    page.drawLine(x, y + height, x + width, y + height)
  
  page.stroke()
  page.restoreState()
  
  # Draw text (wrapped into multiple lines)
  if cell.wrappedLines.len > 0 and cell.wrappedLines[0].len > 0:
    page.saveState()
    
    # Set font if specified in cell style
    if cell.style.fontFamily.len > 0:
      # Determine font style
      var fontStyle: set[FontStyle] = {}
      if cell.style.fontBold and cell.style.fontItalic:
        fontStyle = {FS_BOLD, FS_ITALIC}
      elif cell.style.fontBold:
        fontStyle = {FS_BOLD}
      elif cell.style.fontItalic:
        fontStyle = {FS_ITALIC}
      else:
        fontStyle = {FS_REGULAR}
      
      # Use actualFontSize (which may be auto-scaled)
      let size = if cell.actualFontSize > 0: cell.actualFontSize 
                 else: page.toUser(page.state.gState.fontSize)
      
      page.setFont(cell.style.fontFamily, fontStyle, size)
    elif cell.style.fontSize > 0 or cell.actualFontSize > 0:
      # Only font size changed, keep current font family
      # Get current font to preserve family
      let savedFont = page.state.gState.font
      if savedFont != nil:
        # Determine font style
        var fontStyle: set[FontStyle] = {}
        if cell.style.fontBold and cell.style.fontItalic:
          fontStyle = {FS_BOLD, FS_ITALIC}
        elif cell.style.fontBold:
          fontStyle = {FS_BOLD}
        elif cell.style.fontItalic:
          fontStyle = {FS_ITALIC}
        else:
          fontStyle = {FS_REGULAR}
        
        # Use actualFontSize if available (auto-scaled), otherwise use specified fontSize
        let size = if cell.actualFontSize > 0: cell.actualFontSize else: cell.style.fontSize
        page.setFont("Helvetica", fontStyle, size)
    
    page.setFillColor(cell.style.textColor)
    
    let lineHeight = page.getTextHeight("Ag") * 1.2  # 1.2x for comfortable line spacing
    let totalTextHeight = float64(cell.wrappedLines.len) * lineHeight
    
    # Calculate starting Y position for the first line's baseline based on vertical alignment
    # drawText positions text by baseline. lineHeight includes space for ascenders.
    var startY: float64
    case cell.style.verticalAlign
    of ALIGN_TOP:
      # Position text at the top - baseline is lineHeight from top (space for ascenders)
      startY = y + cell.style.padding.top + lineHeight * 0.75  # Approximate ascent
    of ALIGN_MIDDLE:
      # Center the entire text block vertically
      let textBlockHeight = totalTextHeight
      let availableSpace = height - cell.style.padding.top - cell.style.padding.bottom
      let topOffset = cell.style.padding.top + (availableSpace - textBlockHeight) / 2.0
      startY = y + topOffset + lineHeight * 0.75
    of ALIGN_BOTTOM:
      # Position text at the bottom
      let availableSpace = height - cell.style.padding.top - cell.style.padding.bottom
      startY = y + cell.style.padding.top + availableSpace - totalTextHeight + lineHeight * 0.75
    else:
      # Default to top alignment
      startY = y + cell.style.padding.top + lineHeight * 0.75
    
    # Draw each line
    for lineIdx, line in cell.wrappedLines:
      if line.len > 0:
        let lineWidth = page.getTextWidth(line)
        
        # Calculate horizontal position for this line
        var textX = x + cell.style.padding.left
        case cell.style.horizontalAlign
        of ALIGN_CENTER:
          textX = x + (width - lineWidth) / 2.0
        of ALIGN_RIGHT:
          textX = x + width - lineWidth - cell.style.padding.right
        else:
          discard
        
        let textY = startY + float64(lineIdx) * lineHeight
        page.drawText(textX, textY, line)
    
    page.restoreState()

proc drawRows*(table: Table, page: ContentBase, startRow, endRow: int, 
              x, y: float64, maxWidth: float64 = 0.0, 
              includeHeaders: bool = false): tuple[width, height: float64] =
  ## Draws a subset of table rows from startRow to endRow (inclusive).
  ## If includeHeaders is true, also draws header rows at the top.
  ## Returns the dimensions (width, height) used.
  ## This enables manual page wrapping by drawing different row ranges on different pages.
  
  # Get page dimensions
  let pageSize = page.getPageSize()
  let pageWidth = page.toUser(pageSize.width.toPT)
  let rightMargin = 10.0
  let availableWidth = pageWidth - x - rightMargin
  
  var effectiveMaxWidth = availableWidth
  if maxWidth > 0 and maxWidth < effectiveMaxWidth:
    effectiveMaxWidth = maxWidth
  
  # Calculate dimensions (reuse existing calculations)
  table.calculateColumnWidths(page, effectiveMaxWidth)
  table.calculateRowHeights(page)
  
  var currentY = y
  let startY = y
  
  # First, draw header rows if requested
  if includeHeaders:
    # Find header rows (those with headerStyle)
    for row in table.rows:
      var isHeader = false
      if row.cells.len > 0:
        # Check if this row uses header style
        let firstCell = row.cells[0]
        if firstCell.style.backgroundColor == table.headerStyle.backgroundColor:
          isHeader = true
      
      if isHeader:
        var currentX = x
        for i, cell in row.cells:
          if i < table.columnWidths.len:
            var cellWidth = table.columnWidths[i]
            if cell.colspan > 1:
              for j in 1 ..< cell.colspan:
                if i + j < table.columnWidths.len:
                  cellWidth += table.columnWidths[i + j]
            page.drawCell(cell, currentX, currentY, cellWidth, row.height)
            currentX += cellWidth
        currentY += row.height
  
  # Draw the specified range of rows
  let actualEndRow = min(endRow, table.rows.len - 1)
  for rowIdx in startRow .. actualEndRow:
    if rowIdx >= 0 and rowIdx < table.rows.len:
      let row = table.rows[rowIdx]
      var currentX = x
      
      for i, cell in row.cells:
        if i < table.columnWidths.len:
          var cellWidth = table.columnWidths[i]
          if cell.colspan > 1:
            for j in 1 ..< cell.colspan:
              if i + j < table.columnWidths.len:
                cellWidth += table.columnWidths[i + j]
          page.drawCell(cell, currentX, currentY, cellWidth, row.height)
          currentX += cellWidth
      currentY += row.height
  
  result.width = table.totalWidth
  result.height = currentY - startY

# Convenience method to draw a simple table from 2D string array with auto-wrapping
proc drawSimpleTable*[T: ContentBase](page: var T, doc: auto, currentY: var float64, 
                     data: seq[seq[string]], hasHeader: bool = true, 
                     maxWidth: float64 = 190.0, spacing: float64 = 0.0): tuple[width, height: float64] =
  ## Convenience method to quickly draw a table from a 2D string array.
  ## Automatically handles page wrapping when needed.
  ## Returns the total width and height used across all pages.
  if data.len == 0:
    return (0.0, 0.0)
  
  var table = newTable(10, currentY, autoFit = true)
  
  for rowIdx, rowData in data:
    if rowIdx == 0 and hasHeader:
      table.addHeaderRow(rowData)
    else:
      table.addDataRow(rowData)
  
  result = table.draw(page, doc, currentY, maxWidth, spacing)

type
  RowSplit* = object
    startRow*: int
    endRow*: int
    height*: float64

proc draw*[T: ContentBase](table: Table, page: var T, doc: auto, 
           currentY: var float64, maxWidth: float64 = 190.0, 
           spacing: float64 = 0.0): tuple[width, height: float64] =
  ## Draws table with automatic page wrapping as needed.
  ## Updates `page` and `currentY` references for next element.
  ## Automatically copies font settings from the original page to new pages.
  ## Returns total dimensions (width, height) used across all pages.
  
  # Save current font settings to restore on new pages
  let currentFont = page.state.gState.font
  let currentFontSize = page.state.gState.fontSize
  
  # Calculate page splits
  var splits = table.calculatePageSplits(page, currentY, maxWidth)
  
  # If no splits (table doesn't fit), start on new page
  if splits.len == 0:
    let pageSize = page.getPageSize()
    page = doc.addPage(pageSize, PGO_PORTRAIT)
    # Restore font settings on new page by copying font state and outputting PDF command
    if currentFont != nil:
      page.state.gState.font = currentFont
      page.state.gState.fontSize = currentFontSize
      page.put("BT /F", $currentFont.ID, " ", $currentFontSize, " Tf ET")
    currentY = 10.0
    splits = table.calculatePageSplits(page, currentY, maxWidth)
  
  # Draw each split on its page
  var totalHeight = 0.0
  for splitIdx, split in splits:
    if splitIdx > 0:
      let pageSize = page.getPageSize()
      page = doc.addPage(pageSize, PGO_PORTRAIT)
      # Restore font settings on new page by copying font state and outputting PDF command
      if currentFont != nil:
        page.state.gState.font = currentFont
        page.state.gState.fontSize = currentFontSize
        page.put("BT /F", $currentFont.ID, " ", $currentFontSize, " Tf ET")
      currentY = 10.0
    
    let dims = table.drawRows(page, split.startRow, split.endRow, 
                             10, currentY, maxWidth, includeHeaders = true)
    totalHeight += dims.height
    currentY += dims.height
  
  # Add spacing after table
  currentY += spacing
  
  result.width = table.totalWidth
  result.height = totalHeight

proc calculatePageSplits*(table: Table, page: ContentBase, startY: float64, 
                         maxWidth: float64 = 0.0): seq[RowSplit] =
  ## Calculates how to split table rows across pages.
  ## Returns a sequence of RowSplit objects indicating which rows fit on each page.
  ## Use this information to manually draw the table across multiple pages.
  
  # Get page dimensions
  let pageSize = page.getPageSize()
  let pageWidth = page.toUser(pageSize.width.toPT)
  let pageHeight = page.toUser(pageSize.height.toPT)
  let bottomMargin = 10.0
  
  # Calculate effective width
  var effectiveMaxWidth = pageWidth - table.x - 10.0
  if maxWidth > 0 and maxWidth < effectiveMaxWidth:
    effectiveMaxWidth = maxWidth
  
  # Calculate table dimensions
  table.calculateColumnWidths(page, effectiveMaxWidth)
  table.calculateRowHeights(page)
  
  result = @[]
  if table.rows.len == 0:
    return
  
  # Detect if first row is a header by checking if it uses header style
  var hasHeader = false
  var headerHeight = 0.0
  if table.rows.len > 0 and table.rows[0].cells.len > 0:
    let firstCell = table.rows[0].cells[0]
    if firstCell.style.backgroundColor == table.headerStyle.backgroundColor:
      hasHeader = true
      headerHeight = table.rows[0].height
  
  var currentRow = if hasHeader: 1 else: 0  # Start after header if present, otherwise from 0
  var isFirstPage = true
  let topMargin = 10.0  # Standard top margin for new pages
  
  while currentRow < table.rows.len:
    # Calculate available height for this page
    let availableHeight = if isFirstPage:
      pageHeight - startY - bottomMargin
    else:
      pageHeight - topMargin - bottomMargin
    
    # Determine how many rows fit (header is drawn separately by drawRows)
    var heightUsed = headerHeight  # Include header height in calculation
    var lastRow = currentRow - 1
    
    for rowIdx in currentRow ..< table.rows.len:
      let totalHeightWithThisRow = heightUsed + table.rows[rowIdx].height
      if totalHeightWithThisRow <= availableHeight:
        heightUsed = totalHeightWithThisRow
        lastRow = rowIdx
      else:
        break
    
    # Add this page's split
    if lastRow >= currentRow:
      result.add(RowSplit(startRow: currentRow, endRow: lastRow, height: heightUsed))
      currentRow = lastRow + 1
      isFirstPage = false
    else:
      # No rows fit on this page
      if isFirstPage:
        # On first page, if not even one data row fits with header, return empty
        # This signals caller to move entire table to a new page
        result = @[]
        return
      else:
        # On subsequent pages, this means the row is too large
        echo "Warning: Row ", currentRow, " (height: ", table.rows[currentRow].height, ") too large to fit on page (available: ", availableHeight, ")"
        break
