# Architecture Review, Bug Report & Improvement Roadmap: `qwtw` and `QWTWPlot.jl`

## 1. Executive Summary

`qwtw` and `QWTWPlot.jl` share a strong architectural foundation for engineering, control-systems, and simulation analysis:

* **Out-of-process rendering (`libqwtw` + `qwproc`)**: `libqwtw` links only the system C/C++ runtime (zero Qt or Boost link dependencies), spawning and talking to `qwproc` over a local stream (`AF_UNIX` domain socket on macOS/Linux, Named Pipe on Windows). Plots stay interactive even while the Julia REPL or simulation is busy or paused.
* **Domain-specific engineering workflows**: Synchronized cross-plot time markers, clip-group zooming (`qclipgrp`), interactive windowed PSD/FFT (`f` key), spectrograms with per-cell 3D coordinates and timestamps, and **multicast UDP synchronization** (`239.255.0.1:49561` / `49562`) so external tools, replay GUIs, and Julia scripts can exchange marker and clip events in real time.

Recent work in `qwtw` modernized the C++ core to **C++23 + Qt6 + vendored Qwt 6.3 + zero Boost dependencies** (along with a modernized `python/qwtwc.py`). This review documents:

1. **How to switch 100% to Qt6 cleanly** across both repositories and Julia's BinaryBuilder (`Yggdrasil`) ecosystem.
2. **Bugs found and fixed** across both `QWTWPlot.jl` and `qwtw` (especially around Qt6 ABI, multicast UDP packets, and VPN/loopback routing).
3. **Recommended next improvements** for both `QWTWPlot.jl` and `qwtw`.

---

## 2. Switching 100% to Qt6: Is It Possible?

**Yes — switching 100% to Qt6 is completely possible and is the cleanest path forward.** Mixing Qt5 and Qt6 in the same process or via `QT_PLUGIN_PATH` causes immediate startup crashes, so removing all Qt5 remnants is strongly recommended.

### 2.1 Status in `qwtw` (C++ Backend)

* **Core (`libqwtw` + `qwproc` + vendored `extern/qwt`)**: Already 100% Qt6 (`Qt6::Core`, `Qt6::Gui`, `Qt6::Widgets`, `Qt6::Network`, `Qt6::OpenGL`, `Qt6::OpenGLWidgets`). `libqwtw` itself does not even link Qt — only `qwproc` does.
* **Multicast UDP (`WITH_UDP_SYNC`)**: Uses `QUdpSocket` / `QNetworkInterface` from `Qt6::Network`, which is already linked unconditionally. Keeping `WITH_UDP_SYNC=ON` by default works natively in Qt6 with zero extra dependencies.
* **Native OpenStreetMap view (`USE_MARBLE` completely eliminated)**:
  * Replaced KDE Marble (`MarView` / `marblewidget`) with a native Qt6 + Qwt Web Mercator slippy-map implementation (`MapView`, `MercatorLatTransform`, `OsmTileItem`, and `OsmTileManager` in `qwtw/mapview.h` & `qwtw/mapview.cpp`, ~380 lines of C++23 with zero external library dependencies).
  * `qfmap()` / `qwtmap()` is now built-in unconditionally on macOS (including Apple Silicon), Linux, and Windows, caches tiles in RAM + `~/.qwtw/tiles/` (configurable via `"map_tile_url"` in `~/.qwtw/settings.json`), and inherits all `Figure2` features (`qremove`, `qchange`, `qsavepng`, interactive picker/UDP callbacks, clip groups, and zoom/pan).
  * Unified `qtstart()` and `qtstart_debug(int level)` into a single clean C ABI across all builds.
* **Optional `USE_MGL` (3D Lines/Surfaces via MathGL)**:
  * System `MathGL2` packages on older Linux distros often link Qt5 (`libmgl-qt5`), which cannot be linked into Qt6 `qwproc`. If `USE_MGL=ON` is needed with Qt6, either build MathGL 8.x with `-Denable-qt6=ON` or render MathGL to an in-memory RGBA buffer (`mglGraph` bitmap) displayed in a native Qt6 `QWidget` (eliminating the `mgl-qt` widget dependency altogether), or migrate 3D plots to `QtGraphs` / `QtDataVisualization` in Qt6.

