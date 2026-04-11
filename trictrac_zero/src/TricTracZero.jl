module TricTracZero

using AlphaZero
import AlphaZero.GI
using JSON3

const PACKAGE_ROOT = normpath(joinpath(@__DIR__, ".."))
const REPO_ROOT = normpath(joinpath(PACKAGE_ROOT, ".."))
const BRIDGE_SCRIPT = joinpath(REPO_ROOT, "priv", "training", "trictrac_bridge_stdio.exs")
const DEFAULT_SESSIONS_ROOT = joinpath(PACKAGE_ROOT, "sessions")

include("actions.jl")
include("state.jl")
include("bridge.jl")
include("env.jl")
include("network.jl")
include("experiment.jl")

export TricTracAction
export TricTracState
export TricTracGameSpec
export TricTracGameEnv
export TricTracSparseNet
export TricTracSparseNetHP
export action_catalog
export available_presets
export default_experiment
export smoke_experiment
export gpu_available
export register_experiments!
export run_train
export run_smoke
export run_explore

register_experiments!()

atexit(close_cached_bridges!)

end
