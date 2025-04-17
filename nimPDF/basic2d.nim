#
#
#            Nim's Runtime Library
#        (c) Copyright 2013 Robert Persson
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

import math
import strutils


## Basic 2d support with vectors, points, matrices and some basic utilities.
## Vectors are implemented as direction vectors, ie. when transformed with a matrix
## the translation part of matrix is ignored.
## Operators `+` , `-` , `*` , `/` , `+=` , `-=` , `*=` and `/=` are implemented for vectors and scalars.
##
## Quick start example:
##
## .. code-block:: nim
##
##   # Create a matrix which first rotates, then scales and at last translates
##
##   var m:Matrix2d=rotate(DEG90) & scale(2.0) & move(100.0,200.0)
##
##   # Create a 2d point at (100,0) and a vector (5,2)
##
##   var pt:Point2d=point2d(100.0,0.0)
##
##   var vec:Vector2d=vector2d(5.0,2.0)
##
##
##   pt &= m # transforms pt in place
##
##   var pt2:Point2d=pt & m #concatenates pt with m and returns a new point
##
##   var vec2:Vector2d=vec & m #concatenates vec with m and returns a new vector


const
  DEG360* = PI * 2.0
    ## 360 degrees in radians.
  DEG270* = PI * 1.5
    ## 270 degrees in radians.
  DEG180* = PI
    ## 180 degrees in radians.
  DEG90* = PI / 2.0
    ## 90 degrees in radians.
  DEG60* = PI / 3.0
    ## 60 degrees in radians.
  DEG45* = PI / 4.0
    ## 45 degrees in radians.
  DEG30* = PI / 6.0
    ## 30 degrees in radians.
  DEG15* = PI / 12.0
    ## 15 degrees in radians.
  RAD2DEGCONST = 180.0 / PI
    ## used internally by DegToRad and RadToDeg

type
  Matrix2d* = object
    ## Implements a row major 2d matrix, which means
    ## transformations are applied the order they are concatenated.
    ## The rightmost column of the 3x3 matrix is left out since normally
    ## not used for geometric transformations in 2d.
    ax*,ay*,bx*,by*,tx*,ty*:float
  Point2d* = object
    ## Implements a non-homogeneous 2d point stored as
    ## an `x` coordinate and an `y` coordinate.
    x*,y*:float
  Vector2d* = object
    ## Implements a 2d **direction vector** stored as
    ## an `x` coordinate and an `y` coordinate. Direction vector means,
    ## that when transforming a vector with a matrix, the translational
    ## part of the matrix is ignored.
    x*,y*:float


# Some forward declarations...
proc matrix2d*(ax,ay,bx,by,tx,ty:float):Matrix2d {.noInit.}
  ## Creates a new matrix.
  ## `ax`,`ay` is the local x axis
  ## `bx`,`by` is the local y axis
  ## `tx`,`ty` is the translation
proc vector2d*(x,y:float):Vector2d {.noInit,inline.}
  ## Returns a new vector (`x`,`y`)
proc point2d*(x,y:float):Point2d {.noInit,inline.}
  ## Returns a new point (`x`,`y`)



let
  IDMATRIX*:Matrix2d=matrix2d(1.0,0.0,0.0,1.0,0.0,0.0)
    ## Quick access to an identity matrix
  ORIGO*:Point2d=point2d(0.0,0.0)
    ## Quick access to point (0,0)
  XAXIS*:Vector2d=vector2d(1.0,0.0)
    ## Quick access to an 2d x-axis unit vector
  YAXIS*:Vector2d=vector2d(0.0,1.0)
    ## Quick access to an 2d y-axis unit vector


# ***************************************
#     Private utils
# ***************************************

proc rtos(val:float):string=
  return formatFloat(val,ffDefault,0)

proc safeArccos(v:float):float=
  ## assumes v is in range 0.0-1.0, but clamps
  ## the value to avoid out of domain errors
  ## due to rounding issues
  return arccos(clamp(v,-1.0,1.0))


