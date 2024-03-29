"""
QWTwPlot package   
qwt - based 2D/3D plotting   
   
"""

#__precompile__(true)
module QWTWPlot

using Printf
using Libdl
using Sockets # for callbacks
import JSON3  # for settings file
import Qt_jll # for paths info
import qwtw_jll # for plotting
import marble_jll # for paths info

function __init__()
	# this is not OK  qStart() # start in normal mode
	global cbTaskH # callback task handler
	cbTaskH = @task udpDataReader(); # for callbacks
	cbTaskH.sticky = false
	return
end

# DLLs and function handles below:
qwtwLibHandle = 0
qwtwFigureH = 0
qwtwSpectrogramTestH = 0
qwtwSetSpectrogramInfoH = 0
qwtwSetSpectrogramInfoH2 = 0
qwtwServiceH = 0
qwtwClipGroupH = 0
qwtwRemoveLineH = 0
qwtwDebugMode = false
qwtwChangeLineH = 0
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
qwtDisableBroadcastH = 0

qwtMglH = 0
qwtMglLine = 0
qwtMglMesh = 0
#qwtSetCBH = 0

qwtStartH = 0
qwtStartDebugH = 0
qwtStopH = 0
started = false   # should be true when we attached to the library, and library 'attached' to QT part

old_path = ""
old_qtPath = ""
oldLdLibPath = ""

udpPort = 0 	# UDP port number
smip = "239.255.0.1"
cfg = Dict()	# settings info
pleaseStopUdp = false
cbLock = ReentrantLock()
errrorBreak = false	# do 'error()' when parameters are not OK

"""
	QCBInfo

information for the callback function 
about the mouse click
"""
struct QCBInfo
	type::Int32		# callback type ('1' for simple mouse click.. something else in case 'external UDP message info')
	plotID::Int32	# ID of the plot window
	lineID::Int32	# ID of the closest line
	index::Int32	# closest point index
	xx::Int32		# x window coord
	yy::Int32		# y window coord

	# closest point info
	x::Float64	# X coord
	y::Float64	# Y coord
	z::Float64  # Z coord (probably zero, when 'type' == 1)
	time::Float64 # time info
	label::String # label of the selected line
end
function QCBInfo()
	return QCBInfo(0, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, "empty")
end
export QCBInfo

cbFunction  = function(info::QCBInfo) # 'picker' callback user function
	# doing nothing by default
	return
end

"""
	QClipCallbackInfo

information about the 'clip' callback (when the user is pressing 'clip' button )
"""
struct QClipCallbackInfo
	t1::Float64 	# time 1 (left)
	t2::Float64		# time 2 (right)
	clipGroup::Int32 # clip group (every plot has its group)
	havePos::Bool       # true if x y z are valid
	x1::Float64		# point corresponding to time1, if any
	y1::Float64
	z1::Float64
	x2::Float64 	# point corresponding to time2, if any
	y2::Float64
	z2::Float64
