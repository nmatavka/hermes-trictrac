include(joinpath(@__DIR__, "bootstrap.jl"))
using TricTracZero

dir = isempty(ARGS) ? nothing : ARGS[1]
TricTracZero.run_brade_train(dir = dir)
