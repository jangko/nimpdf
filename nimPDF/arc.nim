# Copyright (c) 2015 Andri Lim
#
# Distributed under the MIT license
# (See accompanying file LICENSE.txt)
#
#-------------------------------------
# this module try to approximate circle, arc, ellipse
# using Bezier cubic curve
# this module export arcTo, drawArc, and degree_to_radian

const
  bezier_arc_angle_epsilon = 0.01

type
  arc_cmd = enum
    LINE_TO, BEZIER_TO

  arc_approx = object
    cmd : arc_cmd
    num_vertices: int
    vertices: array[0..25, float64]

proc arc_to_bezier(cx, cy, rx, ry, start_angle, sweep_angle: float64, curve: var openArray[float64]) =
  let x0 = math.cos(sweep_angle / 2.0)
  let y0 = math.sin(sweep_angle / 2.0)
  let tx = (1.0 - x0) * 4.0 / 3.0
  let ty = y0 - tx * x0 / y0

  var px = [x0, x0 + tx, x0 + tx, x0]
  var py = [-y0, -ty, ty, y0]

  let sn = math.sin(start_angle + sweep_angle / 2.0)
  let cs = math.cos(start_angle + sweep_angle / 2.0)

  for i in 0..3:
    curve[i * 2]   = cx + rx * (px[i] * cs - py[i] * sn)
    curve[i * 2 + 1] = cy + ry * (px[i] * sn + py[i] * cs)

proc bezier_arc_centre(x, y, rx, ry, start, sweep : float64, approx: var arc_approx) =
  var sweep_angle = sweep
  var start_angle = start

  start_angle = start_angle mod (2.0 * math.PI).float64
  if sweep_angle >= 2.0 * math.PI: sweep_angle = 2.0 * math.PI
  if sweep_angle <= -2.0 * math.PI: sweep_angle = -2.0 * math.PI

  if abs(sweep_angle) < 1e-10:
    approx.num_vertices = 4
    approx.cmd = LINE_TO
    approx.vertices[0] = x + rx * math.cos(start_angle)
    approx.vertices[1] = y + ry * math.sin(start_angle)
    approx.vertices[2] = x + rx * math.cos(start_angle + sweep_angle)
    approx.vertices[3] = y + ry * math.sin(start_angle + sweep_angle)
    return

  var total_sweep = 0.0
  var local_sweep = 0.0
  var prev_sweep: float64

  approx.num_vertices = 2
  approx.cmd = BEZIER_TO
  var done = false
  var curve: array[0..7, float64]
  while true:
    if sweep_angle < 0.0:
      prev_sweep  = total_sweep
      local_sweep = -math.PI * 0.5
      total_sweep -= math.PI * 0.5
      if total_sweep <= (sweep_angle + bezier_arc_angle_epsilon):
        local_sweep = sweep_angle - prev_sweep
        done = true
    else:
      prev_sweep  = total_sweep
      local_sweep =  math.PI * 0.5
      total_sweep += math.PI * 0.5
      if total_sweep >= (sweep_angle - bezier_arc_angle_epsilon):
        local_sweep = sweep_angle - prev_sweep
        done = true

    arc_to_bezier(x, y, rx, ry, start_angle, local_sweep, curve)
    for i in 0..7:
      approx.vertices[approx.num_vertices - 2 + i] = curve[i]
    approx.num_vertices += 6
    start_angle += local_sweep

    if done or (approx.num_vertices >= 26):
      break

