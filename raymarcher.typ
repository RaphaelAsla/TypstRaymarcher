#import calc: *

#let SKY_COLOR = (0.5, 0.7, 0.9)
#let GROUND_COLOR = (0.3, 0.25, 0.2)
#let CYLINDER_CENTER = (0.0, 1.0, 1.5)
#let LIGHT_POSITION = (3.0, 4.0, -1.0)

#let GRID_SIZE = 50 // Start small, because of Typst caching, memory usage skyrockets, I can only go to 140x140 on 100 MAX_STEPS before crashing (image in read me)
#let MAX_STEPS = 50 // Same goes here
#let MAX_DIST = 100.0
#let SURF_DIST = 0.001
#let UNIT = 5pt

#let TEXTURE = json("./texture.json")
#let TEXTURE_WIDTH = TEXTURE.remove(0)
#let TEXTURE_HEIGHT = TEXTURE.remove(0)

#let scaleVector(v, s) = (v.at(0) * s, v.at(1) * s, v.at(2) * s)
#let mulVectors(a, b) = (a.at(0) * b.at(0), a.at(1) * b.at(1), a.at(2) * b.at(2))
#let addVectors(a, b) = (a.at(0) + b.at(0), a.at(1) + b.at(1), a.at(2) + b.at(2))
#let subVectors(a, b) = (a.at(0) - b.at(0), a.at(1) - b.at(1), a.at(2) - b.at(2))
#let subVectors2(a, b) = (a.at(0) - b.at(0), a.at(1) - b.at(1))
#let dot(a, b) = a.at(0) * b.at(0) + a.at(1) * b.at(1) + a.at(2) * b.at(2)
#let dot2(a, b) = a.at(0) * b.at(0) + a.at(1) * b.at(1)
#let abs2(v) = (abs(v.at(0)), abs(v.at(1)))
#let max2(a, b) = (max(a.at(0), b.at(0)), max(a.at(1), b.at(1)))
#let pow3(v, p) = (pow(v.at(0), p), pow(v.at(1), p), pow(v.at(2), p))
#let getLength(v) = sqrt(dot(v, v))
#let getLength2(v) = sqrt(dot2(v, v))
#let normalize(v) = scaleVector(v, 1.0 / getLength(v))
#let reflect(d, n) = subVectors(d, scaleVector(n, 2.0 * dot(d, n)))
#let opU(a, b) = if a.at(0) < b.at(0) { a } else { b }

#let intToRGB(i) = (
  (i.bit-rshift(16)).bit-and(0xFF) / 255,
  (i.bit-rshift(8)).bit-and(0xFF) / 255,
  i.bit-and(0xFF) / 255,
)

// https://iquilezles.org/articles/distfunctions/
#let sdCylinder(p, h, r, id) = {
  let d = subVectors2(abs2((getLength2((p.at(0), p.at(2))), p.at(1))), (r, h))
  (min(max(d.at(0), d.at(1)), 0.0) + getLength2(max2(d, (0.0, 0.0))), id)
}

#let getCylinderUV(p) = {
  let P = subVectors(p, CYLINDER_CENTER)
  let angle = atan2(P.at(0), P.at(2)).rad()
  let u = angle / (2.0 * 3.14159) + 0.5
  let v = (P.at(1) + 1.0) / 2.0
  (u, v)
}

#let checkerTexture(uv, col1, col2) = {
  let u = floor(uv.at(0))
  let v = floor(uv.at(1))
  if rem(u + v, 2.0) == 0 { col2 } else { col1 }
}

#let getTextureColor(p, id) = {
  if id == 1 {
    let uv = getCylinderUV(p)
    // wrap it
    let texX = min(int(rem(uv.at(0), 1.0) * TEXTURE_WIDTH), TEXTURE_WIDTH - 1)
    let texY = min(int(rem(uv.at(1), 1.0) * TEXTURE_HEIGHT), TEXTURE_HEIGHT - 1)
    intToRGB(TEXTURE.at(texY * TEXTURE_WIDTH + texX))
  } else if id == 2 {
    let uv = (p.at(0), p.at(2))
    checkerTexture(uv, GROUND_COLOR, scaleVector(GROUND_COLOR, 1.5))
  }
}