template makeBinOpVector(s: untyped)=
  ## implements binary operators ``+``, ``-``, ``*`` and ``/`` for vectors
  proc s*(a,b:Vector2d):Vector2d {.inline,noInit.} = vector2d(s(a.x,b.x),s(a.y,b.y))
  proc s*(a:Vector2d,b:float):Vector2d {.inline,noInit.}  = vector2d(s(a.x,b),s(a.y,b))
  proc s*(a:float,b:Vector2d):Vector2d {.inline,noInit.}  = vector2d(s(a,b.x),s(a,b.y))

template makeBinOpAssignVector(s: untyped)=
  ## implements inplace binary operators ``+=``, ``-=``, ``/=`` and ``*=`` for vectors
  proc s*(a:var Vector2d,b:Vector2d) {.inline.} = s(a.x,b.x) ; s(a.y,b.y)
  proc s*(a:var Vector2d,b:float) {.inline.} = s(a.x,b) ; s(a.y,b)


# ***************************************
#     Matrix2d implementation
# ***************************************

proc setElements*(t:var Matrix2d,ax,ay,bx,by,tx,ty:float) {.inline.}=
  ## Sets arbitrary elements in an existing matrix.
  t.ax=ax
  t.ay=ay
  t.bx=bx
  t.by=by
  t.tx=tx
  t.ty=ty

proc matrix2d*(ax,ay,bx,by,tx,ty:float):Matrix2d =
  result.setElements(ax,ay,bx,by,tx,ty)

proc `&`*(a,b:Matrix2d):Matrix2d {.noInit.} = #concatenate matrices
  ## Concatenates matrices returning a new matrix.

  # | a.AX a.AY 0 |   | b.AX b.AY 0 |
  # | a.BX a.BY 0 | * | b.BX b.BY 0 |
  # | a.TX a.TY 1 |   | b.TX b.TY 1 |
  result.setElements(
    a.ax * b.ax + a.ay * b.bx,
    a.ax * b.ay + a.ay * b.by,
    a.bx * b.ax + a.by * b.bx,
    a.bx * b.ay + a.by * b.by,
    a.tx * b.ax + a.ty * b.bx + b.tx,
    a.tx * b.ay + a.ty * b.by + b.ty)


proc scale*(s:float):Matrix2d {.noInit.} =
  ## Returns a new scale matrix.
  result.setElements(s,0,0,s,0,0)

proc scale*(s:float,org:Point2d):Matrix2d {.noInit.} =
  ## Returns a new scale matrix using, `org` as scale origin.
  result.setElements(s,0,0,s,org.x-s*org.x,org.y-s*org.y)

proc stretch*(sx,sy:float):Matrix2d {.noInit.} =
  ## Returns new a stretch matrix, which is a
  ## scale matrix with non uniform scale in x and y.
  result.setElements(sx,0,0,sy,0,0)

proc stretch*(sx,sy:float,org:Point2d):Matrix2d {.noInit.} =
  ## Returns a new stretch matrix, which is a
  ## scale matrix with non uniform scale in x and y.
  ## `org` is used as stretch origin.
  result.setElements(sx,0,0,sy,org.x-sx*org.x,org.y-sy*org.y)

proc move*(dx,dy:float):Matrix2d {.noInit.} =
  ## Returns a new translation matrix.
  result.setElements(1,0,0,1,dx,dy)

proc move*(v:Vector2d):Matrix2d {.noInit.} =
  ## Returns a new translation matrix from a vector.
  result.setElements(1,0,0,1,v.x,v.y)

proc rotate*(rad:float):Matrix2d {.noInit.} =
  ## Returns a new rotation matrix, which
  ## represents a rotation by `rad` radians
  let
    s=sin(rad)
    c=cos(rad)
  result.setElements(c,s,-s,c,0,0)

proc rotate*(rad:float,org:Point2d):Matrix2d {.noInit.} =
  ## Returns a new rotation matrix, which
  ## represents a rotation by `rad` radians around
  ## the origin `org`
  let
    s=sin(rad)
    c=cos(rad)
  result.setElements(c,s,-s,c,org.x+s*org.y-c*org.x,org.y-c*org.y-s*org.x)

