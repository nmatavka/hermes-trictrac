include(joinpath(@__DIR__, "bootstrap.jl"))
using TricTracZero

dir = isempty(ARGS) ? nothing : ARGS[1]
TricTracZero.run_brade_smoke(dir = dir, num_iters = 1, self_play_workers = 1, arena_workers = 1)
