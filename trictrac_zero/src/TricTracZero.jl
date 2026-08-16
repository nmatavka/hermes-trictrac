module TricTracZero

using AlphaZero
import AlphaZero.GI
using JSON3
using Serialization

const PACKAGE_ROOT = normpath(joinpath(@__DIR__, ".."))
const REPO_ROOT = normpath(joinpath(PACKAGE_ROOT, ".."))
const BRIDGE_SCRIPT = joinpath(REPO_ROOT, "priv", "training", "trictrac_bridge_stdio.exs")
const DEFAULT_SESSIONS_ROOT = joinpath(PACKAGE_ROOT, "sessions")

include("actions.jl")
include("state.jl")
include("bridge.jl")
include("env.jl")
include("brade.jl")
include("race.jl")
include("device.jl")
include("network.jl")
include("experiment.jl")

export TricTracAction
export TricTracState
export TricTracGameSpec
export TricTracGameEnv
export BradeGameSpec
export RaceGameSpec
export tavli_targets
export TricTracSparseNet
export TricTracSparseNetHP
export TricTracMetalSparseNet
export TricTracMetalSparseNetHP
export action_catalog
export available_presets
export device_available
export default_experiment
export smoke_experiment
export gpu_available
export register_experiments!
export resolve_device_backend
export run_train
export run_smoke
export run_explore
export default_brade_experiment
export smoke_brade_experiment
export run_brade_train
export run_brade_smoke
export race_experiment
export run_race_train
export publish_race_champion!
export publish_brade_champion!
export set_runtime_device!

register_experiments!()

atexit(close_cached_bridges!)

end