proc mirror*(v:Vector2d):Matrix2d {.noInit.} =
  ## Returns a new mirror matrix, mirroring
  ## around the line that passes through origo and
  ## has the direction of `v`
  let
    sqx=v.x*v.x
    sqy=v.y*v.y
    nd=1.0/(sqx+sqy) #used to normalize invector
    xy2=v.x*v.y*2.0*nd
    sqd=nd*(sqx-sqy)

  if nd==Inf or nd==NegInf:
    return IDMATRIX #mirroring around a zero vector is arbitrary=>just use identity

  result.setElements(
    sqd,xy2,
    xy2,-sqd,
    0.0,0.0)

proc mirror*(org:Point2d,v:Vector2d):Matrix2d {.noInit.} =
  ## Returns a new mirror matrix, mirroring
  ## around the line that passes through `org` and
  ## has the direction of `v`
  let
    sqx=v.x*v.x
    sqy=v.y*v.y
    nd=1.0/(sqx+sqy) #used to normalize invector
    xy2=v.x*v.y*2.0*nd
    sqd=nd*(sqx-sqy)

  if nd==Inf or nd==NegInf:
    return IDMATRIX #mirroring around a zero vector is arbitrary=>just use identity

  result.setElements(
    sqd,xy2,
    xy2,-sqd,
    org.x-org.y*xy2-org.x*sqd,org.y-org.x*xy2+org.y*sqd)



proc skew*(xskew,yskew:float):Matrix2d {.noInit.} =
  ## Returns a new skew matrix, which has its
  ## x axis rotated `xskew` radians from the local x axis, and
  ## y axis rotated `yskew` radians from the local y axis
  result.setElements(cos(yskew),sin(yskew),-sin(xskew),cos(xskew),0,0)


proc `$`* (t:Matrix2d):string {.noInit.} =
  ## Returns a string representation of the matrix
  return rtos(t.ax) & "," & rtos(t.ay) &
    "," & rtos(t.bx) & "," & rtos(t.by) &
    "," & rtos(t.tx) & "," & rtos(t.ty)

proc isUniform*(t:Matrix2d,tol=1.0e-6):bool=
  ## Checks if the transform is uniform, that is
  ## perpendicular axes of equal length, which means (for example)
  ## it cannot transform a circle into an ellipse.
  ## `tol` is used as tolerance for both equal length comparison
  ## and perp. comparison.

  #dot product=0 means perpendicular coord. system:
  if abs(t.ax*t.bx+t.ay*t.by)<=tol:
    #subtract squared lengths of axes to check if uniform scaling:
    if abs((t.ax*t.ax+t.ay*t.ay)-(t.bx*t.bx+t.by*t.by))<=tol:
      return true
  return false

proc determinant*(t:Matrix2d):float=
  ## Computes the determinant of the matrix.

  #NOTE: equivalent with perp.dot product for two 2d vectors
  return t.ax*t.by-t.bx*t.ay

proc isMirroring* (m:Matrix2d):bool=
  ## Checks if the `m` is a mirroring matrix,
  ## which means it will reverse direction of a curve transformed with it
  return m.determinant<0.0

proc inverse*(m:Matrix2d):Matrix2d {.noInit.} =
  ## Returns a new matrix, which is the inverse of the matrix
  ## If the matrix is not invertible (determinant=0), an EDivByZero
  ## will be raised.
  let d=m.determinant
  if d==0.0:
    raise newException(ValueError,"Cannot invert a zero determinant matrix")

  result.setElements(
    m.by/d,-m.ay/d,
    -m.bx/d,m.ax/d,
    (m.bx*m.ty-m.by*m.tx)/d,
    (m.ay*m.tx-m.ax*m.ty)/d)

proc equals*(m1:Matrix2d,m2:Matrix2d,tol=1.0e-6):bool=
  ## Checks if all elements of `m1`and `m2` is equal within
  ## a given tolerance `tol`.
  return
    abs(m1.ax-m2.ax)<=tol and
    abs(m1.ay-m2.ay)<=tol and
    abs(m1.bx-m2.bx)<=tol and
    abs(m1.by-m2.by)<=tol and
    abs(m1.tx-m2.tx)<=tol and
    abs(m1.ty-m2.ty)<=tol

