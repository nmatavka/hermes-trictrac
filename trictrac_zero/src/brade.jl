const BRADE_BRIDGE_SCRIPT = joinpath(REPO_ROOT, "priv", "training", "brade_bridge_stdio.exs")
const BRADE_MATCH_LENGTHS = ("3", "5", "7")
const BRADE_SESSION_LAYOUT_VERSION = "brade-sparse-v1-arena96x16"
const BRADE_CHAMPION_MANIFEST = "brade-champion.json"

mutable struct BradeMatchLengthSchedule
  lengths::Vector{String}
  next_index::Int
  lock::ReentrantLock
end

const BRADE_MATCH_LENGTH_SCHEDULE_LOCK = ReentrantLock()
const BRADE_MATCH_LENGTH_SCHEDULES = Dict{String, BradeMatchLengthSchedule}()

"""
    BradeGameSpec(; match_lengths=("3", "5", "7"), ...)

Builds the dedicated Bräde training configuration while retaining the shared
AlphaZero game-spec storage and sparse policy infrastructure.  The raw action
encoding is selected by `variant_id == "brade"` throughout the shared layer.
"""
function BradeGameSpec(;
  repo_root::String = REPO_ROOT,
  match_lengths = BRADE_MATCH_LENGTHS,
  temp_max_game_length::Union{Nothing, Int} = nothing
)
  lengths = normalize_brade_match_lengths(match_lengths)
  spec = TricTracGameSpec(
    repo_root = repo_root,
    bridge_script = joinpath(repo_root, "priv", "training", "brade_bridge_stdio.exs"),
    variant_id = "brade",
    match_options = Dict{String, Any}(
      "matchLength" => "5",
      "bradeMatchLengths" => lengths
    ),
    tactical_config = Dict{String, Any}(
      "enabled" => false,
      "horizon_own_turns" => 0,
      "reward_weight" => 0.0,
      "heuristic_weight" => 0.0,
      "version" => "brade-official-v1"
    ),
    temp_max_game_length = temp_max_game_length
  )
  install_brade_match_length_schedule!(spec)
  return spec
end

function normalize_brade_match_lengths(values)
  normalized = String[]
  for value in values
    text = String(value)
    text in BRADE_MATCH_LENGTHS && !(text in normalized) && push!(normalized, text)
  end
  return isempty(normalized) ? collect(BRADE_MATCH_LENGTHS) : normalized
end

function brade_match_lengths(gspec::TricTracGameSpec)
  values = get(gspec.match_options, "bradeMatchLengths", BRADE_MATCH_LENGTHS)
  return normalize_brade_match_lengths(values)
end

function install_brade_match_length_schedule!(gspec::TricTracGameSpec)
  brade_variant(gspec) || return nothing
  lock(BRADE_MATCH_LENGTH_SCHEDULE_LOCK)
  try
    get!(BRADE_MATCH_LENGTH_SCHEDULES, gspec.storage) do
      BradeMatchLengthSchedule(brade_match_lengths(gspec), 1, ReentrantLock())
    end
  finally
    unlock(BRADE_MATCH_LENGTH_SCHEDULE_LOCK)
  end
  return nothing
end

function remove_brade_match_length_schedule!(gspec::TricTracGameSpec)
  # Keep one shared schedule through self-play and arena calls so concurrent
  # simulations rotate evenly across best-of 3/5/7 instead of resetting to 3.
  return nothing
end

function next_brade_match_length!(gspec::TricTracGameSpec)
  install_brade_match_length_schedule!(gspec)
  lock(BRADE_MATCH_LENGTH_SCHEDULE_LOCK)
  schedule = BRADE_MATCH_LENGTH_SCHEDULES[gspec.storage]
  unlock(BRADE_MATCH_LENGTH_SCHEDULE_LOCK)

  lock(schedule.lock)
  try
    value = schedule.lengths[schedule.next_index]
    schedule.next_index = schedule.next_index == length(schedule.lengths) ? 1 : schedule.next_index + 1
    return value
  finally
    unlock(schedule.lock)
  end
end

function brade_get(value, key::String, default = 0)
  value isa AbstractDict || return default
  return get(value, key, get(value, Symbol(key), default))
end

function brade_number(value, default = 0.0)
  value isa Number && return Float64(value)
  try
    return parse(Float64, String(value))
  catch
    return default
  end
end

brade_string(value, default = "") = isnothing(value) ? default : String(value)

function brade_board_count(board, point::Int, color::String)
  points = brade_get(board, "points", Any[])
  point + 1 <= length(points) || return 0.0
  return brade_number(brade_get(points[point + 1], color, 0))
end

