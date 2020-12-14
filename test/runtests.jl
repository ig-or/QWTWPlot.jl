using QWTWPlot
using Printf
using Test

@testset "QWTWPlot.jl" begin
	# Write your tests here.
	@test (check =	qstart()) == 0
	@test (check =	qstop()) == 0
end
