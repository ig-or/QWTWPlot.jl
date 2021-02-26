#
# QWTwPlot module
# qwt - based 2D plotting
#

#__precompile__(true)
module QWTWPlot

using Printf
using Libdl

import Qt_jll
import qwtw_jll
import marble_jll

function __init__()
	# this is not OK  qwtwStart(Int64(0)) # start in normal mode
end

# DLLs and function handles below:
qwtwLibHandle = 0
qwtwFigureH = 0
qwtwRemoveLineH = 0
#qwtwFigure3DH = 0 # not supported because of license restrictions..    maybe later... 
qwtwMapViewH = 0
qwtwsetimpstatusH = 0
qwtwCLearH = 0
qwtwPlotH = 0
qwtwPlot2H = 0
#qwtwPlot3DH = 0 # not supported because of license restrictions..    maybe later... 
qwtwXlabelH = 0
qwtwYlabelH = 0
qwywTitleH = 0
qwtwVersionH = 0
qwtwMWShowH = 0
qwtEnableBroadcastH = 0

qwtMglH = 0
qwtMglLine = 0
qwtMglMesh = 0

qwtStartH = 0
qwtStartDebugH = 0
qwtStopH = 0
started = false

old_path = ""
old_qtPath = ""
oldLdLibPath = ""

"""
function saveEnv()
	saves some of the env vars
"""
function saveEnv()
	global old_path, old_qtPath, oldLdLibPath
	try old_path = ENV["PATH"]; catch end
	try old_qtPath = ENV["QT_PLUGIN_PATH"]; catch end
	try oldLdLibPath = ENV["LD_LIBRARY_PATH"]; catch end
	return
end

"""
function restoreEnv()
	restores env vars back
"""
function restoreEnv()
	global old_path, old_qtPath, oldLdLibPath
	ENV["PATH"] = old_path
	ENV["QT_PLUGIN_PATH"] = old_qtPath 
	ENV["LD_LIBRARY_PATH"] = oldLdLibPath 
	return
end

"""
function printEnv()
	simply print some of the env variables
"""
function printEnv()
	try
		@printf "\n\tPATH = %s \n\n" String(ENV["PATH"])
		@printf "\n\tQT_PLUGIN_PATH = %s \n\n" String(ENV["QT_PLUGIN_PATH"])
		try
			ldp = String(ENV["LD_LIBRARY_PATH"])
			@printf "\n\tLD_LIBRARY_PATH = %s \n\n" ldp
		catch
			@printf "no LD_LIBRARY_PATH\n\n"
		end
	catch
		@printf "printEnv: not everything was printed \n"
	end
end

"""
function addEnvItem(item, var)
	add something to the ENV from the beginning
	item -  what to add
	var - where to add
"""
function addEnvItem(item, var::String; debug = false)
	dv = ":"
	@static if Sys.iswindows()
		dv = ";"
	end
	useDV = true
	try # check: do we have it?
		test = ENV[var]  # yes
	catch ex # no such variable
		useDV = false
	end

	item2Add = "" # what we will actually add
	if typeof(item) == String # simple case
		item2Add = item
		if debug
			@printf "adding [%s] to [%s] \n" item2Add  var
		end
	elseif typeof(item) == Base.RefValue{String} # this can happen also
		item2Add = item[]
		if debug
			@printf "adding [%s] to [%s] \n" item2Add  var
		end
	else  # strange case
		@printf "WARNING: trying to add following item to %s : " var
		print(item)
		try
			item2Add = String(item)
		catch ex
			item2Add = item
		end
	end

	try
		if useDV
			ENV[var] = item2Add * dv * ENV[var]
		else
			ENV[var] = item2Add 
			if debug
				@printf " new ENV %s created \n " var
			end
		end
	catch ex
		@printf "ERROR while adding item to [%s]: " var
		print(ex)
		print(item)
	end
end