#let sdMap(p) = {
  let s = sdCylinder(subVectors(p, CYLINDER_CENTER), 1.0, 0.45, 1)
  let g = (p.at(1), 2)
  opU(g, s)
}

#let getNormal(p) = {
  let (d, _) = sdMap(p)
  let e = (0.01, 0.0)
  let n = (
    d - sdMap(subVectors(p, (e.at(0), e.at(1), e.at(1)))).at(0),
    d - sdMap(subVectors(p, (e.at(1), e.at(0), e.at(1)))).at(0),
    d - sdMap(subVectors(p, (e.at(1), e.at(1), e.at(0)))).at(0),
  )
  normalize(n)
}

#let rayMarch(ro, rd) = {
  let t = 0.0
  let p = ro
  let (d, id) = sdMap(p)
  let step = 0
  while d > SURF_DIST and t < MAX_DIST and step < MAX_STEPS {
    p = addVectors(ro, scaleVector(rd, t))
    (d, id) = sdMap(p)
    t += d
    step += 1
  }
  (p, id, (d < SURF_DIST))
}

// https://iquilezles.org/articles/rmshadows/
#let softShadow(ro, rd, mint, maxt, k) = {
  let res = 1.0
  let t = mint
  for i in range(32) {
    if t < maxt {
      let (d, id) = sdMap(addVectors(ro, scaleVector(rd, t)))
      if d < SURF_DIST {
        return 0.0
      }
      res = min(res, k * d / t)
      t += d
    }
  }
  res
}

#let getLight(p, id) = {
  let color = getTextureColor(p, id)
  let n = getNormal(p)
  let l = normalize(subVectors(LIGHT_POSITION, p))
  let diff = max(dot(n, l), 0.0)
  let r = reflect(scaleVector(l, -1.0), n)
  let v = normalize(subVectors((0.0, 0.0, 5.0), p))
  let spec = pow(max(dot(r, v), 0.0), 32.0)
  let diffuse = mulVectors(scaleVector((1.0, 0.9, 0.7), diff), color)
  let specular = scaleVector(scaleVector((1.0, 0.9, 0.7), 0.5), spec)
  let ambient = scaleVector(color, 0.5)
  let shadow = softShadow(addVectors(p, scaleVector(n, SURF_DIST * 2.0)), l, 0.02, 5.0, 16.0)
  addVectors(ambient, scaleVector(addVectors(diffuse, specular), shadow))
}

#let castRay(i, j) = {
  let x = i / GRID_SIZE * 2.0 - 1.0
  let y = -(j / GRID_SIZE * 2.0 - 1.0)
  let ro = (0.0, 1.0, -0.5)
  let rd = normalize((x, y, 1.0))
  let (p, id, h) = rayMarch(ro, rd)
  let color = ()
  if h {
    color = getLight(p, id)
  } else {
    color = SKY_COLOR
  }
  pow3(color, 0.4545)
}

#page(
  width: UNIT * GRID_SIZE,
  height: UNIT * GRID_SIZE,
  margin: 0pt,
  fill: black,
  for i in range(GRID_SIZE) {
    for j in range(GRID_SIZE) {
      let color = castRay(i, j)
      color = rgb(
        int(clamp(color.at(0), 0.0, 1.0) * 255),
        int(clamp(color.at(1), 0.0, 1.0) * 255),
        int(clamp(color.at(2), 0.0, 1.0) * 255),
      )
      place(dx: UNIT * i, dy: UNIT * j, square(width: UNIT, height: UNIT, fill: color))
    }
  },
)