### 2.2 Status in `QWTWPlot.jl` and Julia's BinaryBuilder (`Yggdrasil`)

* **Why `Project.toml` previously pulled Qt5**:
  * `QWTWPlot` previously depended on `Qt_jll` (`v5.15.2`), `marble_jll` (`v23.4.3`, built against Qt5), and `qwtw_jll` (`v2.13.2`, built against Qt5 + `boost_jll` + `qwt_jll` 6.0).
  * None of those legacy Qt5 JLLs had `aarch64-apple-darwin` (Apple Silicon) builds, and setting `ENV["QT_PLUGIN_PATH"] = Qt_jll.artifact_dir * "/plugins"` breaks Qt6 `qwproc` on Linux/Windows.
* **Step 1 — Completed in `QWTWPlot.jl`**:
  * Removed `Qt_jll`, `marble_jll`, and Qt5 `qwtw_jll` from `Project.toml`.
  * `QWTWPlot.jl` now has **zero Qt5 dependencies** and resolves the Qt6 `libqwtw` library automatically via:
    1. Explicit `qstart(libraryName = ...)` path or directory,
    2. `ENV["QWTW_LIB_PATH"]`,
    3. `"qwtw_lib_path"` in `~/.qwtw/settings.json`,
    4. Local workspace build directories (`lib/macos-arm64/release`, `lib/linux-x86_64/release`, `lib_win32_build/release`, etc.),
    5. System dynamic linker path.
* **Step 2 — Publishing `qwtw_jll v3.0.0` on `JuliaPackaging/Yggdrasil` (for zero-build `] add QWTWPlot`)**:
  * Julia's General Registry **already ships `Qt6Base_jll` (`v6.10.2`)** across Linux (`x86_64`, `aarch64`), macOS (`x86_64`, **`aarch64-apple-darwin` Apple Silicon**), and Windows (`x86_64`).
  * Because `qwtw` dropped Boost and vendors Qwt 6.3 statically in `extern/qwt`, the Yggdrasil `build_tarballs.jl` recipe for `qwtw v3.0.0` becomes dramatically simpler than `v2.13.2`:
    * **Drop**: `Qt_jll`, `boost_jll`, `qwt_jll`, `marble_jll`, `MathGL_jll`, `FreeType2_jll`.
    * **Add**: `Dependency("Qt6Base_jll"; compat="~6.8")` (or current Yggdrasil Qt6 compat baseline) and build with `-DCMAKE_BUILD_TYPE=Release -DWITH_UDP_SYNC=ON -DUSE_MARBLE=OFF -DUSE_MGL=OFF` using GCC 13+ / Clang 16+ (for C++23).
    * Once `qwtw_jll v3.0.0` is registered, add `qwtw_jll = "3"` to `QWTWPlot/Project.toml` `[compat]` and check `qwtw_jll.is_available()` as fallback after `QWTW_LIB_PATH`.

---

## 3. Bugs Found & Fixed

### 3.1 Fixes in `QWTWPlot.jl`

1. **Corrupted `label` in picker UDP callbacks (`onPickUdp` byte-offset mismatch)**:
   * In `qwtw/qwtypes.h`, `CBPickerInfo` (`#pragma pack(1)`) has a 4-byte `int flag` field at packet bytes `61:64` immediately before `char label[24]` at bytes `65:88` (total `PickerMessage` size: 92 bytes).
   * `QWTWPlot.jl` previously read `x[61:84]` as `label`, interpreting `flag = 1` (`0x01, 0x00, 0x00, 0x00` little-endian) as a 1-character string `"\x01"` on every click. Fixed to read `flag` at `61:64` and `label` at `65:88`.
