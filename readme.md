# nimPDF

[![Build Status (Travis)](https://img.shields.io/travis/jangko/nimpdf/master.svg?label=Linux%20/%20macOS "Linux/macOS build status (Travis)")](https://travis-ci.org/jangko/nimpdf)
[![Windows build status (Appveyor)](https://img.shields.io/appveyor/ci/jangko/nimpdf/master.svg?label=Windows "Windows build status (Appveyor)")](https://ci.appveyor.com/project/jangko/nimpdf)
![nimble](https://img.shields.io/badge/available%20on-nimble-yellow.svg?style=flat-square)
![license](https://img.shields.io/github/license/citycide/cascade.svg?style=flat-square)

nimPDF is a free PDF writer library, written mostly in nim programming language

nimPDF was heavily inspired by PHP-[FPDF](http://www.fpdf.org) but also influenced by  [jagPDF](http://www.jagpdf.org), [libHaru](http://www.libharu.org)(especially for the demo), [PyFPDF](https://code.google.com/p/pyfpdf), [pdfkit](http://devongovett.github.io/pdfkit)

after lodePNG substituted with PNG decoder written in nim, nimPDF become one step closer to 100% pure nim

nimPDF implements the following features(see [demo.pdf](https://github.com/jangko/nimpdf/blob/master/demo/demo.pdf)):

nimPDF version 0.4.0 introduces many breaking changes, see [migration guide](migration.md) to help you change your code.

* **images**
  - PNG -- ~~use [LodePNG](lodev.org/lodepng), still in C~~ now written in nim
  - JPEG -- use [uJPEG (MicroJPEG) -- KeyJ's Small Baseline JPEG Decoder](http://keyj.emphy.de/nanojpeg), still in C
  - BMP -- use [EasyBMP](http://easybmp.sourceforge.net), already ported to nim, support 1bit, 4bit, 8bit, 16bit, 24bit, and 32bit images
  - beside transparency from original image(such as from PNG), you can adjust individual image transparency as easy as other elements in your document

* **text and fonts**
  - support TTF/TTC font subsetting -- use [Google sfntly](code.google.com/p/sfntly), ported(partially) to nim and modified
  - you can easily tell the library to look for fonts in certain folder(s)
  - you only need to ask for font family name and it's style, the library will try to find the right one for you(if avilable)
  - text encoded in UTF-8 if you use TTF/TTC
  - 14 base font in PDF use Standard,MacRoman,WinAnsi encoding
  - TTF/TTC fonts can be written vertically if they have vertical metrics

* **Path construction**
  - straight segments, Bezier curves, elliptical arcs, roundrect
  - join styles and miter limits
  - dash patterns
  - path clipping
  - arbitrary path bounding box calculation(i use it to implement gradient too)
  - construct path from mathematical function - taken from [ C# GraphDisplay](http://www.codeproject.com/Articles/58280/GraphDisplay-a-Bezier-based-control-for-graphing-f)

* **Color spaces**
  - Gray, RGB, CMYK
  - alpha channel for text, path, and images too!
  - linear gradient to fill any closed shape
  - radial gradient to fill any closed shape

* **Interactive Features**(see demo folder)
  - Page Labels
  - Document Outline
  - Hyperlinks
  - Text annotation
  - Encryption(protect document with password)
  - choose between ARC4-40, ARC4-128, AES-128, AES-256 encryption mode
  - Form Field:
    - TextField
    - Combo Box
    - Radio
    - Push Button
    - List Box
    - Check Box

* **Coordinate Space**
  - top-down mode
  - bottom-up mode
  - unit measured in point, inch, and mm

* **others**
  - output to file or memory using nim stream module
  - images, fonts, and other resources search path(s)
  - document compression using flate decode(use lodePNG compressor)
  - transformation and graphics state

* **unimplemented features**
  - CIE based color space
  - patterns(this can be achieved using PDF primitives and path clipping)
  - ~~encryption~~
  - ~~annotation~~
  - ~~hyperlinks~~
  - ~~other encoding beside UTF-8~~(nim has [encoding](http://nim-lang.org/docs/encodings.html) module, i will use it someday)
  - basic text formating(will be implemented as separate layer)
  - ~~radial gradient~~ and multi color gradient
  - table generator(as in FPDF)(will be implemented as separate layer)
  - ~~document outline~~
  - permission
  - digital signature

# Documentation
The documentation is generated using docutils

The documentation provided may not be complete, please help to improve it

# Installation and build instructions

* build general demo: `nim c demo`
* build specific demo: goto nimPDF/demo folder, type `nim e build.nims`

# Dependencies

* ![nimBMP](https://github.com/jangko/nimBMP)
* ![nimPNG](https://github.com/jangko/nimPNG)
* ![nimAES](https://github.com/jangko/nimAES)
* ![nimSHA2](https://github.com/jangko/nimSHA2)