end
function QClipCallbackInfo() 
	return QClipCallbackInfo(0.0, 0.0, 0, false, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
end

export QClipCallbackInfo

clipCallbackFunction = function(info::QClipCallbackInfo) # 'clip' callback user function
	# doing nothing by default
	return
end

lastUdpPacket = zeros(UInt8, 80) 
export lastUdpPacket # just for testing/debugging

"""
	onPickUdp(x::Vector{UInt8})

process picker UDP message.  Called only when we get info from UDP
x is the message
"""
function onPickUdp(x::Vector{UInt8})
	global cbFunction
	global qwtwDebugMode
	global qwtwServiceH
	ii = QCBInfo()

	if qwtwDebugMode
		@printf "onPickUdp starting!\n"
	end

	try
		time = reinterpret(Float64, x[5:12])[1]
		iks =  reinterpret(Float64, x[13:20])[1]
		igrek =  reinterpret(Float64, x[21:28])[1]
		zet =  reinterpret(Float64, x[29:36])[1]
		
		index =  reinterpret(Int32, x[37:40])[1]

		xx = reinterpret(Int32, x[41:44])[1]
		yy =  reinterpret(Int32, x[45:48])[1]
		plotID =  reinterpret(Int32, x[49:52])[1]
		lineID = reinterpret(Int32, x[53:56])[1]
		type = reinterpret(Int32, x[57:60])[1]
		
		# and the 'label'
		eos = 84
		for k= 61:84
			if x[k] == 0
				eos = k
				break
			end
		end
		if eos == 61
			label = ""
		else
			label = String(x[61:eos-1])
		end
		if qwtwDebugMode
			@printf "\t type = %d; index = %d; label = %s\n" type index label
		end

		ii = QCBInfo(type, plotID, lineID, index, xx, yy, iks, igrek, zet, time, label)
	catch ex
		if qwtwDebugMode
			@printf "cannot process picker message\n "
			bt = backtrace()
			msg = sprint(showerror, ex, bt)
			@printf "%s\n" msg
		end
	end

	try
		stest1 = ccall(qwtwServiceH, Int32, (Int32,), 1);
		Base.invokelatest(cbFunction, ii)  # call the user function
		stest2 = ccall(qwtwServiceH, Int32, (Int32,), 2);
	catch ex
		@printf "onPickUdp: callback function failed\n "
		bt = backtrace()
		msg = sprint(showerror, ex, bt)
		@printf "%s\n" msg
	end

	return
end


"""
	onClipUdp(x::Vector{UInt8})

process clip UDP message
"""
function onClipUdp(x::Vector{UInt8})
	global clipCallbackFunction
	global qwtwDebugMode
	global qwtwServiceH
	ii = QClipCallbackInfo()

	if qwtwDebugMode
		@printf "onClipUdp\n"
	end

	try
		time1 = reinterpret(Float64, x[5:12])[1]
		time2 = reinterpret(Float64, x[13:20])[1]
		clipGroup = reinterpret(Int32, x[21:24])[1]
		havePos = reinterpret(Int32, x[25:28])[1]

		x1 = reinterpret(Float64, x[29:36])[1]
		y1 = reinterpret(Float64, x[37:44])[1]
		z1 = reinterpret(Float64, x[45:52])[1]
		x2 = reinterpret(Float64, x[53:60])[1]
		y2 = reinterpret(Float64, x[61:68])[1]
		z2 = reinterpret(Float64, x[69:76])[1]

		ii = QClipCallbackInfo(time1, time2, clipGroup, havePos, x1, y1, z1, x2, y2, z2)
	catch ex
		if qwtwDebugMode
			@printf "onClipUdp: cannot process 'clip' message\n "
			bt = backtrace()
			msg = sprint(showerror, ex, bt)
			@printf "%s\n" msg
		end
	end

	if qwtwDebugMode
		@printf "\ttime1 = %f, time2 = %f\n" ii.t1  ii.t2
	end

	try
		stest1 = ccall(qwtwServiceH, Int32, (Int32,), 1);
		Base.invokelatest(clipCallbackFunction, ii) # call the user function
		stest2 = ccall(qwtwServiceH, Int32, (Int32,), 2);
	catch ex
		@printf "onClipUdp: callback function failed\n "
		bt = backtrace()
		msg = sprint(showerror, ex, bt)
		@printf "%s\n" msg
	end

	return
end


"""
	udpDataReader()

UDP reader task. this is a very simple UDP client.
"""
function udpDataReader()
	global udpPort
	global pleaseStopUdp
	global qwtwDebugMode
	global cbLock
	global lastUdpPacket
	global smip

	if udpPort == 0    # this should be initialized inside qstart()
		@warn " 1 cannot start udpDataReader \n"
		return
	end


	type = 0; plotID = 0; lineID = 0; index = 0; xx = 0; yy = 0; iks = 0.0; igrek = 0.0; zet = 0.0; time = 0.0; label = "hello";
	ii = QCBInfo(type, plotID, lineID, index, xx, yy, iks, igrek, zet, time, label)

	time1 = 0.0; time2 = 0.0
	x1 = 0.0; y1 = 0.0; z1 = 0.0;  x2 = 0.0; y2 = 0.0; z2 = 0.0; clipGroup = 0; havePos = false;
	clipInfo = QClipCallbackInfo(time1, time2, clipGroup, havePos, x1, y1, z1, x2, y2, z2)
	x = zeros(UInt8, 88)
	nx = 0; eos = 84; k = 1;

	if qwtwDebugMode
		@info "starting udp data reader on port $udpPort; smip = $smip"
	end
	group = IPv4(smip)
	sock=UDPSocket()
	counter = 0
	test = bind(sock, ip"0.0.0.0", udpPort,  reuseaddr=true)
	if !test
		if qwtwDebugMode
			@info "udpDataReader() bind failed"
		end
	end
	join_multicast_group(sock, group)
	lock(cbLock)    # the only meaning of cbLock is that this thread is running
	while pleaseStopUdp == false
		#@printf "udpDataReader waiting for the data from UDP.. \n"
		x = recv(sock)
		#x=reinterpret(UInt8, packet)    # ??
		lastUdpPacket = x
		if pleaseStopUdp
			break
		end
		nx = length(x)
		if nx < 80      # too short message
			if qwtwDebugMode
				@printf "\t QWTWPlot udpDataReader() got %d bytes" nx
			end
			continue
		end

		if qwtwDebugMode
			@printf "got %d bytes  \n" length(x) 
			print(typeof(x))
			@printf "  %s\n" x[1:4]
			#print(x)
		end

		if x[1] == 0x50 # 'P'
			onPickUdp(x)
		elseif x[1] ==  0x43 #  'C'
			onClipUdp(x)
		end

		counter +=1
    end 
	leave_multicast_group(sock, group)
    close(sock)
	unlock(cbLock)

	if qwtwDebugMode
		@info "stopping udp data reader on port $udpPort"
	end
end

#cbTaskH = Task(udpDataReader)

"""
	saveEnv()

	saves some of the env vars to global variables
"""
function saveEnv()
	global old_path, old_qtPath, oldLdLibPath
	try old_path = ENV["PATH"]; catch end
	try old_qtPath = ENV["QT_PLUGIN_PATH"]; catch end
	try oldLdLibPath = ENV["LD_LIBRARY_PATH"]; catch end
	return
end

"""
	restoreEnv()

restores env vars back from global variables
"""
function restoreEnv()
	global old_path, old_qtPath, oldLdLibPath
	ENV["PATH"] = old_path
	ENV["QT_PLUGIN_PATH"] = old_qtPath 
	ENV["LD_LIBRARY_PATH"] = oldLdLibPath 
	return
end

"""
	printEnv()

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
	addEnvItem(item, var::String; debug = false)

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
	qstart(;debug = false, qwtw_test = false, libraryName = "libqwtw")::Int32

starts the qwtw "C" library. 

Without it, nothing will work. Call it before any other functions.\\
if debug, will try to enable debug print out. A lot of info. Just for debugging.\\
qwtw_test	-> if true, will try to not modify env variables. \\
libraryName: if not empty, then use this a a library name instead of the library from artifact (for debugging)

return 0 if success
"""
function qstart(;debug = false, qwtw_test = false, libraryName = "libqwtw")::Int32
	global qwtwDebugMode
	qwtwDebugMode = debug
	qwtw_libName = "nolib"
	if debug
		@printf "starting qwtw; current path: %s\n\n" ENV["PATH"]
	end

	# this could be still useful:
	#if debug qwtw_libName *= "d"; end

	global qwtwLibHandle, qwtwFigureH, qwtwSpectrogramTestH, qwtwSetSpectrogramInfoH, qwtwSetSpectrogramInfoH2
	global qwtwMapViewH,  qwtwsetimpstatusH, qwtwCLearH, qwtwPlotH, qwtwServiceH
	global qwtwPlot2H, qwtwXlabelH, qwtwYlabelH, qwywTitleH, qwtwVersionH, qwtwMWShowH, qwtwRemoveLineH
	global qwtEnableBroadcastH, qwtDisableBroadcastH, qwtwChangeLineH, qwtwClipGroupH
	#global qwtwPlot3DH, qwtwFigure3DH
	global qwtStartH, qwtStopH, started
	global old_path, old_qtPath, oldLdLibPath
	global qwtMglH, qwtMglLine, qwtMglMesh
	#global qwtSetCBH
	global udpPort, smip
	global cfg
	global pleaseStopUdp

	if started
		@printf "qwtw already started\n"
		return 0
	end

	settingsFileName = joinpath(homedir(), ".qwtw", "settings.json")
	try
		settings = read(settingsFileName)
		cfg = JSON3.read(String(settings))
		udpPort = parse(Int32, cfg["udp_client_port"])
		smip = cfg["smip"]
	catch ex
		udpPort = 0
		@warn "error while reading settings file $settingsFileName ($ex)  "
	end
	if udpPort != 0
		pleaseStopUdp = false
		#udpDataReader();
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
		@printf "qwtw test; loading %s .. \n" qwtw_libName
		@printf "\nPATH = %s\n\n" ENV["PATH"]
	else
		addEnvItem(qwtw_jll.PATH, "PATH", debug = debug)
		@static if Sys.iswindows() 
			ENV["QT_PLUGIN_PATH"]=Qt_jll.artifact_dir * "\\plugins"	
			addEnvItem(qwtw_jll.LIBPATH, "PATH", debug = debug)
			
			#ENV["PATH"]= boost_jll.artifact_dir * "\\bin;" *  ENV["PATH"] 
			#ENV["PATH"]= qwt_jll.artifact_dir * "\\bin;" *  ENV["PATH"] 
			#ENV["PATH"]= Qt_jll.artifact_dir * "\\bin;" *  ENV["PATH"] 

			#ENV["PATH"]= CompilerSupportLibraries_jll.artifact_dir * "\\bin;" *  ENV["PATH"] 
			#new_env["PATH"]= FreeType2_jll.artifact_dir * "\\bin;" *  ENV["PATH"] 
		else
			ENV["QT_PLUGIN_PATH"]=string(Qt_jll.artifact_dir) * "/plugins"	
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
			try
				@printf "LD_LIBRARY_PATH: %s \n\n" String(ENV["LD_LIBRARY_PATH"])
			catch
				@printf "NO LD_LIBRARY_PATH \n"
			end
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
		@info "Sorry, dlopen for $qwtw_libName failed; something is wrong ($ex)\n"
		throw(ex)
	end

	if debug 
		@printf "\nlibrary %s opened from %s \n" qwtw_libName  Libdl.dlpath(qwtwLibHandle)
	end
	qwtwFigureH = Libdl.dlsym(qwtwLibHandle, "qwtfigure")
	try
		qwtwSpectrogramTestH = Libdl.dlsym(qwtwLibHandle, "qwtspectrogram")
		qwtwSetSpectrogramInfoH = Libdl.dlsym(qwtwLibHandle, "spectrogram_info")
		qwtwSetSpectrogramInfoH2 = Libdl.dlsym(qwtwLibHandle, "spectrogram_info2")
	catch ex
		@info "looks like spectrograms not implemented by qwtw; $ex"
		qwtwSpectrogramTestH = 0
		qwtwSetSpectrogramInfoH = 0
		qwtwSetSpectrogramInfoH2 = 0
	end
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
	qwtwChangeLineH = Libdl.dlsym(qwtwLibHandle, "qwtchange")

	qwtwServiceH = Libdl.dlsym(qwtwLibHandle, "qwtservice")

	try
		qwtwClipGroupH = Libdl.dlsym(qwtwLibHandle, "qwtclipgroup")
	catch
		@printf "WARNING: clip groups disabled (wrong qwtw version?) \n"
	end

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
#=
	try 
		qwtSetCBH = Libdl.dlsym(qwtwLibHandle, "setcallback")

		qcbTest1H = Libdl.dlsym(qwtwLibHandle, "setcallback_t1")
		qcbTest2H = Libdl.dlsym(qwtwLibHandle, "setcallback_t2")

		cbTest1 = @cfunction(qcbTest1, Cvoid, ())
		ccall(qcbTest1H, Cvoid, (Ptr{Cvoid},), cbTest1);

		#if qwtSetCBH != 0
		#	cb_c = @cfunction(qCallback, Cvoid, (Cint, Cint, Cint, Cint, Cint, 
		#		Cdouble, Cdouble, Cdouble, Cdouble, Cstring))
#
		#	ccall(qwtSetCBH, Cvoid, (Ptr{Cvoid},), cb_c);
		#end
	catch
		@printf "WARNING: setcallback features disabled \n"
	end
=#
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

It maybe useful for debugging. What it does actually, it sends a command to the QT process to exit.\\
Have to call `qstart()` before, though.
"""
function qstop()
	global qwtwLibHandle, qwtStopH
	global started
	global pleaseStopUdp
	
	pleaseStopUdp = true
	
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
	qErrorBreak(b::Bool)

if b == true, then do 'error()' in case of bad input parameters
"""
function qErrorBreak(b::Bool)
	global errrorBreak
	errrorBreak = b
	return
end
export qErrorBreak

"""
	qversion() :: String

useful for debugging.\\
return version info (as a string); 
"""
function qversion() :: String
	global qwtwVersionH, qwtwLibHandle
	if qwtwLibHandle == 0
		return "not started yet"
	end
	v = zeros(UInt8, 1024)
	#@printf "qwtwc version: "
	bs = ccall(qwtwVersionH, Int32, (Ptr{UInt8}, Int32), v, 1024);
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
	qfigure(n::Integer = 0; xAxisType=:aLinear, yAxisType=:aLinear)::Int32

create a new plot window, OR make plot (with this ID 'n') 'active'.

looks like 'n' have to be an integer number (this plot ID, or zero if you do not care).\\
after this function, this plot is the "active plot". \\
If 'n == 0' then another new plot will be created.
xAxisType and yAxisType could be :aLinear (default) or :aLog (logarithmic)

Returns ID of the created plot. 
"""
function qfigure(n::Integer = 0; xAxisType=:aLinear, yAxisType=:aLinear)::Int32
	global qwtwFigureH, started
	if !started
		@printf "not started (was qstart() called?)\n"
		return 0
	end
	flags::UInt32 = 0
	if xAxisType == :aLog
		flags |= 1
	end
	if yAxisType == :aLog
		flags |= 2
	end
	test = ccall(qwtwFigureH, Int32, (Int32, UInt32), n, flags);
	return test
end;



function qspectrogram(n::Integer = 0; xAxisType=:aLinear, yAxisType=:aLinear)::Int32
	global qwtwSpectrogramTestH, started
	if !started
		@printf "not started (was qstart() called?)\n"
		return 0
	end
	flags::UInt32 = 0
	if xAxisType == :aLog
		flags |= 1
	end
	if yAxisType == :aLog
		flags |= 2
	end
	test = ccall(qwtwSpectrogramTestH, Int32, (Int32, UInt32), n, flags);
	return test
end
export qspectrogram

"""
	qspectrogram_info(ymin::Float64, ymax::Float64, xmin::Float64, xmax::Float64, z::Matrix{Float64}; p::AbstractArray{Float64, 3} = zeros(1, 1, 1), t::Matrix{Float64} = [0.0 0.0])::Int32
  
parameters:  		
* xmin minimum x coord
* xmax maximum x coord
* ymin minimum y coord
* ymax maximum y coord
* z a spectrogramm info. [ny x nx] matrix
* p a 3D array of points associated with every pixel  [3 x ny x nx] Float64  array
* tt a parameter (timestamp?) value, assiciated with every pixel [ny x nx] Float64 matrix
"""
function qspectrogram_info(ymin::Float64, ymax::Float64, xmin::Float64, xmax::Float64, z::Matrix{Float64};
			p::AbstractArray{Float64, 3} = zeros(1, 1, 1), t::Matrix{Float64} = [0.0 0.0])::Int32
	global qwtwSetSpectrogramInfoH2, started
	if !started
		@info "not started (was qstart() called?)\n"
		return 0
	end
	ny, nx = size(z)

	pp = C_NULL
	tt = C_NULL

	if length(t) > 2   # try to use this parameter
		nty, ntx = size(t)
		if ntx != nx || nty != ny
			@warn "qspectrogram_info: wrong t size ([$nty, $ntx]); it should be ([$ny, $nx])"
			return 1
		end
		tt = copy(t')    # do the transpose !!!!
	end
	if length(p) > 1
		n1, n2, n3 = size(p)
		if n1 != 3 || n2 != ny || n3 != nx
			@warn "qspectrogram_info: wrong p size ([$n1, $n2, $n3], it should be ([3, $ny, $nx]))"
			return 2
		end
		perm = (1, 3, 2);
		pp = copy(permutedims(p, perm))  # do the transpose !!!!
	end
	zz = copy(z')

	test = ccall(qwtwSetSpectrogramInfoH2, Int32, (Int32, Int32, Float64, Float64, Float64, Float64, Ptr{Float64}, Ptr{Float64}, Ptr{Float64}), 
		ny, nx, ymin, ymax, xmin, xmax, zz, pp, tt);
	return test
end
export qspectrogram_info



"""
	qclipgrp(gr) 

set current 'clip group'.

gr is the ID of this new group. 
all (new) subsequent plots/figires will belong to this group. if press 'clip' button, 
then if will work only for plots from the same group. 

useful in case some of the plots have another time range.
"""
function qclipgrp(gr) 
	global qwtwClipGroupH, qwtwLibHandle, started
	if (qwtwLibHandle == 0) || (!started)
		@printf "not started (was qstart() called?)\n"
		return
	end
	if qwtwClipGroupH == 0
		@printf "clip groups are not supported, sorry\n"
		return
	end

	ccall(qwtwClipGroupH, Cvoid, (Int32,), Int32(gr));
end
export qclipgrp

"""
	qremove(id::Int32)

remove a line from a plot.
id: ID of the line to remove
"""
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

create a new  plot window to draw on a map (with specific window ID)\\
'n' is Int32
"""
function qfmap(n)::Int32
	global qwtwMapViewH, qwtwLibHandle, started
	if (qwtwLibHandle == 0) || (!started)
		@printf "not started (was qstart() called?)\n"
		return 0
	end
	if qwtwMapViewH == 0
		@printf "map vew not supported, sorry\n"
		return 0
	end
	test = 0
	try
		test = ccall(qwtwMapViewH, Int32, (Int32,), n);
	catch ex
		@printf "ERROR in QWTWPlot::qfmap()\n"
		println(ex)
	end
	return test
end

"""
	qfmap()

create a new  plot window to draw on a map.
"""
function qfmap()::Int32
	return qfmap(0)
end;

"""
	qmgl(n = 0)

create a new  plot window to draw 3D lines / surfaces.

currently works only for Linux (?)
"""
function qmgl(n = 0)::Int32
	global qwtMglH, qwtwLibHandle, started
	if (qwtwLibHandle == 0) || (!started)
		@printf "not started (was qstart() called?)\n"
		return 0
	end
	if qwtMglH == 0
		@printf "3D not supported, sorry\n"
		return 0
	end

	test = ccall(qwtMglH, Int32, (Int32,), n);
	return test
end;

export qmgl

"""
	qmgline(x::Vector{Float64}, y::Vector{Float64}, z::Vector{Float64}, style::String = "-sb"; name = "")

draw a 3D line. 

x, y, and z are the vectors with point coordinates.\\
style - how to draw a line. Explanation is here: http://mathgl.sourceforge.net/doc_en/Line-styles.html\\
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

draw a 3D mesh/surface.   Currently works only for Linux (is this true?). \\

data - vertical (z) coordinates of the surface. should be Array{Float64, 2}\\
xMin, xMax, yMin, yMax is the definition of the range where to draw a surface. All the 
coordinates from 'data' are evenly distributed inside this range.\\
style how to draw the surface. Some hints could be taken from here: http://mathgl.sourceforge.net/doc_en/Color-scheme.html \\
type  -   0 or 1;  mesh/grid  or surface\\
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
	
looks like `0` means 'not important', `1` means "important.\\
'not important' will not participate in 'clipping':\\
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
#=
function qsetcallback(cb)
	global qwtSetCBH, qwtwLibHandle, started
	if (qwtwLibHandle == 0) || (!started)
		@printf "not started (was qstart() called?)\n"
		return
	end
	if qwtSetCBH == 0
		@printf "qwtSetCBH == 0 \n"
		return
	end
	
	#ccall(qwtSetCBH, Cvoid, (cb,));
	return
end
export qsetcallback
=#

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

x and y:   the points.\\

name:      	name for this line.\\

style: 	 	how to draw a line.\\

lineWidth:	is a line width.\\

symSize:	size of the symbols, if they are used in 'style' spec.\\

what does 'style' parameter means? It's a string which has 1 or 2 or 3 symbols. \\

Look at two places for the detail explanation:\\
* example code  https://github.com/ig-or/QWTWPlot.jl/blob/master/src/qwexample.jl   
* https://github.com/ig-or/QWTWPlot.jl/blob/master/docs/line-styles.md

this function returns ID of the line created. hopefully you can use it in some other functions\\
ID supposed to be >=0 is all is OK, or <0 in case of error
"""
function qplot(x::Vector{Float64}, y::Vector{Float64}, name::String, style::String="-b", lineWidth=1, symSize=1) :: Int32
	global qwtwPlotH, qwtwLibHandle, started, qwtwDebugMode
	global errrorBreak
	if (qwtwLibHandle == 0) || (!started)
		@printf "not started (was qstart() called?)\n"
		return -88
	end

	n = length(x)
	n1 = length(y)
	if  (n < 1) || (n != n1)
		mm = @sprintf "QWTWPlot qplot: bad input array length x[%d], y[%d]; name = %s" n n1 name
		if errrorBreak
			error(mm)
		else
			println(mm)
		end
		return -89
	end

	ww::Int32 = lineWidth;
	s::Int32 = symSize
	test::Int32 = -50

	if qwtwDebugMode
		@printf "qplot: (%s) (%s) n=%d \n " name style n
	end
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

```

x and y:   the points   
name:      	name for this line   
style: 	 	how to draw a line   
symSize:	size of the symbols  

```

what does 'style' parameter means? It's a string which has 1 or 2 or 3 symbols. \\
Look at two places for the detail explanation:

* example code  https://github.com/ig-or/QWTWPlot.jl/blob/master/src/qwexample.jl
* https://github.com/ig-or/QWTWPlot.jl/blob/master/docs/line-styles.md


this function returns ID of the line created. hopefully you can use it in some other functions\\
ID supposed to be >=0 is all is OK, or <0 in case of error
	
"""
function qplot1(x::Vector{Float64}, y::Vector{Float64}, name::String, style::String, symSize) :: Int32
	global qwtwPlotH, qwtwLibHandle, started, qwtwDebugMode
	global errrorBreak
	if (qwtwLibHandle == 0) || (!started)
		@printf "not started (was qstart() called?)\n"
		return -88
	end

	n = length(x)
	n1 = length(y)
	if (n < 1) || (n1 < 1) || (n != n1)
		mm = @sprintf "QWTWPlot qplot1: bad input array length (x:%d; y:%d) name=%s style=%s symSize=%d\n" n n1 name style symSize
		if errrorBreak
			error(mm)
		else
			println(mm)
		end
		return -89
	end

	ww::Int32 = symSize;
	test::Int32 = -50
	if qwtwDebugMode
		@printf "qplot1: (%s) (%s) n=%d \n " name style n
	end

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
end

"""
	qchange(id::Int32, x::Vector{Float64}, y::Vector{Float64}, t::Vector{Float64} = []) :: Int32

change existing line.
id: ID of the line to change
x : new X vectors
y: new Y vectors
t : (optional) new 'time' vector
"""
function qchange(id::Int32, x::Vector{Float64}, y::Vector{Float64}, t::Vector{Float64} = Vector{Float64}([])) :: Int32
	global qwtwChangeLineH, started
	global errrorBreak
	if !started
		@printf "not started (was qstart() called?)\n"
		return
	end
	n = length(x)
	n1 = length(y)
	n2 = length(t)

	if (n < 1) || (n != n1)
		mm = @sprintf "QWTWPlot qchange: bad input array length (x:%d; y:%d)\n" n n1
		if errrorBreak
			error(mm)
		else
			println(mm)
		end
		return -89
	end

	zz = Ptr{Float64}(C_NULL)
	tt = Ptr{Float64}(C_NULL)
	if n2 > 0
		tt = t
		if n2 != n
			mm = @sprintf "qchange: wrong _t_ array length (t: %d; n:%d)" n2  n
			if errrorBreak
				error(mm)
			else
				println(mm)
			end
			return 84
		end
	end
	test = -50
	try
		test = ccall(qwtwChangeLineH, Int32, (Int32, Ptr{Float64}, Ptr{Float64}, Ptr{Float64}, Ptr{Float64}, Int32), 
			id, x, y, zz, tt, n);
	catch ex
		@printf "qchange ERROR\n"
		throw(ex)
		return -42
	end
	return test
end
export qchange

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

Enable UDP client.\\

In case you'd like to connect to some external software from this library,
it has UDP client and server inside. If/when you will move a marker, it will 
broadcast 'marker information' via UDP. \\
Other way should also work: if some other application will broadcast UDP with marker info,
all the markers in this library supposed to be updated.

parameters: x, y,  and z are the vectors describing the line in 3D space;
and 'time' is an additional time information, for every point of the line.

It will send out marker info to UDP port 49561.\\
Incoming (to this library) UDP  port number is 49562, and IP address is "127.0.0.1".

Incoming message format:  'CRDS"<x><y><z>"FFFF', where
<x>, <y>, and <z> are  Float64 point coordinates, 8 bytes each,
so this message contains 4 + 3*8 + 4 bytes\\
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

	if n < 1
		@printf "QWTWPlot qEnableCoordBroadcast: bad input array length (%d) \n" n
	end

	ccall(qwtEnableBroadcastH, Cvoid, (Ptr{Float64}, Ptr{Float64}, Ptr{Float64},
			 Ptr{Float64}, Int32),
		x, y, z , time, n);
	sleep(0.025)
	return
end;

"""
	qDisableCoordBroadcast()
disable all this UDP -related stuff.\\

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

```

julia-repl
julia> time=collect(0.0:0.01:10.0)
x = sin.(time)
y = cos.(time)
qfigure()
qplot(time, x + y, "function 1", "-b", 3)
qfigure()
qplot2(x, y, time, "function 2", "-m", 3)

```
Now use marker on both plots and see that it moves on both plots.


this function returns ID of the line created. hopefully you can use it in some other functions\\
ID supposed to be >=0 is all is OK, or <0 in case of error

"""
function qplot2(x::Array{Float64}, y::Array{Float64}, time::Array{Float64}, name::String, style::String, lineWidth=1, symSize=1):: Int32
	global qwtwPlot2H, qwtwLibHandle, started, qwtwDebugMode
	global errrorBreak
	if (qwtwLibHandle == 0) || (!started)
		@printf "not started (was qstart() called?)\n"
		return -88
	end
	n = length(x)
	n1 = length(y)
	n2 = length(time)
	if (n < 1) || (n != n1) || (n != n2)
		mm = @sprintf "QWTWPlot qplot2 error: bad array length; x:%d; y:%d; time:%d; name = %s" n n1 n2 name
		if errrorBreak
			error(mm)
		else 
			println(mm)
		end
		return -76
	end	

	ww::Int32 = lineWidth;
	s::Int32 = symSize;
	test::Int32 = -50
	if qwtwDebugMode
		@printf "qplot2: (%s) (%s) n=%d \n " name style n
	end
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

put a label on the horizontal axis on the bottom.
"""
function qxlabel(s::String)
	global qwtwXlabelH, qwtwLibHandle, started
	if (qwtwLibHandle == 0) || (!started)
		@printf "not started (was qstart() called?)\n"
		return
	end

	ccall(qwtwXlabelH, Cvoid, (Ptr{UInt8},), s);
	return
end

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
end

"""
	qtitle(s::String)

put a title on the current plot.
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
function qStarted() :: Bool
	global started
	return started
end

export qfigure, qfmap, qplot, qplot1, qplot2, qxlabel,  qylabel, qtitle
export qimportant, qclear, qstart, qstop, qversion, qsmw
export traceit
export  qEnableCoordBroadcast, qDisableCoordBroadcast
export qStarted
#export qplot3d, qf3d,

"""
	stopUdpThread()

stops UDP thread.	
"""
function stopUdpThread()
	global pleaseStopUdp
	global udpPort
	global cbTaskH
	global qwtwDebugMode
	global cbLock

	if qwtwDebugMode
		@printf "stopUdpThread: istaskdone1(cbTaskH): %d\n" istaskdone(cbTaskH)
	end
	#if istaskstarted(cbTaskH) # stop the task
	if islocked(cbLock)
		@assert istaskstarted(cbTaskH)
		if qwtwDebugMode
			@printf "stopping the task..\n"
		end
		pleaseStopUdp = true
		group = IPv4(smip)
		sock=UDPSocket()
		#Sockets.setopt(sock, enable_broadcast=true)

		for i = 1:25
			send(sock, group, udpPort, "stop\n")
		end

		if qwtwDebugMode
			@printf "waiting for the task to finish..\n"
		end
		#while !istaskdone(cbTaskH)
		#end

		#lock(cbLock)
		#unlock(cbLock)

		wait(cbTaskH)
		if qwtwDebugMode
			@printf "finished ..\n"
			@printf "stopUdpThread: istaskdone2(cbTaskH): %d\n" istaskdone(cbTaskH)
		end

		cbTaskH = @task udpDataReader();
	else
		@assert !istaskstarted(cbTaskH)
	end
end

"""
	startUdpThread()

start UDP thread	
"""
function startUdpThread()
	global pleaseStopUdp, cbTaskH
	pleaseStopUdp = false
	@assert !istaskstarted(cbTaskH)
	schedule(cbTaskH)
	return
end
export startUdpThread, stopUdpThread

"""
	qsetCallback(cb) 

set up another 'picker' callback
cb is the callback function, which will take one single parameter of type QCBInfo
see cbtest.jl for example how to use this.
"""
function qsetCallback(cb) 
	global cbFunction
	global qwtwDebugMode
	#global cbLock

	stopUdpThread()

	#@printf "qsetCallback  locking.. \n"
	#lock(cbLock)
	#@printf "qsetCallback locked ! \n"
	cbFunction = cb
	if qwtwDebugMode
		@printf "setting up cbFunction \n"
	end
	#unlock(cbLock)
	#@printf "qsetCallback unlocked ! \n"
	startUdpThread()
	return
end
export qsetCallback


"""
	qsetClipCallback(cb) 

set up a 'clip' callback
cb is the callback function, which will take one single parameter of type QClipCallbackInfo
see cbtest.jl for example how to use this.
"""
function qsetClipCallback(cb) 
	global clipCallbackFunction
	global qwtwDebugMode

	stopUdpThread()
	clipCallbackFunction = cb
	if qwtwDebugMode
		@printf "setting up clipCallbackFunction! \n"
	end
	startUdpThread()
	return
end
export qsetClipCallback

"""
	setDebugMode(m::Bool)

for testing/defugging
"""
function setDebugMode(m::Bool)
	global qwtwDebugMode
	qwtwDebugMode = m
	return
end
export setDebugMode

end # module
