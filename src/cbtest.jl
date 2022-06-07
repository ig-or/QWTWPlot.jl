#callback functions test

using QWTWPlot 
using Printf
qstart()

# lets create simple a sinus plot
x = collect(0.0:0.01:1.0)
y=sin.(x.*10.0)
qfigure()
qplot1(x, y, "test", "-eb", 5)#
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
	# make another set of points
	# number of points came as a parameter
	nn = Int32(round(q.x*10.0))

	@printf "bigger_callback   nn=%d\n"  nn
	@printf "plot %d, line %d (%s);   index = %d; xx = %d; yy = %d \n" q.plotID q.lineID q.label q.index q.xx  q.yy
	@printf "x = %f;  y = %f; z = %f; time = %f\n\n" q.x  q.y q.z q.time

	if q.plotID == f # not react on this plot
		return
	end

	qfigure(f)  # make 'f' active
	if p >= 0
		qremove(p)  # remove existing line
	end


	if nn > 0
		x = sort(rand(nn))
		y = rand(nn)
		#@printf "nn = \n%d \n" nn
		p = qplot1(x, y, "points", " em", 5) # add new line to the plot
	else
		p = -1
	end
end
qsetCallback(bigger_callback)

# now you can test this bigger_callback function is called when you 
# push left mouse button over the very first plot, in 'marker mode'
#
#
#

#And this is very simple 'clip' callback
#it is called when you press 'clip' button (second from the right)
function clipCallback(q::QClipCallbackInfo)
	@printf "\nclipCallback!\n\tt1 = %f\n\tt2 = %f; clipGroup=%d\n\n" q.t1  q.t2 q.clipGroup
	return
end

qsetClipCallback(clipCallback)