proc bezier_arc_endpoints(x0, y0, rrx, rry, angle: float64; large_arc_flag, sweep_flag: bool; x2, y2: float64; approx: var arc_approx) =
  var radii_ok = true
  var rx = rrx
  var ry = rry

  if rx < 0.0: rx = -rx
  if ry < 0.0: ry = -ry

  #Calculate the middle point between
  #the current and the final points
  #------------------------
  let dx2 = (x0 - x2) / 2.0
  let dy2 = (y0 - y2) / 2.0

  let cos_a = math.cos(angle)
  let sin_a = math.sin(angle)

  #Calculate (x1, y1)
  #------------------------
  let x1 =  cos_a * dx2 + sin_a * dy2
  let y1 = -sin_a * dx2 + cos_a * dy2

  #Ensure radii are large enough
  #-----------------------
  var prx = rx * rx
  var pry = ry * ry
  let px1 = x1 * x1
  let py1 = y1 * y1

  #Check that radii are large enough
  #------------------------
  let radii_check = px1/prx + py1/pry
  if radii_check > 1.0:
    rx = math.sqrt(radii_check) * rx
    ry = math.sqrt(radii_check) * ry
    prx = rx * rx
    pry = ry * ry
    if radii_check > 10.0: radii_ok = false


  #Calculate (cx1, cy1)
  #------------------------
  var sign = 1.0
  if large_arc_flag == sweep_flag:
    sign = -1.0
  var sq   = (prx*pry - prx*py1 - pry*px1) / (prx*py1 + pry*px1)
  if sq < 0: sq = 0
  let coef = sign * math.sqrt(sq)
  let cx1  = coef * ((rx * y1) / ry)
  let cy1  = coef * -((ry * x1) / rx)


  #Calculate (cx, cy) from (cx1, cy1)
  #------------------------
  let sx2 = (x0 + x2) / 2.0
  let sy2 = (y0 + y2) / 2.0
  let cx = sx2 + (cos_a * cx1 - sin_a * cy1)
  let cy = sy2 + (sin_a * cx1 + cos_a * cy1)

  #Calculate the start_angle (angle1) and the sweep_angle (dangle)
  #------------------------
  let ux =  (x1 - cx1) / rx
  let uy =  (y1 - cy1) / ry
  let vx = (-x1 - cx1) / rx
  let vy = (-y1 - cy1) / ry
  var p, n: float64

  #Calculate the angle start
  #------------------------
  n = math.sqrt(ux*ux + uy*uy)
  p = ux #(1 * ux) + (0 * uy)
  if uy < 0:
    sign = -1.0
  else:
    sign = 1.0

  var v = p / n
  if v < -1.0: v = -1.0
  if v > 1.0: v = 1.0
  let start_angle = sign * math.arccos(v)

  #Calculate the sweep angle
  #------------------------
  n = math.sqrt((ux*ux + uy*uy) * (vx*vx + vy*vy))
  p = ux * vx + uy * vy
  if (ux * vy - uy * vx) < 0:
    sign = -1.0
  else:
    sign = 1.0

  v = p / n
  if v < -1.0: v = -1.0
  if v > 1.0: v = 1.0

  var sweep_angle = sign * math.arccos(v);
  if (not sweep_flag) and (sweep_angle > 0):
    sweep_angle -= math.PI * 2.0
  elif sweep_flag and (sweep_angle < 0):
    sweep_angle += math.PI * 2.0

  #We can now build and transform the resulting arc
  #------------------------
  bezier_arc_centre(0.0, 0.0, rx, ry, start_angle, sweep_angle, approx)

  var mtx: Matrix2d = move(cx, cy)
  mtx = mtx & rotate(angle)

  var i = 2
  while i < approx.num_vertices - 2:
    mtx.apply(approx.vertices[i], approx.vertices[i + 1])
    inc(i, 2)

  #We must make sure that the starting and ending points
  #exactly coincide with the initial (x0,y0) and (x2,y2)
  approx.vertices[0] = x0
  approx.vertices[1] = y0
  if approx.num_vertices > 2:
    approx.vertices[approx.num_vertices - 2] = x2
    approx.vertices[approx.num_vertices - 1] = y2

proc draw_arc_approximation(self: Page, a: arc_approx) =
  if a.cmd == LINE_TO:
    self.lineTo(a.vertices[2], a.vertices[3])
  else:
    assert a.cmd == BEZIER_TO
    var i = 2
    while i < a.num_vertices:
      self.bezierCurveTo(a.vertices[i], a.vertices[i+1], a.vertices[i+2], a.vertices[i+3], a.vertices[i+4], a.vertices[i+5])
      inc(i, 6)

proc drawArc*(self: Page; cx, cy, rx, ry, start_angle, sweep_angle: float64) =
  var approx : arc_approx
  approx.num_vertices = 0

  bezier_arc_centre(cx, cy, rx, ry, degree_to_radian(start_angle), degree_to_radian(sweep_angle), approx)
  assert approx.num_vertices > 3

  self.moveTo(approx.vertices[0], approx.vertices[1])
  self.draw_arc_approximation(approx)


proc arcTo*(self: Page; x, y, rx, ry, angle: float64; large_arc_flag, sweep_flag: bool) =
  var approx : arc_approx
  approx.num_vertices = 0

  bezier_arc_endpoints(self.state.pathEndX, self.state.pathEndY, rx, ry, degree_to_radian(angle), large_arc_flag, sweep_flag, x, y, approx)
  assert approx.num_vertices > 3
  assert 0 == ((approx.num_vertices - 2) mod 6)

  self.draw_arc_approximation(approx)
