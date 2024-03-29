"""
simple test for the spectrogramm functionality.
"""
using QWTWPlot 
using Printf

# data for a single line
x1 = collect(-10.0:0.1:25)
y1 = sin.(x1)

# data for the spectrogramm
xmin = -8.0
xmax = 5.0
wx = xmax - xmin
ymin = -2.0
ymax = 1.0
wy = ymax - ymin

b = 0.1
nx = ceil(Int, wx / b)
ny = ceil(Int, wy / b)
z = zeros(ny, nx)
size(z)
z[2, 2] = 10.0
z[3, 3] = 10.0
z[2, 3] = 8.0
z[3, 2] = 8.0
z[end-1, end-1] = 12.0
z[end-2, end-2] = 12.0


t = zeros(ny, nx)


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

ymin = minimum(y)
ymax = maximum(y)
xmin = minimum(x)
xmax = maximum(x)

# start the library
qstart(debug = false, qwtw_test = true, libraryName = raw"C:\Users\ISandler\space\qwtw\lib_win32_build\release\qwtwd") 

# draw the spectrogramm
qspectrogram()
#result = qspectrogram_info(ymin, ymax, xmin, xmax, z, t = t)
result = qspectrogram_info(ymin, ymax, xmin, xmax, z)
qxlabel("X label !!!!")
qylabel("Y label !!!!")
qtitle("The Title!")

# draw the line plot
qfigure()
qplot1(x1, y1, "line", "-eb", 3)

qsmw()

qstop() # unload the library (its working!!)

