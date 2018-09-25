# Copyright (c) 2015 Andri Lim
#
# Distributed under the MIT license
# (See accompanying file LICENSE.txt)
#
#-----------------------------------------
# this is nim version of GraphDisplay(without GUI)
# http://www.codeproject.com/Articles/58280/GraphDisplay-a-Bezier-based-control-for-graphing-f
# originally written by Ken Johnson in C#
# from this module, we learn that nim closure works perfectly

import basic2d, math, path

type
  FuncType* = proc (v: float64): float64

  TPoints* = seq[Point2d]

  TFunction* = ref object of RootObj
    mF, mDF: FuncType

  Curve* = ref object of RootObj
    mX, mDx, mY, mDy: FuncType

  CyclicCurve* = ref object of Curve
    CycleStart*, CycleEnd* : float64

  TransformedFunction* = ref object of RootObj
    f, xTrans, yTrans: TFunction

proc GCD(x, y: int): float64 =
  var temp: int
  var a = x
  var b = y
  while b != 0:
    temp = b
    b = a mod b
    a = temp
  result = float64(a)

proc makeFunction*(f, df: FuncType): TFunction =
  new(result)
  result.mF = f
  result.mDF = df

proc Val*(f: TFunction, x: float64): float64 =
  result = f.mF(x)

proc DVal*(f: TFunction, x: float64): float64 =
  result = f.mDF(x)

proc Points*(f: TFunction, fstart, fend: float64, segments: int): TPoints =
  result = @[]
  for i in 0..segments-1:
    let a = float64(i) * (fend - fstart) / float64(segments) + fstart
    result.add(point2d(a, f.Val(a)))

proc Compose(f,g:TFunction): TFunction =
  #Composition f(g(x)) #Chain Rule  f'(g(x))*g'(x)
  result = makeFunction(
    proc (x:float64): float64 = f.Val(g.Val(x)),
    proc (x:float64): float64 = f.DVal(g.Val(x)) * g.DVal(x) )

proc Sum(f,g:TFunction): TFunction =
  result = makeFunction(
    proc (x:float64): float64 = f.Val(x) + g.Val(x),
    proc (x:float64): float64 = f.DVal(x) + g.DVal(x) )

proc Difference(f,g:TFunction): TFunction =
  result = makeFunction(
    proc (x:float64): float64 = f.Val(x) - g.Val(x),
    proc (x:float64): float64 = f.DVal(x) - g.DVal(x) )

proc Product(f,g:TFunction): TFunction =
  #Chain Rule f'(x)g(x) + f(x)g'(x)
  result = makeFunction(
    proc (x:float64): float64 = f.Val(x) * g.Val(x),
    proc (x:float64): float64 = f.DVal(x) * g.Val(x) + g.DVal(x) * f.Val(x) )

proc Quotient(f,g:TFunction): TFunction =
  #Chain rule (f'(x)g(x) - f(x)g'(x))/g(x)^2
  proc mDF (x:float64): float64 =
    result = (f.DVal(x) * g.Val(x) - f.Val(x) * g.DVal(x)) / math.pow(g.Val(x), 2)
  result = makeFunction(proc (x:float64): float64 = f.Val(x) / g.Val(x), mDF)

proc `&`*(f,g:TFunction): TFunction = Compose(f,g)
proc `+`*(f,g:TFunction): TFunction = Sum(f,g)
proc `-`*(f,g:TFunction): TFunction = Difference(f,g)
proc `*`*(f,g:TFunction): TFunction = Product(f,g)
proc `/`*(f,g:TFunction): TFunction = Quotient(f,g)

proc makeSine*(A,N,D:float64): TFunction =
  result = makeFunction(
    proc (x:float64): float64 = A * math.sin(N * x + D),
    proc (x:float64): float64 = N * A * math.cos(N * x + D) )

proc makeSine*(): TFunction = makeSine(1,1,0)
proc makeSine*(a,n:float64): TFunction = makeSine(a,n,0)

proc makeCosine*(A,N,D: float64): TFunction =
  result = makeFunction(
    proc (x:float64): float64 = A * math.cos(N * x + D),
    proc (x:float64): float64 = -N * A * math.sin(N * x + D) )

proc makeCosine*(): TFunction = makeCosine(1,1,0)