function brade_color_count(board, field::String, color::String)
  return brade_number(brade_get(brade_get(board, field, Dict{String, Any}()), color, 0))
end

function brade_fill_scalar!(features, channel::Int, value)
  features[:, :, channel] .= Float32(clamp(Float64(value), -1.0, 1.0))
  return nothing
end

function brade_vectorize_state(::TricTracGameSpec, state::TricTracState)
  features = zeros(Float32, BRADE_FEATURE_SHAPE)
  runtime = state_runtime(state)
  board = brade_get(runtime, "board", Dict{String, Any}())

  # Physical board coordinates are intentionally left untouched. Bräde black
  # follows the Jacquet-parallel route, not a reflected backgammon route.
  for point in 0:23
    features[point + 1, 1, 1] = Float32(brade_board_count(board, point, "white") / 15.0)
    features[point + 1, 1, 2] = Float32(brade_board_count(board, point, "black") / 15.0)
  end

  brade_fill_scalar!(features, 3, brade_color_count(board, "bar", "white") / 15.0)
  brade_fill_scalar!(features, 4, brade_color_count(board, "bar", "black") / 15.0)
  brade_fill_scalar!(features, 5, brade_color_count(board, "outside", "white") / 15.0)
  brade_fill_scalar!(features, 6, brade_color_count(board, "outside", "black") / 15.0)

  dice = brade_get(runtime, "dice", nothing)
  values = dice === nothing ? Any[] : brade_get(dice, "values", Any[])
  moves_left = dice === nothing ? Any[] : brade_get(dice, "moves_left", Any[])
  brade_fill_scalar!(features, 7, length(values) >= 1 ? brade_number(values[1]) / 6.0 : 0.0)
  brade_fill_scalar!(features, 8, length(values) >= 2 ? brade_number(values[2]) / 6.0 : 0.0)
  for die in 1:6
    brade_fill_scalar!(features, 8 + die, count(value -> brade_number(value) == die, moves_left) / 4.0)
  end

  phase = state_phase(state)
  brade_fill_scalar!(features, 15, phase == "opening" ? 1.0 : 0.0)
  brade_fill_scalar!(features, 16, phase == "roll" ? 1.0 : 0.0)
  brade_fill_scalar!(features, 17, phase == "move" ? 1.0 : 0.0)
  brade_fill_scalar!(features, 18, state_terminal(state) ? 1.0 : 0.0)
  brade_fill_scalar!(features, 19, state_white_to_play(state) ? 1.0 : 0.0)

  match = brade_get(runtime, "match", Dict{String, Any}())
  match_length = max(brade_number(brade_get(match, "length", 5)), 1.0)
  score = brade_get(match, "score", Dict{String, Any}())
  brade_fill_scalar!(features, 20, brade_number(brade_get(score, "white", 0)) / (6.0 * match_length))
  brade_fill_scalar!(features, 21, brade_number(brade_get(score, "black", 0)) / (6.0 * match_length))
  brade_fill_scalar!(features, 22, match_length / 7.0)
  brade_fill_scalar!(features, 23, brade_number(brade_get(runtime, "turn_number", 0)) / 200.0)

  results = brade_get(match, "results", Any[])
  for (index, result) in enumerate(Iterators.take(results, 7))
    channel = 24 + (index - 1) * 4
    winner = brade_string(brade_get(result, "winner", ""))
    brade_fill_scalar!(features, channel, winner == "white" ? 1.0 : 0.0)
    brade_fill_scalar!(features, channel + 1, winner == "black" ? 1.0 : 0.0)
    brade_fill_scalar!(features, channel + 2, brade_number(brade_get(result, "points", 0)) / 6.0)
    brade_fill_scalar!(features, channel + 3, brade_number(brade_get(result, "game_number", index)) / 7.0)
  end

  variant_state = brade_get(runtime, "variant_state", Dict{String, Any}())
  causes = brade_get(variant_state, "brade_turn_cause", Dict{String, Any}())
  for (offset, color) in enumerate(("white", "black"))
    cause = brade_get(causes, color, Dict{String, Any}())
    brade_fill_scalar!(features, 52 + offset, isnothing(brade_get(cause, "last_inward_signature", nothing)) ? 0.0 : 1.0)
    brade_fill_scalar!(features, 54 + offset, isnothing(brade_get(cause, "qualifying_signature", nothing)) ? 0.0 : 1.0)
  end

  opening = brade_get(variant_state, "brade_teker_rolls", Dict{String, Any}())
  brade_fill_scalar!(features, 56, brade_number(brade_get(opening, "white", 0)) / 6.0)
  brade_fill_scalar!(features, 57, brade_number(brade_get(opening, "black", 0)) / 6.0)
  brade_fill_scalar!(features, 58, brade_number(brade_get(variant_state, "game_number", 1)) / 7.0)
  brade_fill_scalar!(features, 59, brade_get(match, "is_over", false) == true ? 1.0 : 0.0)
  brade_fill_scalar!(features, 60, brade_get(match, "winner", "") == "white" ? 1.0 : 0.0)
  brade_fill_scalar!(features, 61, brade_get(match, "winner", "") == "black" ? 1.0 : 0.0)
  return features
