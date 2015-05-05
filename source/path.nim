import basic2d, math

const
    straight_line* = 1.0
    quadratic_curve* = 2.0
    cubic_curve* = 3.0
    rectangle* = 4.0
    
type
    poc = tuple[res:bool, p:TPoint2d]
    bound* = tuple[xmin,ymin,xmax,ymax:float64]
    TVals = object
        len: int
        vals: array[0..10, float64]
        
    Path* = seq[float64]

proc `[]`(t: var TVals, index: int): float64 {.inline.} = t.vals[index]
proc len(t:TVals): int {.inline.} = t.len

proc push(t: var TVals, val: float64) =
    t.vals[t.len] = val
    inc(t.len)
    
proc tvals(): TVals =
    result.len = 0

proc max(t:TVals): float64 =
    result = 0
    if t.len > 0:
        result = t.vals[0]
        for i in 0..t.len-1:
            result = max(result, t.vals[i])

proc min(t:TVals): float64 =
    result = 0
    if t.len > 0:
        result = t.vals[0]
        for i in 0..t.len-1:
            result = min(result, t.vals[i])

#compute B(t) (see wikipedia).
proc value(t, x1, x2, x3: float64): float64 =
    result = math.pow(1-t, 2) * x1 + 2 * (1-t) * t * x2 + math.pow(t, 2) * x3

#solve B(t)'=0 (use wolframalpha.com).
proc derivative1_root(x1, x2, x3: float64): float64 =
    let denom = x1 - 2*x2 + x3
    if denom == 0: return -1
    result = (x1 - x2) / denom

#compute the minimum and maximum values for B(t).
proc minmax(x1, x2, x3: float64): tuple[min,max:float64] =
    #start off with the assumption that the curve doesn't extend past its endpoints.
    var minx = min(x1, x3)
    var maxx = max(x1, x3)
    #if the control point is between the endpoints, the curve has no local extremas.
    if x2 >= minx and x2 <= maxx:
        return (min: minx, max: maxx)
    
    #if the curve has local minima and/or maxima then adjust the bounding box.
    let t = derivative1_root(x1, x2, x3)
    if t >= 0 and t <= 1:
        let x = value(t, x1, x2, x3)
        minx = min(x, minx)
        maxx = max(x, maxx)
    
    result = (min:minx, max:maxx)

proc quadraticCurveBounds*(x1, y1, x2, y2, x3, y3: float64): bound =
    let x = minmax(x1, x2, x3)
    let y = minmax(y1, y2, y3)
    result = (xmin:x.min, ymin:y.min, xmax:x.max, ymax:y.max)

proc cubicCurveBounds*(x0, y0, x1, y1, x2, y2, x3, y3: float64): bound =
    var tvalues = tvals()
    var boundx = tvals()
    var boundy = tvals()
    
    var a, b, c, t, t1, t2, b2ac, sqrtb2ac: float64
  
    for i in 0..1:
        if i == 0:
            b = 6 * x0 - 12 * x1 + 6 * x2
            a = -3 * x0 + 9 * x1 - 9 * x2 + 3 * x3
            c = 3 * x1 - 3 * x0
        else:
            b = 6 * y0 - 12 * y1 + 6 * y2
            a = -3 * y0 + 9 * y1 - 9 * y2 + 3 * y3
            c = 3 * y1 - 3 * y0
    

        if math.fabs(a) < 1e-12:     #Numerical robustness
            if math.fabs(b) < 1e-12: continue #Numerical robustness
            t = -c / b
            if 0.0 < t and t < 1.0: tvalues.push(t)
            continue
    
        b2ac = b * b - 4 * c * a
        sqrtb2ac = math.sqrt(b2ac)
        if b2ac < 0: continue
    
        t1 = (-b + sqrtb2ac) / (2 * a)
        if 0.0 < t1 and t1 < 1.0: tvalues.push(t1)
    
        t2 = (-b - sqrtb2ac) / (2 * a)
        if 0.0 < t2 and t2 < 1.0: tvalues.push(t2)
     
    var x, y, mt: float64
    var j = tvalues.len
    
    while j >= 0:
        t = tvalues[j]
        mt = 1 - t
        x = (mt * mt * mt * x0) + (3 * mt * mt * t * x1) + (3 * mt * t * t * x2) + (t * t * t * x3)
        y = (mt * mt * mt * y0) + (3 * mt * mt * t * y1) + (3 * mt * t * t * y2) + (t * t * t * y3)
        boundx.push(x)
        boundy.push(y)
        dec(j)
    
    boundx.push(x0)
    boundx.push(x3)
    boundy.push(y0)
    boundy.push(y3)
   
    result = (xmin:boundx.min(), ymin:boundy.min(), xmax:boundx.max(), ymax:boundy.max())
    