"""
	qstart(;debug = false)::Int32
start qwtw "C" library. 

Without it, nothing will work. Call it before any other functions.
if debug, will try to enable debug print out. A lot of info. Just for debugging.
qwtw_test	-> if true, will try to not modify env variables. 
"""
function qstart(;debug = false, qwtw_test = false, libraryName = "libqwtw")::Int32
	qwtw_libName = "nolib"
	if debug
	@printf "startint qwtw; current path: %s\n\n" ENV["PATH"]
	end

	# this could be still useful:
	#if debug qwtw_libName *= "d"; end

	global qwtwLibHandle, qwtwFigureH, qwtwMapViewH,  qwtwsetimpstatusH, qwtwCLearH, qwtwPlotH
	global qwtwPlot2H, qwtwXlabelH, qwtwYlabelH, qwywTitleH, qwtwVersionH, qwtwMWShowH, qwtwRemoveLineH
	global qwtEnableBroadcastH, qwtDisableBroadcastH
	#global qwtwPlot3DH, qwtwFigure3DH
	global qwtStartH, qwtStopH, started
	global old_path, old_qtPath, oldLdLibPath
	global qwtMglH, qwtMglLine, qwtMglMesh

	if started
		@printf "qwtw already started\n"
		return 0
	end

	@static if Sys.iswindows() #  this part will handle OS differences
		qwtw_libName = libraryName * ".dll"
	else # hopefully this may be Linux
		if debug
			@printf "\t non-Windows detected\n"
		end
		qwtw_libName = libraryName * ".so"
	end
	
	saveEnv()

	marbleDataPath = joinpath(marble_jll.artifact_dir, "data")
	marblePluginPath = joinpath(marble_jll.artifact_dir, "plugins")

	if qwtw_test
		@printf "qwtw debug; loading %s .. \n" qwtw_libName
		@printf "\nPATH = %s\n\n" ENV["PATH"]
	else
		@static if Sys.iswindows() 
			ENV["QT_PLUGIN_PATH"]=Qt_jll.artifact_dir * "\\plugins"	
			addEnvItem(qwtw_jll.PATH, "PATH", debug = debug)
			addEnvItem(qwtw_jll.LIBPATH, "PATH", debug = debug)
			
			#ENV["PATH"]= boost_jll.artifact_dir * "\\bin;" *  ENV["PATH"] 
			#ENV["PATH"]= qwt_jll.artifact_dir * "\\bin;" *  ENV["PATH"] 
			#ENV["PATH"]= Qt_jll.artifact_dir * "\\bin;" *  ENV["PATH"] 

			#ENV["PATH"]= CompilerSupportLibraries_jll.artifact_dir * "\\bin;" *  ENV["PATH"] 
			#new_env["PATH"]= FreeType2_jll.artifact_dir * "\\bin;" *  ENV["PATH"] 
		else
			ENV["QT_PLUGIN_PATH"]=string(Qt_jll.artifact_dir) * "/plugins"	
			addEnvItem(qwtw_jll.PATH, "PATH", debug = debug)	
			addEnvItem(qwtw_jll.LIBPATH, "LD_LIBRARY_PATH", debug = debug)	

			#ENV["PATH"]= boost_jll.artifact_dir * "/bin;" *  ENV["PATH"] 
			
			#ENV["LD_LIBRARY_PATH"] = string(Qt_jll.LIBPATH) * ":" * ENV["LD_LIBRARY_PATH"] # do not sure why this is not already there
			#ENV["LD_LIBRARY_PATH"] = string(CompilerSupportLibraries_jll.LIBPATH) * ":" * ENV["LD_LIBRARY_PATH"] # do not sure why this is not already there
			#ENV["LD_LIBRARY_PATH"] = string(FreeType2_jll.LIBPATH) * ":" * ENV["LD_LIBRARY_PATH"] # do not sure why this is not already there
		end
	end

	if debug
		@printf "\nloading %s \n" qwtw_libName 
		@printf "corrected ENV:\n"
		@static if Sys.iswindows() 

		else
			@printf "LD_LIBRARY_PATH: %s \n\n" String(ENV["LD_LIBRARY_PATH"])
		end
		@printf "PATH: %s \n\n" String(ENV["PATH"])
		@printf "\n"
	end	

	try 
		qwtwLibHandle = Libdl.dlopen(qwtw_libName)
	catch ex
		if debug
			printEnv();
		end
		restoreEnv()
		@printf "Sorry, dlopen for %s failed; something is wrong\n" qwtw_libName
		throw(ex)
	end

	if debug 
		@printf "\nlibrary %s opened from %s \n" qwtw_libName  Libdl.dlpath(qwtwLibHandle)
	end
	qwtwFigureH = Libdl.dlsym(qwtwLibHandle, "qwtfigure")
	#qwtwFigure3DH = Libdl.dlsym(qwtwLibHandle, "qwtfigure3d")

	try
		qwtwMapViewH = Libdl.dlsym(qwtwLibHandle, "qwtmap")
	catch
		qwtwMapViewH = 0
		@printf "WARNING: topview functions disabled (looks like no [marble] support)\n"
	end

	qwtwsetimpstatusH = Libdl.dlsym(qwtwLibHandle, "qwtsetimpstatus")
	qwtwCLearH = Libdl.dlsym(qwtwLibHandle, "qwtclear")
	qwtwPlotH = Libdl.dlsym(qwtwLibHandle, "qwtplot")
	#qwtwPlot3DH = Libdl.dlsym(qwtwLibHandle, "qwtplot3d")
	qwtwPlot2H = Libdl.dlsym(qwtwLibHandle, "qwtplot2")
	qwtwXlabelH = Libdl.dlsym(qwtwLibHandle, "qwtxlabel")
	qwtwYlabelH = Libdl.dlsym(qwtwLibHandle, "qwtylabel")
	qwywTitleH = Libdl.dlsym(qwtwLibHandle, "qwttitle")
	qwtwVersionH = Libdl.dlsym(qwtwLibHandle, "qwtversion")
	qwtwMWShowH = Libdl.dlsym(qwtwLibHandle, "qwtshowmw")
	qwtStartH = Libdl.dlsym(qwtwLibHandle, "qtstart")
	qwtStartDebugH = Libdl.dlsym(qwtwLibHandle, "qtstart_debug")
	qwtStopH = Libdl.dlsym(qwtwLibHandle, "qwtclose")
	qwtwRemoveLineH = Libdl.dlsym(qwtwLibHandle, "qwtremove")

	try
		qwtEnableBroadcastH = Libdl.dlsym(qwtwLibHandle, "qwtEnableCoordBroadcast")
		qwtDisableBroadcastH = Libdl.dlsym(qwtwLibHandle, "qwtDisableCoordBroadcast")
	catch
		@printf "WARNING: UDP broacast disabled \n"
	end

	try 
		qwtMglH = Libdl.dlsym(qwtwLibHandle, "qwtmgl")
		qwtMglLine = Libdl.dlsym(qwtwLibHandle, "qwtmgl_line")
		qwtMglMesh = Libdl.dlsym(qwtwLibHandle, "qwtmgl_mesh")
	catch
		@printf "WARNING: 3D features disabled \n"
	end

	# hangs tight!!!!
	if debug
		@printf "starting qstart in debug mode \n"
		@printf "\tmarbleDataPath %s \n" marbleDataPath
		@printf "\tmarblePluginPath %s \n" marblePluginPath
	end
	test = 1
	try
		if debug
			test = ccall(qwtStartDebugH, Int32, (Ptr{UInt8}, Ptr{UInt8}, Int32), 
				marbleDataPath, marblePluginPath, 10); 
		else
			test = ccall(qwtStartH, Int32, (Ptr{UInt8}, Ptr{UInt8}), 
				marbleDataPath, marblePluginPath); # very important to call this in the very beginning
		end
	catch ex
		if debug
			printEnv();
		end
		restoreEnv()
		@printf "Sorry, cannot start qwtw. Something is wrong\n" 
		throw(ex)
	end
	#end
	#@printf "qtstart = %d \n" test	

	#version = qversion();
	#println(version);
	if test == 0
		started = true
		if debug
			version = qversion();
			println(version);
		end
	else
		@printf "\nERROR: library was not started (return code %d) \n" test
		if debug
			printEnv();
		end
	end

	restoreEnv()

	return test
