
using QWTWPlot 
using Printf

x = collect(-3.0:0.1:2.0)
y = collect(-3.0:0.1:2.0)
z = [ a^2 * b^2  for a in x, b in y ]
maximum(z)
minimum(z)

qstart(debug = true, qwtw_test = true, libraryName = raw"C:\Users\ISandler\space\qwtw\lib_win32_build\release\qwtw") 
qspectrogram()
result = qspectrogram_info(x[1], x[end], y[1], y[end], z)



qxlabel("X label !!!!")
qylabel("Y label !!!!")

qtitle("The Title!")

qsmw()
qstop()