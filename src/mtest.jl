#   very small QWTwPlot "Marble" test

using QWTWPlot 

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

