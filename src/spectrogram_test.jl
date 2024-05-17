"""
simple test for the spectrogramm functionality.
"""

using QWTWPlot 
using Printf

#----------- data for a single line----------------
x1 = collect(-10.0:0.1:25)
y1 = sin.(x1)

# ------------------data for the spectrogramm------------------------
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
p = zeros(3, ny, nx)
size(z)

for i = 1:ny
	yy = ymin + (i-1) * b
	for j  =  1:nx
		xx = xmin + (j-1) * b
		z[i, j] = xx * xx * yy
		p[1, i, j] = xx
		p[2, i, j] = yy
		p[3, i, j] = 18.0
	end
end

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


# start the library
qstart(debug = false, qwtw_test = true, libraryName = raw"C:\Users\ISandler\space\qwtw\lib_win32_build\release\qwtwd") 
#qstop()

# draw the spectrogramm
qspectrogram()
#result = qspectrogram_info(ymin, ymax, xmin, xmax, z, t = t)
result = qspectrogram_info(ymin, ymax, xmin, xmax, z, p = p, t = t)
#result = qspectrogram_info(ymin, ymax, xmin, xmax, z)
qxlabel("X label !!!!")
qylabel("Y label !!!!")
qtitle("The Title!")

# draw the line plot
qfigure()
qplot1(x1, y1, "line", "-eb", 3)

# make a 'trajectory'
R = min(wx, wy) * 0.5
t2 = maximum(t)
t1 = minimum(t)
wt = t2 - t1
bdt = wt / 1000.0
bt = collect(t1:bdt:t2)
fi = (bt .- t1) .* (2.0 * pi / wt)
bx = sin.(fi) .* R
by = cos.(fi) .* R
bz = ones(length(bx))
qEnableCoordBroadcast(bx, by, bz, bt)

qfigure()
qplot2(bx, by, bt, "traj", "-eb", 2, 4)
qtitle("trajectory")


qsmw()

qstop() # unload the library (its working!!)