2. **Silent failure parsing `~/.qwtw/settings.json`**:
   * `qwtw/settings.cpp` writes `"udp_client_port": 49561` as a JSON integer, whereas `QWTWPlot.jl` called `parse(Int32, cfg["udp_client_port"])`, throwing a `MethodError` on `Int64` and falling back to defaults whenever `settings.json` existed. Fixed to accept both JSON integers and strings.
3. **`qtstart` / `qtstart_debug` C ABI mismatch when `USE_MARBLE=OFF`**:
   * `qwtw.h` defines `qtstart()` and `qtstart_debug(int level)` when `USEMARBLE` is not defined, vs. `qtstart(const char* mdp, const char* mpp)` and `qtstart_debug(mdp, mpp, level)` when `USEMARBLE` is defined.
   * `QWTWPlot.jl` previously passed `(marbleDataPath, marblePluginPath, 10)` unconditionally, passing a `char*` pointer as `int level` on non-Marble builds. Fixed by checking `qwtwMapViewH != C_NULL` (`qwtmap` symbol presence) at runtime.
4. **Multicast UDP listener lifecycle, race conditions & VPN routing**:
   * `__init__()` previously created a one-shot `Task` before `udpPort` was initialized; calling `qsetCallback` before `qstart()` permanently killed the task.
   * `stopUdpThread()` previously spammed 25 `"stop\n"` multicast datagrams to wake `recv(sock)` (which throws `EHOSTUNREACH` / `ENETUNREACH` when offline or on VPN) and `qstop()` never closed the UDP socket.
   * `udpDataReader()` previously joined multicast only on `INADDR_ANY`, which on macOS with active VPN tunnels (`utun*`) fails to receive loopback multicast.
   * **Fixed**: `udpDataReader` now joins `smip` across all local IPv4 interfaces (including `127.0.0.1`), synchronizes startup with a `Base.Event` so packets sent immediately after `qsetCallback` are never missed, updates callbacks in place without tearing down the socket, and shuts down cleanly via `close(sock)`.
5. **`qstop()` and `qchange()` return-type bugs (failing `Pkg.test()`)**:
   * `qstop()` returned `nothing`, causing `@test qstop() == 0` in `test/runtests.jl` to fail.
   * `qchange(...)::Int32` executed a bare `return` (`nothing`) when `!started`, throwing a `TypeError`.
6. **Artificial `sleep(0.025)` latency removed**:
   * `qplot`, `qplot1`, `qplot2`, `qmgline`, `qmglmesh`, `qEnableCoordBroadcast`, and `qDisableCoordBroadcast` all slept 25 ms per call despite `libqwtw`'s local-socket `sendTransaction` already being synchronous request-reply.
7. **GC safety, typed `Ptr{Cvoid}` handles, `ENV` restoration & `AbstractVector` support**:
   * Added `GC.@preserve` in `qversion()`, `qchange()`, and `qspectrogram_info()`.
   * Replaced 30+ untyped `0`-initialized globals with typed `Ptr{Cvoid}` (`C_NULL`) bindings and `Cstring` arguments.
   * Fixed `saveEnv()` / `restoreEnv()` so previously unset `QT_PLUGIN_PATH` / `LD_LIBRARY_PATH` keys are deleted rather than left set to `""`.
   * Widened vector/ID parameters to `AbstractVector{<:Real}` and `Integer` (zero-copy when already `Vector{Float64}`), so ranges like `0.0:0.01:10.0`, views, and `Int` IDs work directly without `collect(...)` or `Int32(...)`.

### 3.2 Fixes in `qwtw`

1. **Enabled `WITH_UDP_SYNC=ON` by default (`qwtw/CMakeLists.txt`)**:
   * Restores multicast UDP marker/picker/clip broadcasts and `qwtEnableCoordBroadcast` / `qwtDisableCoordBroadcast` in default Qt6 builds (`Qt6::Network` was already linked unconditionally).