proc `=~`*(m1,m2:Matrix2d):bool=
  ## Checks if `m1`and `m2` is approximately equal, using a
  ## tolerance of 1e-6.
  equals(m1,m2)

proc isIdentity*(m:Matrix2d,tol=1.0e-6):bool=
  ## Checks is a matrix is approximately an identity matrix,
  ## using `tol` as tolerance for each element.
  return equals(m,IDMATRIX,tol)

proc apply*(m:Matrix2d,x,y:var float,translate=false)=
  ## Applies transformation `m` onto `x`,`y`, optionally
  ## using the translation part of the matrix.
  if translate: # positional style transform
    let newx=x*m.ax+y*m.bx+m.tx
    y=x*m.ay+y*m.by+m.ty
    x=newx
  else: # delta style transform
    let newx=x*m.ax+y*m.bx
    y=x*m.ay+y*m.by
    x=newx



# ***************************************
#     Vector2d implementation
# ***************************************
proc vector2d*(x,y:float):Vector2d = #forward decl.
  result.x=x
  result.y=y

proc polarVector2d*(ang:float,len:float):Vector2d {.noInit.} =
  ## Returns a new vector with angle `ang` and magnitude `len`
  result.x=cos(ang)*len
  result.y=sin(ang)*len

proc slopeVector2d*(slope:float,len:float):Vector2d {.noInit.} =
  ## Returns a new vector having slope (dy/dx) given by
  ## `slope`, and a magnitude of `len`
  let ang=arctan(slope)
  result.x=cos(ang)*len
  result.y=sin(ang)*len

proc len*(v:Vector2d):float {.inline.}=
  ## Returns the length of the vector.
  sqrt(v.x*v.x+v.y*v.y)

proc `len=`*(v:var Vector2d,newlen:float) {.noInit.} =
  ## Sets the length of the vector, keeping its angle.
  let fac=newlen/v.len

  if newlen==0.0:
    v.x=0.0
    v.y=0.0
    return

  if fac==Inf or fac==NegInf:
    #to short for float accuracy
    #do as good as possible:
    v.x=newlen
    v.y=0.0
  else:
    v.x*=fac
    v.y*=fac

proc sqrLen*(v:Vector2d):float {.inline.}=
  ## Computes the squared length of the vector, which is
  ## faster than computing the absolute length.
  v.x*v.x+v.y*v.y

proc angle*(v:Vector2d):float=
  ## Returns the angle of the vector.
  ## (The counter clockwise plane angle between posetive x axis and `v`)
  result=arctan2(v.y,v.x)
  if result<0.0: result+=DEG360

proc `$` *(v:Vector2d):string=
  ## String representation of `v`
  result=rtos(v.x)
  result.add(",")
  result.add(rtos(v.y))


proc `&` *(v:Vector2d,m:Matrix2d):Vector2d {.noInit.} =
  ## Concatenate vector `v` with a transformation matrix.
  ## Transforming a vector ignores the translational part
  ## of the matrix.

  #             | AX AY 0 |
  # | X Y 1 | * | BX BY 0 |
  #             | 0  0  1 |
  result.x=v.x*m.ax+v.y*m.bx
  result.y=v.x*m.ay+v.y*m.by


proc `&=`*(v:var Vector2d,m:Matrix2d) {.inline.}=
  ## Applies transformation `m` onto `v` in place.
  ## Transforming a vector ignores the translational part
  ## of the matrix.

  #             | AX AY 0 |
  # | X Y 1 | * | BX BY 0 |
  #             | 0  0  1 |
  let newx=v.x*m.ax+v.y*m.bx
  v.y=v.x*m.ay+v.y*m.by
  v.x=newx


proc tryNormalize*(v:var Vector2d):bool=
  ## Modifies `v` to have a length of 1.0, keeping its angle.
  ## If `v` has zero length (and thus no angle), it is left unmodified and
  ## false is returned, otherwise true is returned.

  let mag=v.len

  if mag==0.0:
    return false

  v.x/=mag
  v.y/=mag
  return true


