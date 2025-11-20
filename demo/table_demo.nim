# Table demo for nimPDF
# Comprehensive demonstration of table features

import ../nimPDF/nimPDF

proc addDescription(page: Page, title: string, description: seq[string], y: var float64) =
  ## Helper to add a description section on the current page
  # Font sizes are in MM in nimPDF by default
  page.setFont("Helvetica", {FS_BOLD}, 4.5)  # ~14pt
  page.drawText(10, y, title)
  
  y += 7.0
  page.setFont("Helvetica", {FS_REGULAR}, 3.2)  # ~10pt
  
  for line in description:
    page.drawText(10, y, line)
    y += 4.5
  
  y += 3.0  # Extra spacing after description

proc main() =
  var doc = newPDF()
  var page = doc.addPage(getSizeFromName("A4"), PGO_PORTRAIT)
  
  # Title page - Professional styling
  page.setFont("Helvetica", {FS_BOLD}, 7)  # ~20pt
  page.drawText(20, 80, "Table System Documentation")
  page.setFont("Helvetica", {FS_REGULAR}, 4)  # ~12pt
  page.drawText(20, 92, "Feature Demonstrations and Usage Examples")
  page.setFont("Helvetica", {FS_REGULAR}, 3)  # ~9pt
  
  # Start examples on new page
  page = doc.addPage(getSizeFromName("A4"), PGO_PORTRAIT)
  page.setFont("Helvetica", {FS_REGULAR}, 8)  # Smaller default font for tables
  
  var currentY = 15.0
  let spacing = 8.0  # Space between sections
  
  # Example 1: Quick table with drawSimpleTable
  echo "Creating quick simple table..."
  addDescription(page, "Example 1: Quick Tables with drawSimpleTable()", @[
    "The fastest way to create a table from a 2D array.",
    "Automatically handles page wrapping and column distribution."
  ], currentY)
  
  let quickData = @[
    @["Product", "Price", "Stock"],
    @["Laptop", "$999", "15"],
    @["Mouse", "$25", "50"],
    @["Keyboard", "$75", "30"]
  ]
  
  let dims1 = page.drawSimpleTable(doc, currentY, quickData, hasHeader = true, maxWidth = 190, spacing = spacing)
  
  # Example 2: Basic table with manual construction
  echo "Creating basic table..."
  if currentY > 220:
    page = doc.addPage(getSizeFromName("A4"), PGO_PORTRAIT)
    page.setFont("Helvetica", {FS_REGULAR}, 8)
    currentY = 15.0
  
  addDescription(page, "Example 2: Manual Table Construction", @[
    "Build tables row-by-row for more control over content.",
    "All tables automatically wrap to new pages when needed."
  ], currentY)
  
  var basicTable = newTable(10, currentY, autoFit = true)
  basicTable.addHeaderRow("Department", "Manager", "Location", "Status")
  basicTable.addDataRow("Sales", "Alice Johnson", "New York", "Active")
  basicTable.addDataRow("Engineering", "Bob Smith", "London", "Active")
  basicTable.addDataRow("Marketing", "Charlie Brown", "Paris", "Active")
  
  let dims2 = basicTable.draw(page, doc, currentY, 190, spacing)
  
  # Example 3: Custom styled table
  echo "Creating custom styled table..."
  if currentY > 220:  # Check if we need a new page
    page = doc.addPage(getSizeFromName("A4"), PGO_PORTRAIT)
    page.setFont("Helvetica", {FS_REGULAR}, 8)
    currentY = 15.0
  
  addDescription(page, "Example 3: Professional Styling & Merged Cells", @[
    "Corporate styling with custom colors, borders, and cell spanning.",
    "Demonstrates professional invoice/report layouts."
  ], currentY)
  
  var customTable = newTable(10, currentY, autoFit = true)
  
  # Professional business styling - more subdued colors
  customTable.defaultCellStyle.backgroundColor = initRGB(1.0, 1.0, 1.0)
  customTable.defaultCellStyle.padding = (left: 4.0, right: 4.0, top: 2.5, bottom: 2.5)
  customTable.defaultCellStyle.border = initCellBorder(0.5, initRGB(0.6, 0.6, 0.6))
  
  customTable.headerStyle.backgroundColor = initRGB(0.25, 0.35, 0.55)
  customTable.headerStyle.textColor = initRGB(1.0, 1.0, 1.0)
  customTable.headerStyle.border = initCellBorder(0.5, initRGB(0.2, 0.3, 0.5))
  
  # Add header
  customTable.addHeaderRow("Product", "Price", "Quantity", "Total")
  
  # Add data rows
  customTable.addDataRow("Widget A", "$19.99", "5", "$99.95")
  customTable.addDataRow("Widget B", "$24.50", "3", "$73.50")
  customTable.addDataRow("Widget C", "$15.00", "10", "$150.00")
  
  # Add a total row with custom style, merged cells, and bold font
  var totalStyle = initCellStyle()
  totalStyle.backgroundColor = initRGB(0.92, 0.92, 0.92)
  totalStyle.horizontalAlign = ALIGN_RIGHT
  totalStyle.verticalAlign = ALIGN_MIDDLE
  totalStyle.border = initCellBorder(1.0, initRGB(0.4, 0.4, 0.4))
  totalStyle.fontBold = true
  totalStyle.fontSize = 6
  
  # Create a cell that spans 3 columns for "Total:" label
  var totalLabelCell = newCell("Total:", totalStyle)
  totalLabelCell.colspan = 3
  
  var totalRow = newRow(
    totalLabelCell,
    newCell("$323.45", totalStyle)
  )
  customTable.addRow(totalRow)
  
  let dims3 = customTable.draw(page, doc, currentY, 190, spacing)
  
  # Example 4: Table with different alignments
  echo "Creating alignment demo table..."
  # Start Example 4 on a fresh page to keep heading, description, and table together
  page = doc.addPage(getSizeFromName("A4"), PGO_PORTRAIT)
  page.setFont("Helvetica", {FS_REGULAR}, 8)
  currentY = 15.0
  
  addDescription(page, "Example 4: Text Alignment Options", @[
    "Each cell shows text positioned at that alignment.",
    "Demonstrates all 9 combinations of horizontal and vertical alignment."
  ], currentY)
  
  var alignTable = newTable(10, currentY, autoFit = true)
  
  # Header
  alignTable.addHeaderRow("Left", "Center", "Right")
  
  # Define all 9 alignment styles with moderate padding to show positioning clearly
  var topLeft = initCellStyle()
  topLeft.horizontalAlign = ALIGN_LEFT
  topLeft.verticalAlign = ALIGN_TOP
  topLeft.padding = (left: 3.0, right: 3.0, top: 2.0, bottom: 2.0)
  
  var topCenter = initCellStyle()
  topCenter.horizontalAlign = ALIGN_CENTER
  topCenter.verticalAlign = ALIGN_TOP
  topCenter.padding = (left: 3.0, right: 3.0, top: 2.0, bottom: 2.0)
  
  var topRight = initCellStyle()
  topRight.horizontalAlign = ALIGN_RIGHT
  topRight.verticalAlign = ALIGN_TOP
  topRight.padding = (left: 3.0, right: 3.0, top: 2.0, bottom: 2.0)
  
  var middleLeft = initCellStyle()
  middleLeft.horizontalAlign = ALIGN_LEFT
  middleLeft.verticalAlign = ALIGN_MIDDLE
  middleLeft.padding = (left: 3.0, right: 3.0, top: 2.0, bottom: 2.0)
  
  var middleCenter = initCellStyle()
  middleCenter.horizontalAlign = ALIGN_CENTER
  middleCenter.verticalAlign = ALIGN_MIDDLE
  middleCenter.padding = (left: 3.0, right: 3.0, top: 2.0, bottom: 2.0)
  
  var middleRight = initCellStyle()
  middleRight.horizontalAlign = ALIGN_RIGHT
  middleRight.verticalAlign = ALIGN_MIDDLE
  middleRight.padding = (left: 3.0, right: 3.0, top: 2.0, bottom: 2.0)
  
  var bottomLeft = initCellStyle()
  bottomLeft.horizontalAlign = ALIGN_LEFT
  bottomLeft.verticalAlign = ALIGN_BOTTOM
  bottomLeft.padding = (left: 3.0, right: 3.0, top: 2.0, bottom: 2.0)
  
  var bottomCenter = initCellStyle()
  bottomCenter.horizontalAlign = ALIGN_CENTER
  bottomCenter.verticalAlign = ALIGN_BOTTOM
  bottomCenter.padding = (left: 3.0, right: 3.0, top: 2.0, bottom: 2.0)
  
  var bottomRight = initCellStyle()
  bottomRight.horizontalAlign = ALIGN_RIGHT
  bottomRight.verticalAlign = ALIGN_BOTTOM
  bottomRight.padding = (left: 3.0, right: 3.0, top: 2.0, bottom: 2.0)
  
  # Top row - set minHeight to make vertical alignment visible
  var topRow = newRow(
    newCell("Top-Left", topLeft),
    newCell("Top-Center", topCenter),
    newCell("Top-Right", topRight)
  )
  topRow.minHeight = 30.0
  alignTable.addRow(topRow)
  
  # Middle row
  var middleRow = newRow(
    newCell("Middle-Left", middleLeft),
    newCell("Middle-Center", middleCenter),
    newCell("Middle-Right", middleRight)
  )
  middleRow.minHeight = 30.0
  alignTable.addRow(middleRow)
  
  # Bottom row
  var bottomRow = newRow(
    newCell("Bottom-Left", bottomLeft),
    newCell("Bottom-Center", bottomCenter),
    newCell("Bottom-Right", bottomRight)
  )
  bottomRow.minHeight = 30.0
  alignTable.addRow(bottomRow)
  
  let dims4 = alignTable.draw(page, doc, currentY, 190, spacing)
  
  # Example 5: Table with different fonts per cell
  echo "Creating font demo table..."
  if currentY > 220:
    page = doc.addPage(getSizeFromName("A4"), PGO_PORTRAIT)
    page.setFont("Helvetica", {FS_REGULAR}, 8)
    currentY = 15.0
  
  addDescription(page, "Example 5: Font Customization", @[
    "Per-cell font control for emphasis and readability.",
    "Supports Helvetica, Times, Courier with bold and italic styles."
  ], currentY)
  
  var fontTable = newTable(10, currentY, autoFit = true)
  
  fontTable.addHeaderRow("Font", "Style", "Example")
  
  # Regular font
  var regularStyle = initCellStyle()
  fontTable.addRow(newRow(
    newCell("Helvetica", regularStyle),
    newCell("Regular", regularStyle),
    newCell("The quick brown fox", regularStyle)
  ))
  
  # Bold font
  var boldStyle = initCellStyle()
  boldStyle.fontBold = true
  fontTable.addRow(newRow(
    newCell("Helvetica", regularStyle),
    newCell("Bold", regularStyle),
    newCell("The quick brown fox", boldStyle)
  ))
  
  # Italic font
  var italicStyle = initCellStyle()
  italicStyle.fontItalic = true
  fontTable.addRow(newRow(
    newCell("Helvetica", regularStyle),
    newCell("Italic", regularStyle),
    newCell("The quick brown fox", italicStyle)
  ))
  
  # Large font
  var largeStyle = initCellStyle()
  largeStyle.fontSize = 7.0  # ~20pt
  largeStyle.fontBold = true
  fontTable.addRow(newRow(
    newCell("Helvetica", regularStyle),
    newCell("Large Bold", regularStyle),
    newCell("The quick brown fox", largeStyle)
  ))
  
  # Times font
  var timesStyle = initCellStyle()
  timesStyle.fontFamily = "Times"
  fontTable.addRow(newRow(
    newCell("Times", regularStyle),
    newCell("Regular", regularStyle),
    newCell("The quick brown fox", timesStyle)
  ))
  
  # Courier font
  var courierStyle = initCellStyle()
  courierStyle.fontFamily = "Courier"
  fontTable.addRow(newRow(
    newCell("Courier", regularStyle),
    newCell("Regular", regularStyle),
    newCell("The quick brown fox", courierStyle)
  ))
  
  let dims5 = fontTable.draw(page, doc, currentY, 190, spacing)
  
  # Example 6: Financial report table with page wrapping
  echo "Creating financial report table..."
  if currentY > 180:
    page = doc.addPage(getSizeFromName("A4"), PGO_PORTRAIT)
    page.setFont("Helvetica", {FS_REGULAR}, 8)
    currentY = 15.0
  
  addDescription(page, "Example 6: Financial Reports with Auto-Pagination", @[
    "Quarterly financial data with automatic page breaks.",
    "Headers repeat on new pages for multi-page reports."
  ], currentY)
  
  var reportTable = newTable(10, currentY, autoFit = true)
  
  # Professional financial report styling
  reportTable.headerStyle.backgroundColor = initRGB(0.2, 0.3, 0.5)
  reportTable.headerStyle.textColor = initRGB(1.0, 1.0, 1.0)
  reportTable.defaultCellStyle.padding = (left: 5.0, right: 5.0, top: 2.5, bottom: 2.5)
  
  reportTable.addHeaderRow("Period", "Revenue", "Expenses", "Net Profit", "Margin %")
  
  # Add multiple years of quarterly data to demonstrate pagination
  reportTable.addDataRow("Q1 2021", "$98,450", "$72,300", "$26,150", "26.6%")
  reportTable.addDataRow("Q2 2021", "$105,200", "$78,900", "$26,300", "25.0%")
  reportTable.addDataRow("Q3 2021", "$112,800", "$82,400", "$30,400", "27.0%")
  reportTable.addDataRow("Q4 2021", "$118,500", "$86,200", "$32,300", "27.3%")
  
  reportTable.addDataRow("Q1 2022", "$125,000", "$87,000", "$38,000", "30.4%")
  reportTable.addDataRow("Q2 2022", "$132,500", "$91,200", "$41,300", "31.2%")
  reportTable.addDataRow("Q3 2022", "$138,900", "$94,800", "$44,100", "31.7%")
  reportTable.addDataRow("Q4 2022", "$145,200", "$98,400", "$46,800", "32.2%")
  
  reportTable.addDataRow("Q1 2023", "$152,000", "$102,000", "$50,000", "32.9%")
  reportTable.addDataRow("Q2 2023", "$158,500", "$105,200", "$53,300", "33.6%")
  reportTable.addDataRow("Q3 2023", "$165,900", "$108,800", "$57,100", "34.4%")
  reportTable.addDataRow("Q4 2023", "$172,200", "$112,400", "$59,800", "34.7%")
  
  reportTable.addDataRow("Q1 2024", "$180,000", "$115,000", "$65,000", "36.1%")
  reportTable.addDataRow("Q2 2024", "$187,500", "$118,200", "$69,300", "37.0%")
  reportTable.addDataRow("Q3 2024", "$195,900", "$121,800", "$74,100", "37.8%")
  reportTable.addDataRow("Q4 2024", "$203,200", "$125,400", "$77,800", "38.3%")
  
  reportTable.addDataRow("Q1 2025", "$210,000", "$128,000", "$82,000", "39.0%")
  reportTable.addDataRow("Q2 2025", "$218,500", "$131,200", "$87,300", "40.0%")
  reportTable.addDataRow("Q3 2025", "$226,900", "$134,800", "$92,100", "40.6%")
  reportTable.addDataRow("Q4 2025", "$235,200", "$138,400", "$96,800", "41.2%")
  
  # Draw with automatic page wrapping - will span multiple pages
  let dims6 = reportTable.draw(page, doc, currentY, 190, spacing)
  
  # Example 7: Table with text wrapping
  echo "Creating text wrapping demo table..."
  # draw() already positioned us correctly, just check if we need more space
  if currentY > 220:
    page = doc.addPage(getSizeFromName("A4"), PGO_PORTRAIT)
    page.setFont("Helvetica", {FS_REGULAR}, 8)
    currentY = 15.0
  
  addDescription(page, "Example 7: Automatic Text Wrapping", @[
    "Long text content wraps automatically within cells.",
    "Row heights adjust dynamically to fit multi-line content."
  ], currentY)
  
  var wrapTable = newTable(10, currentY, autoFit = true)
  
  wrapTable.headerStyle.backgroundColor = initRGB(0.25, 0.35, 0.55)
  wrapTable.headerStyle.textColor = initRGB(1.0, 1.0, 1.0)
  
  wrapTable.addHeaderRow("Feature", "Description", "Status")
  wrapTable.addDataRow(
    "Text Wrapping", 
    "Automatically wraps long text content within table cells to fit the available column width without overflow",
    "Active"
  )
  wrapTable.addDataRow(
    "Auto-fit Columns",
    "Distributes available space proportionally across columns based on content requirements",
    "Active"
  )
  wrapTable.addDataRow(
    "Custom Styling",
    "Supports custom colors, borders, padding, and alignment options for individual cells or entire tables",
    "Active"
  )
  
  # Draw with automatic page wrapping
  let dims7 = wrapTable.draw(page, doc, currentY, 190, spacing)
  
  # Example 8: Auto-sizing demonstration
  echo "Creating auto-sizing demo table..."
  # draw() already positioned us correctly
  if currentY > 220:
    page = doc.addPage(getSizeFromName("A4"), PGO_PORTRAIT)
    page.setFont("Helvetica", {FS_REGULAR}, 8)
    currentY = 15.0
  
  addDescription(page, "Example 8: Smart Font Sizing", @[
    "Automatic font scaling prevents text overflow while maintaining readability.",
    "Auto-shrink mode and scale-to-fit options with minimum size enforcement.",
    "The middle column is intentionally narrow to demonstrate the scaling effect."
  ], currentY)
  
  var autoSizeTable = newTable(10, currentY, autoFit = true)
  
  autoSizeTable.headerStyle.backgroundColor = initRGB(0.25, 0.35, 0.55)
  autoSizeTable.headerStyle.textColor = initRGB(1.0, 1.0, 1.0)

  autoSizeTable.addHeaderRow("Mode", "Example Text", "Behavior")

  # Regular mode with overflow (text will auto-shrink)
  autoSizeTable.addDataRow(
    "Auto-shrink",
    "ThisIsAnExtremelyLongWordThatDefinitelyWillNotFitInTheCellWithoutScaling",
    "Font size reduced automatically"
  )
  
  # Another auto-shrink example
  autoSizeTable.addDataRow(
    "Auto-shrink",
    "Pneumonoultramicroscopicsilicovolcanoconiosis",
    "Longest English word shrinks to fit"
  )
  
  # ScaleToFit mode - keeps text on one line
  var scaleStyle = initCellStyle()
  scaleStyle.scaleToFit = true
  scaleStyle.fontFamily = "Courier"
  autoSizeTable.addRow(newRow(
    newCell("Scale-to-fit", autoSizeTable.defaultCellStyle),
    newCell("The quick brown fox jumps over the lazy dog and runs through the forest", scaleStyle),
    newCell("Scaled horizontally to single line", autoSizeTable.defaultCellStyle)
  ))
  
  # ScaleToFit with minimum font size
  var scaleWithMinStyle = initCellStyle()
  scaleWithMinStyle.scaleToFit = true
  scaleWithMinStyle.minFontSize = 6.0
  scaleWithMinStyle.fontFamily = "Times"
  autoSizeTable.addRow(newRow(
    newCell("Scale w/ 6pt min", autoSizeTable.defaultCellStyle),
    newCell("This is a very long text that will scale down but will not go below 6pt minimum font size", scaleWithMinStyle),
    newCell("Enforces 6pt minimum", autoSizeTable.defaultCellStyle)
  ))
  
  # ScaleToFit with tiny minimum
  var tinyMinStyle = initCellStyle()
  tinyMinStyle.scaleToFit = true
  tinyMinStyle.minFontSize = 3.0
  autoSizeTable.addRow(newRow(
    newCell("Scale w/ 3pt min", autoSizeTable.defaultCellStyle),
    newCell("This is an extremely long text that will scale to a very tiny size with only 3pt minimum allowing much smaller text", tinyMinStyle),
    newCell("Can become very small", autoSizeTable.defaultCellStyle)
  ))
  
  # Multi-line with scaleToFit (respects \n)
  var multiLineStyle = initCellStyle()
  multiLineStyle.scaleToFit = true
  autoSizeTable.addRow(newRow(
    newCell("Multi-line scale", autoSizeTable.defaultCellStyle),
    newCell("Line 1: First line\nLine 2: Second line\nLine 3: Third line", multiLineStyle),
    newCell("Respects \\n, scales each line", autoSizeTable.defaultCellStyle)
  ))
  
  # Bold with scale-to-fit
  var boldScaleStyle = initCellStyle()
  boldScaleStyle.scaleToFit = true
  boldScaleStyle.fontBold = true
  autoSizeTable.addRow(newRow(
    newCell("Bold + scale", autoSizeTable.defaultCellStyle),
    newCell("Bold text also scales: The quick brown fox", boldScaleStyle),
    newCell("Bold fonts supported", autoSizeTable.defaultCellStyle)
  ))
  
  # Italic with scale-to-fit
  var italicScaleStyle = initCellStyle()
  italicScaleStyle.scaleToFit = true
  italicScaleStyle.fontItalic = true
  italicScaleStyle.fontFamily = "Helvetica"
  autoSizeTable.addRow(newRow(
    newCell("Italic + scale", autoSizeTable.defaultCellStyle),
    newCell("Italic text scales too: The quick brown fox jumps", italicScaleStyle),
    newCell("Italic fonts supported", autoSizeTable.defaultCellStyle)
  ))
  
  # Use narrower width (140mm instead of 190mm) to force more aggressive scaling
  let dims8 = autoSizeTable.draw(page, doc, currentY, 140, spacing)
  
  # Save the document
  echo "Saving table_demo.pdf..."
  discard doc.writePDF("table_demo.pdf")
  echo "Done! Created table_demo.pdf"

main()
