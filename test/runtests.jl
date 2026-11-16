using QWTWPlot
using Sockets
using Test

function _make_picker_packet(;
	time::Float64 = 1.25,
	x::Float64 = 2.5,
	y::Float64 = -3.75,
	z::Float64 = 4.0,
	index::Int32 = Int32(7),
	xx::Int32 = Int32(120),
	yy::Int32 = Int32(240),
	plotID::Int32 = Int32(500),
	lineID::Int32 = Int32(3),
	type::Int32 = Int32(1),
	flag::Int32 = Int32(3),
	label::String = "sin_wave",
)::Vector{UInt8}
	io = IOBuffer()
	write(io, b"PPPP")
	write(io, time, x, y, z)
	write(io, index, xx, yy, plotID, lineID, type, flag)
	lbl_bytes = zeros(UInt8, 24)
	raw = codeunits(label)
	copyto!(lbl_bytes, 1, raw, 1, min(length(raw), 23))
	write(io, lbl_bytes)
	write(io, b"TTTT")
	return take!(io)
end

function _make_clip_packet(;
	t1::Float64 = 1.0,
	t2::Float64 = 5.5,
	clipGroup::Int32 = Int32(2),
	havePos::Int32 = Int32(1),
	pos1::NTuple{3, Float64} = (1.0, 2.0, 3.0),
	pos2::NTuple{3, Float64} = (4.0, 5.0, 6.0),
)::Vector{UInt8}
	io = IOBuffer()
	write(io, b"CCCC")
	write(io, t1, t2, clipGroup, havePos)
	write(io, pos1[1], pos1[2], pos1[3])
	write(io, pos2[1], pos2[2], pos2[3])
	write(io, b"LLLL")
	return take!(io)
end