proc normalize*(v:var Vector2d) {.inline.}=
  ## Modifies `v` to have a length of 1.0, keeping its angle.
  ## If  `v` has zero length, an EDivByZero will be raised.
  if not tryNormalize(v):
    raise newException(ValueError,"Cannot normalize zero length vector")

proc transformNorm*(v:var Vector2d,t:Matrix2d)=
  ## Applies a normal direction transformation `t` onto `v` in place.
  ## The resulting vector is *not* normalized.  Transforming a vector ignores the
  ## translational part of the matrix. If the matrix is not invertible
  ## (determinant=0), an EDivByZero will be raised.

  # transforming a normal is done by transforming
  # by the transpose of the inverse of the original matrix
  # this can be heavily optimized by precompute and inline
  #             | | AX AY 0 | ^-1| ^T
  # | X Y 1 | * | | BX BY 0 |    |
  #             | | 0  0  1 |    |
  let d=t.determinant
  if(d==0.0):
    raise newException(ValueError,"Matrix is not invertible")
  let newx = (t.by*v.x-t.ay*v.y)/d
  v.y = (t.ax*v.y-t.bx*v.x)/d
  v.x = newx

proc transformInv*(v:var Vector2d,t:Matrix2d)=
  ## Applies inverse of a transformation `t` to `v` in place.
  ## This is faster than creating an inverse matrix and apply() it.
  ## Transforming a vector ignores the translational part
  ## of the matrix. If the matrix is not invertible (determinant=0), an EDivByZero
  ## will be raised.
  let d=t.determinant

  if(d==0.0):
    raise newException(ValueError,"Matrix is not invertible")

  let newx=(t.by*v.x-t.bx*v.y)/d
  v.y = (t.ax*v.y-t.ay*v.x)/d
  v.x = newx

proc transformNormInv*(v:var Vector2d,t:Matrix2d)=
  ## Applies an inverse normal direction transformation `t` onto `v` in place.
  ## This is faster than creating an inverse
  ## matrix and transformNorm(...) it. Transforming a vector ignores the
  ## translational part of the matrix.

  # normal inverse transform is done by transforming
  # by the inverse of the transpose of the inverse of the org. matrix
  # which is equivalent with transforming with the transpose.
  #             | | | AX AY 0 |^-1|^T|^-1                | AX BX 0 |
  # | X Y 1 | * | | | BX BY 0 |   |  |    =  | X Y 1 | * | AY BY 0 |
  #             | | | 0  0  1 |   |  |                   | 0  0  1 |
  # This can be heavily reduced to:
  let newx=t.ay*v.y+t.ax*v.x
  v.y=t.by*v.y+t.bx*v.x
  v.x=newx

proc rotate90*(v:var Vector2d) {.inline.}=
  ## Quickly rotates vector `v` 90 degrees counter clockwise,
  ## without using any trigonometrics.
  swap(v.x,v.y)
  v.x= -v.x

proc rotate180*(v:var Vector2d){.inline.}=
  ## Quickly rotates vector `v` 180 degrees counter clockwise,
  ## without using any trigonometrics.
  v.x= -v.x
  v.y= -v.y

proc rotate270*(v:var Vector2d) {.inline.}=
  ## Quickly rotates vector `v` 270 degrees counter clockwise,
  ## without using any trigonometrics.
  swap(v.x,v.y)
  v.y= -v.y

proc rotate*(v:var Vector2d,rad:float) =
  ## Rotates vector `v` `rad` radians in place.
  let
    s=sin(rad)
    c=cos(rad)
    newx=c*v.x-s*v.y
  v.y=c*v.y+s*v.x
  v.x=newx

proc scale*(v:var Vector2d,fac:float){.inline.}=
  ## Scales vector `v` `rad` radians in place.
  v.x*=fac
  v.y*=fac

proc stretch*(v:var Vector2d,facx,facy:float){.inline.}=
  ## Stretches vector `v` `facx` times horizontally,
  ## and `facy` times vertically.
  v.x*=facx
  v.y*=facy

