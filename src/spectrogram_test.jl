"""
simple test for the spectrogramm functionality.
"""
using QWTWPlot 
using Printf

# data for a single line
x1 = collect(-10.0:0.1:25)
y1 = sin.(x1)

# data for the spectrogramm
x = collect(-3.0:0.1:2.0)
y = collect(-2.0:0.1:1.0)
z = [ a^2 * b^2  for a in y, b in x ]	# the values
size(z)

t = [ -10.0  for a in y, b in x ]		# the 't' parameters
sy, sx = size(t)
sy * sx
j = sy >> 1								# make a line in a middle
for i=0:sx-1
	t[j, i+1] = x1[1] + i * (x1[end] - x1[1]) / (sx-1)
end

t[15, 10]

# some statistics
maximum(z)
minimum(z)
maximum(t)
minimum(t)
size(t)

# start the library
qstart(debug = false, qwtw_test = true, libraryName = raw"C:\Users\ISandler\space\qwtw\lib_win32_build\release\qwtwd") 

# draw the spectrogramm
qspectrogram()
result = qspectrogram_info(x[1], x[end], y[1], y[end], z, t = t)
qxlabel("X label !!!!")
qylabel("Y label !!!!")
qtitle("The Title!")

# draw the line plot
qfigure()
qplot1(x1, y1, "line", "-eb", 3)

qsmw()

qstop() # unload the library (its working!!)

