#callback function test

using QWTWPlot 
using Printf
qstart()

# lets create simple a sinus plot
x = collect(0.0:0.01:1.0)
y=sin.(x.*10.0)
qfigure()
qplot1(x, y, "test", "-eb", 5)
qtitle("press arrow button and push me")


## very simple callback:
#function very_simple_callback(i::QCBInfo)
#	@printf "hello from callback! \n"
#end
#qsetCallback(very_simple_callback)
#
## more useful callback:
#function my_callback(q::QCBInfo)
#	@printf "plot %d, line %d (%s);   index = %d; xx = %d; yy = %d \n" q.plotID q.lineID q.label q.index q.xx  q.yy
#	@printf "x = %f;  y = %f; z = %f; time = %f\n\n" q.x  q.y q.z q.time
#end
## lets register it:
#qsetCallback(my_callback)

# ============= bigger callback: ==============
# draw some points
x = sort(rand(10))
y = rand(10)
f = qfigure()
p = qplot1(x, y, "points", " em", 5)
qtitle("the points")

# this is the callback function
function bigger_callback(q::QCBInfo)
	global p, f
	if q.plotID == f # not react on this plot
		return
	end
	# make another set of points
	# number of points came as a parameter
	nn = Int32(round(q.x*10.0))
	x = sort(rand(nn))
	y = rand(nn)
	#@printf "nn = \n%d \n" nn
	qfigure(f)  # make 'f' active
	qremove(p)  # remove existing line
	p = qplot1(x, y, "points", " em", 5) # add new line to the plot
end
qsetCallback(bigger_callback)