end

"""
	qstop()
close everything and detach from qwtw library.

It maybe useful for debugging. What it does actually, it sends a command to the QT process to exit.
Have to call `qstart()` before, though.
"""
function qstop()
	global qwtwLibHandle, qwtStopH
	global started
	
	if qwtwLibHandle != 0
		if (qwtStopH != 0) 
			ccall(qwtStopH,  Cvoid, ())
			#@printf "qwtw stopped\n"
		else
			@printf "error: was not started correctly\n"
		end
		Libdl.dlclose(qwtwLibHandle)
	else
		@printf "not started (was qstart() called?)\n"
		return
	end
	qwtwLibHandle = 0
	started = false
	return
end

"""
	qversion() :: String

useful for debugging.
return version info (as string); 
"""
function qversion() :: String
	global qwtwVersionH, qwtwLibHandle
	if qwtwLibHandle == 0
		return "not started yet"
	end
	v = zeros(UInt8, 2048)
	#@printf "qwtwc version: "
	bs = ccall(qwtwVersionH, Int32, (Ptr{UInt8}, Int32), v, 2040);
	#return bytestring(pointer(v))
	cmd = unsafe_string(pointer(v), bs);
	#@printf " bs = %d .... " bs
	return cmd
end

# looks like not used anymore
function traceit( msg )
     # global g_bTraceOn
      if ( true )
         bt = backtrace() ;
         s = sprint(io->Base.show_backtrace(io, bt))
         println( "debug: $s: $msg" )
      end
