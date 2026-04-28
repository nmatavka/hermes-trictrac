include(joinpath(@__DIR__, "cpu_config.jl"))

const STARTUP = TricTracScriptCPU.prepare_startup(:explore, abspath(@__FILE__), ARGS)

include(joinpath(@__DIR__, "bootstrap.jl"))

using TricTracZero

dir = isempty(STARTUP.positional) ? nothing : STARTUP.positional[1]

TricTracZero.run_explore(dir = dir, preset = STARTUP.game.value, device = STARTUP.device.value)
