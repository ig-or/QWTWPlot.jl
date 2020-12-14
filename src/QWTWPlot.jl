#
# QWTwPlot module
# qwt - based 2D plotting
#

#__precompile__(true)
module QWTWPlot

using Printf
using Libdl

#import Qt_jll
import qwtw_jll
#import CompilerSupportLibraries_jll
#import FreeType2_jll
#import boost_jll
#import qwt_jll

function __init__()
	# this is not OK  qwtwStart(Int64(0)) # start in normal mode
end

# DLLs and function handles below:
qwtwLibHandle = 0
qwtwFigureH = 0
#qwtwFigure3DH = 0 # not supported because of license restrictions..    maybe later... 
qwtwTopviewH = 0
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
qwtStartH = 0
qwtStartDebugH = 0
qwtStopH = 0
started = false

old_path = ""
old_qtPath = ""
oldLdLibPath = ""

function saveEnv()
	global old_path, old_qtPath, oldLdLibPath
	try old_path = ENV["PATH"]; catch end
	try old_qtPath = ENV["QT_PLUGIN_PATH"]; catch end
	try oldLdLibPath = ENV["LD_LIBRARY_PATH"]; catch end
	return
end

function restoreEnv()
	global old_path, old_qtPath, oldLdLibPath
	ENV["PATH"] = old_path
	ENV["QT_PLUGIN_PATH"] = old_qtPath 
	ENV["LD_LIBRARY_PATH"] = oldLdLibPath 
	return
end