end

"""
	qfigure(n)
create a new plot window, OR make plot (with this ID `n`) 'active'.

looks like `n` have to be an integer number (this plot ID, or zero if you do not care).
after this function, this plot is the "active plot". 
If `n == 0` then another new plot will be created.
"""
function qfigure(n)
	global qwtwFigureH, started
	if !started
		@printf "not started (was qstart() called?)\n"
		return
	end
	ccall(qwtwFigureH, Cvoid, (Int32,), n);
	return
end;

function qfigure()
	qfigure(0);
end;

function qremove(id::Int32)
	global qwtwRemoveLineH, started
	if !started
		@printf "not started (was qstart() called?)\n"
		return
	end
	ccall(qwtwRemoveLineH, Cvoid, (Int32,), id);
	return
end
export qremove

"""
	qfmap(n)
create a new  plot window to draw on a map (with specific window ID)
'n' is Int32
"""
function qfmap(n)
	global qwtwMapViewH, qwtwLibHandle, started
	if (qwtwLibHandle == 0) || (!started)
		@printf "not started (was qstart() called?)\n"
		return
	end
	if qwtwMapViewH == 0
		@printf "map vew not supported, sorry\n"
		return
	end

	ccall(qwtwMapViewH, Cvoid, (Int32,), n);
end;

"""
function qfmap()
create a new  plot window to draw on a map
"""
function qfmap()
	qfmap(0)
end;

"""
qmgl(n = 0)
create a new  plot window to draw 3D lines / surfaces
currently works only for Linux
"""
function qmgl(n = 0)
	global qwtMglH, qwtwLibHandle, started
	if (qwtwLibHandle == 0) || (!started)
		@printf "not started (was qstart() called?)\n"
		return
	end
	if qwtMglH == 0
		@printf "3D not supported, sorry\n"
		return
	end

	ccall(qwtMglH, Cvoid, (Int32,), n);
	return
end;

export qmgl

"""
qmgline(x::Vector{Float64}, y::Vector{Float64}, z::Vector{Float64}, style::String = "-sb"; name = "")
draw a 3D line. 
x, y, and z are the vectors with point coordinates.
style - how to draw a line. Explanation is here: http://mathgl.sourceforge.net/doc_en/Line-styles.html
name - a legend for this line
"""
function qmgline(x::Vector{Float64}, y::Vector{Float64}, z::Vector{Float64}, style::String = "-sb"; name = "")
	global qwtMglLine, qwtwLibHandle, started
	if (qwtwLibHandle == 0) || (!started)
		@printf "not started (was qstart() called?)\n"
		return
	end
	if qwtMglLine == 0
		@printf "3D not supported, sorry\n"
		return
	end
	if length(x) < 1
		@printf "QWTWPlot::qmgline empty X value\n"
		return
	end
	n = length(x)
	@assert length(x) == length(y)
	@assert length(z) == length(x)
	
	try
	ccall(qwtMglLine, Cvoid, (Int32, Ptr{Float64}, Ptr{Float64}, Ptr{Float64}, Ptr{UInt8}, Ptr{UInt8}), 
		n, x, y, z, name, style);

		sleep(0.025)
	catch
		@printf "ERROR in QWTWPlot::qmgline\n"
	end
	return
end
export qmgline