proc makeExp*(A,K,D: float64): TFunction =
  result = makeFunction(
    proc (x:float64): float64 = A * math.exp(x * K + D),
    proc (x:float64): float64 = A * K * math.exp(x * K + D) )

proc makeExp*(): TFunction = makeExp(1,1,0)

proc makeCurve*(x, y: TFunction): Curve =
  new(result)
  result.mX  = x.mF
  result.mDx = x.mDF
  result.mY  = y.mF
  result.mDy = y.mDF

proc X*(f: Curve, t: float64): float64 = f.mX(t)

proc Y*(f: Curve, t: float64): float64 = f.mY(t)

proc Dx*(f: Curve, t: float64): float64 = f.mDx(t)

proc Dy*(f: Curve, t: float64): float64 = f.mDy(t)

proc Points*(f: Curve, fstart, fend: float64, segments: int): TPoints =
  result = @[]
  for i in 0..segments-1:
    let a = float64(i) * (fend - fstart) / float64(segments) + fstart
    result.add(point2d(f.X(a), f.Y(a)))

proc makeCyclicCurve*(x,y: TFunction; cycleStart, cycleEnd: float64): CyclicCurve =
  new(result)
  result.mX = x.mF
  result.mDx = x.mDF

  result.mY = y.mF
  result.mDy = y.mDF

  result.CycleStart = cycleStart
  result.CycleEnd = cycleEnd

proc makePolarCurve*(r: TFunction): Curve =
  result = makeCurve(r * makeCosine(), r * makeSine())

proc makePolarCyclicCurve*(r: TFunction; cycleStart, cycleEnd: float64): CyclicCurve =
  result = makeCyclicCurve(r * makeCosine(), r * makeSine(), cycleStart, cycleEnd)

proc makeRose*(A: float64, N, D: int): CyclicCurve =
  let Omega = float64(N) / float64(D)

  let f = makeFunction(
    proc (theta: float64): float64 = A * math.sin(Omega * theta),
    proc (theta: float64): float64 = Omega * A * math.cos(Omega * theta))

  var cycle = float64(D) * 2 * math.PI / GCD(N, D)
  if ((N == 1) and ((D mod 2) == 1)): cycle = cycle / 2

  result = makePolarCyclicCurve(f, 0, cycle)

proc makeLissajous*(A, B: float64; N, D: int; Delta: float64) : CyclicCurve =
  let Omega = float64(N) / float64(D)

  let x = makeFunction(
    proc (t: float64): float64 = A * math.sin(Omega * t + Delta),
    proc (t: float64): float64 = Omega * A * math.cos(Omega * t + Delta))

  let y = makeFunction(
    proc (t: float64): float64 = B * math.sin(t),
    proc (t: float64): float64 = B * math.cos(t))

  result = makeCyclicCurve(x,y, 0, math.PI * 2 * float64(D) / GCD(N,D) )

proc makeEpicycloid*(R, P: float64; N, D: int) : CyclicCurve =
  let gcd = GCD(N, D)
  let pp  = float64(N) / gcd
  let qq  = float64(D) / gcd
  let k   = pp / qq

  let fx = makeFunction(
    proc (x: float64): float64 = R * ((k + 1) * math.cos(x + P) - math.cos((k + 1) * x + P)),
    proc (x: float64): float64 = -R * ((k + 1) * math.sin(x + P) - (k + 1) * math.sin((k + 1) * x + P)))

  let fy = makeFunction(
    proc (x: float64): float64 = R * (k + 1) * math.sin(x + P) - R * math.sin((k + 1) * x + P),
    proc (x: float64): float64 = R * (k + 1) * math.cos(x + P) - R * (k + 1) * math.cos((k + 1) * x + P))

  result = makeCyclicCurve(fx, fy, 0,  math.PI * 2 * qq)