# start qwtw "C" library and attach handlers to it
# if debug, will try enable debug print out
function qstart(;debug = false)::Int32
	qwtw_libName = "nolib"
	if debug
	@printf "startint qwtw; current path: %s\n\n" ENV["PATH"]
	end

	# this could be still useful:
	#if debug qwtw_libName *= "d"; end

	global qwtwLibHandle, qwtwFigureH, qwtwTopviewH,  qwtwsetimpstatusH, qwtwCLearH, qwtwPlotH
	global qwtwPlot2H, qwtwXlabelH, qwtwYlabelH, qwywTitleH, qwtwVersionH, qwtwMWShowH
	global qwtwPlot3DH, qwtwFigure3DH, qwtEnableBroadcastH, qwtDisableBroadcastH
	global qwtStartH, qwtStopH, started
	global old_path, old_qtPath, oldLdLibPath

	#if qwtwLibHandle != 0 # looks like we already started
	if started
		@printf "qwtw already started\n"
		return 0
	end

	#  this part will handle OS differences
	@static if Sys.iswindows() 
		qwtw_libName = "libqwtw.dll"
	else # hopefully this may be Linux
		#@printf "\t non-Windows detected\n"
		qwtw_libName = "libqwtw.so"
	end

	#old_env = Dict()
	#try
	#	old_env = deepcopy(Base.ENV)
	#catch
	#	@printf "no ENV\n"
	#end
	#new_env = deepcopy(old_env)

	saveEnv()
		
	@static if Sys.iswindows() 
		#ENV["QT_PLUGIN_PATH"]=Qt_jll.artifact_dir * "\\plugins"	
		ENV["PATH"]= string(qwtw_jll.PATH[]) * ";" *  string(ENV["PATH"])
		ENV["PATH"]= string(qwtw_jll.LIBPATH[]) * ";" *  string(ENV["PATH"])
		
		#ENV["PATH"]= boost_jll.artifact_dir * "\\bin;" *  ENV["PATH"] 
		#ENV["PATH"]= qwt_jll.artifact_dir * "\\bin;" *  ENV["PATH"] 
		#ENV["PATH"]= Qt_jll.artifact_dir * "\\bin;" *  ENV["PATH"] 

		#ENV["PATH"]= CompilerSupportLibraries_jll.artifact_dir * "\\bin;" *  ENV["PATH"] 
		#new_env["PATH"]= FreeType2_jll.artifact_dir * "\\bin;" *  ENV["PATH"] 
				
	else
		#ENV["QT_PLUGIN_PATH"]=string(Qt_jll.artifact_dir) * "/plugins"			
		ENV["PATH"]=   string(qwtw_jll.PATH[]) * ":" *  string(Base.ENV["PATH"])
		ENV["LD_LIBRARY_PATH"] = string(qwtw_jll.LIBPATH[]) * ":" * string(Base.ENV["LD_LIBRARY_PATH"]) # not sure if this is needed
		#ENV["PATH"]= boost_jll.artifact_dir * "/bin;" *  ENV["PATH"] 
		
		#ENV["LD_LIBRARY_PATH"] = string(Qt_jll.LIBPATH) * ":" * ENV["LD_LIBRARY_PATH"] # do not sure why this is not already there
		#ENV["LD_LIBRARY_PATH"] = string(CompilerSupportLibraries_jll.LIBPATH) * ":" * ENV["LD_LIBRARY_PATH"] # do not sure why this is not already there
		#ENV["LD_LIBRARY_PATH"] = string(FreeType2_jll.LIBPATH) * ":" * ENV["LD_LIBRARY_PATH"] # do not sure why this is not already there
	end

	#@printf "new_env: %s  \n" typeof(new_env)
	#print(new_env)

	#withenv("QT_PLUGIN_PATH"=>new_env["QT_PLUGIN_PATH"],
	#"PATH"=>new_env["PATH"],
	#"LD_LIBRARY_PATH"=>new_env["LD_LIBRARY_PATH"]) do

	#Base.ENV = new_env

		#@printf "loading %s \n" qwtw_libName 
		try 
			qwtwLibHandle = Libdl.dlopen(qwtw_libName)
		catch ex
			restoreEnv()
			@printf "Sorry, dlopen for %s failed; something is wrong\n" qwtw_libName
			throw(ex)
		end
		qwtwFigureH = Libdl.dlsym(qwtwLibHandle, "qwtfigure")
		#qwtwFigure3DH = Libdl.dlsym(qwtwLibHandle, "qwtfigure3d")

		try
			qwtwTopviewH = Libdl.dlsym(qwtwLibHandle, "topview")
		catch
			#@printf "WARNING: topview functions disabled (looks like no [marble] support)\n"
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

		try
			qwtEnableBroadcastH = Libdl.dlsym(qwtwLibHandle, "qwtEnableCoordBroadcast")
			qwtDisableBroadcastH = Libdl.dlsym(qwtwLibHandle, "qwtDisableCoordBroadcast")
		catch
			@printf "WARNING: UDP broacast disabled \n"
		end

		# hangs tight!!!!
		#@printf "starting qstart \n"
		test = 1
		try
			if debug
				test = ccall(qwtStartDebugH, Int32, (Int32,), 10); 
			else
				test = ccall(qwtStartH, Int32, ()); # very important to call this in the very beginning
			end
		catch ex
			restoreEnv()
			@printf "Sorry, cannot start qwtw. Something is wrong\n" 
			throw(ex)
		end
	#end
	#@printf "qtstart = %d \n" test

	#Base.ENV = old_env
	restoreEnv()

	#version = qversion();
	#println(version);
	if test == 0
		started = true
	end

	return test
end

# close everything and detach from qwtw library  (maybe useful for debugging)
function qstop()
	global qwtwLibHandle, qwtStopH
	
	if qwtwLibHandle != 0
		if (qwtStopH != 0) 
			started = false
			ccall(qwtStopH,  Cvoid, ())
			@printf "qwtw stopped\n"
		end
		Libdl.dlclose(qwtwLibHandle)
	else
		@printf "not started (was qstart() called?)\n"
		return
	end
	qwtwLibHandle = 0
end

# return version info (as string); 
function qversion() :: String
	global qwtwVersionH, qwtwLibHandle
	if qwtwLibHandle == 0
		return "not started yet"
	end
	v = zeros(UInt8, 2048)
	@printf "qwtwc version: "
	bs = ccall(qwtwVersionH, Int32, (Ptr{UInt8}, Int32), v, 2040);
	#return bytestring(pointer(v))
	cmd = unsafe_string(pointer(v), bs);
	#@printf " bs = %d .... " bs
	return cmd
end

# looks like not used anymore
function traceit( msg )
      global g_bTraceOn
      if ( true )
         bt = backtrace() ;
         s = sprint(io->Base.show_backtrace(io, bt))
         println( "debug: $s: $msg" )
      end
end

# create a new plot window, OR make plot (with this ID) 'active'
# looks like "n" have to be an integer number (this plot ID)
# now this plot is the "active plot"
function qfigure(n)
	global qwtwFigureH
	ccall(qwtwFigureH, Cvoid, (Int32,), n);
