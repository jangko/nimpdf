# Copyright (c) 2015 Andri Lim
#
# Distributed under the MIT license
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------
import FontData

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

proc TableVersion*(t: MAXPTable): int = t.data.readFixed(kVersion)
proc NumGlyphs*(t: MAXPTable): int = t.data.readUShort(kNumGlyphs)
proc MaxPoints*(t: MAXPTable): int = t.data.readUShort(kMaxPoints)
proc MaxContours*(t: MAXPTable): int = t.data.readUShort(kMaxContours)
proc MaxCompositePoints*(t: MAXPTable): int = t.data.readUShort(kMaxCompositePoints)
proc MaxCompositeContours*(t: MAXPTable): int = t.data.readUShort(kMaxCompositeContours)
proc MaxZones*(t: MAXPTable): int = t.data.readUShort(kMaxZones)
proc MaxTwilightPoints*(t: MAXPTable): int = t.data.readUShort(kMaxTwilightPoints)
proc MaxStorage*(t: MAXPTable): int = t.data.readUShort(kMaxStorage)
proc MaxFunctionDefs*(t: MAXPTable): int = t.data.readUShort(kMaxFunctionDefs)
proc MaxInstructionDefs*(t: MAXPTable): int = t.data.readUShort(kMaxInstructionDefs)
proc MaxStackElements*(t: MAXPTable): int = t.data.readUShort(kMaxStackElements)
proc MaxSizeOfInstructions*(t: MAXPTable): int = t.data.readUShort(kMaxSizeOfInstructions)
proc MaxComponentElements*(t: MAXPTable): int = t.data.readUShort(kMaxComponentElements)
proc MaxComponentDepth*(t: MAXPTable): int = t.data.readUShort(kMaxComponentDepth)

proc newMAXPTable*(header: Header, data: FontData): MAXPTable =
  new(result)
  initFontTable(result, header, data)
#---------------------------------------
proc SetTableVersion*(t: MAXPTable, version: int) = discard t.data.writeUShort(kVersion, version)
proc SetNumGlyphs*(t: MAXPTable, num_glyphs: int) = discard t.data.writeUShort(kNumGlyphs, num_glyphs)
proc SetMaxPoints*(t: MAXPTable, max_points: int) = discard t.data.writeUShort(kMaxPoints, max_points)
proc SetMaxContours*(t: MAXPTable, max_contours: int) = discard t.data.writeUShort(kMaxContours, max_contours)
proc SetMaxCompositePoints*(t: MAXPTable, max_composite_points: int) = discard t.data.writeUShort(kMaxCompositePoints, max_composite_points)
proc SetMaxCompositeContours*(t: MAXPTable, max_composite_contours: int) = discard t.data.writeUShort(kMaxCompositeContours, max_composite_contours)
proc SetMaxZones*(t: MAXPTable, max_zones: int) = discard t.data.writeUShort(kMaxZones, max_zones)
proc SetMaxTwilightPoints*(t: MAXPTable, max_twilight_points: int) = discard t.data.writeUShort(kMaxTwilightPoints, max_twilight_points)
proc SetMaxStorage*(t: MAXPTable, max_storage: int) = discard t.data.writeUShort(kMaxStorage, max_storage)
proc SetMaxFunctionDefs*(t: MAXPTable, max_function_defs: int) = discard t.data.writeUShort(kMaxFunctionDefs, max_function_defs)
proc SetMaxInstructionDefs*(t: MAXPTable, max_instruction_defs: int) = discard t.data.writeUShort(kMaxInstructionDefs, max_instruction_defs)
proc SetMaxStackElements*(t: MAXPTable, max_stack_elements: int) = discard t.data.writeUShort(kMaxStackElements, max_stack_elements)
proc SetMaxSizeOfInstructions*(t: MAXPTable, max_size_of_instructions: int) = discard t.data.writeUShort(kMaxSizeOfInstructions, max_size_of_instructions)
proc SetMaxComponentElements*(t: MAXPTable, max_component_elements: int) = discard t.data.writeUShort(kMaxComponentElements, max_component_elements)

proc SetMaxComponentDepth*(t: MAXPTable, max_component_depth: int) = discard t.data.writeUShort(kMaxComponentDepth, max_component_depth)