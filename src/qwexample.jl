#   simple QWTwPlot package example
#   look at wiki page for more info
#   wiki lives here: https://github.com/ig-or/QWTWPlot.jl/wiki
#   also, useful page located here: https://github.com/ig-or/QWTWPlot.jl/wiki/qwtw-library-features
#   

using QWTWPlot # start 'qwtw' library
using Random
qstart(debug = false) # sorry, have to call this explicity here, not in __init__

# draw thin blue 'sinus':
tMax = 10. # let it be `maximum time`
#t = Array(linspace(0.,tMax, 10000)); # our `time info`
t = Array(range(0.,stop=tMax, length=10000)); # our `time info`
n = length(t);
y = sin.(t);     # we will draw this signal
qfigure(1); # "1" the number of the first plot window
 # parameters: 'x' and 'y' data vectors, then 'name of this line', then 'style description', then 'line width'
qplot(t, y, "blue line", "-b", 1)

# add green thick line (another sinus) on the same plot:
y = sin.(t .* 4.) + cos.(t * 0.8);
qplot(t, y, "thick green line", "-g", 4) #'x' and 'y' data vectors, then 'name of this line', then 'style description', then 'line width'
qtitle("first plot window") # add a title for the first plot
qxlabel("time (in seconds)") # put a label on X axis
qylabel("happiness") # put a label on Y axis

#= By default, "ZOOM" mode is active. This means that
	now you can select some part of the plot with left mouse button
	(press left mouse button, select what you need on a plot,
	release left mouse button).
	Right mouse button will return you back to the previous `ZOOM` state.
	And try how mouse wheel is working in this mode also.

	Button with a "hand" - it's a "pan mode".  It will shift all the picture,
	but it will not change scale.

	"disk" button - allow you to save image to a (png) file

	"[]" buttom means "make square axis" i.e. make equal scale for X and Y axis.
	this `[]` button is useful when you draw something like a `top view plot`

	Real magic is in left and right buttons; see below about it.
    and also look at https://github.com/ig-or/QWTWPlot.jl/wiki/qwtw-library-features

=#

# create another plot, with high frequency signal and noise
noise = rand(n);
y = sin.(t * 100.) + noise;
qfigure(2)   # make a plot with another plot ID
qplot(t, y, "sinus + noise", "-m", 2)
qtitle("frequency test")

#= what is the frequency of our signal from last window?
 pless "f" button, another small window will appear;
 then - on new small window - select "sinus + noise",
 select "4" from combo box and close this small window (with Alt-F4 (for example))

 after this, "frequency" plot will be created,
 actually, it is called "Power Spectral Dencity plot"
 PSD creation code was implemented by Anton Klimenkov
=#

# add another line to the first plot:
t1 = Array(range(0.,stop = 10., length=5))
y1 = cos.(t1 * 0.5)
qfigure(1); # switch back to the first plot

# if we do not need the lines, only symbols:
qplot1(t1, y1, "points and line #1", " eb",  8)

#= the parameter #4 in qplot or qplot1 functions is a "line style"
	it is a string consisting from 1 or 2 or 3 characters
	the last symbol is a color description;
	first is always a line style:
	middle is symbol type

	for additional info about this line style,
	see info here:
	https://raw.githubusercontent.com/wiki/ig-or/qwtwplot/line-style.md
=#

 # parameters: 'x' and 'y' data vectors, then 'name of this line',
 # then 'style description', then 'line width', and "symbol size"
qplot(t1, y1, "points and line #2", "-tm", 2, 10)

#= now, try to use an arrow burtton: it will draw a marker on all the plots.
	Press "Arrow" button, then left mouse button somewhere inside the plot.
	Notice that markers will appear on all the plots, and all the lines.

	Next, select some region on one of the plots using ZOOM tool;  and press right "clip" button.
	All the plots will (try to) zoom to the same region.
=#

# create a circle on another plot window:
x = sin.(t .* (2.0*pi/tMax)); y = cos.(t .* (2.0*pi/tMax));
qfigure(3);
qplot2(x, y, "circle #1", "-r", 2, t)
qtitle("circle")

# now press "[]" buttol in order to make a circle look like circle

# try to use left button ("ARROW") on a circle plot - it also works

# draw one more circle on the same plot:
t1 = Array(range(0.,  stop=2. * pi, length=8));
x1 = 0.5*sin.(t1);
y1 = 0.5*cos.(t1);
qplot2p(x1, y1, "circle #2", " ec", 20, t1)

## small 3D example: - disabled (not supported now because of the license limitations) 
##qf3d(124)
##qplot3d(x, y, x .* y, "3D", "-g", 1, t)
##qplot3d(x1, y1, x1 .* y1, "3D", "-r", 8, t1)
#
#= show "main window" in order to control all other windows:
it will allow you to switch between all other plot windows

When you have more than 15 plots, it's very convinient to switch
between plots using this helpful window
=#
qsmw()


# another 2000000 points plot:
N = 1000000.0
R1 = 10.0
R2 = 4.0
R3 = 1.2
t = collect(1.0:N) .* (2.0 * pi / N)
x = similar(t)
y = similar(t)
x1 = similar(t)
y1 = similar(t)
@. x = sin(t) * R1 + sin(t * 10.) * R2 + sin(t * 24.) * R3 + rand() * R3*0.25
@. y = cos(t) * R1 + cos(t * 9.) * R2 + cos(t * 21.) * R3 + rand() * R3*0.25
@. x1 = sin(t) * R1 + sin(t * 11.) * R2 + sin(t * 31.) * R3 + randn() * R3*0.015
@. y1 = cos(t) * R1 + cos(t * 8.) * R2 + cos(t * 23.) * R3 + randn() * R3*0.015
qfigure()
qplot2p(x, y, "$N test 1", " tb", 5, t)
qplot2p(x1, y1, "$N test 2", " eg", 3, t)
qxlabel("?"); qylabel("?"); qtitle("$N points test");
#
## now lets try to draw a map;
#
#mwn = 4 # for this small example, we have only 4 points
#north = [55.688713, 55.698713, 55.678713, 55.60]; # coords in degrees
#east = [37.901073, 37.911073, 37.905073, 37.9]; # coords in degrees
#t4 = Array(range(0.,stop=tMax, length=4)); # create corresponding time info (for our cool magic markers)
#
#
#qfmap(5)
#qplot2p(east, north, "trajectory #1", "-rb",  20, t4);
#qtitle("top view test");
#
##another map:
#north1 = [65.688713, 65.698713, 65.678713, 65.60]; # coords in degrees
#east1 = [27.901073, 28.111073, 28.005073, 27.9]; # coords in degrees
#qfmap(6)
#qplot2(east1, north1, "trajectory #2", "-rb",  2, t4);
#qplot2(east1, north1, "points", " er",  20, t4);
#qtitle("top view test #2");


# if everything is working as you need, you can
# close all the plots with following command:
#qclear()

# if you need bugs to be fixed, do not hesitate to fix them %)
# and create a pull request
# and/or create an issue on github - maybe it'll be
# much faster for me to fix everything or make some  changes or add functionality
#