end;

function qfigure()
	qfigure(0);
end;

# create a new  plot window to draw on a map (with specific window ID)
# 'n' is Int32
function qfmap(n)
	global qwtwTopviewH, qwtwLibHandle
	if qwtwLibHandle == 0
		@printf "not started (was qstart() called?)\n"
		return
	end

	ccall(qwtwTopviewH, Cvoid, (Int32,), n);
end;

# create a new  window to draw a 3D points (QT engine)
#function qf3d(n)
#	global qwtwFigure3DH
#	ccall(qwtwFigure3DH, Cvoid, (Int32,), n);
#end;

#=  set up an importance status for next lines. looks like '0' means 'not important'
'not important' will not participate in 'clipping'
=#
function qimportant(i)
	global qwtwsetimpstatusH, qwtwLibHandle
	if qwtwLibHandle == 0
		@printf "not started (was qstart() called?)\n"
		return
	end

	ccall(qwtwsetimpstatusH, Cvoid, (Int32,), i);
end

#= close all the plots
=#
function qclear()
	global qwtwCLearH, qwtwLibHandle
	if qwtwLibHandle == 0
		@printf "not started (was qstart() called?)\n"
		return
	end

	
	ccall(qwtwCLearH, Cvoid, ());
end

# open/show "main control window"
function qsmw()
	global qwtwMWShowH, qwtwLibHandle
	if qwtwLibHandle == 0
		@printf "not started (was qstart() called?)\n"
		return
	end

	ccall(qwtwMWShowH, Cvoid, ());
end

# plot normal lines
#
# x and y:   the points
# name:      name for this line
# style: 	 how to draw a line
# lineWidth is a line width
# symSize:	 size of the symbols, if they are used in 'style' spec
#
# what does 'style' parameter means? It's a string which has 1 or 2 or 3 symbols. 
# Look at two places for the explanation:
# 	 (1) example code (  https://github.com/ig-or/QWTwPlot.jl/blob/master/src/qwexample.jl  )
#	 (2) C spec:   https://github.com/ig-or/qwtw/wiki/line-styles

function qplot(x::Vector{Float64}, y::Vector{Float64}, name::String, style::String,
		lineWidth, symSize)
	global qwtwPlotH, qwtwLibHandle
	if qwtwLibHandle == 0
		@printf "not started (was qstart() called?)\n"
		return
	end

	if length(x) != length(y)
		@printf "qplot: x[%d], y[%d]\n" length(x) length(y)
		traceit("error")
	end
	@assert (length(x) == length(y))

	n = length(x)
	ww::Int32 = lineWidth;
	s::Int32 = symSize
	try
		ccall(qwtwPlotH, Cvoid, (Ptr{Float64}, Ptr{Float64}, Int32, Ptr{UInt8}, Ptr{UInt8}, Int32, Int32),
			x, y, n, name, style, ww, s);
		sleep(0.025)
	catch
		@printf "qplot: error #2\n"
		traceit("error #2")
	end
end;

# plot lines without symbols (simplyfied version of the previous function)
function qplot(x::Vector{Float64}, y::Vector{Float64}, name::String, style::String, lineWidth)
	qplot(x, y, name, style, lineWidth, 1)
end;

# draw symbols with optional line width = 1
#
#
# 'w' is a symbol size
function qplot1(x::Vector{Float64}, y::Vector{Float64}, name::String, style::String, w)
	global qwtwPlotH, qwtwLibHandle
	if qwtwLibHandle == 0
		@printf "not started (was qstart() called?)\n"
		return
	end

	n = length(x)
	n1 = length(y)
	@assert n > 0
	@assert n1 > 0
	@assert (n == n1)
	if (n == 0) || (n1 ==0) || (n != n1)
		error("qplot1: wrong array length")
	end
	ww::Int32 = w;
	ccall(qwtwPlotH, Cvoid, (Ptr{Float64}, Ptr{Float64}, Int32, Ptr{UInt8}, Ptr{UInt8}, Int32, Int32),
		x, y, n, name, style, 1, ww);
	sleep(0.025)

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



