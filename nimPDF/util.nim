import gstate

proc HSL2RGB(RGBColor, REAL hue, REAL sat, REAL lum) {
    REAL v, red, green, blue, m, sv, fract, vsf, mid1, mid2;
    int sextant;

    red = lum; green = lum; blue = lum; //default to gray
    v = (lum <= 0.5) ? (lum * (1.0 + sat)) : (lum + sat - lum * sat);
    m = lum + lum - v; sv = (v - m) / v;
    hue /= 60.0;  //get into range 0..6
    sextant = floor(hue);  // int32 rounds up or down.
    fract = hue - sextant; vsf = v * sv * fract;  mid1 = m + vsf; mid2 = v - vsf;

    if (v > 0) {
        switch (sextant) {
            case 0: red = v; green = mid1; blue = m; break;
            case 1: red = mid2; green = v; blue = m; break;
            case 2: red = m; green = v; blue = mid1; break;
            case 3: red = m; green = mid2; blue = v; break;
            case 4: red = mid1; green = m; blue = v; break;
            case 5: red = v; green = m; blue = mid2; break;
        }
    }
	cc->r = red; cc->g = green; cc->b = blue;
}

proc RGB2HSL(
r /= 255, g /= 255, b /= 255;

  var max = Math.max(r, g, b), min = Math.min(r, g, b);
  var h, s, l = (max + min) / 2;

  if (max == min) {
    h = s = 0; // achromatic
  } else {
    var d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);

    switch (max) {
      case r: h = (g - b) / d + (g < b ? 6 : 0); break;
      case g: h = (b - r) / d + 2; break;
      case b: h = (r - g) / d + 4; break;
    }

    h /= 6;
}

static void HSV2RGB(spruceColor* cc, REAL h, REAL s, REAL v) {
	h = (fmod(h, 360.0f) / 360.0) * 360.0;
	int i = floor(fmod((h / 60), 6));
	REAL f = (h / 60) - i;

    REAL vs[] = {v, v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)};
    static int perm[][3] = {{0, 3, 1}, {2, 0, 1}, {1, 0, 3}, {1, 2, 0}, {3, 1, 0}, {0, 1, 2}};
	cc->r = vs[perm[i][0]]; cc->g = vs[perm[i][1]]; cc->b = vs[perm[i][2]];
}