proc mirror*(v:var Vector2d,mirrvec:Vector2d)=
  ## Mirrors vector `v` using `mirrvec` as mirror direction.
  let
    sqx=mirrvec.x*mirrvec.x
    sqy=mirrvec.y*mirrvec.y
    nd=1.0/(sqx+sqy) #used to normalize invector
    xy2=mirrvec.x*mirrvec.y*2.0*nd
    sqd=nd*(sqx-sqy)

  if nd==Inf or nd==NegInf:
    return #mirroring around a zero vector is arbitrary=>keep as is is fastest

  let newx=xy2*v.y+sqd*v.x
  v.y=v.x*xy2-sqd*v.y
  v.x=newx


proc `-` *(v:Vector2d):Vector2d=
  ## Negates a vector
  result.x= -v.x
  result.y= -v.y

# declare templated binary operators
makeBinOpVector(`+`)
makeBinOpVector(`-`)
makeBinOpVector(`*`)
makeBinOpVector(`/`)
makeBinOpAssignVector(`+=`)
makeBinOpAssignVector(`-=`)
makeBinOpAssignVector(`*=`)
makeBinOpAssignVector(`/=`)


proc dot*(v1,v2:Vector2d):float=
  ## Computes the dot product of two vectors.
  ## Returns 0.0 if the vectors are perpendicular.
  return v1.x*v2.x+v1.y*v2.y

proc cross*(v1,v2:Vector2d):float=
  ## Computes the cross product of two vectors, also called
  ## the 'perpendicular dot product' in 2d. Returns 0.0 if the vectors
  ## are parallel.
  return v1.x*v2.y-v1.y*v2.x

proc equals*(v1,v2:Vector2d,tol=1.0e-6):bool=
  ## Checks if two vectors approximately equals with a tolerance.
  return abs(v2.x-v1.x)<=tol and abs(v2.y-v1.y)<=tol

proc `=~` *(v1,v2:Vector2d):bool=
  ## Checks if two vectors approximately equals with a
  ## hardcoded tolerance 1e-6
  equals(v1,v2)

proc angleTo*(v1,v2:Vector2d):float=
  ## Returns the smallest of the two possible angles
  ## between `v1` and `v2` in radians.
  var
    nv1=v1
    nv2=v2
  if not nv1.tryNormalize or not nv2.tryNormalize:
    return 0.0 # zero length vector has zero angle to any other vector
  return safeArccos(dot(nv1,nv2))

proc angleCCW*(v1,v2:Vector2d):float=
  ## Returns the counter clockwise plane angle from `v1` to `v2`,
  ## in range 0 - 2*PI
  let a=v1.angleTo(v2)
  if v1.cross(v2)>=0.0:
    return a
  return DEG360-a

proc angleCW*(v1,v2:Vector2d):float=
  ## Returns the clockwise plane angle from `v1` to `v2`,
  ## in range 0 - 2*PI
  let a=v1.angleTo(v2)
  if v1.cross(v2)<=0.0:
    return a
  return DEG360-a

proc turnAngle*(v1,v2:Vector2d):float=
  ## Returns the amount v1 should be rotated (in radians) to equal v2,
  ## in range -PI to PI
  let a=v1.angleTo(v2)
  if v1.cross(v2)<=0.0:
    return -a
  return a

proc bisect*(v1,v2:Vector2d):Vector2d {.noInit.}=
  ## Computes the bisector between v1 and v2 as a normalized vector.
  ## If one of the input vectors has zero length, a normalized version
  ## of the other is returned. If both input vectors has zero length,
  ## an arbitrary normalized vector is returned.
  var
    vmag1=v1.len
    vmag2=v2.len

  # zero length vector equals arbitrary vector, just change to magnitude to one to
  # avoid zero division
  if vmag1==0.0:
    if vmag2==0: #both are zero length return any normalized vector
      return XAXIS
    vmag1=1.0
  if vmag2==0.0: vmag2=1.0

  let
    x1=v1.x/vmag1
    y1=v1.y/vmag1
    x2=v2.x/vmag2
    y2=v2.y/vmag2

  result.x=(x1 + x2) * 0.5
  result.y=(y1 + y2) * 0.5

  if not result.tryNormalize():
    # This can happen if vectors are colinear. In this special case
    # there are actually two bisectors, we select just
    # one of them (x1,y1 rotated 90 degrees ccw).
    result.x = -y1
    result.y = x1



