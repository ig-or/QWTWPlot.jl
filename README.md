# QWTWPlot
This is another 2D plotting tool for Julia language.  It is based on `qwtw` `C` library, which is based on `QWT` library which is based on `QT` library. Also, `MathGL` and `KDE Marble` libraries are used.

quickly draw a lot of points:
 ![](docs/img/logo.png "big plot")

Current version supposed to work for `Windows` _and_ for `Linux` x64 bits.
It is very useful for data analysis (like if you have a dynamic systems with a big state vector, sometimes its difficult to say how one variable influence other variable).

## how to install it

* just install it as usual Julia package, with `] add QWTWPlot` .  

BTW, this is possible because of https://github.com/JuliaPackaging/BinaryBuilder.jl

look at usage example here: https://github.com/ig-or/QWTWPlot.jl/blob/master/src/qwexample.jl   and for callback also here https://github.com/ig-or/QWTWPlot.jl/blob/master/src/cbtest.jl,
or just `] dev QWTWPlot`


## the most useful features

* all plots are "connected" - this makes it very easy to analyze small parts of long dynamic process with a lot of variables;  what this means:


  * when you point a 'marker' on one plot, you can see markers on all other plots pointing on the 'same place'

how "markers" looks like:

 ![](docs/img/marker.png "marker examples")


  * after you select some interesting area on plot "X", and then press right plot button ("CLIP" button),  all the other plots are resizing accordingly ("time" interval on all other plots became equal to this interval on plot "X")

First, select some interesting area on one plot:

 ![](docs/img/clip-1.png "select area")

After this, press "clip" button:

 ![](docs/img/clip-2.png "clipping examples")
 
 BTW, if you do not want that *all* plots do resize after this, use `qclipgrp` function. See more details in qwexample.jl about how to use it.


* you can create a "Power Spectral Dencity" plot for some  (selected) area of your plot, by pressing "f" button

First, select a desired time range with ZOOM tool and then press "f" button:

![](docs/img/psd-1.png "marker examples")

After this (in new small window) select lines for which you'd like to create a PSD plots, select "window size" (not very big) and close this small window (Alt+F4?).  Enjoy new PSD plot! You can easily estimate the frequency of the original signal. Again, PSD was created only from the data which were visible on the 'original' plot.

![](docs/img/psd-2.png "marker examples")

* you can draw a 'meta-window' with list of all plots; This is very convenient in case you have 10 - 15 plots or even more

![](docs/img/meta-window.png "meta-window example")

* this library have UDP client&server, so it can display incoming "marker" messages and send out marker positions when using "marker gui"
 * possible to use log axis scale

 * Maps functionality returned. You can draw on maps. Please see example for the details.
 ![](docs/img/map-example.png "marker examples")
 

 * Now its possible to create 3D lines and surfaces (because of MathGL).  There are a few details about how to do this in the example.    https://github.com/ig-or/QWTWPlot.jl/blob/master/src/qwexample.jl
 
 Markers not supported here (yet?).
 ![](docs/img/3d.png "3d examples")

 also,  it's possible to remove or change existing lines on plots (see an example how to do it)(implemented for simple 2D plots).

 #### keyboard shortcuts
 * _M_ switch to "marker mode"
 * _P_ switch to "pan mode"
 * _Z_ switch to "zoom mode"
 * _V_ add/remove "(permanent)vertical marker" to the current marker position
 * _Shift+V_  same as _V_ but for all the existing plots which can support it (simple 2D plots)
 * _A_  add/remove an "(permanent) arrow-like marker" to the current marker position.

 For permanent vertical markers, you can change its label, and for "arrow" marker you can change its label and color.
 How those (permanent) markers looks like:
 ![](docs/img/pm.png "3permanent markers example")

 #### user callbacks

  now you can make your own function to be called, when  you do a mouse click on a plot. `qwexample.jl` supposed to have more examples about it.
 following (exported from a module) struct is a parameter to your callback function:

```
struct QCBInfo
	type::Int32		# callback type ('1' for simple mouse click.. something else in case 'external UDP message info')
	plotID::Int32	# ID of the plot window
	lineID::Int32	# ID of the closest line
	index::Int32	# closest point index
	xx::Int32		# window coord
	yy::Int32		# window coord

	# closest point info
	x::Float64	# X coord
	y::Float64	# Y coord
	z::Float64  # Z coord (probably zero, when 'type' == 1)
	time::Float64 # time info
	label::String # label of the selected line
end
```
 lets create and test a simple callback function:
```
function my_callback(q::QCBInfo)
	@printf "plot %d, line %d (%s);   index = %d; xx = %d; yy = %d \n" q.plotID q.lineID q.label q.index q.xx  q.yy
	@printf "x = %f;  y = %f; z = %f; time = %f\n\n" q.x  q.y q.z q.time
end
```

lets register it:

```

qsetCallback(my_callback)
```

now, you can click on the plots (when "marker mode" enabled! usually this means that 'arrow button' was pressed)
 and see how your callback is working.
 BTW it is called from the different Julia thread, so be careful. But sometimes it's OK to use `qwtw` functions from a callbacks. 
 File `cbtest.jl` has an example how to use qwtw functions from a callback.


#### Settings 
are stored in ~/.qwtw/settings.json file. In rare cases you may want to update this file manually. 
 * `pickerDigitsNumber` is the number of digits (with pointer coordinates) displayed near mouse cursor when you press left mouse button on a plot window (in 'marker' mode).
 * 'udp_server_port' and 'udp_client_port' ports have to be available to UDP protocols. Most functionality is implemented via shared memory, but there is still some parts relying on UDP. 

 I suspect the underlying qwtw library is not thread-safe, so would not recommend to use it from different julia threads simultaneously. But you should be able to call most of the qwtw functions from a 'callback'.
 
