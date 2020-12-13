# QWTwPlot

This is another 2D plotting tool for Julia language.  It is based on (my) `qwtw` `"C"` library, which is based on `QWT` library which is based on `QT` library.

Current version should work for `Windows` and for `Linux`.
I'm using this for mostly for data analysis (dynamic systems with big state vector, sometimes its difficult to say how one variable influence other variable). Some useful features are explained on following page: https://github.com/ig-or/QWTwPlot.jl/wiki/qwtw-library-features


how to install it
----------------------------
* install `qwtw` library using instructions from here
		https://github.com/ig-or/qwtw
* in Julia command prompt, run 	
		Pkg.add("QWTwPlot")
 * run `Pkg.checkout("QWTwPlot")` if you'd like to use latest bug fixes and new features
* look at usage example https://github.com/ig-or/QWTwPlot.jl/blob/master/src/qwexample.jl
* and let the force be with you

There is some additional info and usage examples on project WIKI page here  https://github.com/ig-or/QWTwPlot.jl/wiki


Another description
----------------------------
You can see how it looks like here:
		https://github.com/ig-or/qwtw - on qwtw library page. There are a number of pictures in this description.

In order to use this package, you'll have to have `qwtw` library "installed". For `Windows10 x64`  there is an installation package:  https://github.com/ig-or/qwtw/releases


[![Build Status](https://travis-ci.org/ig-or/qwtwplot.jl.svg?branch=master)](https://travis-ci.org/ig-or/qwtwplot.jl)