proc makeEpitrochoid*(R, P, M: float64; N, D: int) : CyclicCurve =
  let gcd = GCD(N, D)
  let pp  = float64(N) / gcd
  let qq  = float64(D) / gcd
  let k   = pp / qq

  let fx = makeFunction(
    proc (t: float64): float64 = R * ((k + 1) * math.cos(t + P) - math.pow(2, M) * math.cos((k + 1) * t + P)),
    proc (t: float64): float64 = -R * ((k + 1) * math.sin(t + P) - (k + 1) * math.pow(2, M) * math.sin((k + 1) * t + P)))

  let fy = makeFunction(
    proc (t: float64): float64 = R * (k + 1) * math.sin(t + P) - R * math.pow(2, M) * math.sin((k + 1) * t + P),
    proc (t: float64): float64 = R * (k + 1) * math.cos(t + P) - R * (k + 1) * math.pow(2, M) * math.cos((k + 1) * t + P))

  result = makeCyclicCurve(fx, fy, 0, math.PI * 2 * qq)

proc makeHipocycloid*(R, P: float64; N, D: int) : CyclicCurve =
  let gcd = GCD(N, D)
  let pp  = float64(N) / gcd
  let qq  = float64(D) / gcd
  let m   = pp / qq - 1

  let fx = makeFunction(
    proc (t: float64): float64 = R * m * math.cos(t + P) + R * math.cos(m * t + P),
    proc (t: float64): float64 = -R * m * math.sin(t + P) - m * R * math.sin(m * t + P))

  let fy = makeFunction(
    proc (t: float64): float64 = R * m * math.sin(t + P) - R * math.sin(m * t + P),
    proc (t: float64): float64 = R * m * math.cos(t + P) - R * m * math.cos(m * t + P))

  result = makeCyclicCurve(fx, fy, 0, math.PI * 2 * qq)

proc makeHipotrochoid*(R, P, M: float64; N, D: int) : CyclicCurve =
  let gcd = GCD(N, D)
  let pp  = float64(N) / gcd
  let qq  = float64(D) / gcd
  let k   = pp / qq

  let fx = makeFunction(
    proc (t: float64): float64 = R * ((k - 1) * math.cos(t + P) + math.pow(2, M) * math.cos((k - 1) * t + P)),
    proc (t: float64): float64 = -R * ((k - 1) * math.sin(t + P) + (k - 1) * math.pow(2, M) * math.sin((k - 1) * t + P)))

  let fy = makeFunction(
    proc (t: float64): float64 = R * (k - 1) * math.sin(t + P) - R * math.pow(2, M) * math.sin((k - 1) * t + P),
    proc (t: float64): float64 = R * (k - 1) * math.cos(t + P) - R * (k - 1) * math.pow(2, M) * math.cos((k - 1) * t + P))

  result = makeCyclicCurve(fx, fy, 0, math.PI * 2 * qq)

proc makeFarrisWheel*(F1, F2, F3, W1, W2, W3, P1, P2, P3, R, P: float64) : CyclicCurve =
  let maxRadius   = abs(W1) + abs(W2) + abs(W3)
  let scaleFactor = R / maxRadius
  let pp1PI = (P + P1) * math.PI
  let pp2PI = (P + P2) * math.PI
  let pp3PI = (P + P3) * math.PI

  let fx = makeFunction(
    proc (t: float64): float64 = scaleFactor * (W1 * math.cos(F1 * t + pp1PI) + W2 * math.cos(F2 * t + pp2PI) + W3 * math.cos(F3 * t + pp3PI)),
    proc (t: float64): float64 = scaleFactor * (-F1 * W1 * math.sin(F1 * t + pp1PI) - F2 * W2 * math.sin(F2 * t + pp2PI) - F3 * W3 * math.sin(F3 * t + pp3PI)))

  let fy = makeFunction(
    proc (t: float64): float64 = scaleFactor * (W1 * math.sin(F1 * t + pp1PI) + W2 * math.sin(F2 * t + pp2PI) + W3 * math.sin(F3 * t + pp3PI)),
    proc (t: float64): float64 = scaleFactor * (F1 * W1 * math.cos(F1 * t + pp1PI) + F2 * W2 * math.cos(F2 * t + pp2PI) + F3 * W3 * math.cos(F3 * t + pp3PI)))

  result = makeCyclicCurve(fx, fy, 0, math.PI * 2)


proc TransformedCurve*(c: Curve; xTrans, yTrans: TFunction): Curve =
  let x = makeFunction(
     proc (t: float64): float64 = xTrans.Val(c.X(t)),
     proc (t: float64): float64 = xTrans.DVal(c.X(t)) * c.Dx(t) ) #chain rule

  let y = makeFunction(
    proc (t: float64): float64 = yTrans.Val(c.Y(t)),
    proc (t: float64): float64 = yTrans.DVal(c.Y(t)) * c.Dy(t) ) #chain rule

  result = makeCurve(x, y)

