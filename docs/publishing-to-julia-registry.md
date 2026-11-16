# Publishing `qwtw_jll` v3.0.0 & `QWTWPlot.jl` v2.0.0 to the Julia Registry

Both `qwtw` and `QWTWPlot.jl` are now verified in GitHub Actions CI across **Linux x86_64**, **macOS Apple Silicon**, and **Windows x86_64 (MinGW UCRT64)**.

Follow these two short steps to make `] add QWTWPlot` install everything automatically out of the box again:

---

## Step 1: Open a PR to `JuliaPackaging/Yggdrasil` (`qwtw_jll` v3.0.0)

1. Fork/clone [`JuliaPackaging/Yggdrasil`](https://github.com/JuliaPackaging/Yggdrasil) and replace `Q/qwtw/build_tarballs.jl` with [`julia/build_tarballs.jl`](https://github.com/ig-or/qwtw/blob/master/julia/build_tarballs.jl) from your `qwtw` repo (already pinned to `qwtw` `bb317eda2008643f49d0f98e013f95b39c1c4f55` and `qwt` `2dc09fd351ec8c30252913b5eb8af6c46ef4101c`).
2. Open a Pull Request to `JuliaPackaging/Yggdrasil` titled `[qwtw] Update to v3.0.0 (Qt6, macOS + aarch64 support)`.
3. Yggdrasil's Azure Pipelines will build tarballs for:
   - `x86_64-linux-gnu` & `aarch64-linux-gnu`
   - `x86_64-apple-darwin` & `aarch64-apple-darwin`
   - `x86_64-w64-mingw32`
4. Once merged, Yggdrasil automatically publishes and registers `qwtw_jll v3.0.0+0` in Julia's `General` registry.

---

## Step 2: Register `QWTWPlot.jl` v2.0.0

`src/QWTWPlot.jl` **already contains** automatic runtime discovery and environment configuration for `qwtw_jll v3+` + `Qt6Base_jll` (`_jll_library_path()` and `_configure_jll_runtime_env!()`).

Once `qwtw_jll v3.0.0` is live in `General`:

1. Update `Project.toml` in `QWTWPlot.jl` to add `qwtw_jll` and `Qt6Base_jll` and set `version = "2.0.0"`:

```toml
name = "QWTWPlot"
uuid = "193516b8-fe0d-4284-b46c-e203758f96c4"
version = "2.0.0"
authors = ["ig-or <19777752+ig-or@users.noreply.github.com> and contributors"]

[deps]
JSON3 = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"
Libdl = "8f399da3-3557-5675-b5ff-fb832c97cbdb"
Printf = "de0858da-6303-5e67-8744-51eddeeeb8d7"
Qt6Base_jll = "c0090381-4147-56d7-9ebc-da0b1113ec56"
Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
Sockets = "6462fe0b-24de-5631-8697-dd941f90decc"
qwtw_jll = "d5de49f9-40c9-5bd5-980e-f7e357ea5903"

[compat]
JSON3 = "1.1"
Qt6Base_jll = "6.10"
julia = "1.6"
qwtw_jll = "3"

[extras]
Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[targets]
test = ["Test"]
```

2. Commit, push to `ig-or/QWTWPlot.jl`, and comment `@JuliaRegistrator register` on that commit.