2. **Fixed `XQPlots::sendClipInfo` dropping clip UDP packets (`qwtw/sfigure.cpp`)**:
   * `bc->bcSend(...)` was nested inside `if (bcInfo->bcOK())`, so pressing the Clip button never sent `ClipUdpMessage` unless `qEnableCoordBroadcast` had also been called with a 3D trajectory. `ClipUdpMessage` is now always sent (with `havePos = 1` when 3D trajectory endpoints exist and `havePos = 0` otherwise).
3. **Fixed `BCUdpServer` rejecting 32-byte `BroadcastMessage` packets (`qwtw/sfigure.cpp`)**:
   * `BroadcastMessage` is `4 + 3*8 + 4 = 32` bytes (`"CRDS"<x><y><z>"FFFF"`), but `BCUdpServer` previously checked `n == 8 * 3 + 4` (28 bytes) and wrote `rb[25] = 0`. Updated to accept both 28-byte and 32-byte packets cleanly.
4. **Fixed `BCUdpClient` / `BCUdpServer` multicast routing under VPN tunnels & offline mode (`qwtw/sfigure.cpp`)**:
   * `BCUdpClient` now enables `MulticastLoopbackOption`, selects a non-`IsPointToPoint` multicast-capable IPv4 interface (avoiding VPN `utun` blackholes), and automatically falls back to the loopback interface (`lo0`) if LAN multicast returns `EHOSTUNREACH` or is offline. `BCUdpServer` joins the multicast group on all eligible IPv4 interfaces.
5. **Fixed `#ifdef USEMARBLE` accidentally hiding `setcallback` / `setclipcallback` (`qwtw/proclib/qwtw.cpp`)**:
   * Moved `setcallback`, `setclipcallback`, `setcallback_t1`, and `setcallback_t2` outside `#ifdef USEMARBLE` to match `qwtw.h`.
6. **Updated Marble CMake lookup to Qt6 (`buildsys/FindMarble.cmake`, `qwtw/proc/CMakeLists.txt`)**:
   * Changed `marblewidget-qt5` to `marblewidget-qt6` / `marblewidget`.

---

## 4. Further Improvement Suggestions for `QWTWPlot.jl`

### 4.1 Package Layout & Examples Cleanup
* **Move scripts out of `src/` into `examples/`**:
  * `src/qwexample.jl`, `src/cbtest.jl`, `src/mtest.jl`, `src/spectrogram_test.jl`, and `src/setpos_test.jl` sit inside `src/` and several contain hardcoded developer paths (`/home/igor/...`, `C:\Users\ISandler\...`). Moving them to `examples/` and updating their `qstart()` calls makes the package cleaner and easier to learn from.
* **Add GitHub Actions CI (`.github/workflows/CI.yml`)**:
  * Currently `.github/workflows/` only has `CompatHelper.yml` and `TagBot.yml`. Adding a lightweight CI workflow running `Pkg.test()` on Julia `1.10` (LTS) and `1.12` guarantees pure-Julia packet/API tests never regress (and on Linux runners with `xvfb-run`, can even test `qwproc` headless with `QT_QPA_PLATFORM=offscreen`!).

