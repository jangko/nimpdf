# migration guide from nimPDF 0.3.x to 0.4.x

This breaking changes needed because not only the new features need code restructuring
but also the old code not conforms with Nim coding style.

* Document object become PDF object
* initPDF() become newPDF()
* makeXXXDest() become newXXXDest(), and only accept Page object as first argument, not Document and Page anymore
* makeOutline() become outline()
* getSize() become getPageSize()
* makeRGB() become initRGB()
* makeCYMK() become initCYMK()
* makeCoord() become initCoord()
* makeLinearGradient() become newLinearGradient()
* makeRadialGradient() become newRadialGradient()
* roundRect() become drawRoundRect(), longer but consistent with the rest of the API
* makeDoctOpt() become newPDFOptions()
* makePageSize() become initPageSize()