end

function brade_match_utility(runtime)
  match = brade_get(runtime, "match", Dict{String, Any}())
  length = max(brade_number(brade_get(match, "length", 5)), 1.0)
  score = brade_get(match, "score", Dict{String, Any}())
  score_term = (brade_number(brade_get(score, "white", 0)) - brade_number(brade_get(score, "black", 0))) / (6.0 * length)
  winner = brade_string(brade_get(match, "winner", ""))
  winner_term = winner == "white" ? 1.0 : (winner == "black" ? -1.0 : 0.0)
  return 0.5 * score_term + 0.5 * winner_term
end

function brade_experiment(; smoke::Bool = false, repo_root::String = REPO_ROOT, device = DEFAULT_DEVICE, use_gpu::Bool = false, move_cap = nothing, num_iters = nothing, self_play_workers = nothing, arena_workers = nothing)
  resolved_device = resolve_device_backend(resolve_requested_device(device = device, use_gpu = use_gpu))
  NetworkType = network_type_for_device(resolved_device)
  hyper = netparams(device = resolved_device, network_type = NetworkType)
  gspec = BradeGameSpec(repo_root = repo_root, temp_max_game_length = move_cap)
  name = smoke ? "brade-smoke" : "brade"
  return Experiment(
    name,
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
    hyper,
    BENCHMARKS
  )
end

default_brade_experiment(; kwargs...) = brade_experiment(; smoke = false, kwargs...)
smoke_brade_experiment(; kwargs...) = brade_experiment(; smoke = true, kwargs...)

function brade_session_dir(_exp::Experiment)
  # This is a serving contract: the Julia trainer and the released bot must
  # resolve the same champion directory, regardless of CPU/GPU network layout.
  return joinpath(DEFAULT_SESSIONS_ROOT, BRADE_SESSION_LAYOUT_VERSION)
end

brade_champion_manifest_path(dir::String) = joinpath(dir, BRADE_CHAMPION_MANIFEST)

function publish_brade_champion!(dir::String, iteration::Int)
  isfile(joinpath(dir, AlphaZero.UserInterface.BESTNN_FILE)) || return false
  AlphaZero.UserInterface.write_json_atomic(
    brade_champion_manifest_path(dir),
    Dict("accepted" => true, "checkpoint" => "bestnn.data", "iteration" => iteration, "schema" => 1)
  )
  return true
end

function checkpoint_accepted(session)
  hasproperty(session, :report) || return false
  report = getproperty(session, :report)
  hasproperty(report, :iterations) || return false

  for iteration in getproperty(report, :iterations)
    hasproperty(iteration, :learning) || continue
    learning = getproperty(iteration, :learning)
    hasproperty(learning, :checkpoints) || continue
    any(checkpoint -> hasproperty(checkpoint, :success) && getproperty(checkpoint, :success), getproperty(learning, :checkpoints)) && return true
  end
  return false
end

function run_brade_train(; dir::Union{Nothing, String} = nothing, smoke::Bool = false, device = DEFAULT_DEVICE, use_gpu::Bool = false, reset_memory::Bool = false, move_cap = nothing, num_iters = nothing, self_play_workers = nothing, arena_workers = nothing)
  requested_device = resolve_requested_device(device = device, use_gpu = use_gpu)
  resolved_device = set_runtime_device!(requested_device)
  return with_bridge_mode_for_backend(resolved_device) do
    exp = brade_experiment(smoke = smoke, device = resolved_device, use_gpu = is_gpu_backend(resolved_device), move_cap = move_cap, num_iters = num_iters, self_play_workers = self_play_workers, arena_workers = arena_workers)
    session_dir = isnothing(dir) ? brade_session_dir(exp) : dir
    if reset_memory && reset_session_memory!(session_dir)
      @info "Reset Bräde replay buffer in $session_dir before training."
    end
    session = AlphaZero.Scripts.train(exp; dir = session_dir, autosave = true, save_intermediate = false)
    checkpoint_accepted(session) && publish_brade_champion!(session_dir, session.env.itc)
    return session
  end
end

run_brade_smoke(; kwargs...) = run_brade_train(; smoke = true, kwargs...)