### 4.2 Idiomatic Julia API Additions (100% Backward-Compatible)
* **Keyword-argument & shorthand overloads**:
  * Support `qplot(y; name="", style="-b", lw=1, ms=1)` (auto-generating `1:length(y)` for `x`), `qplot(x, y; name="", style="-b", lw=1, ms=1, t=nothing)` (unifying `qplot`, `qplot1`, and `qplot2`), and matrix `qplot(M::AbstractMatrix)` (matching `python/qwtwc.py`'s `plot()` / `line()`).
* **Structured line style helper (optional)**:
  * Keep the compact 1–3 char style strings (`"-b"`, `" er"`, `"-tm"`), while optionally accepting readable keywords (`color=:blue, marker=:circle, linestyle=:solid`) so new Julia users don't have to memorize `docs/line-styles.md`.
* **`do`-block context helpers**:
  * Example: `qfigure(xAxisType=:aLog) do; qplot(t, y); qtitle("..."); end` or `qwith_important(false) do; qplot(...); end` (automatically restoring `qimportant(1)` even if an exception occurs).
* **1-based vs 0-based `QCBInfo.index` documentation**:
  * `CBPickerInfo::index` from C++ is 0-based, whereas Julia arrays are 1-based (`x[q.index + 1]`). Documenting this explicitly in `QCBInfo`'s docstring (or adding a helper property/note) prevents off-by-one bugs in user callbacks.

### 4.3 Encapsulate Module State in a Single Struct + Precompile Workload
* Grouping the module's mutable variables (`qwtwLibHandle`, function pointers, `udpSock`, `cbTaskH`, callbacks) into a single `Base.@kwdef mutable struct ClientState` held in `const STATE = ClientState()` eliminates `global` declarations inside functions and improves type stability.
* Adding a minimal `PrecompileTools.@compile_workload` for packet parsing and vector conversion eliminates first-call JIT latency.

---

## 5. Further Improvement Suggestions for `qwtw` (C++ / Qt6)

### 5.1 Completed: Unified `qtstart` C ABI & Native OpenStreetMap View
* Replaced KDE Marble with native Qt6 + Qwt Web Mercator slippy-map rendering (`qwtw/mapview.h` / `qwtw/mapview.cpp`), eliminating `#ifdef USEMARBLE` and unifying `qtstart()` / `qtstart_debug(int level)` across C, Python (`python/qwtwc.py`), and Julia (`QWTWPlot.jl`).

### 5.2 Multicast UDP Enhancements (Since Multicast Remains a First-Class Feature)
* **Configurable multicast interface in `~/.qwtw/settings.json`**:
  * Add an optional `"udp_interface"` setting (e.g. `"auto"`, `"127.0.0.1"`, `"192.168.1.9"`, or `"en0"`) alongside `"smip"` and `"udp_client_port"` so multi-NIC simulation rigs (e.g. separate lab network vs corporate Wi-Fi/VPN) can pin multicast traffic to a specific NIC deterministically.
* **Longer or dynamic line labels in UDP/IPC picker events**:
  * `CBPickerInfo::label` is currently truncated to 23 characters (`lSize = 24`). Expanding `lSize` to `64` (with a protocol magic/version byte in the 4-byte header, e.g. `"PPP2"`, so receivers detect packet v1 vs v2 cleanly) avoids truncating descriptive signal names in complex state vectors.
* **Include `qwproc` path override via `ENV["QWTW_PROC_PATH"]`**:
  * `findQwProcPath()` in `pclient.cpp` checks cwd, `libqwtw` directory, executable directory, and `PATH`. Adding `std::getenv("QWTW_PROC_PATH")` at the top makes containerized, relocatable, and BinaryBuilder/JLL deployments trivial to debug and override.

### 5.3 Headless / Offscreen Testing in CMake (`ctest`)
* Qt6 supports headless rendering natively via `QT_QPA_PLATFORM=offscreen` on macOS, Linux, and Windows (no X11/Wayland display server needed!).
* Adding a `ctest` target that runs an automated non-interactive smoke test (`qtstart` -> `qwtfigure` -> `qwtplot2` -> `qwtspectrogram` -> `qwtsave_png` -> UDP picker/clip check -> `qwtclose` under `QT_QPA_PLATFORM=offscreen`) will let GitHub Actions test both `qwtw` and `QWTWPlot.jl` end-to-end on every push across macOS, Linux, and Windows.

### 5.4 Modernize Build & Packaging Details
* **Remove unused `addBoost` macro in `buildsys/ccmake.cmake`**: Boost was dropped from `qwtw`, so pruning dead `addBoost` / `rdframer_extlib` CMake macros simplifies maintenance.
* **Embed `@loader_path` / `$ORIGIN` RPATHs & `CMakePackageConfigHelpers`**: Makes installing `libqwtw` + `qwproc` into standard prefixes (and Yggdrasil `$prefix/lib` + `$prefix/bin`) work out of the box without wrapper environment scripts.