# ***************************************
#     Point2d implementation
# ***************************************

proc point2d*(x,y:float):Point2d =
  result.x=x
  result.y=y

proc sqrDist*(a,b:Point2d):float=
  ## Computes the squared distance between `a` and `b`
  let dx=b.x-a.x
  let dy=b.y-a.y
  result=dx*dx+dy*dy

proc dist*(a,b:Point2d):float {.inline.}=
  ## Computes the absolute distance between `a` and `b`
  result=sqrt(sqrDist(a,b))

proc angle*(a,b:Point2d):float=
  ## Computes the angle of the vector `b`-`a`
  let dx=b.x-a.x
  let dy=b.y-a.y
  result=arctan2(dy,dx)
  if result<0:
    result += DEG360

proc `$` *(p:Point2d):string=
  ## String representation of `p`
  result=rtos(p.x)
  result.add(",")
  result.add(rtos(p.y))

proc `&`*(p:Point2d,t:Matrix2d):Point2d {.noInit,inline.} =
  ## Concatenates a point `p` with a transform `t`,
  ## resulting in a new, transformed point.

  #             | AX AY 0 |
  # | X Y 1 | * | BX BY 0 |
  #             | TX TY 1 |
  result.x=p.x*t.ax+p.y*t.bx+t.tx
  result.y=p.x*t.ay+p.y*t.by+t.ty

proc `&=` *(p:var Point2d,t:Matrix2d) {.inline.}=
  ## Applies transformation `t` onto `p` in place.
  let newx=p.x*t.ax+p.y*t.bx+t.tx
  p.y=p.x*t.ay+p.y*t.by+t.ty
  p.x=newx


proc transformInv*(p:var Point2d,t:Matrix2d){.inline.}=
  ## Applies the inverse of transformation `t` onto `p` in place.
  ## If the matrix is not invertable (determinant=0) , EDivByZero will
  ## be raised.

  #             | AX AY 0 | ^-1
  # | X Y 1 | * | BX BY 0 |
  #             | TX TY 1 |
  let d=t.determinant
  if d==0.0:
    raise newException(ValueError,"Cannot invert a zero determinant matrix")
  let
    newx= (t.bx*t.ty-t.by*t.tx+p.x*t.by-p.y*t.bx)/d
  p.y = -(t.ax*t.ty-t.ay*t.tx+p.x*t.ay-p.y*t.ax)/d
  p.x=newx


proc `+`*(p:Point2d,v:Vector2d):Point2d {.noInit,inline.} =
  ## Adds a vector `v` to a point `p`, resulting
  ## in a new point.
  result.x=p.x+v.x
  result.y=p.y+v.y

proc `+=`*(p:var Point2d,v:Vector2d) {.noInit,inline.} =
  ## Adds a vector `v` to a point `p` in place.
  p.x+=v.x
  p.y+=v.y

proc `-`*(p:Point2d,v:Vector2d):Point2d {.noInit,inline.} =
  ## Subtracts a vector `v` from a point `p`, resulting
  ## in a new point.
  result.x=p.x-v.x
  result.y=p.y-v.y

proc `-`*(p1,p2:Point2d):Vector2d {.noInit,inline.} =
  ## Subtracts `p2`from `p1` resulting in a difference vector.
  result.x=p1.x-p2.x
  result.y=p1.y-p2.y

proc `-=`*(p:var Point2d,v:Vector2d) {.noInit,inline.} =
  ## Subtracts a vector `v` from a point `p` in place.
  p.x-=v.x
  p.y-=v.y

proc equals(p1,p2:Point2d,tol=1.0e-6):bool {.inline.}=
  ## Checks if two points approximately equals with a tolerance.
  return abs(p2.x-p1.x)<=tol and abs(p2.y-p1.y)<=tol

