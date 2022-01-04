#   very small QWTwPlot "Marble" test

using QWTWPlot 
using Printf

qstart(debug = false) 

tMax = 10.0 # let it be `maximum time`
t = Array(range(0.0,stop=tMax, length=10000)); # our `time info`
n = length(t);

mwn = 4 # for this small example, we have only 4 points
t4 = Array(range(0.,stop=tMax, length=4)); # create corresponding time info (for our cool magic markers)
north1 = [65.688713, 65.698713, 65.678713, 65.60]; # coords in degrees
east1 = [27.901073, 28.111073, 28.005073, 27.9]; # coords in degrees
qfmap()
qplot2(east1, north1, t4, "trajectory #2", "-rb",  3);
qtitle("Marble test");

using QWTWPlot 
using Printf

qstart(debug = false, qwtw_test=true, libraryName="/home/igor/space/qwtw/lib/release/libqwtw") 

x = collect(0.0:0.1:10)
y = sin.(x)
f = qfigure()
p = qplot1(x, y, "test", "-eb", 5)
qtitle("test")



f1 = qfigure()
x1 = rand(10)
y1 = rand(10)
p1 = qplot1(x1, y1, "points", " rb", 5)
qtitle("callback test")


function cb(q::QCBInfo)
	global p1
	global f1
	@printf "plot %d, line %d (%s);   index = %d; xx = %d; yy = %d \n" q.plotID q.lineID q.label q.index q.xx  q.yy
	@printf "x = %f;  y = %f; z = %f; time = %f\n\n" q.x  q.y q.z q.time

	nn = Int32(round(q.time))
	if nn > 0
		qfigure(f1)
		qremove(p1)
		x1 = rand(nn)
		y1 = rand(nn)
		p1 = qplot1(x1, y1, "points", " rb", 5)
	end
end
qsetCallback(cb)

