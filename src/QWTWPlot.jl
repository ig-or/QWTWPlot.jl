"""
QWTWPlot package
Qt6 / Qwt - based out-of-process 2D/3D plotting
"""
module QWTWPlot

using Printf
using Libdl
using Sockets # for multicast UDP callbacks
import JSON3  # for ~/.qwtw/settings.json

function __init__()
	return
end

@inline _dlsym_opt(handle::Ptr{Cvoid}, sym::Symbol)::Ptr{Cvoid} =
	something(Libdl.dlsym(handle, sym; throw_error = false), C_NULL)
@inline _f64vec(v::Vector{Float64}) = v
@inline _f64vec(v::AbstractVector{<:Real}) = collect(Float64, v)

# DLL and C function handles (typed Ptr{Cvoid} instead of untyped Int globals)
qwtwLibHandle::Ptr{Cvoid} = C_NULL
qwtwFigureH::Ptr{Cvoid} = C_NULL
qwtwSpectrogramTestH::Ptr{Cvoid} = C_NULL
qwtwSetSpectrogramInfoH::Ptr{Cvoid} = C_NULL
qwtwSetSpectrogramInfoH2::Ptr{Cvoid} = C_NULL
qwtwServiceH::Ptr{Cvoid} = C_NULL
qwtwClipGroupH::Ptr{Cvoid} = C_NULL
qwtwRemoveLineH::Ptr{Cvoid} = C_NULL
qwtwDebugMode::Bool = false
qwtwChangeLineH::Ptr{Cvoid} = C_NULL
qwtwMapViewH::Ptr{Cvoid} = C_NULL
qwtwsetimpstatusH::Ptr{Cvoid} = C_NULL
qwtwCLearH::Ptr{Cvoid} = C_NULL
qwtwPlotH::Ptr{Cvoid} = C_NULL
qwtwPlot2H::Ptr{Cvoid} = C_NULL
qwtwXlabelH::Ptr{Cvoid} = C_NULL
qwtwYlabelH::Ptr{Cvoid} = C_NULL
qwtwTitleH::Ptr{Cvoid} = C_NULL
qwtwVersionH::Ptr{Cvoid} = C_NULL
qwtSavePng::Ptr{Cvoid} = C_NULL
qwtwMWShowH::Ptr{Cvoid} = C_NULL
qwtEnableBroadcastH::Ptr{Cvoid} = C_NULL
qwtDisableBroadcastH::Ptr{Cvoid} = C_NULL
qwtSetPosH::Ptr{Cvoid} = C_NULL

qwtMglH::Ptr{Cvoid} = C_NULL
qwtMglLine::Ptr{Cvoid} = C_NULL
qwtMglMesh::Ptr{Cvoid} = C_NULL

qwtStartH::Ptr{Cvoid} = C_NULL
qwtStartDebugH::Ptr{Cvoid} = C_NULL
qwtStopH::Ptr{Cvoid} = C_NULL
started::Bool = false # true when attached to libqwtw and connected to qwproc

const _SAVED_ENV = Dict{String, Tuple{Bool, String}}()

udpPort::Int32 = Int32(0) # multicast UDP port number
smip::String = ""         # multicast group IPv4 address
cfg = Dict{Symbol, Any}() # settings info
pleaseStopUdp::Bool = false
udpSock::Union{Nothing, UDPSocket} = nothing
cbTaskH::Union{Nothing, Task} = nothing
hasUserCallback::Bool = false
const cbLock = ReentrantLock()
errorBreak::Bool = false  # throw error() when parameters are invalid

"""
	QCBInfo

information for the callback function
about the mouse click
"""
struct QCBInfo
	type::Int32     # callback type ('1' for simple mouse click.. something else in case 'external UDP message info')
	plotID::Int32   # ID of the plot window
	lineID::Int32   # ID of the closest line
	index::Int32    # closest point index
	xx::Int32       # x window coord
	yy::Int32       # y window coord

	# closest point info
	x::Float64      # X coord
	y::Float64      # Y coord
	z::Float64      # Z coord (probably zero, when 'type' == 1)
	time::Float64   # time info
	label::String   # label of the selected line
end
function QCBInfo()
	return QCBInfo(0, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0.0, "empty")
end
export QCBInfo

cbFunction = function(info::QCBInfo) # 'picker' callback user function
	return
end

"""
	QClipCallbackInfo

information about the 'clip' callback (when the user is pressing 'clip' button )
"""
struct QClipCallbackInfo
	t1::Float64      # time 1 (left)
	t2::Float64      # time 2 (right)
	clipGroup::Int32 # clip group (every plot has its group)
	havePos::Bool    # true if x y z are valid
	x1::Float64      # point corresponding to time1, if any
	y1::Float64
	z1::Float64
	x2::Float64      # point corresponding to time2, if any
	y2::Float64
	z2::Float64