proc `=~`*(p1,p2:Point2d):bool {.inline.}=
  ## Checks if two vectors approximately equals with a
  ## hardcoded tolerance 1e-6
  equals(p1,p2)

proc polar*(p:Point2d,ang,dist:float):Point2d {.noInit.} =
  ## Returns a point with a given angle and distance away from `p`
  result.x=p.x+cos(ang)*dist
  result.y=p.y+sin(ang)*dist

proc rotate*(p:var Point2d,rad:float)=
  ## Rotates a point in place `rad` radians around origo.
  let
    c=cos(rad)
    s=sin(rad)
    newx=p.x*c-p.y*s
  p.y=p.y*c+p.x*s
  p.x=newx

proc rotate*(p:var Point2d,rad:float,org:Point2d)=
  ## Rotates a point in place `rad` radians using `org` as
  ## center of rotation.
  let
    c=cos(rad)
    s=sin(rad)
    newx=(p.x - org.x) * c - (p.y - org.y) * s + org.x
  p.y=(p.y - org.y) * c + (p.x - org.x) * s + org.y
  p.x=newx

proc scale*(p:var Point2d,fac:float) {.inline.}=
  ## Scales a point in place `fac` times with world origo as origin.
  p.x*=fac
  p.y*=fac

proc scale*(p:var Point2d,fac:float,org:Point2d){.inline.}=
  ## Scales the point in place `fac` times with `org` as origin.
  p.x=(p.x - org.x) * fac + org.x
  p.y=(p.y - org.y) * fac + org.y

proc stretch*(p:var Point2d,facx,facy:float){.inline.}=
  ## Scales a point in place non uniformly `facx` and `facy` times with
  ## world origo as origin.
  p.x*=facx
  p.y*=facy

proc stretch*(p:var Point2d,facx,facy:float,org:Point2d){.inline.}=
  ## Scales the point in place non uniformly `facx` and `facy` times with
  ## `org` as origin.
  p.x=(p.x - org.x) * facx + org.x
  p.y=(p.y - org.y) * facy + org.y

proc move*(p:var Point2d,dx,dy:float){.inline.}=
  ## Translates a point `dx`, `dy` in place.
  p.x+=dx
  p.y+=dy

proc move*(p:var Point2d,v:Vector2d){.inline.}=
  ## Translates a point with vector `v` in place.
  p.x+=v.x
  p.y+=v.y

proc sgnArea*(a,b,c:Point2d):float=
  ## Computes the signed area of the triangle thru points `a`,`b` and `c`
  ## result>0.0 for counter clockwise triangle
  ## result<0.0 for clockwise triangle
  ## This is commonly used to determinate side of a point with respect to a line.
  return ((b.x - c.x) * (b.y - a.y)-(b.y - c.y) * (b.x - a.x))*0.5

proc area*(a,b,c:Point2d):float=
  ## Computes the area of the triangle thru points `a`,`b` and `c`
  return abs(sgnArea(a,b,c))

proc closestPoint*(p:Point2d,pts:varargs[Point2d]):Point2d=
  ## Returns a point selected from `pts`, that has the closest
  ## euclidean distance to `p`
  assert(pts.len>0) # must have at least one point

  var
    bestidx=0
    bestdist=p.sqrDist(pts[0])
    curdist:float

  for idx in 1..high(pts):
    curdist=p.sqrDist(pts[idx])
    if curdist<bestdist:
      bestidx=idx
      bestdist=curdist

  result=pts[bestidx]


# ***************************************
#     Misc. math utilities that should
#     probably be in another module.
# ***************************************
proc normAngle*(ang:float):float=
  ## Returns an angle in radians, that is equal to `ang`,
  ## but in the range 0 to <2*PI
  if ang>=0.0 and ang<DEG360:
    return ang

  return ang mod DEG360

proc degToRad*(deg:float):float {.inline.}=
  ## converts `deg` degrees to radians
  deg / RAD2DEGCONST

proc radToDeg*(rad:float):float {.inline.}=
  ## converts `rad` radians to degrees
  rad * RAD2DEGCONST