proc quadraticCurveBounds2*(ax, ay, bx, by, cx, cy: float64): bound =
    let two:float64 = 2/3
    let cx1 = ax + two * (bx-ax)
    let cx2 = cx + two * (bx-cx)
    
    let cy1 = ay + two * (by-ay)
    let cy2 = cy + two * (by-cy)
        
    result = cubicCurveBounds(ax,ay,cx1,cy1,cx2,cy2,cx,cy)

proc makePath*(): Path =
    result = @[]

proc addLine*(p: var Path, x1,y1,x2,y2:float64) =
    p.add(straight_line)
    p.add(x1)
    p.add(y1)
    p.add(x2)
    p.add(y2)

proc addLine*(p: var Path, p1,p2:TPoint2d) =
    p.addLine(p1.x,p1.y,p2.x,p2.y)
    
proc addRect*(p: var Path, x,y,w,h:float64) =
    p.add(rectangle)
    p.add(x)
    p.add(y)
    p.add(w+x)
    p.add(h+y)

proc addQuadraticCurve*(p: var Path, ax,ay,bx,by,cx,cy:float64) =
    p.add(quadratic_curve)
    p.add(ax)
    p.add(ay)
    p.add(bx)
    p.add(by)
    p.add(cx)
    p.add(cy)

proc addQuadraticCurve*(p: var Path, a,b,c:TPoint2d) =
    p.addQuadraticCurve(a.x,a.y,b.x,b.y,c.x,c.y)
    
proc addCubicCurve*(p: var Path, ax,ay,bx,by,cx,cy,dx,dy:float64) =
    p.add(cubic_curve)
    p.add(ax)
    p.add(ay)
    p.add(bx)
    p.add(by)
    p.add(cx)
    p.add(cy)
    p.add(dx)
    p.add(dy)

proc addCubicCurve*(p: var Path, a,b,c,d:TPoint2d) =
    p.addCubicCurve(a.x,a.y,b.x,b.y,c.x,c.y,d.x,d.y)
    
proc isClosed*(p: Path) : bool =
    if p.len == 0: return false
    if p.len == 5 and p[0] == rectangle: return true
    if p[1] == p[p.len - 2] and p[2] == p[p.len - 1]: return true
    result = false
    
proc calculateBounds*(p: Path): bound =
    let len = p.len
    if len < 5: return (xmin:0.0,ymin:0.0,xmax:0.0,ymax:0.0)
    var i = 0
    var xmin = p[1]
    var ymin = p[2]
    
    var xmax = p[1]
    var ymax = p[2]
    
    while i < len:
        let op = p[i]
        if op == straight_line or op == rectangle:
            xmin = min(xmin, p[i+1])
            ymin = min(ymin, p[i+2])
            xmin = min(xmin, p[i+3])
            ymin = min(ymin, p[i+4])
            xmax = max(xmax, p[i+1])
            ymax = max(ymax, p[i+2])
            xmax = max(xmax, p[i+3])
            ymax = max(ymax, p[i+4])
            inc(i, 5)
        if op == quadratic_curve:
            let bb = quadraticCurveBounds(p[i+1],p[i+2],p[i+3],p[i+4],p[i+5],p[i+6])
            xmin = min(xmin, bb.xmin)
            ymin = min(ymin, bb.ymin)
            xmax = max(xmax, bb.xmax)
            ymax = max(ymax, bb.ymax)
            inc(i, 7)
        if op == cubic_curve:
            let bb = cubicCurveBounds(p[i+1],p[i+2],p[i+3],p[i+4],p[i+5],p[i+6],p[i+7],p[i+8])
            xmin = min(xmin, bb.xmin)
            ymin = min(ymin, bb.ymin)
            xmax = max(xmax, bb.xmax)
            ymax = max(ymax, bb.ymax)
            inc(i, 9)
    result = (xmin:xmin, ymin:ymin, xmax:xmax, ymax:ymax)