"""
qmglmesh(data::Array{Float64, 2}, xMin = -10.0, xMax = 10.0, yMin = -10.0, yMax = 10.0,  style::String = ""; name = "", type = 0)
	draw a 3D mesh/surface.   Currently works only for Linux. 
data - vertical (z) coordinates of the surface. should be Array{Float64, 2}
xMin, xMax, yMin, yMax is the definition of the range where to draw a surface. All the 
coordinates from 'data' are evenly distributed inside this range.
style how to draw the surface. Some hints could be taken from here: http://mathgl.sourceforge.net/doc_en/Color-scheme.html
type  -   0 or 1;  mesh/grid  or surface
name - not used yet (maybe will add later)
"""
function qmglmesh(data::Array{Float64, 2}, xMin = -10.0, xMax = 10.0, yMin = -10.0, yMax = 10.0,  style::String = ""; name = "", type = 0)
	global qwtMglMesh, qwtwLibHandle, started
	if (qwtwLibHandle == 0) || (!started)
		@printf "not started (was qstart() called?)\n"
		return
	end
	if qwtMglMesh == 0
		@printf "3D not supported, sorry\n"
		return
	end
	if length(data) < 1
		@printf "QWTWPlot::qmgline empty X value\n"
		return
	end
	d = size(data)
	if (d[1] < 1) || (d[2] < 1) 
		@printf "QWTWPlot::qmglmesh empty data\n"
		return
	end
	xSize = d[1]
	ySize = d[2]
	
	try
	ccall(qwtMglMesh, Cvoid, (Int32, Int32, 
		Float64, Float64, Float64, Float64, 
		Ptr{Float64},
		Ptr{UInt8}, Ptr{UInt8}, Int32),
		xSize, ySize, 
		xMin, xMax, yMin, yMax, data,  name, style, type);

		sleep(0.025)
	catch
		@printf "ERROR in QWTWPlot::qwtMglMesh\n"
	end
	return
end

export qmglmesh


# create a new  window to draw a 3D points (QT engine)
#function qf3d(n)
#	global qwtwFigure3DH
#	ccall(qwtwFigure3DH, Cvoid, (Int32,), n);
#end;

"""
	qimportant(i)
set up an importance status for next lines. 
	
looks like `0` means 'not important', `1` means "important.
'not important' will not participate in 'clipping':
	'not important' lines may be not completely inside the window.
"""
function qimportant(i)
	global qwtwsetimpstatusH, qwtwLibHandle, started
	if (qwtwLibHandle == 0) || (!started)
		@printf "not started (was qstart() called?)\n"
		return
	end

	ccall(qwtwsetimpstatusH, Cvoid, (Int32,), i);
	return
end

"""
	qclear()
close all the plots
"""
function qclear()
	global qwtwCLearH, qwtwLibHandle, started
	if (qwtwLibHandle == 0) || (!started)
		@printf "not started (was qstart() called?)\n"
		return
	end
	
	ccall(qwtwCLearH, Cvoid, ());
	return
end

"""
	qsmw()
open/show "main control window".
"""
function qsmw()
	global qwtwMWShowH, qwtwLibHandle, started
	if (qwtwLibHandle == 0) || (!started)
		@printf "not started (was qstart() called?)\n"
		return
	end

	ccall(qwtwMWShowH, Cvoid, ());
	return
end

"""
qplot(x::Vector{Float64}, y::Vector{Float64}, name::String, style::String, lineWidth, symSize):: Int32

plot normal lines.

#Parameters:

x and y:   the points.

name:      	name for this line.

style: 	 	how to draw a line.

lineWidth:	is a line width.

symSize:	size of the symbols, if they are used in 'style' spec.

what does 'style' parameter means? It's a string which has 1 or 2 or 3 symbols. 

Look at two places for the detail explanation:
* example code  https://github.com/ig-or/QWTWPlot.jl/blob/master/src/qwexample.jl   
* https://github.com/ig-or/QWTWPlot.jl/blob/master/docs/line-styles.md

this function returns ID of the line created. hopefully you can use it in some other functions
ID supposed to be >=0 is all is OK, or <0 in case of error
"""
function qplot(x::Vector{Float64}, y::Vector{Float64}, name::String, style::String="-b", lineWidth=1, symSize=1) :: Int32
	global qwtwPlotH, qwtwLibHandle, started
	if (qwtwLibHandle == 0) || (!started)
		@printf "not started (was qstart() called?)\n"
		return -88
	end

	if length(x) != length(y)
		@printf "qplot: x[%d], y[%d]\n" length(x) length(y)
		traceit("error")
		return -89
	end
	@assert (length(x) == length(y))

	n = length(x)
	ww::Int32 = lineWidth;
	s::Int32 = symSize
	test::Int32 = -50
	try
		test = ccall(qwtwPlotH, Int32, (Ptr{Float64}, Ptr{Float64}, Int32, Ptr{UInt8}, Ptr{UInt8}, Int32, Int32),
			x, y, n, name, style, ww, s);
		sleep(0.025)
	catch
		@printf "qplot: error #2  n = %d;  name = %s style = %s\n" n name style
		traceit("error #2")
		return -42
	end
	return test