end
function QClipCallbackInfo()
	return QClipCallbackInfo(0.0, 0.0, 0, false, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
end

export QClipCallbackInfo

clipCallbackFunction = function(info::QClipCallbackInfo) # 'clip' callback user function
	return
end

lastUdpPacket = zeros(UInt8, 92)
export lastUdpPacket # just for testing/debugging

"""
	onPickUdp(x::Vector{UInt8})

process picker UDP message (`PickerMessage` = 4-byte head + `CBPickerInfo` + 4-byte tail).
"""
function onPickUdp(x::Vector{UInt8})
	ii = QCBInfo()

	if qwtwDebugMode
		@info "onPickUdp starting!"
	end

	if length(x) < 88
		if qwtwDebugMode
			@warn "onPickUdp: packet too short ($(length(x)) bytes, expected >= 88)"
		end
		return
	end

	try
		time   = reinterpret(Float64, @view x[5:12])[1]
		iks    = reinterpret(Float64, @view x[13:20])[1]
		igrek  = reinterpret(Float64, @view x[21:28])[1]
		zet    = reinterpret(Float64, @view x[29:36])[1]

		index  = reinterpret(Int32, @view x[37:40])[1]
		xx     = reinterpret(Int32, @view x[41:44])[1]
		yy     = reinterpret(Int32, @view x[45:48])[1]
		plotID = reinterpret(Int32, @view x[49:52])[1]
		lineID = reinterpret(Int32, @view x[53:56])[1]
		type   = reinterpret(Int32, @view x[57:60])[1]
		_flag  = reinterpret(Int32, @view x[61:64])[1]

		# CBPickerInfo::label[24] starts at byte 65 (after 4-byte `flag`)
		label_end = min(88, length(x))
		eos = label_end + 1
		for k in 65:label_end
			if x[k] == 0x00
				eos = k
				break
			end
		end
		label = eos <= 65 ? "" : String(x[65:eos-1])

		if qwtwDebugMode
			@info "\ttype = $type; flag = $_flag; index = $index; label = $label"
		end

		ii = QCBInfo(type, plotID, lineID, index, xx, yy, iks, igrek, zet, time, label)
	catch ex
		if qwtwDebugMode
			bt = catch_backtrace()
			msg = sprint(showerror, ex, bt)
			@warn "cannot process picker message ($ex)\n$msg"
		end
		return
	end

	try
		if started && qwtwServiceH != C_NULL
			ccall(qwtwServiceH, Int32, (Int32,), 1)
		end
		try
			Base.invokelatest(cbFunction, ii)
		finally
			if started && qwtwServiceH != C_NULL
				ccall(qwtwServiceH, Int32, (Int32,), 2)
			end
		end
	catch ex
		bt = catch_backtrace()
		msg = sprint(showerror, ex, bt)
		@warn "onPickUdp: callback function failed ($ex)\n$msg"
	end

	return
end


"""
	onClipUdp(x::Vector{UInt8})

process clip UDP message (`ClipUdpMessage` = 80 bytes).
"""
function onClipUdp(x::Vector{UInt8})
	ii = QClipCallbackInfo()

	if qwtwDebugMode
		@info "onClipUdp"
	end

	if length(x) < 76
		if qwtwDebugMode
			@warn "onClipUdp: packet too short ($(length(x)) bytes, expected >= 76)"
		end
		return
	end

	try
		time1     = reinterpret(Float64, @view x[5:12])[1]
		time2     = reinterpret(Float64, @view x[13:20])[1]
		clipGroup = reinterpret(Int32, @view x[21:24])[1]
		havePos   = reinterpret(Int32, @view x[25:28])[1] != 0

		x1 = reinterpret(Float64, @view x[29:36])[1]
		y1 = reinterpret(Float64, @view x[37:44])[1]
		z1 = reinterpret(Float64, @view x[45:52])[1]
		x2 = reinterpret(Float64, @view x[53:60])[1]
		y2 = reinterpret(Float64, @view x[61:68])[1]
		z2 = reinterpret(Float64, @view x[69:76])[1]

		ii = QClipCallbackInfo(time1, time2, clipGroup, havePos, x1, y1, z1, x2, y2, z2)
	catch ex
		if qwtwDebugMode
			bt = catch_backtrace()
			msg = sprint(showerror, ex, bt)
			@warn "onClipUdp: cannot process 'clip' message ($ex)\n$msg"
		end
		return
	end

	if qwtwDebugMode
		@info "\ttime1 = $(ii.t1), time2 = $(ii.t2)"
	end

	try
		if started && qwtwServiceH != C_NULL
			ccall(qwtwServiceH, Int32, (Int32,), 1)
		end
		try
			Base.invokelatest(clipCallbackFunction, ii)
		finally
			if started && qwtwServiceH != C_NULL
				ccall(qwtwServiceH, Int32, (Int32,), 2)
			end
		end
	catch ex
		bt = catch_backtrace()
		msg = sprint(showerror, ex, bt)
		@warn "onClipUdp: callback function failed\n$msg"
	end

	return
end


"""
	udpDataReader(ready_ev::Union{Nothing, Base.Event} = nothing)

Multicast UDP reader task for picker and clip callbacks.
"""
function udpDataReader(ready_ev::Union{Nothing, Base.Event} = nothing)
	global udpSock, lastUdpPacket

	if udpPort == 0 || isempty(smip)
		ready_ev !== nothing && notify(ready_ev)
		@warn "udpDataReader: UDP port or multicast address not initialized (call qstart() first)"
		return
	end

	if qwtwDebugMode
		@info "starting udp data reader on port $udpPort; smip = $smip"
	end

	group = IPv4(smip)
	sock = UDPSocket()
	udpSock = sock
	joined_addrs = IPv4[]

	lock(cbLock)
	try
		bound = bind(sock, ip"0.0.0.0", udpPort; reuseaddr = true)
		if !bound
			ready_ev !== nothing && notify(ready_ev)
			@warn "udpDataReader: bind failed on port $udpPort"
			return
		end
		# Join multicast group across all local IPv4 interfaces (including 127.0.0.1 loopback)
		# so multicast works reliably even when VPN tunnels override the default route.
		for iface_addr in getipaddrs(IPv4; loopback = true)
			try
				join_multicast_group(sock, group, iface_addr)
				push!(joined_addrs, iface_addr)
			catch
			end
		end
		if isempty(joined_addrs)
			try
				join_multicast_group(sock, group)
			catch ex
				@warn "udpDataReader: join_multicast_group($group) failed ($ex)"
			end
		end
		ready_ev !== nothing && notify(ready_ev)

		while !pleaseStopUdp
			local x::Vector{UInt8}
			try
				x = recv(sock)
			catch ex
				if pleaseStopUdp || ex isa EOFError || ex isa Base.IOError
					break
				end
				rethrow()
			end

			lastUdpPacket = x
			pleaseStopUdp && break

			nx = length(x)
			if nx < 76
				if qwtwDebugMode
					@info "\tQWTWPlot udpDataReader() ignored short packet ($nx bytes)"
				end
				continue
			end

			if qwtwDebugMode
				@info "got $nx bytes; header = $(x[1:4])"
			end

			if x[1] == 0x50 # 'P'
				onPickUdp(x)
			elseif x[1] == 0x43 # 'C'
				onClipUdp(x)
			end
		end
	finally
		if isopen(sock)
			for iface_addr in joined_addrs
				try
					leave_multicast_group(sock, group, iface_addr)
				catch
				end
			end
		end
		isopen(sock) && close(sock)
		if udpSock === sock
			udpSock = nothing
		end
		unlock(cbLock)
		if qwtwDebugMode
			@info "stopped udp data reader on port $udpPort"
		end
	end
	return
end

"""
	saveEnv()

saves `PATH`, `QT_PLUGIN_PATH`, and `LD_LIBRARY_PATH` (preserving unset state).
"""
const _ENV_KEYS = ("PATH", "QT_PLUGIN_PATH", "LD_LIBRARY_PATH", "DYLD_FALLBACK_LIBRARY_PATH", "QWTW_PROC_PATH")

function saveEnv()
	empty!(_SAVED_ENV)
	for k in _ENV_KEYS
		if haskey(ENV, k)
			_SAVED_ENV[k] = (true, ENV[k])
		else
			_SAVED_ENV[k] = (false, "")
		end
	end
	return
end

"""
	restoreEnv()

restores env vars back to their exact state prior to `saveEnv()`.
"""
function restoreEnv()
	for (k, (existed, val)) in _SAVED_ENV
		if existed
			ENV[k] = val
		else
			delete!(ENV, k)
		end
	end
	return
end

"""
	printEnv()

simply print some of the env variables
"""
function printEnv()
	for k in _ENV_KEYS
		if haskey(ENV, k)
			@info "$k = $(ENV[k])"
		else
			@info "$k is not set"
		end
	end
	return
end

"""
	addEnvItem(item, var::String; debug = false)

prepend a non-empty entry to `ENV[var]`.
"""
function addEnvItem(item, var::String; debug = false)
	dv = Sys.iswindows() ? ";" : ":"

	item2Add = if item isa AbstractString
		String(item)
	elseif item isa Base.RefValue{String}
		item[]
	else
		string(item)
	end

	isempty(item2Add) && return

	if debug
		@info "adding [$item2Add] to [$var]"
	end

	if haskey(ENV, var) && !isempty(ENV[var])
		ENV[var] = item2Add * dv * ENV[var]
	else
		ENV[var] = item2Add
	end
	return
end

"""
	appendEnvItem(item, var::String; debug = false)

append a non-empty entry to `ENV[var]` (used on Windows so Julia's own bundled
MinGW DLLs stay ahead of JLL / MSYS2 runtime DLLs on `PATH`).
"""
function appendEnvItem(item, var::String; debug = false)
	dv = Sys.iswindows() ? ";" : ":"

	item2Add = if item isa AbstractString
		String(item)
	elseif item isa Base.RefValue{String}
		item[]
	else
		string(item)
	end

	isempty(item2Add) && return

	if debug
		@info "appending [$item2Add] to [$var]"
	end

	if haskey(ENV, var) && !isempty(ENV[var])
		ENV[var] = ENV[var] * dv * item2Add
	else
		ENV[var] = item2Add
	end
	return
end

const _QWTW_JLL_PKGID = Base.PkgId(Base.UUID("d5de49f9-40c9-5bd5-980e-f7e357ea5903"), "qwtw_jll")
const _QT6BASE_JLL_PKGID = Base.PkgId(Base.UUID("c0090381-4147-56d7-9ebc-da0b1113ec56"), "Qt6Base_jll")

function _platform_lib_ext()::String
	@static if Sys.iswindows()
		return ".dll"
	elseif Sys.isapple()
		return ".dylib"
	else
		return ".so"
	end
end

function _try_load_jll(pkgid::Base.PkgId)
	Base.locate_package(pkgid) === nothing && return nothing
	try
		return Base.require(pkgid)
	catch
		return nothing
	end
end

function _jll_library_path()::Union{Nothing, String}
	jll = _try_load_jll(_QWTW_JLL_PKGID)
	jll === nothing && return nothing
	if isdefined(jll, :is_available) && !Base.invokelatest(jll.is_available)
		return nothing
	end
	# Only use qwtw_jll if it is the Qt6 v3+ build (not legacy Qt5 v2.x which depended on Qt_jll)
	if isdefined(jll, :Qt_jll)
		return nothing
	end
	if isdefined(jll, :get_qwtw_path)
		p = String(Base.invokelatest(jll.get_qwtw_path))
		isfile(p) && return p
	end
	if isdefined(jll, :qwtw)
		p = String(getfield(jll, :qwtw))
		isfile(p) && return p
	end
	return nothing
end

function _configure_jll_runtime_env!(; debug::Bool = false)
	jll = _try_load_jll(_QWTW_JLL_PKGID)
	if jll !== nothing && !isdefined(jll, :Qt_jll) && isdefined(jll, :is_available) && Base.invokelatest(jll.is_available)
		if isdefined(jll, :PATH)
			appendEnvItem(getfield(jll, :PATH), "PATH"; debug = debug)
		end
		if isdefined(jll, :LIBPATH)
			@static if Sys.iswindows()
				appendEnvItem(getfield(jll, :LIBPATH), "PATH"; debug = debug)
			elseif Sys.isapple()
				addEnvItem(getfield(jll, :LIBPATH), "DYLD_FALLBACK_LIBRARY_PATH"; debug = debug)
			else
				addEnvItem(getfield(jll, :LIBPATH), "LD_LIBRARY_PATH"; debug = debug)
			end
		end
		if isdefined(jll, :qwproc_path) && !haskey(ENV, "QWTW_PROC_PATH")
			ENV["QWTW_PROC_PATH"] = String(getfield(jll, :qwproc_path))
		elseif isdefined(jll, :artifact_dir) && !haskey(ENV, "QWTW_PROC_PATH")
			exe = Sys.iswindows() ? "qwproc.exe" : "qwproc"
			cand = joinpath(String(getfield(jll, :artifact_dir)), "bin", exe)
			isfile(cand) && (ENV["QWTW_PROC_PATH"] = cand)
		end
	end

	qt6 = _try_load_jll(_QT6BASE_JLL_PKGID)
	if qt6 !== nothing && isdefined(qt6, :artifact_dir) && !haskey(ENV, "QT_PLUGIN_PATH")
		ad = String(getfield(qt6, :artifact_dir))
		for rel in ("plugins", joinpath("share", "qt6", "plugins"), joinpath("lib", "qt6", "plugins"))
			pdir = joinpath(ad, rel)
			if isdir(pdir)
				ENV["QT_PLUGIN_PATH"] = pdir
				debug && @info "QT_PLUGIN_PATH set from Qt6Base_jll: $pdir"
				break
			end
		end
	end
	return
end

function _platform_build_subdirs()::Vector{String}
	arch = lowercase(String(Sys.ARCH))
	@static if Sys.isapple()
		if arch in ("aarch64", "arm64")
			return ["macos-arm64", "macos-aarch64", "macos-x86_64"]
		else
			return ["macos-x86_64", "macos-arm64"]
		end
	elseif Sys.iswindows()
		return ["win32_build"]
	else
		if arch in ("aarch64", "arm64")
			return ["linux-aarch64", "linux-x86_64"]
		else
			return ["linux-x86_64", "linux-aarch64"]
		end
	end
end

function _resolve_library_name(libraryName::AbstractString)::String
	ext = _platform_lib_ext()
	default_names = Sys.iswindows() ? ["libqwtw.dll", "qwtw.dll"] : ["libqwtw" * ext]

	# 1. Explicit non-default libraryName passed by caller
	if libraryName != "libqwtw" && !isempty(libraryName)
		s = String(libraryName)
		if isfile(s) || endswith(lowercase(s), ext)
			return s
		elseif isdir(s)
			for nm in default_names
				cand = joinpath(s, nm)
				isfile(cand) && return cand
			end
		end
		return s * ext
	end

	# 2. QWTW_LIB_PATH environment variable
	env_path = strip(get(ENV, "QWTW_LIB_PATH", ""))
	if !isempty(env_path)
		if isfile(env_path)
			return env_path
		elseif isdir(env_path)
			for nm in default_names
				cand = joinpath(env_path, nm)
				isfile(cand) && return cand
			end
		elseif isfile(env_path * ext)
			return env_path * ext
		end
		return env_path
	end

	# 3. Optional path in ~/.qwtw/settings.json ("qwtw_lib_path")
	cfg_path = strip(string(get(cfg, :qwtw_lib_path, "")))
	if !isempty(cfg_path)
		if isfile(cfg_path)
			return cfg_path
		elseif isdir(cfg_path)
			for nm in default_names
				cand = joinpath(cfg_path, nm)
				isfile(cand) && return cand
			end
		elseif isfile(cfg_path * ext)
			return cfg_path * ext
		end
	end

	# 4. Local/workspace Qt6 build output directories (walking up from pwd())
	plat_dirs = _platform_build_subdirs()
	search_roots = String[pwd()]
	cur = pwd()
	for _ in 1:3
		parent = dirname(cur)
		parent == cur && break
		push!(search_roots, parent)
		cur = parent
	end
	push!(search_roots, joinpath(homedir(), ".qwtw"))

	# 5. Check sibling developer workspace in ~/Library/CloudStorage/*/space/qwtw or ~/space/qwtw
	for cand_base in (
		joinpath(homedir(), "space", "qwtw"),
		joinpath(homedir(), "qwtw"),
	)
		isdir(cand_base) && push!(search_roots, cand_base)
	end
	cs_dir = joinpath(homedir(), "Library", "CloudStorage")
	if isdir(cs_dir)
		for entry in readdir(cs_dir; join = true)
			cand_base = joinpath(entry, "space", "qwtw")
			isdir(cand_base) && push!(search_roots, cand_base)
		end
	end

	for root in search_roots
		for prefix in (root, joinpath(root, "qwtw"))
			for pd in plat_dirs
				for build_cfg in ("release", "debug")
					for lib_dir_name in ("lib", "lib_win32_build")
						dir = joinpath(prefix, lib_dir_name, pd, build_cfg)
						for nm in default_names
							cand = joinpath(dir, nm)
							isfile(cand) && return cand
						end
					end
				end
			end
			for nm in default_names
				cand = joinpath(prefix, "lib", "release", nm)
				isfile(cand) && return cand
			end
		end
	end

	# 6. Prebuilt Qt6 qwtw_jll v3+ artifact (when installed via Julia package manager)
	jll_lib = _jll_library_path()
	jll_lib !== nothing && return jll_lib

	# 7. Default shared library name for system dynamic linker
	return default_names[1]
end

function _load_settings!(; debug::Bool = false)
	global udpPort, smip, cfg
	settingsFileName = joinpath(homedir(), ".qwtw", "settings.json")
	if isfile(settingsFileName)
		try
			parsed = JSON3.read(read(settingsFileName, String))
			empty!(cfg)
			for (k, v) in pairs(parsed)
				cfg[Symbol(k)] = v
			end
			if haskey(cfg, :udp_client_port)
				raw_port = cfg[:udp_client_port]
				udpPort = raw_port isa Integer ? Int32(raw_port) : parse(Int32, string(raw_port))
			end
			if haskey(cfg, :smip) && !isempty(string(cfg[:smip]))
				smip = string(cfg[:smip])
			end
			if debug
				@info "loaded settings: udpPort = $udpPort, smip = $smip from $settingsFileName"
			end
		catch ex
			udpPort = Int32(0)
			if debug
				@warn "error while reading settings file $settingsFileName ($ex)"
			end
		end
	elseif debug
		@info "settings file $settingsFileName not found; using defaults"
	end

	if udpPort == 0
		udpPort = Int32(49561)
		debug && @info "using default udpPort = $udpPort"
	end
	if isempty(smip)
		smip = "239.255.0.1"
		debug && @info "using default smip = $smip"
	end
	return
end

"""
	qstart(; debug = false, qwtw_test = false, libraryName = "libqwtw", marbleDataPath = "", marblePluginPath = "", skipMarble = false)::Int32

starts the `qwtw` C library and connects to (or spawns) the `qwproc` Qt6 plot server.
Call this before any plotting functions.

* `debug`: enable verbose debug logging in both `QWTWPlot` and `libqwtw`/`qwproc`.
* `qwtw_test`: kept for backward compatibility (avoids modifying environment variables).
* `libraryName`: path or name of `libqwtw` (also configurable via `ENV["QWTW_LIB_PATH"]` or `"qwtw_lib_path"` in `~/.qwtw/settings.json`).
* `marbleDataPath` / `marblePluginPath` / `skipMarble`: accepted as no-ops for backward compatibility (maps are now built in natively via Qt6 + OpenStreetMap).

Returns `0` on success.
"""
function qstart(; debug = false, qwtw_test = false, libraryName = "libqwtw", marbleDataPath = "", marblePluginPath = "", skipMarble = false)::Int32
	global qwtwDebugMode = debug
	global qwtwLibHandle, qwtwFigureH, qwtwSpectrogramTestH, qwtwSetSpectrogramInfoH, qwtwSetSpectrogramInfoH2
	global qwtwMapViewH, qwtwsetimpstatusH, qwtwCLearH, qwtwPlotH, qwtwServiceH
	global qwtwPlot2H, qwtwXlabelH, qwtwYlabelH, qwtwTitleH, qwtwVersionH, qwtwMWShowH, qwtwRemoveLineH, qwtSavePng
	global qwtEnableBroadcastH, qwtDisableBroadcastH, qwtwChangeLineH, qwtwClipGroupH, qwtSetPosH
	global qwtStartH, qwtStartDebugH, qwtStopH, started
	global qwtMglH, qwtMglLine, qwtMglMesh
	global pleaseStopUdp

	if started && qwtwLibHandle != C_NULL && qwtStartH != C_NULL
		# Call qtstart/qtstart_debug even when already started so libqwtw verifies
		# its local socket to qwproc is still alive (and respawns qwproc if it exited).
		rc = debug ? ccall(qwtStartDebugH, Int32, (Int32,), Int32(10)) :
		             ccall(qwtStartH, Int32, ())
		if rc == 0
			debug && @info "qwtw already started and connected"
			return Int32(0)
		end
		debug && @warn "qwtw connection lost (rc = $rc); reinitializing..."
		qstop()
	end

	_load_settings!(; debug = debug)
	pleaseStopUdp = false

	qwtw_libName = _resolve_library_name(libraryName)

	saveEnv()
	if !qwtw_test
		_configure_jll_runtime_env!(; debug = debug)
		if isfile(qwtw_libName) && Sys.iswindows()
			appendEnvItem(dirname(abspath(qwtw_libName)), "PATH"; debug = debug)
		end
	end

	if debug
		@info "loading $qwtw_libName"
	end

	if qwtwLibHandle == C_NULL
		try
			qwtwLibHandle = Libdl.dlopen(qwtw_libName)
		catch ex
			debug && printEnv()
			restoreEnv()
			@error "dlopen for $qwtw_libName failed ($ex). Set ENV[\"QWTW_LIB_PATH\"] or pass libraryName=\"/path/to/libqwtw\"."
			rethrow()
		end
	end

	if debug
		@info "library opened from $(Libdl.dlpath(qwtwLibHandle))"
	end

	qwtwFigureH          = Libdl.dlsym(qwtwLibHandle, :qwtfigure)
	qwtwSpectrogramTestH = _dlsym_opt(qwtwLibHandle, :qwtspectrogram)
	qwtwSetSpectrogramInfoH  = _dlsym_opt(qwtwLibHandle, :spectrogram_info)
	qwtwSetSpectrogramInfoH2 = _dlsym_opt(qwtwLibHandle, :spectrogram_info2)
	if qwtwSpectrogramTestH == C_NULL && debug
		@info "spectrogram functions not present in this libqwtw build"
	end

	qwtwMapViewH = _dlsym_opt(qwtwLibHandle, :qwtmap)
	if qwtwMapViewH == C_NULL && debug
		@info "map support (qwtmap) not present in this libqwtw build"
	end

	qwtwsetimpstatusH = Libdl.dlsym(qwtwLibHandle, :qwtsetimpstatus)
	qwtwCLearH        = Libdl.dlsym(qwtwLibHandle, :qwtclear)
	qwtwPlotH         = Libdl.dlsym(qwtwLibHandle, :qwtplot)
	qwtwPlot2H        = Libdl.dlsym(qwtwLibHandle, :qwtplot2)
	qwtwXlabelH       = Libdl.dlsym(qwtwLibHandle, :qwtxlabel)
	qwtwYlabelH       = Libdl.dlsym(qwtwLibHandle, :qwtylabel)
	qwtwTitleH        = Libdl.dlsym(qwtwLibHandle, :qwttitle)
	qwtwVersionH      = Libdl.dlsym(qwtwLibHandle, :qwtversion)
	qwtwMWShowH       = Libdl.dlsym(qwtwLibHandle, :qwtshowmw)
	qwtStartH         = Libdl.dlsym(qwtwLibHandle, :qtstart)
	qwtStartDebugH    = Libdl.dlsym(qwtwLibHandle, :qtstart_debug)
	qwtStopH          = Libdl.dlsym(qwtwLibHandle, :qwtclose)
	qwtwRemoveLineH   = Libdl.dlsym(qwtwLibHandle, :qwtremove)
	qwtwChangeLineH   = Libdl.dlsym(qwtwLibHandle, :qwtchange)
	qwtwServiceH      = Libdl.dlsym(qwtwLibHandle, :qwtservice)
	qwtSavePng        = Libdl.dlsym(qwtwLibHandle, :qwtsave_png)
	qwtSetPosH        = _dlsym_opt(qwtwLibHandle, :qwtsetpos)
	qwtwClipGroupH    = _dlsym_opt(qwtwLibHandle, :qwtclipgroup)

	qwtEnableBroadcastH  = _dlsym_opt(qwtwLibHandle, :qwtEnableCoordBroadcast)
	qwtDisableBroadcastH = _dlsym_opt(qwtwLibHandle, :qwtDisableCoordBroadcast)
	if qwtEnableBroadcastH == C_NULL && debug
		@info "UDP broadcast functions (WITH_UDP_SYNC) not enabled in this libqwtw build"
	end

	qwtMglH    = _dlsym_opt(qwtwLibHandle, :qwtmgl)
	qwtMglLine = _dlsym_opt(qwtwLibHandle, :qwtmgl_line)
	qwtMglMesh = _dlsym_opt(qwtwLibHandle, :qwtmgl_mesh)
	if qwtMglH == C_NULL && debug
		@info "3D MathGL features (USE_MGL) not enabled in this libqwtw build"
	end

	test::Int32 = Int32(1)
	try
		if debug
			test = ccall(qwtStartDebugH, Int32, (Int32,), Int32(10))
		else
			test = ccall(qwtStartH, Int32, ())
		end
	catch ex
		debug && printEnv()
		Libdl.dlclose(qwtwLibHandle)
		qwtwLibHandle = C_NULL
		restoreEnv()
		@error "cannot start qwtw ($ex)"
		rethrow()
	end

	restoreEnv()

	if test == 0
		started = true
		if debug
			@info "qwtw version: $(qversion())"
		end
		if hasUserCallback
			startUdpThread()
		end
	else
		Libdl.dlclose(qwtwLibHandle)
		qwtwLibHandle = C_NULL
		@error "library was not started (return code $test)"
		debug && printEnv()
	end

	return test
end

"""
	qstop()::Int32

close everything and detach from `qwtw` library.
Sends the exit command to `qwproc`, stops the multicast UDP listener task, and closes `libqwtw`.
Returns `0` on clean stop.
"""
function qstop()::Int32
	global qwtwLibHandle, qwtStopH, started

	stopUdpThread()

	if qwtwLibHandle != C_NULL
		if qwtStopH != C_NULL && started
			ccall(qwtStopH, Cvoid, ())
		end
		# On Windows (MinGW winpthreads / static libstdc++), FreeLibrary can
		# deadlock under the OS Loader Lock when C++ threads were created in the DLL.
		# Keep the handle open for reuse on Windows, matching python/qwtwc.py.
		@static if !Sys.iswindows()
			Libdl.dlclose(qwtwLibHandle)
			qwtwLibHandle = C_NULL
			qwtStopH = C_NULL
		end
		started = false
		return Int32(0)
	else
		@info "not started (was qstart() called?)"
		started = false
		return Int32(-1)
	end
end

"""
	qErrorBreak(b::Bool)

if `b == true`, throw `error()` on invalid input parameters.
"""
function qErrorBreak(b::Bool)
	global errorBreak = b
	return
end
export qErrorBreak

"""
	qversion()::String

return native `libqwtw` version string.
"""
function qversion()::String
	if !started || qwtwLibHandle == C_NULL || qwtwVersionH == C_NULL
		return "not started yet"
	end
	v = zeros(UInt8, 1024)
	GC.@preserve v begin
		bs = ccall(qwtwVersionH, Int32, (Ptr{UInt8}, Int32), pointer(v), Int32(length(v)))
		if bs <= 0
			return ""
		end
		nbytes = min(Int(bs), length(v))
		# Trim trailing NUL if included in returned byte count
		while nbytes > 0 && v[nbytes] == 0x00
			nbytes -= 1
		end
		return unsafe_string(pointer(v), nbytes)
	end
end

function traceit(msg)
	bt = backtrace()
	s = sprint(io -> Base.show_backtrace(io, bt))
	println("debug: $s: $msg")
	return
end

"""
	qfigure(n::Integer = 0; xAxisType = :aLinear, yAxisType = :aLinear)::Int32

create a new plot window, OR make plot with ID `n` active.
`xAxisType` and `yAxisType` can be `:aLinear` (default) or `:aLog` (logarithmic).

Returns ID of the created/activated plot.
"""
function qfigure(n::Integer = 0; xAxisType = :aLinear, yAxisType = :aLinear)::Int32
	if !started || qwtwFigureH == C_NULL
		@info "not started (was qstart() called?)"
		return Int32(0)
	end
	flags::UInt32 = UInt32(0)
	xAxisType == :aLog && (flags |= UInt32(1))
	yAxisType == :aLog && (flags |= UInt32(2))
	return ccall(qwtwFigureH, Int32, (Int32, UInt32), Int32(n), flags)
end

function qspectrogram(n::Integer = 0; xAxisType = :aLinear, yAxisType = :aLinear)::Int32
	if !started
		@info "not started (was qstart() called?)"
		return Int32(0)
	end
	if qwtwSpectrogramTestH == C_NULL
		@info "spectrograms are not supported by this libqwtw build"
		return Int32(0)
	end
	flags::UInt32 = UInt32(0)
	xAxisType == :aLog && (flags |= UInt32(1))
	yAxisType == :aLog && (flags |= UInt32(2))
	return ccall(qwtwSpectrogramTestH, Int32, (Int32, UInt32), Int32(n), flags)
end
export qspectrogram

"""
	qspectrogram_info(ymin::Real, ymax::Real, xmin::Real, xmax::Real, z::AbstractMatrix{<:Real}; p::AbstractArray{<:Real, 3} = zeros(1, 1, 1), t::AbstractMatrix{<:Real} = [0.0 0.0])::Int32

parameters:
* `xmin`, `xmax`, `ymin`, `ymax`: coordinate bounds
* `z`: spectrogram values, `[ny, nx]` matrix
* `p`: optional `[3, ny, nx]` array of 3D coordinates per cell
* `t`: optional `[ny, nx]` matrix of timestamps per cell
"""
function qspectrogram_info(ymin::Real, ymax::Real, xmin::Real, xmax::Real, z::AbstractMatrix{<:Real};
		p::AbstractArray{<:Real, 3} = zeros(1, 1, 1), t::AbstractMatrix{<:Real} = [0.0 0.0])::Int32
	if !started || qwtwSetSpectrogramInfoH2 == C_NULL
		@info "not started (was qstart() called?)"
		return Int32(0)
	end
	ny, nx = size(z)

	has_t = length(t) > 2
	tt_buf = Matrix{Float64}(undef, 0, 0)
	if has_t
		nty, ntx = size(t)
		if ntx != nx || nty != ny
			@warn "qspectrogram_info: wrong t size ([$nty, $ntx]); expected ([$ny, $nx])"
			return Int32(1)
		end
		tt_buf = permutedims(Float64.(t), (2, 1))
	end

	has_p = length(p) > 1
	pp_buf = Array{Float64, 3}(undef, 0, 0, 0)
	if has_p
		n1, n2, n3 = size(p)
		if n1 != 3 || n2 != ny || n3 != nx
			@warn "qspectrogram_info: wrong p size ([$n1, $n2, $n3]); expected ([3, $ny, $nx])"
			return Int32(2)
		end
		pp_buf = permutedims(Float64.(p), (1, 3, 2))
	end

	zz_buf = permutedims(Float64.(z), (2, 1))

	GC.@preserve zz_buf pp_buf tt_buf begin
		p_ptr = has_p ? pointer(pp_buf) : Ptr{Float64}(C_NULL)
		t_ptr = has_t ? pointer(tt_buf) : Ptr{Float64}(C_NULL)
		return ccall(qwtwSetSpectrogramInfoH2, Int32,
			(Int32, Int32, Float64, Float64, Float64, Float64, Ptr{Float64}, Ptr{Float64}, Ptr{Float64}),
			Int32(ny), Int32(nx), Float64(ymin), Float64(ymax), Float64(xmin), Float64(xmax),
			pointer(zz_buf), p_ptr, t_ptr)
	end
end
export qspectrogram_info

"""
	qclipgrp(gr::Integer)

set current 'clip group'. All subsequent plots will belong to group `gr`.
"""
function qclipgrp(gr::Integer)
	if (qwtwLibHandle == C_NULL) || (!started)
		@info "not started (was qstart() called?)"
		return
	end
	if qwtwClipGroupH == C_NULL
		@info "clip groups are not supported, sorry"
		return
	end
	ccall(qwtwClipGroupH, Cvoid, (Int32,), Int32(gr))
	return
end
export qclipgrp

"""
	qremove(id::Integer)

remove a line from a plot by line ID.
"""
function qremove(id::Integer)
	if !started || qwtwRemoveLineH == C_NULL
		@info "not started (was qstart() called?)"
		return
	end
	ccall(qwtwRemoveLineH, Cvoid, (Int32,), Int32(id))
	return
end
export qremove

"""
	qfmap(n::Integer = 0)::Int32

create a new OpenStreetMap slippy-map plot window (longitude in degrees on X, latitude in degrees on Y).
"""
function qfmap(n::Integer = 0)::Int32
	if (qwtwLibHandle == C_NULL) || (!started)
		@info "not started (was qstart() called?)"
		return Int32(0)
	end
	if qwtwMapViewH == C_NULL
		@info "map view not supported by this libqwtw build"
		return Int32(0)
	end
	return ccall(qwtwMapViewH, Int32, (Int32,), Int32(n))
end

"""
	qmgl(n::Integer = 0)::Int32

create a new plot window to draw 3D lines / surfaces (MathGL).
"""
function qmgl(n::Integer = 0)::Int32
	if (qwtwLibHandle == C_NULL) || (!started)
		@info "not started (was qstart() called?)"
		return Int32(0)
	end
	if qwtMglH == C_NULL
		@info "3D not supported (requires -DUSE_MGL=ON build)"
		return Int32(0)
	end
	return ccall(qwtMglH, Int32, (Int32,), Int32(n))
end
export qmgl

"""
	qmgline(x::AbstractVector{<:Real}, y::AbstractVector{<:Real}, z::AbstractVector{<:Real}, style::AbstractString = "-sb"; name::AbstractString = "")

draw a 3D line.
"""
function qmgline(x::AbstractVector{<:Real}, y::AbstractVector{<:Real}, z::AbstractVector{<:Real}, style::AbstractString = "-sb"; name::AbstractString = "")
	if (qwtwLibHandle == C_NULL) || (!started)
		@info "not started (was qstart() called?)"
		return
	end
	if qwtMglLine == C_NULL
		@info "3D not supported (requires -DUSE_MGL=ON build)"
		return
	end
	if isempty(x)
		@info "QWTWPlot::qmgline empty X value"
		return
	end
	n = length(x)
	@assert length(y) == n "x and y lengths must match"
	@assert length(z) == n "x and z lengths must match"

	xv = _f64vec(x)
	yv = _f64vec(y)
	zv = _f64vec(z)
	ccall(qwtMglLine, Cvoid, (Int32, Ptr{Float64}, Ptr{Float64}, Ptr{Float64}, Cstring, Cstring),
		Int32(n), xv, yv, zv, String(name), String(style))
	return
end
export qmgline

"""
	qmglmesh(data::AbstractMatrix{<:Real}, xMin = -10.0, xMax = 10.0, yMin = -10.0, yMax = 10.0, style::AbstractString = ""; name::AbstractString = "", type = 0)

draw a 3D mesh (`type = 0`) or surface (`type = 1`).
"""
function qmglmesh(data::AbstractMatrix{<:Real}, xMin = -10.0, xMax = 10.0, yMin = -10.0, yMax = 10.0, style::AbstractString = ""; name::AbstractString = "", type = 0)
	if (qwtwLibHandle == C_NULL) || (!started)
		@info "not started (was qstart() called?)"
		return
	end
	if qwtMglMesh == C_NULL
		@info "3D not supported (requires -DUSE_MGL=ON build)"
		return
	end
	xSize, ySize = size(data)
	if xSize < 1 || ySize < 1
		@info "QWTWPlot::qmglmesh empty data"
		return
	end
	mat = data isa Matrix{Float64} ? data : Matrix{Float64}(data)
	ccall(qwtMglMesh, Cvoid,
		(Int32, Int32, Float64, Float64, Float64, Float64, Ptr{Float64}, Cstring, Cstring, Int32),
		Int32(xSize), Int32(ySize),
		Float64(xMin), Float64(xMax), Float64(yMin), Float64(yMax),
		mat, String(name), String(style), Int32(type))
	return
end
export qmglmesh

"""
	qimportant(i::Integer)

set importance flag (`0` = not important / excluded from clipping bounds, `1` = important) for subsequent lines.
"""
function qimportant(i::Integer)
	if (qwtwLibHandle == C_NULL) || (!started)
		@info "not started (was qstart() called?)"
		return
	end
	ccall(qwtwsetimpstatusH, Cvoid, (Int32,), Int32(i))
	return
end

"""
	qclear()

close all plots.
"""
function qclear()
	if (qwtwLibHandle == C_NULL) || (!started)
		@info "not started (was qstart() called?)"
		return
	end
	ccall(qwtwCLearH, Cvoid, ())
	return
end

"""
	qsavepng(fileName::AbstractString, plotId::Integer = 0)::Int32

save a plot to a PNG file.
"""
function qsavepng(fileName::AbstractString, plotId::Integer = 0)::Int32
	if (qwtwLibHandle == C_NULL) || (!started) || (qwtSavePng == C_NULL)
		@info "not started (was qstart() called?)"
		return Int32(150)
	end
	result = ccall(qwtSavePng, Int32, (Int32, Cstring), Int32(plotId), String(fileName))
	if qwtwDebugMode
		@info "QWTWPlot::qsavepng(): result = $result"
	end
	return result
end
export qsavepng

"""
	qsetpos(plotID::Integer, set::Bool = false, x = 0, y = 0, w = 0, h = 0)

get/set window coords and size.
Returns `(result, x, y, w, h)`.
"""
function qsetpos(plotID::Integer, set::Bool = false, x = 0, y = 0, w = 0, h = 0)
	if (qwtwLibHandle == C_NULL) || (!started) || (qwtSetPosH == C_NULL)
		@info "qsetpos(): qwtw not started (was qstart() called?)"
		return Int32(150), Int32(0), Int32(0), Int32(0), Int32(0)
	end
	xx = Ref{Cint}(x)
	yy = Ref{Cint}(y)
	ww = Ref{Cint}(w)
	hh = Ref{Cint}(h)
	s = set ? Int32(1) : Int32(0)

	result = ccall(qwtSetPosH, Int32, (Int32, Ptr{Int32}, Ptr{Int32}, Ptr{Int32}, Ptr{Int32}, Int32),
		Int32(plotID), xx, yy, ww, hh, s)
	return result, xx[], yy[], ww[], hh[]
end
export qsetpos

"""
	qsmw()

open/show "main control window".
"""
function qsmw()
	if (qwtwLibHandle == C_NULL) || (!started)
		@info "not started (was qstart() called?)"
		return
	end
	ccall(qwtwMWShowH, Cvoid, ())
	return
end

"""
	qplot(x::AbstractVector{<:Real}, y::AbstractVector{<:Real}, name::AbstractString = "", style::AbstractString = "-b", lineWidth = 1, symSize = 1)::Int32

plot 2D lines/symbols on the active figure. Returns line ID (`>= 0` on success, `< 0` on error).
"""
function qplot(x::AbstractVector{<:Real}, y::AbstractVector{<:Real}, name::AbstractString = "", style::AbstractString = "-b", lineWidth = 1, symSize = 1)::Int32
	if (qwtwLibHandle == C_NULL) || (!started)
		@info "not started (was qstart() called?)"
		return Int32(-88)
	end

	n = length(x)
	n1 = length(y)
	if (n < 1) || (n != n1)
		mm = @sprintf "QWTWPlot qplot: bad input array length x[%d], y[%d]; name = %s" n n1 name
		errorBreak ? error(mm) : println(mm)
		return Int32(-89)
	end

	xv = _f64vec(x)
	yv = _f64vec(y)
	ww = Int32(lineWidth)
	s = Int32(symSize)

	if qwtwDebugMode
		@info "qplot: ($name) ($style) n=$n"
	end

	try
		return ccall(qwtwPlotH, Int32, (Ptr{Float64}, Ptr{Float64}, Int32, Cstring, Cstring, Int32, Int32),
			xv, yv, Int32(n), String(name), String(style), ww, s)
	catch ex
		@warn "qplot error: n = $n; name = $name; style = $style ($ex)"
		traceit("qplot error")
		return Int32(-42)
	end
end

"""
	qplot1(x::AbstractVector{<:Real}, y::AbstractVector{<:Real}, name::AbstractString, style::AbstractString, symSize)::Int32

plot lines with `lineWidth == 1`. Returns line ID (`>= 0` on success, `< 0` on error).
"""
function qplot1(x::AbstractVector{<:Real}, y::AbstractVector{<:Real}, name::AbstractString, style::AbstractString, symSize)::Int32
	if (qwtwLibHandle == C_NULL) || (!started)
		@info "not started (was qstart() called?)"
		return Int32(-88)
	end

	n = length(x)
	n1 = length(y)
	if (n < 1) || (n1 < 1) || (n != n1)
		mm = @sprintf "QWTWPlot qplot1: bad input array length (x:%d; y:%d) name=%s style=%s symSize=%d\n" n n1 name style symSize
		errorBreak ? error(mm) : println(mm)
		return Int32(-89)
	end

	xv = _f64vec(x)
	yv = _f64vec(y)
	ww = Int32(symSize)

	if qwtwDebugMode
		@info "qplot1: ($name) ($style) n=$n"
	end

	return ccall(qwtwPlotH, Int32, (Ptr{Float64}, Ptr{Float64}, Int32, Cstring, Cstring, Int32, Int32),
		xv, yv, Int32(n), String(name), String(style), Int32(1), ww)
end

"""
	qchange(id::Integer, x::AbstractVector{<:Real}, y::AbstractVector{<:Real}, t::AbstractVector{<:Real} = Float64[])::Int32

replace data of an existing line in place.
"""
function qchange(id::Integer, x::AbstractVector{<:Real}, y::AbstractVector{<:Real}, t::AbstractVector{<:Real} = Float64[])::Int32
	if !started || qwtwChangeLineH == C_NULL
		@info "not started (was qstart() called?)"
		return Int32(-88)
	end
	n = length(x)
	n1 = length(y)
	n2 = length(t)

	if (n < 1) || (n != n1)
		mm = @sprintf "QWTWPlot qchange: bad input array length (x:%d; y:%d)\n" n n1
		errorBreak ? error(mm) : println(mm)
		return Int32(-89)
	end

	if n2 > 0 && n2 != n
		mm = @sprintf "qchange: wrong _t_ array length (t: %d; n:%d)" n2 n
		errorBreak ? error(mm) : println(mm)
		return Int32(84)
	end

	xv = _f64vec(x)
	yv = _f64vec(y)
	tv = n2 > 0 ? _f64vec(t) : Float64[]

	GC.@preserve xv yv tv begin
		zz_ptr = Ptr{Float64}(C_NULL)
		tt_ptr = n2 > 0 ? pointer(tv) : Ptr{Float64}(C_NULL)
		return ccall(qwtwChangeLineH, Int32,
			(Int32, Ptr{Float64}, Ptr{Float64}, Ptr{Float64}, Ptr{Float64}, Int32),
			Int32(id), pointer(xv), pointer(yv), zz_ptr, tt_ptr, Int32(n))
	end
end
export qchange

"""
	qEnableCoordBroadcast(x::AbstractVector{<:Real}, y::AbstractVector{<:Real}, z::AbstractVector{<:Real}, time::AbstractVector{<:Real})

Enable multicast UDP marker coordinate synchronization.
"""
function qEnableCoordBroadcast(x::AbstractVector{<:Real}, y::AbstractVector{<:Real}, z::AbstractVector{<:Real}, time::AbstractVector{<:Real})
	if (qwtwLibHandle == C_NULL) || (!started)
		@info "not started (was qstart() called?)"
		return
	end
	if qwtEnableBroadcastH == C_NULL
		@warn "UDP coordinate broadcast not available (libqwtw built without -DWITH_UDP_SYNC=ON)"
		return
	end

	n = length(time)
	@assert length(x) == n "x and time lengths must match"
	@assert length(y) == n "y and time lengths must match"
	@assert length(z) == n "z and time lengths must match"

	if n < 1
		@info "QWTWPlot qEnableCoordBroadcast: bad input array length ($n)"
		return
	end

	xv = _f64vec(x)
	yv = _f64vec(y)
	zv = _f64vec(z)
	tv = _f64vec(time)

	ccall(qwtEnableBroadcastH, Cvoid, (Ptr{Float64}, Ptr{Float64}, Ptr{Float64}, Ptr{Float64}, Int32),
		xv, yv, zv, tv, Int32(n))
	return
end

"""
	qDisableCoordBroadcast()

stop UDP coordinate broadcast server and client.
"""
function qDisableCoordBroadcast()
	if (qwtwLibHandle == C_NULL) || (!started) || (qwtDisableBroadcastH == C_NULL)
		@info "not started (was qstart() called?)"
		return
	end
	ccall(qwtDisableBroadcastH, Cvoid, ())
	return
end

"""
	qplot2(x::AbstractVector{<:Real}, y::AbstractVector{<:Real}, time::AbstractVector{<:Real}, name::AbstractString, style::AbstractString, lineWidth = 1, symSize = 1)::Int32

plot 2D series with an explicit timestamp vector `time` for synchronized markers/clipping.
"""
function qplot2(x::AbstractVector{<:Real}, y::AbstractVector{<:Real}, time::AbstractVector{<:Real}, name::AbstractString, style::AbstractString, lineWidth = 1, symSize = 1)::Int32
	if (qwtwLibHandle == C_NULL) || (!started)
		@info "not started (was qstart() called?)"
		return Int32(-88)
	end
	n = length(x)
	n1 = length(y)
	n2 = length(time)
	if (n < 1) || (n != n1) || (n != n2)
		mm = @sprintf "QWTWPlot qplot2 error: bad array length; x:%d; y:%d; time:%d; name = %s" n n1 n2 name
		errorBreak ? error(mm) : println(mm)
		return Int32(-76)
	end

	xv = _f64vec(x)
	yv = _f64vec(y)
	tv = _f64vec(time)
	ww = Int32(lineWidth)
	s = Int32(symSize)

	if qwtwDebugMode
		@info "qplot2: ($name) ($style) n=$n"
	end

	try
		return ccall(qwtwPlot2H, Int32, (Ptr{Float64}, Ptr{Float64}, Int32, Cstring, Cstring, Int32, Int32, Ptr{Float64}),
			xv, yv, Int32(n), String(name), String(style), ww, s, tv)
	catch ex
		@warn "qplot2 ERROR ($ex)"
		rethrow()
	end
end

"""
	qxlabel(s::AbstractString)

put a label on the bottom horizontal axis.
"""
function qxlabel(s::AbstractString)
	if (qwtwLibHandle == C_NULL) || (!started)
		@info "not started (was qstart() called?)"
		return
	end
	ccall(qwtwXlabelH, Cvoid, (Cstring,), String(s))
	return
end

"""
	qylabel(s::AbstractString)

put a label on the left vertical axis.
"""
function qylabel(s::AbstractString)
	if (qwtwLibHandle == C_NULL) || (!started)
		@info "not started (was qstart() called?)"
		return
	end
	ccall(qwtwYlabelH, Cvoid, (Cstring,), String(s))
	return
end

"""
	qtitle(s::AbstractString)

put a title on the current plot.
"""
function qtitle(s::AbstractString)
	if (qwtwLibHandle == C_NULL) || (!started)
		@info "not started (was qstart() called?)"
		return
	end
	ccall(qwtwTitleH, Cvoid, (Cstring,), String(s))
	return
end

"""
	qStarted()::Bool

return `true` if `qstart()` has succeeded and `qstop()` has not been called.
"""
function qStarted()::Bool
	return started
end

export qfigure, qfmap, qplot, qplot1, qplot2, qxlabel, qylabel, qtitle
export qimportant, qclear, qstart, qstop, qversion, qsmw
export traceit
export qEnableCoordBroadcast, qDisableCoordBroadcast
export qStarted

"""
	stopUdpThread()

stops the multicast UDP listener task cleanly by closing its socket.
"""
function stopUdpThread()
	global pleaseStopUdp, cbTaskH, udpSock

	pleaseStopUdp = true
	sock = udpSock
	if sock !== nothing && isopen(sock)
		try
			close(sock)
		catch
		end
	end

	t = cbTaskH
	if t !== nothing && istaskstarted(t) && !istaskdone(t)
		try
			wait(t)
		catch
		end
	end
	cbTaskH = nothing
	return
end

"""
	startUdpThread()

starts the multicast UDP listener task if not already running.
If `qstart()` has not been called yet (`udpPort == 0`), loads settings first so the listener can bind immediately or on `qstart()`.
"""
function startUdpThread()
	global pleaseStopUdp, cbTaskH

	t = cbTaskH
	if t !== nothing && istaskstarted(t) && !istaskdone(t)
		return
	end

	if udpPort == 0 || isempty(smip)
		_load_settings!(; debug = qwtwDebugMode)
	end

	pleaseStopUdp = false
	ready_ev = Base.Event()
	task = @task udpDataReader(ready_ev)
	task.sticky = false
	cbTaskH = task
	schedule(task)
	wait(ready_ev)
	return
end
export startUdpThread, stopUdpThread

"""
	qsetCallback(cb)

register a picker callback `cb(info::QCBInfo)` invoked on marker clicks via multicast UDP.
"""
function qsetCallback(cb)
	global cbFunction = cb
	global hasUserCallback = true
	if qwtwDebugMode
		@info "setting up cbFunction"
	end
	startUdpThread()
	return
end
export qsetCallback

"""
	qsetClipCallback(cb)

register a clip callback `cb(info::QClipCallbackInfo)` invoked when the clip button is pressed via multicast UDP.
"""
function qsetClipCallback(cb)
	global clipCallbackFunction = cb
	global hasUserCallback = true
	if qwtwDebugMode
		@info "setting up clipCallbackFunction"
	end
	startUdpThread()
	return
end
export qsetClipCallback

"""
	setDebugMode(m::Bool)

enable or disable debug logging.
"""
function setDebugMode(m::Bool)
	global qwtwDebugMode = m
	return
end
export setDebugMode

end # module
