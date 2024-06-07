"""
qsetpos function test
"""

using QWTWPlot 
using Printf

qstart()
#qstart(debug = false, qwtw_test = true, libraryName = raw"C:\Users\ \space\qwtw\lib_win32_build\release\qwtw")

x = collect(0.0:0.1:10.0)
y = sin.(x)
a = qfigure()
qplot1(x, y, "mtest", "-eb", 4)

result, xx, yy, ww, hh = qsetpos(a)

result, xx, yy, ww, hh = qsetpos(a, true, xx, yy, 500, hh)