end	

"""
qplot1(x::Vector{Float64}, y::Vector{Float64}, name::String, style::String, symSize):: Int32

plot lines with line width == 1.

x and y:   the points   
name:      	name for this line   
style: 	 	how to draw a line   
symSize:	size of the symbols  

what does 'style' parameter means? It's a string which has 1 or 2 or 3 symbols. 
Look at two places for the detail explanation:

* example code  https://github.com/ig-or/QWTWPlot.jl/blob/master/src/qwexample.jl
* https://github.com/ig-or/QWTWPlot.jl/blob/master/docs/line-styles.md


this function returns ID of the line created. hopefully you can use it in some other functions
	ID supposed to be >=0 is all is OK, or <0 in case of error
	
"""
function qplot1(x::Vector{Float64}, y::Vector{Float64}, name::String, style::String, symSize) :: Int32
	global qwtwPlotH, qwtwLibHandle, started
	if (qwtwLibHandle == 0) || (!started)
		@printf "not started (was qstart() called?)\n"
		return -88
	end

	n = length(x)
	n1 = length(y)
	@assert n > 0
	@assert n1 > 0
	@assert (n == n1)
	if (n == 0) || (n1 ==0) || (n != n1)
		error("qplot1: wrong array length")
		return -89
	end
	ww::Int32 = symSize;
	test::Int32 = -50
	try
		test = ccall(qwtwPlotH, Int32, (Ptr{Float64}, Ptr{Float64}, Int32, Ptr{UInt8}, Ptr{UInt8}, Int32, Int32),
			x, y, n, name, style, 1, ww);
	catch ex
		@printf "qplot1 ERROR\n"
		throw(ex)
		return -42
	end
	sleep(0.025)
	return test
end;

# draw symbols in 3D space
# currently style and 'w' are not used
#function qplot3d(x::Vector{Float64}, y::Vector{Float64}, z::Vector{Float64},
#	 		name::String, style::String, w, time::Vector{Float64})
#	global qwtwPlotH
#	@assert (length(x) == length(y))
#	n = length(x)
#	ww::Int32 = w;
#	ccall(qwtwPlot3DH, Cvoid, (Ptr{Float64}, Ptr{Float64}, Ptr{Float64},
#			Int32, Ptr{UInt8}, Ptr{UInt8}, Int32, Int32,  Ptr{Float64}),
#		x, y, z, n, name, style, 1, ww, time);
#	sleep(0.025)
#
#end;
#


""" 
	qEnableCoordBroadcast(x::Vector{Float64}, y::Vector{Float64}, z::Vector{Float64}, time::Vector{Float64})
Enable UDP client.

In case you'd like to connect to some external software from this library,
it has UDP client and server inside. If/when you will move a marker, it will 
broadcast 'marker information' via UDP. 
Other way should also work: if some other application will broadcast UDP with marker info,
all the markers in this library supposed to be updated.

parameters: x, y,  and z are the vectors describing the line in 3D space;
and 'time' is an additional time information, for every point of the line.

It will send out marker info to UDP port 49561.
Incoming (to this library) UDP  port number is 49562, and IP address is "127.0.0.1".

Incoming message format:  'CRDS"<x><y><z>"FFFF', where
<x>, <y>, and <z> are  Float64 point coordinates, 8 bytes each
so this message contains 4 + 3*8 + 4 bytes
outgoing message format is approximately the same: "EEEE"<x><y><z>"FFFF"

If UDP client is enabled, server will also start. For all this to work, some firewall rules have to be added probably, 
line 'allow 49561 and 49562 ports for the local host'.
"""
function qEnableCoordBroadcast(x::Vector{Float64}, y::Vector{Float64}, z::Vector{Float64},
	 		time::Vector{Float64})
	global qwtEnableBroadcastH, qwtwLibHandle, started
	if (qwtwLibHandle == 0) || (!started)
		@printf "not started (was qstart() called?)\n"
		return
	end

	@assert (length(x) == length(y))
	@assert (length(x) == length(z))
	@assert (length(x) == length(time))

	n = length(time)

	ccall(qwtEnableBroadcastH, Cvoid, (Ptr{Float64}, Ptr{Float64}, Ptr{Float64},
			 Ptr{Float64}, Int32),
		x, y, z , time, n);
	sleep(0.025)
	return