proc makeTransformedFunction*(f, xTrans, yTrans: TFunction): TransformedFunction =
  new(result)
  result.f = f
  result.xTrans = xTrans
  result.yTrans = yTrans

proc Input(f: TransformedFunction, x: float64): float64 = f.xTrans.Val(x)

proc Val(f: TransformedFunction, x: float64): float64 = f.yTrans.Val(f.f.Val(x))

proc DVal(f: TransformedFunction, x: float64): float64 =
  result = (f.yTrans.DVal(f.yTrans.Val(x)) / f.xTrans.DVal(x)) * f.f.DVal(x) #Chain Rule

proc QuadraticBezierGeometry*(tf: TransformedFunction, fstart, fend: float64, segments: int): Path =
  result = makePath()
  var StartPoint = point2d(tf.Input(fstart), tf.Val(fstart))

  proc f(x: float64): float64 = tf.Val(x)
  proc df(x: float64): float64 = tf.DVal(x)

  for i in 0..segments-1:
    let aa = float64(i) * (fend - fstart) / float64(segments) + fstart
    let A = tf.Input(aa)
    let bb  = float64(i + 1) * (fend - fstart) / float64(segments) + fstart
    let B = tf.Input(bb)
    let denom = df(bb) - df(aa)
    let P1X = (f(aa) - f(bb) - A * df(aa) + B * df(bb)) / denom
    let P1Y = (f(bb) * df(aa) - (f(aa) + (B - A) * df(aa)) * df(bb)) / -denom
    let P1 = point2d(P1X, P1Y)
    let P2 = point2d(B, f(bb))
    result.addQuadraticCurve(StartPoint, P1, P2)
    StartPoint = P2

proc CubicBezierGeometry*(tf: TransformedFunction, fstart, fend: float64, segments: int): Path =
  result = makePath()
  var StartPoint = point2d(tf.Input(fstart),tf.Val(fstart))

  proc f(x: float64): float64 = tf.Val(x)
  proc df(x: float64): float64 = tf.DVal(x)

  for i in 0..segments-1:
    let aOrig = float64(i) * (fend - fstart) / float64(segments) + fstart
    let aa = tf.Input(aOrig)
    let bOrig = float64(i + 1) * (fend - fstart) / float64(segments) + fstart
    let bb = tf.Input(bOrig)
    let P1 = point2d((2 * aa + bb) / 3, (3 * f(aOrig) - aa * df(aOrig) + bb * df(aOrig)) / 3)
    let P2 = point2d((2 * bb + aa) / 3, (3 * f(bOrig) + aa * df(bOrig) - bb * df(bOrig)) / 3)
    let P3 = point2d(bb, f(bOrig))
    result.addCubicCurve(StartPoint, P1, P2, P3)
    StartPoint = P3

proc CubicBezierGeometry*(tc: Curve, fstart, fend: float64, segments: int): Path =
  result = makePath()

  #P0 = x(t0), y(t0)
  #P3 = x(t1), y(t1)
  #dt = t1 - t0
  #P1 = P0 + (dt/3) P'(t0)
  #P2 = P3 - (dt/3) P'(t1)

  for i in 0..segments-1:
    let t0 = float64(i) * (fend - fstart) / float64(segments) + fstart
    let t1 = float64(i + 1) * (fend - fstart) / float64(segments) + fstart
    var P0 = point2d(tc.X(t0), tc.Y(t0))
    var P3 = point2d(tc.X(t1), tc.Y(t1))
    let dt = t1 - t0
    let dt3 = dt / 3
    let PT0 = point2d(tc.Dx(t0), tc.Dy(t0))
    let PT1 = point2d(tc.Dx(t1), tc.Dy(t1))
    var P1 = point2d(P0.x + dt3 * PT0.x, P0.y + dt3 * PT0.y)
    var P2 = point2d(P3.x - dt3 * PT1.x, P3.y - dt3 * PT1.y)
    result.addCubicCurve(P0, P1, P2, P3)