@testset "QWTWPlot.jl" begin
	@testset "Pre-start guards & return types" begin
		@test !qStarted()
		@test qversion() == "not started yet"
		@test qplot([1.0, 2.0], [3.0, 4.0], "l", "-b") == Int32(-88)
		@test qplot2(1:3, 4:6, 7:9, "l2", "-r") == Int32(-88)
		@test qchange(1, [1.0, 2.0], [3.0, 4.0]) == Int32(-88)
	end

	@testset "Environment save/restore" begin
		sentinel_key = "QT_PLUGIN_PATH"
		had_key = haskey(ENV, sentinel_key)
		old_val = get(ENV, sentinel_key, "")
		delete!(ENV, sentinel_key)
		try
			QWTWPlot.saveEnv()
			ENV[sentinel_key] = "/tmp/fake_qt_plugins"
			QWTWPlot.restoreEnv()
			@test !haskey(ENV, sentinel_key)
		finally
			if had_key
				ENV[sentinel_key] = old_val
			else
				delete!(ENV, sentinel_key)
			end
		end
	end

	@testset "UDP Picker & Clip packet parsing" begin
		got_pick = Ref{QCBInfo}(QCBInfo())
		got_clip = Ref{QClipCallbackInfo}(QClipCallbackInfo())

		# Direct parser verification (verifies 4-byte `flag` offset before `label[24]`)
		QWTWPlot.cbFunction = info -> (got_pick[] = info)
		QWTWPlot.clipCallbackFunction = info -> (got_clip[] = info)

		pkt_p = _make_picker_packet(label = "velocity_x", index = Int32(42), flag = Int32(1))
		@test length(pkt_p) == 92
		QWTWPlot.onPickUdp(pkt_p)
		@test got_pick[].label == "velocity_x"
		@test got_pick[].index == 42
		@test got_pick[].time == 1.25
		@test got_pick[].x == 2.5
		@test got_pick[].y == -3.75

		pkt_c = _make_clip_packet(t1 = 2.0, t2 = 8.0, clipGroup = Int32(3), havePos = Int32(0))
		@test length(pkt_c) == 80
		QWTWPlot.onClipUdp(pkt_c)
		@test got_clip[].t1 == 2.0
		@test got_clip[].t2 == 8.0
		@test got_clip[].clipGroup == 3
		@test got_clip[].havePos == false
	end

	@testset "Multicast UDP listener lifecycle" begin
		println("  [test] Multicast UDP listener lifecycle..."); flush(stdout)
		picked_ch = Channel{QCBInfo}(1)
		qsetCallback(info -> put!(picked_ch, info))

		tx = UDPSocket()
		bind(tx, ip"0.0.0.0", 0; multicast_loop = true)
		try
			pkt = _make_picker_packet(label = "multicast_ok", plotID = Int32(77))
			try
				send(tx, IPv4(QWTWPlot.smip), QWTWPlot.udpPort, pkt)
			catch
			end
			res = timedwait(() -> isready(picked_ch), 0.3)
			if res != :ok
				# Fallback to explicit loopback / unicast (needed under VPN tunnels or CI firewalls)
				@static if Sys.isapple()
					in_addr = Ref(hton(UInt32(ip"127.0.0.1".host)))
					ccall(:setsockopt, Cint, (Cint, Cint, Cint, Ptr{UInt32}, UInt32), Base._fd(tx), 0, 9, in_addr, 4)
					send(tx, IPv4(QWTWPlot.smip), QWTWPlot.udpPort, pkt)
				elseif Sys.islinux()
					in_addr = Ref(hton(UInt32(ip"127.0.0.1".host)))
					ccall(:setsockopt, Cint, (Cint, Cint, Cint, Ptr{UInt32}, UInt32), Base._fd(tx), 0, 32, in_addr, 4)
					send(tx, IPv4(QWTWPlot.smip), QWTWPlot.udpPort, pkt)
				else
					send(tx, ip"127.0.0.1", QWTWPlot.udpPort, pkt)
				end
				res = timedwait(() -> isready(picked_ch), 2.0)
			end
			@test res == :ok
			if isready(picked_ch)
				info = take!(picked_ch)
				@test info.label == "multicast_ok"
				@test info.plotID == 77
			end
		finally
			close(tx)
			stopUdpThread()
		end
		println("  [test] Multicast UDP listener done."); flush(stdout)
	end

	@testset "Live libqwtw + qwproc integration" begin
		println("  [test] Live libqwtw + qwproc integration..."); flush(stdout)
		lib_candidate = QWTWPlot._resolve_library_name("libqwtw")
		require_live = get(ENV, "QWTW_REQUIRE_LIVE_TEST", "0") == "1"
		has_lib = isfile(lib_candidate)
		if !has_lib && !Sys.iswindows()
			h = Libdl.dlopen(lib_candidate; throw_error = false)
			if h !== nothing
				has_lib = true
				Libdl.dlclose(h)
			end
		end
		if require_live
			@test has_lib
		end
		if has_lib
			out_dir = get(ENV, "QWTW_TEST_ARTIFACT_DIR", "")
			if isempty(out_dir)
				out_dir = mktempdir()
			else
				mkpath(out_dir)
			end

			println("  [test] calling qstart()..."); flush(stdout)
			@test qstart() == 0
			@test qStarted()
			@test !isempty(qversion())

			println("  [test] 2D figure + plot + savepng..."); flush(stdout)
			fid = qfigure()
			@test fid > 0
			# Test AbstractVector / Range support as well as Vector{Float64}
			lid = qplot(0.0:0.1:2.0, sin.(0.0:0.1:2.0), "sin", "-b", 2)
			@test lid >= 0
			@test qchange(lid, 0.0:0.1:2.0, cos.(0.0:0.1:2.0)) >= 0
			lid2 = qplot2(0.0:0.1:2.0, sin.(0.0:0.1:2.0), 0.0:0.1:2.0, "sin_t", "-em", 2, 6)
			@test lid2 >= 0
			qtitle("QWTWPlot 2D test")
			qxlabel("t [s]")
			qylabel("amp")
			plot2d_png = joinpath(out_dir, "plot2d_test.png")
			@test qsavepng(plot2d_png, fid) == 0
			@test isfile(plot2d_png) && filesize(plot2d_png) > 1000
			qremove(lid)

			println("  [test] Spectrogram + savepng..."); flush(stdout)
			sfid = qspectrogram()
			@test sfid > 0
			sz = [sin(x) * cos(y) for y in range(-2.0, 2.0, length = 30), x in range(-3.0, 3.0, length = 40)]
			@test qspectrogram_info(-2.0, 2.0, -3.0, 3.0, sz) == 0
			qtitle("Spectrogram test")
			spec_png = joinpath(out_dir, "spectrogram_test.png")
			@test qsavepng(spec_png, sfid) == 0
			@test isfile(spec_png) && filesize(spec_png) > 1000

			println("  [test] OpenStreetMap + savepng..."); flush(stdout)
			mfid = qfmap()
			@test mfid > 0
			east = [37.901073, 37.911073, 37.905073, 37.90]
			north = [55.688713, 55.698713, 55.678713, 55.60]
			t_map = [0.0, 1.0, 2.0, 3.0]
			mlid = qplot2(east, north, t_map, "trajectory", "-rb", 3, 10)
			@test mlid >= 0
			qtitle("OpenStreetMap trajectory test")
			png_path = joinpath(out_dir, "map_test.png")
			@test qsavepng(png_path, mfid) == 0
			@test isfile(png_path) && filesize(png_path) > 1000

			println("  [test] qclear + qstop..."); flush(stdout)
			qclear()

			@test qstop() == 0
			@test !qStarted()
			println("  [test] Live integration done."); flush(stdout)
		else
			@info "Skipping live libqwtw integration test (set QWTW_LIB_PATH to run)"
		end
	end
end