end;

"""
	qDisableCoordBroadcast()
disable all this UDP -related stuff.

This function will stop UDP server and client.
"""
function qDisableCoordBroadcast()
	global qwtDisableBroadcastH, qwtwLibHandle, started
	if (qwtwLibHandle == 0) || (!started)
		@printf "not started (was qstart() called?)\n"
		return
	end


	ccall(qwtDisableBroadcastH, Cvoid, ());
	sleep(0.025);
	return
end;


"""
qplot2(x::Array{Float64}, y::Array{Float64}, time::Array{Float64}, name::String, style::String, lineWidth=1, symSize=1):: Int32

plot with additional parameter (time?) info.

## Parameters:
```
'x', 'y': the line
'name' name of this line
'style'  the line style
'lineWidth' line width
'symSize' symbol size; 
'time' time info, for every point
```

## Example
```julia-repl
julia> time=collect(0.0:0.01:10.0)
x = sin.(time)
y = cos.(time)
qfigure()
qplot(time, x + y, "function 1", "-b", 3)
qfigure()
qplot2(x, y, time, "function 2", "-m", 3)
```
Now use marker on both plots and see that it moves on both plots.


this function returns ID of the line created. hopefully you can use it in some other functions
	ID supposed to be >=0 is all is OK, or <0 in case of error

"""
function qplot2(x::Array{Float64}, y::Array{Float64}, time::Array{Float64}, name::String, style::String, lineWidth=1, symSize=1):: Int32
	global qwtwPlot2H, qwtwLibHandle, started
	if (qwtwLibHandle == 0) || (!started)
		@printf "not started (was qstart() called?)\n"
		return -88
	end

	@assert (length(x) == length(y))
	n = length(x)
	ww::Int32 = lineWidth;
	s::Int32 = symSize;
	test::Int32 = -50
	try 
		test = ccall(qwtwPlot2H, Int32, (Ptr{Float64}, Ptr{Float64}, Int32, Ptr{UInt8}, Ptr{UInt8}, Int32, Int32, Ptr{Float64}),
			x, y, n, name, style, ww, s, time);
	catch ex
		@printf "qplot1 ERROR\n"
		throw(ex)
		return -42
	end

	sleep(0.025)
	return test
end

"""
	qxlabel(s::String)
put a label on the horizontal axis.
"""
function qxlabel(s::String)
	global qwtwXlabelH, qwtwLibHandle, started
	if (qwtwLibHandle == 0) || (!started)
		@printf "not started (was qstart() called?)\n"
		return
	end

	ccall(qwtwXlabelH, Cvoid, (Ptr{UInt8},), s);
	return
end;

"""
	qylabel(s::String)
put a label on the left vertical axis
"""
function qylabel(s::String)
	global qwtwYlabelH, qwtwLibHandle, started
	if (qwtwLibHandle == 0) || (!started)
		@printf "not started (was qstart() called?)\n"
		return
	end

	ccall(qwtwYlabelH, Cvoid, (Ptr{UInt8},), s);
	return
end;

"""
	qtitle(s::String)
put a title on current plot.
"""
function qtitle(s::String)
	global qwywTitleH, qwtwLibHandle, started
	if (qwtwLibHandle == 0) || (!started)
		@printf "not started (was qstart() called?)\n"
		return
	end

	ccall(qwywTitleH, Cvoid, (Ptr{UInt8},), s);
	return
end

"""
	qStarted()
does it started or not yet.
"""
function qStarted()
	global started
	return started
end

export qfigure, qfmap, qplot, qplot1, qplot2, qxlabel,  qylabel, qtitle
export qimportant, qclear, qstart, qstop, qversion, qsmw
export traceit
export  qEnableCoordBroadcast, qDisableCoordBroadcast
export qStarted
#export qplot3d, qf3d,

end # module
