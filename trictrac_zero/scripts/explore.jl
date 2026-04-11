include(joinpath(@__DIR__, "bootstrap.jl"))

using TricTracZero

dir = isempty(ARGS) ? nothing : ARGS[1]

TricTracZero.run_explore(dir = dir)