#  In case you'd like to connect some external software to this library,
# it has UDP client and server inside. If/when you will move a marker, it will 
# broadcast 'marker information' via UDP. Other way should also work: if some other application will broadcast UDP with marker info,
# all the markers in this library supposed to be updated
#
# parameters: x, y,  and z are the vectors describing the line in 3D space, 
# and 'time' is an additional time information, for every point of the line
# 
# it will send marker info to UDP port 49561
# incoming (to this library) UDP  port number: 49562, and IP address is "127.0.0.1"
# 
# incoming message format:  "CRDS"<x><y><z>"FFFF"
# <x>, <y>, and <z> are  Float64 point coordinates, 8 bytes each
# so this message contains 4 + 3*8 + 4 bytes
#
# outgoing message format is approximately the same: "EEEE"<x><y><z>"FFFF"
# 
#
function qEnableCoordBroadcast(x::Vector{Float64}, y::Vector{Float64}, z::Vector{Float64},
	 		time::Vector{Float64})
	global qwtEnableBroadcastH, qwtwLibHandle
	if qwtwLibHandle == 0
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

end;

#
# disable all this UDP -related stuff
#
function qDisableCoordBroadcast()
	global qwtDisableBroadcastH, qwtwLibHandle
	if qwtwLibHandle == 0
		@printf "not started (was qstart() called?)\n"
		return
	end


	ccall(qwtDisableBroadcastH, Cvoid, ());
	sleep(0.025);

end;



# plot with time info (symbol size == 1, very small)
# 'x', 'y': the line
# 'name' name ofthis line
# 'style'  the line style
# 'w' line width
# 'time' time info, for every point
#
function qplot2(x::Array{Float64}, y::Array{Float64}, name::String, style::String, w, time::Array{Float64})
	global qwtwPlot2H, qwtwLibHandle
	if qwtwLibHandle == 0
		@printf "not started (was qstart() called?)\n"
		return
	end

	@assert (length(x) == length(y))
	n = length(x)
	ww::Int32 = w;
	ccall(qwtwPlot2H, Cvoid, (Ptr{Float64}, Ptr{Float64}, Int32, Ptr{UInt8}, Ptr{UInt8}, Int32, Int32, Ptr{Float64}),
		x, y, n, name, style, ww, 1, time);
	sleep(0.025)

end;

# plot  with time info (line width == 1)
# 'x', 'y': the line
# 'name' name ofthis line
# 'style'  the line style
# 'w': symbol size
# 
# 'time' time info, for every point
#
function qplot2p(x::Array{Float64}, y::Array{Float64}, name::String, style::String, w, time::Array{Float64})
	global qwtwPlot2H, qwtwLibHandle
	if qwtwLibHandle == 0
		@printf "not started (was qstart() called?)\n"
		return
	end

	@assert (length(x) == length(y))
	n = length(x)
	ww::Int32 = w;
	ccall(qwtwPlot2H, Cvoid, (Ptr{Float64}, Ptr{Float64}, Int32, Ptr{UInt8}, Ptr{UInt8}, Int32, Int32, Ptr{Float64}),
		x, y, n, name, style, 1, ww, time);
	sleep(0.025)

end;

# put label on horizontal axis
function qxlabel(s::String)
	global qwtwXlabelH, qwtwLibHandle
	if qwtwLibHandle == 0
		@printf "not started (was qstart() called?)\n"
		return
	end

	ccall(qwtwXlabelH, Cvoid, (Ptr{UInt8},), s);
end;

# put label on left vertical axis
function qylabel(s::String)
	global qwtwYlabelH, qwtwLibHandle
	if qwtwLibHandle == 0
		@printf "not started (was qstart() called?)\n"
		return
	end

	ccall(qwtwYlabelH, Cvoid, (Ptr{UInt8},), s);
end;

# put title on current plot
function qtitle(s::String)
	global qwywTitleH, qwtwLibHandle
	if qwtwLibHandle == 0
		@printf "not started (was qstart() called?)\n"
		return
	end

	ccall(qwywTitleH, Cvoid, (Ptr{UInt8},), s);
end;


export qfigure, qfmap, qsetmode, qplot, qplot1, qplot2, qplot2p, qxlabel,  qylabel, qtitle
export qimportant, qclear, qstart, qstop, qversion, qsmw
export traceit
export  qEnableCoordBroadcast, qDisableCoordBroadcast
#export qplot3d, qf3d,

end # module
