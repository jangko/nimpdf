import FontIOStreams, FontData

const
    kVersion = 0
    kNumGlyphs = 4

    #version 1.0
    kMaxPoints = 6
    kMaxContours = 8
    kMaxCompositePoints = 10
    kMaxCompositeContours = 12
    kMaxZones = 14
    kMaxTwilightPoints = 16
    kMaxStorage = 18
    kMaxFunctionDefs = 20
    kMaxInstructionDefs = 22
    kMaxStackElements = 24
    kMaxSizeOfInstructions = 26
    kMaxComponentElements = 28
    kMaxComponentDepth = 30

type
    MAXPTable* = ref object of FontTable

proc TableVersion*(t: MAXPTable): int = t.data.ReadFixed(kVersion)
proc NumGlyphs*(t: MAXPTable): int = t.data.ReadUShort(kNumGlyphs)
proc MaxPoints*(t: MAXPTable): int = t.data.ReadUShort(kMaxPoints)
proc MaxContours*(t: MAXPTable): int = t.data.ReadUShort(kMaxContours)
proc MaxCompositePoints*(t: MAXPTable): int = t.data.ReadUShort(kMaxCompositePoints)
proc MaxCompositeContours*(t: MAXPTable): int = t.data.ReadUShort(kMaxCompositeContours)
proc MaxZones*(t: MAXPTable): int = t.data.ReadUShort(kMaxZones)
proc MaxTwilightPoints*(t: MAXPTable): int = t.data.ReadUShort(kMaxTwilightPoints)
proc MaxStorage*(t: MAXPTable): int = t.data.ReadUShort(kMaxStorage)
proc MaxFunctionDefs*(t: MAXPTable): int = t.data.ReadUShort(kMaxFunctionDefs)
proc MaxStackElements*(t: MAXPTable): int = t.data.ReadUShort(kMaxStackElements)
proc MaxSizeOfInstructions*(t: MAXPTable): int = t.data.ReadUShort(kMaxSizeOfInstructions)
proc MaxComponentElements*(t: MAXPTable): int = t.data.ReadUShort(kMaxComponentElements)
proc MaxComponentDepth*(t: MAXPTable): int = t.data.ReadUShort(kMaxComponentDepth)

proc makeMAXPTable*(header: Header, data: FontData): MAXPTable =
    new(result)
    initFontTable(result, header, data)
#---------------------------------------
proc SetTableVersion*(t: MAXPTable, version: int) = discard t.data.WriteUShort(kVersion, version)
proc SetNumGlyphs*(t: MAXPTable, num_glyphs: int) = discard t.data.WriteUShort(kNumGlyphs, num_glyphs)
proc SetMaxPoints*(t: MAXPTable, max_points: int) = discard t.data.WriteUShort(kMaxPoints, max_points)
proc SetMaxContours*(t: MAXPTable, max_contours: int) = discard t.data.WriteUShort(kMaxContours, max_contours)
proc SetMaxCompositePoints*(t: MAXPTable, max_composite_points: int) = discard t.data.WriteUShort(kMaxCompositePoints, max_composite_points)
proc SetMaxCompositeContours*(t: MAXPTable, max_composite_contours: int) = discard t.data.WriteUShort(kMaxCompositeContours, max_composite_contours)
proc SetMaxZones*(t: MAXPTable, max_zones: int) = discard t.data.WriteUShort(kMaxZones, max_zones)
proc SetMaxTwilightPoints*(t: MAXPTable, max_twilight_points: int) = discard t.data.WriteUShort(kMaxTwilightPoints, max_twilight_points)
proc SetMaxStorage*(t: MAXPTable, max_storage: int) = discard t.data.WriteUShort(kMaxStorage, max_storage)
proc SetMaxFunctionDefs*(t: MAXPTable, max_function_defs: int) = discard t.data.WriteUShort(kMaxFunctionDefs, max_function_defs)
proc SetMaxStackElements*(t: MAXPTable, max_stack_elements: int) = discard t.data.WriteUShort(kMaxStackElements, max_stack_elements)
proc SetMaxSizeOfInstructions*(t: MAXPTable, max_size_of_instructions: int) = discard t.data.WriteUShort(kMaxSizeOfInstructions, max_size_of_instructions)
proc SetMaxComponentElements*(t: MAXPTable, max_component_elements: int) = discard t.data.WriteUShort(kMaxComponentElements, max_component_elements)
proc SetMaxComponentDepth*(t: MAXPTable, max_component_depth: int) = discard t.data.WriteUShort(kMaxComponentDepth, max_component_depth)