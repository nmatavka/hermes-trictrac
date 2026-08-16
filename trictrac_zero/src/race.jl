const RACE_VARIANT_IDS = Set(["backgammon", "tapa", "jacquet", "garanguet", "tavli", "brade"])
const RACE_CHAMPION_MANIFEST = "race-champion.json"
const TAVLI_TARGETS = ("3", "5", "7", "9")

mutable struct TavliTargetSchedule
  targets::Vector{String}
  next_index::Int
  lock::ReentrantLock
end

const TAVLI_TARGET_SCHEDULE_LOCK = ReentrantLock()
const TAVLI_TARGET_SCHEDULES = Dict{String, TavliTargetSchedule}()

"""
    RaceGameSpec(variant_id; match_options=Dict(), ...)

Build an engine-backed AlphaZero specification for a physical race game.  The
Elixir bridge remains the sole rules authority; this spec only transports raw
state and legal actions to Julia.
"""
function RaceGameSpec(
  variant_id::AbstractString;
  repo_root::String = REPO_ROOT,
  match_options = Dict{String, Any}(),
  temp_max_game_length::Union{Nothing, Int} = nothing
)
  id = String(variant_id)
  id in RACE_VARIANT_IDS || error("Unsupported race-game variant $(repr(id)).")
  options = normalize_match_options(match_options)
  if id == "tavli"
    options["tavliTargets"] = normalize_tavli_targets(get(options, "tavliTargets", TAVLI_TARGETS))
    !haskey(options, "tavliTarget") && (options["tavliTarget"] = "7")
  end

  return TricTracGameSpec(
    repo_root = repo_root,
    bridge_script = joinpath(repo_root, "priv", "training", "race_bridge_stdio.exs"),
    variant_id = id,
    match_options = options,
    tactical_config = Dict{String, Any}(
      "enabled" => false,
      "horizon_own_turns" => 0,
      "reward_weight" => 0.0,
      "heuristic_weight" => 0.0,
      "version" => "race-official-v1"
    ),
    temp_max_game_length = temp_max_game_length
  )
end

race_variant(gspec::TricTracGameSpec) = gspec.variant_id in RACE_VARIANT_IDS
tavli_variant(gspec::TricTracGameSpec) = gspec.variant_id == "tavli"

function normalize_tavli_targets(values)
  normalized = String[]
  for value in values
    target = String(value)
    target in TAVLI_TARGETS && !(target in normalized) && push!(normalized, target)
  end
  return isempty(normalized) ? collect(TAVLI_TARGETS) : normalized
end

function tavli_targets(gspec::TricTracGameSpec)
  return normalize_tavli_targets(get(gspec.match_options, "tavliTargets", TAVLI_TARGETS))
end

function install_tavli_target_schedule!(gspec::TricTracGameSpec)
  tavli_variant(gspec) || return nothing
  lock(TAVLI_TARGET_SCHEDULE_LOCK)
  try
    get!(TAVLI_TARGET_SCHEDULES, gspec.storage) do
      TavliTargetSchedule(tavli_targets(gspec), 1, ReentrantLock())
    end
  finally
    unlock(TAVLI_TARGET_SCHEDULE_LOCK)
  end
  return nothing
end

remove_tavli_target_schedule!(::TricTracGameSpec) = nothing

function next_tavli_target!(gspec::TricTracGameSpec)
  install_tavli_target_schedule!(gspec)
  lock(TAVLI_TARGET_SCHEDULE_LOCK)
  schedule = TAVLI_TARGET_SCHEDULES[gspec.storage]
  unlock(TAVLI_TARGET_SCHEDULE_LOCK)

  lock(schedule.lock)
  try
    target = schedule.targets[schedule.next_index]
    schedule.next_index = schedule.next_index == length(schedule.targets) ? 1 : schedule.next_index + 1
    return target
  finally
    unlock(schedule.lock)
  end
end

function race_vectorize_state(gspec::TricTracGameSpec, state::TricTracState)
  # The shared Bräde layout already represents physical board stacks, bar/out,
  # dice, match score, completed rounds, and phase without mirroring.  These
  # variant-specific slots distinguish dedicated race sessions and Tavli legs.
  features = brade_vectorize_state(gspec, state)
  runtime = state_runtime(state)
  variant_id = gspec.variant_id
  for (index, id) in enumerate(("backgammon", "tapa", "jacquet", "garanguet", "tavli"))
    brade_fill_scalar!(features, 51 + index, variant_id == id ? 1.0 : 0.0)
  end

  if variant_id == "tavli"
    variant_state = brade_get(runtime, "variant_state", Dict{String, Any}())
    active_leg = brade_string(brade_get(variant_state, "tavli_active_leg", ""))
    for (index, leg) in enumerate(("backgammon", "tapa", "jacquet"))
      brade_fill_scalar!(features, 57 + index, active_leg == leg ? 1.0 : 0.0)
    end
  end
  return features
end

function race_session_dir(exp::Experiment)
  return joinpath(DEFAULT_SESSIONS_ROOT, "$(exp.name)-sparse-v1-arena96x16")
end

race_champion_manifest_path(dir::String) = joinpath(dir, RACE_CHAMPION_MANIFEST)

function publish_race_champion!(dir::String, iteration::Int, variant_id::String)
  isfile(joinpath(dir, AlphaZero.UserInterface.BESTNN_FILE)) || return false
  AlphaZero.UserInterface.write_json_atomic(
    race_champion_manifest_path(dir),
    Dict(
      "accepted" => true,
      "checkpoint" => "bestnn.data",
      "iteration" => iteration,
      "variant_id" => variant_id,
      "schema" => 1
    )
  )
  return true
end

function race_experiment(
  variant_id::AbstractString;
  smoke::Bool = false,
  repo_root::String = REPO_ROOT,
  device = DEFAULT_DEVICE,
  use_gpu::Bool = false,
  move_cap = nothing,
  num_iters = nothing,
  self_play_workers = nothing,
  arena_workers = nothing
)
  id = String(variant_id)
  resolved_device = resolve_device_backend(resolve_requested_device(device = device, use_gpu = use_gpu))
  NetworkType = network_type_for_device(resolved_device)
  gspec = RaceGameSpec(id, repo_root = repo_root, temp_max_game_length = move_cap)
  return Experiment(
    smoke ? "$(id)-smoke" : id,
    gspec,
    build_params(
      smoke = smoke,
      preset = "classique",
      device = resolved_device,
      use_gpu = is_gpu_backend(resolved_device),
      num_iters = num_iters,
      self_play_workers = self_play_workers,
      arena_workers = arena_workers,
      partie_length_repeats = nothing
    ),
    network_factory(network_type = NetworkType),
    netparams(device = resolved_device, network_type = NetworkType),
    BENCHMARKS
  )
end

function run_race_train(variant_id::AbstractString; dir::Union{Nothing, String} = nothing, smoke::Bool = false, kwargs...)
  exp = race_experiment(variant_id; smoke = smoke, kwargs...)
  session_dir = isnothing(dir) ? race_session_dir(exp) : dir
  session = AlphaZero.Scripts.train(exp; dir = session_dir, autosave = true, save_intermediate = false)
  checkpoint_accepted(session) && publish_race_champion!(session_dir, session.env.itc, String(variant_id))
  return session
end
