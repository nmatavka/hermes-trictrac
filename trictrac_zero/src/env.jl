const BASE_FEATURE_CHANNELS = 76
const BASE_FEATURE_SHAPE = (24, 1, BASE_FEATURE_CHANNELS)
const AECRIRE_LIKE_FEATURE_CHANNELS = 132
const AECRIRE_LIKE_FEATURE_SHAPE = (24, 1, AECRIRE_LIKE_FEATURE_CHANNELS)
const STRAGGLER_TIMEOUT_SECONDS_ENV = "TRICTRAC_ZERO_SELF_PLAY_TAIL_TIMEOUT_SECONDS"
const STRAGGLER_REMAINING_GAMES_ENV = "TRICTRAC_ZERO_SELF_PLAY_TAIL_REMAINING_GAMES"
const CHECKPOINT_STRAGGLER_TIMEOUT_SECONDS_ENV = "TRICTRAC_ZERO_ARENA_TAIL_TIMEOUT_SECONDS"
const CHECKPOINT_STRAGGLER_REMAINING_GAMES_ENV = "TRICTRAC_ZERO_ARENA_TAIL_REMAINING_GAMES"
const TEMP_MAX_GAME_LENGTH_ENV = "TRICTRAC_ZERO_TEMP_MAX_GAME_LENGTH"
const SCORE_MARGIN_DENOMINATOR_ENV = "TRICTRAC_ZERO_SCORE_MARGIN_DENOMINATOR"
const VALUE_TARGET_MODE_ENV = "TRICTRAC_ZERO_VALUE_TARGET_MODE"
const VALUE_TARGET_GAIN_ENV = "TRICTRAC_ZERO_VALUE_TARGET_GAIN"
const AECRIRE_SHAPING_WEIGHT_ENV = "TRICTRAC_ZERO_AECRIRE_SHAPING_WEIGHT"
const COMBINE_HONNEUR_WEIGHT_ENV = "TRICTRAC_ZERO_COMBINE_HONNEUR_WEIGHT"
const COMBINE_PARTIE_WEIGHT_ENV = "TRICTRAC_ZERO_COMBINE_PARTIE_WEIGHT"
const GSPEC_STORAGE_PREFIX = "trictraczero:"

function parse_nonnegative_int_env(name::String, default::Int)
  raw = get(ENV, name, string(default))
  try
    value = parse(Int, raw)
    value < 0 && throw(ArgumentError())
    return value
  catch
    error("$name must be a non-negative integer; got $(repr(raw)).")
  end
end

function parse_nonnegative_float_env(name::String, default::Float64)
  raw = get(ENV, name, string(default))
  try
    value = parse(Float64, raw)
    value < 0 && throw(ArgumentError())
    return value
  catch
    error("$name must be a non-negative number; got $(repr(raw)).")
  end
end

function parse_target_mode_env(name::String, default::String)
  raw = lowercase(strip(get(ENV, name, default)))
  raw in ("linear", "tanh") && return raw
  error("$name must be one of \"linear\" or \"tanh\"; got $(repr(raw)).")
end

const DEFAULT_STRAGGLER_TIMEOUT_SECONDS = 45.0
const DEFAULT_STRAGGLER_REMAINING_GAMES = 1
const DEFAULT_CHECKPOINT_STRAGGLER_TIMEOUT_SECONDS = 120.0
const DEFAULT_CHECKPOINT_STRAGGLER_REMAINING_GAMES = 1
const DEFAULT_TEMP_MAX_GAME_LENGTH = 620
const DEFAULT_SCORE_MARGIN_DENOMINATOR = 144.0
const DEFAULT_VALUE_TARGET_MODE = "tanh"
const DEFAULT_VALUE_TARGET_GAIN = 2.0
const DEFAULT_AECRIRE_SHAPING_WEIGHT = 0.15
const DEFAULT_COMBINE_HONNEUR_WEIGHT = 0.10
const DEFAULT_COMBINE_PARTIE_WEIGHT = 0.05
const AECRIRE_PARTIE_LENGTH_CHOICES = ("6", "8", "10", "12", "14", "16", "18", "20", "22", "24")

mutable struct PartieLengthSchedule
  lengths::Vector{String}
  next_index::Int
  lock::ReentrantLock
end

PartieLengthSchedule(lengths) =
  PartieLengthSchedule(String[length for length in lengths], 1, ReentrantLock())

const ACTIVE_PARTIE_LENGTH_SCHEDULE_LOCK = ReentrantLock()
const ACTIVE_PARTIE_LENGTH_SCHEDULES = Dict{String, PartieLengthSchedule}()

configured_straggler_timeout_seconds() =
  parse_nonnegative_float_env(STRAGGLER_TIMEOUT_SECONDS_ENV, DEFAULT_STRAGGLER_TIMEOUT_SECONDS)
configured_straggler_remaining_games() =
  parse_nonnegative_int_env(STRAGGLER_REMAINING_GAMES_ENV, DEFAULT_STRAGGLER_REMAINING_GAMES)
configured_checkpoint_straggler_timeout_seconds() =
  parse_nonnegative_float_env(CHECKPOINT_STRAGGLER_TIMEOUT_SECONDS_ENV, DEFAULT_CHECKPOINT_STRAGGLER_TIMEOUT_SECONDS)
configured_checkpoint_straggler_remaining_games() =
  parse_nonnegative_int_env(CHECKPOINT_STRAGGLER_REMAINING_GAMES_ENV, DEFAULT_CHECKPOINT_STRAGGLER_REMAINING_GAMES)
configured_temp_max_game_length() =
  parse_nonnegative_int_env(TEMP_MAX_GAME_LENGTH_ENV, DEFAULT_TEMP_MAX_GAME_LENGTH)
configured_score_margin_denominator() =
  parse_nonnegative_float_env(SCORE_MARGIN_DENOMINATOR_ENV, DEFAULT_SCORE_MARGIN_DENOMINATOR)
configured_value_target_mode() =
  parse_target_mode_env(VALUE_TARGET_MODE_ENV, DEFAULT_VALUE_TARGET_MODE)
configured_value_target_gain() =
  parse_nonnegative_float_env(VALUE_TARGET_GAIN_ENV, DEFAULT_VALUE_TARGET_GAIN)
configured_aecrire_shaping_weight() =
  parse_nonnegative_float_env(AECRIRE_SHAPING_WEIGHT_ENV, DEFAULT_AECRIRE_SHAPING_WEIGHT)
configured_combine_honneur_weight() =
  parse_nonnegative_float_env(COMBINE_HONNEUR_WEIGHT_ENV, DEFAULT_COMBINE_HONNEUR_WEIGHT)
configured_combine_partie_weight() =
  parse_nonnegative_float_env(COMBINE_PARTIE_WEIGHT_ENV, DEFAULT_COMBINE_PARTIE_WEIGHT)

function normalize_match_options(options)
  dict = Dict{String, Any}()
  for (key, value) in pairs(options)
    dict[string(key)] = value
  end
  return dict
end

struct TricTracGameSpec <: GI.AbstractGameSpec
  storage::String
end

function encode_gspec_storage(;
  repo_root::String,
  bridge_script::String,
  variant_id::AbstractString,
  match_options
)
  payload = Dict{String, Any}(
    "repo_root" => repo_root,
    "bridge_script" => bridge_script,
    "variant_id" => String(variant_id),
    "match_options" => normalize_match_options(match_options)
  )
  return GSPEC_STORAGE_PREFIX * JSON3.write(payload)
end

function decode_gspec_storage(storage::String)
  if startswith(storage, GSPEC_STORAGE_PREFIX)
    payload = JSON3.read(storage[(ncodeunits(GSPEC_STORAGE_PREFIX) + 1):end])
    return (
      repo_root = String(get(payload, "repo_root", REPO_ROOT)),
      bridge_script = String(get(payload, "bridge_script", BRIDGE_SCRIPT)),
      variant_id = String(get(payload, "variant_id", "trictrac_classique")),
      match_options = normalize_match_options(get(payload, "match_options", Dict{String, Any}()))
    )
  end

  # Legacy sessions stored only the repo root and implicitly meant classique without Margot.
  return (
    repo_root = storage,
    bridge_script = joinpath(storage, "priv", "training", "trictrac_bridge_stdio.exs"),
    variant_id = "trictrac_classique",
    match_options = Dict{String, Any}("margotEnabled" => false)
  )
end

function Base.getproperty(gspec::TricTracGameSpec, name::Symbol)
  if name === :storage
    return getfield(gspec, :storage)
  elseif name === :repo_root || name === :bridge_script || name === :variant_id || name === :match_options
    return getproperty(decode_gspec_storage(getfield(gspec, :storage)), name)
  end

  return getfield(gspec, name)
end

function Base.propertynames(::TricTracGameSpec, private::Bool = false)
  names = (:repo_root, :bridge_script, :variant_id, :match_options)
  return private ? (:storage, names...) : names
end

function TricTracGameSpec(;
  repo_root::String = REPO_ROOT,
  bridge_script::String = BRIDGE_SCRIPT,
  variant_id::AbstractString = "trictrac_classique",
  match_options = Dict{String, Any}("margotEnabled" => false)
)
  return TricTracGameSpec(encode_gspec_storage(
    repo_root = repo_root,
    bridge_script = bridge_script,
    variant_id = variant_id,
    match_options = match_options
  ))
end

mutable struct TricTracGameEnv <: GI.AbstractGameEnv
  spec::TricTracGameSpec
  bridge::BridgeClient
  state::TricTracState
  last_reward::Float64
end

function variant_family(variant_id::AbstractString)
  if variant_id == "trictrac_aecrire"
    return :aecrire
  elseif variant_id == "trictrac_combine"
    return :combine
  else
    return :classical
  end
end

variant_family(gspec::TricTracGameSpec) = variant_family(gspec.variant_id)
aecrire_like_variant(gspec::TricTracGameSpec) = variant_family(gspec) in (:aecrire, :combine)
combine_variant(gspec::TricTracGameSpec) = variant_family(gspec) == :combine

partie_length_schedule_key(gspec::TricTracGameSpec) = gspec.storage

function install_partie_length_schedule!(
  gspec::TricTracGameSpec;
  lengths = AECRIRE_PARTIE_LENGTH_CHOICES
)
  lock(ACTIVE_PARTIE_LENGTH_SCHEDULE_LOCK)
  try
    ACTIVE_PARTIE_LENGTH_SCHEDULES[partie_length_schedule_key(gspec)] = PartieLengthSchedule(lengths)
  finally
    unlock(ACTIVE_PARTIE_LENGTH_SCHEDULE_LOCK)
  end
  return nothing
end

function remove_partie_length_schedule!(gspec::TricTracGameSpec)
  lock(ACTIVE_PARTIE_LENGTH_SCHEDULE_LOCK)
  try
    pop!(ACTIVE_PARTIE_LENGTH_SCHEDULES, partie_length_schedule_key(gspec), nothing)
  finally
    unlock(ACTIVE_PARTIE_LENGTH_SCHEDULE_LOCK)
  end
  return nothing
end

function active_partie_length_schedule(gspec::TricTracGameSpec)
  lock(ACTIVE_PARTIE_LENGTH_SCHEDULE_LOCK)
  try
    return get(ACTIVE_PARTIE_LENGTH_SCHEDULES, partie_length_schedule_key(gspec), nothing)
  finally
    unlock(ACTIVE_PARTIE_LENGTH_SCHEDULE_LOCK)
  end
end

function next_partie_length!(schedule::PartieLengthSchedule)
  lock(schedule.lock)
  try
    length_choice = schedule.lengths[schedule.next_index]
    schedule.next_index = schedule.next_index == length(schedule.lengths) ? 1 : schedule.next_index + 1
    return length_choice
  finally
    unlock(schedule.lock)
  end
end

function resolved_match_options_for_new_game(gspec::TricTracGameSpec)
  options = copy(gspec.match_options)
  if aecrire_like_variant(gspec)
    schedule = active_partie_length_schedule(gspec)
    if !isnothing(schedule)
      options["aEcrirePartieLength"] = next_partie_length!(schedule)
    end
  end
  return options
end

function feature_shape(gspec::TricTracGameSpec)
  return aecrire_like_variant(gspec) ? AECRIRE_LIKE_FEATURE_SHAPE : BASE_FEATURE_SHAPE
end

GI.spec(game::TricTracGameEnv) = game.spec

GI.two_players(::TricTracGameSpec) = true
GI.actions(::TricTracGameSpec) = ACTION_CATALOG
GI.action_type(::TricTracGameSpec) = TricTracAction
GI.state_type(::TricTracGameSpec) = TricTracState
GI.state_dim(gspec::TricTracGameSpec) = feature_shape(gspec)
GI.num_actions(::TricTracGameSpec) = length(ACTION_CATALOG)

function GI.init(gspec::TricTracGameSpec)
  bridge = bridge_client(gspec)
  response = new_game!(bridge, gspec)
  state = TricTracState(response["state"])
  reward = initial_white_reward(gspec, state; fallback = Float64(response["reward"]))
  return TricTracGameEnv(gspec, bridge, state, reward)
end

function GI.init(gspec::TricTracGameSpec, state::TricTracState)
  bridge = bridge_client(gspec)
  return TricTracGameEnv(gspec, bridge, state, 0.0)
end

function GI.clone(game::TricTracGameEnv)
  return TricTracGameEnv(game.spec, game.bridge, game.state, 0.0)
end

function GI.set_state!(game::TricTracGameEnv, state::TricTracState)
  game.state = state
  game.last_reward = 0.0
  return nothing
end

GI.current_state(game::TricTracGameEnv) = game.state
GI.game_terminated(game::TricTracGameEnv) = state_terminal(game.state)
GI.white_playing(game::TricTracGameEnv) = state_white_to_play(game.state)
GI.white_reward(game::TricTracGameEnv) = game.last_reward
GI.symmetries(::TricTracGameSpec, ::TricTracState) = Tuple{TricTracState, Vector{Int}}[]
GI.read_state(::TricTracGameSpec) = nothing

GI.available_actions(game::TricTracGameEnv) = state_catalog_actions(game.state)

function GI.actions_mask(game::TricTracGameEnv)
  mask = falses(length(ACTION_CATALOG))

  for action in state_catalog_actions(game.state)
    mask[ACTION_INDEX[action]] = true
  end

  return mask
end

function GI.play!(game::TricTracGameEnv, action::TricTracAction)
  previous_state = game.state
  raw_action = catalog_action_to_bridge_action(action, state_white_to_play(game.state))
  response = step!(game.bridge, game.spec, game.state, raw_action)
  game.state = TricTracState(response["state"])
  game.last_reward = transition_white_reward(
    game.spec,
    previous_state,
    game.state;
    fallback = Float64(response["reward"])
  )
  return nothing
end

function GI.heuristic_value(game::TricTracGameEnv)
  runtime = state_runtime(game.state)
  myself, opponent = perspective_colors(game.state)
  if aecrire_like_variant(game.spec)
    raw =
      if combine_variant(game.spec)
        combine_scalar_utility(runtime, myself, opponent)
      else
        official_margin(runtime, myself, opponent) +
        configured_aecrire_shaping_weight() * aecrire_potential(runtime, myself, opponent)
      end
    return aecrire_like_value_target(raw, runtime)
  end

  return shape_margin_value(score_margin_unit(score_total(runtime, myself) - score_total(runtime, opponent)))
end

function AlphaZero.self_play_straggler_policy(gspec::TricTracGameSpec)
  if aecrire_like_variant(gspec) &&
     !any(haskey(ENV, name) for name in (STRAGGLER_TIMEOUT_SECONDS_ENV, STRAGGLER_REMAINING_GAMES_ENV))
    return nothing
  end
  timeout_seconds = configured_straggler_timeout_seconds()
  remaining_games = configured_straggler_remaining_games()
  if timeout_seconds <= 0 || remaining_games <= 0
    return nothing
  end
  return AlphaZero.SelfPlayStragglerPolicy(
    timeout_seconds = timeout_seconds,
    remaining_games = remaining_games
  )
end

function AlphaZero.checkpoint_straggler_policy(gspec::TricTracGameSpec)
  if aecrire_like_variant(gspec) &&
     !any(haskey(ENV, name) for name in (CHECKPOINT_STRAGGLER_TIMEOUT_SECONDS_ENV, CHECKPOINT_STRAGGLER_REMAINING_GAMES_ENV))
    return nothing
  end
  timeout_seconds = configured_checkpoint_straggler_timeout_seconds()
  remaining_games = configured_checkpoint_straggler_remaining_games()
  if timeout_seconds <= 0 || remaining_games <= 0
    return nothing
  end
  return AlphaZero.SelfPlayStragglerPolicy(
    timeout_seconds = timeout_seconds,
    remaining_games = remaining_games
  )
end

function AlphaZero.max_game_length(gspec::TricTracGameSpec)
  if aecrire_like_variant(gspec) && !haskey(ENV, TEMP_MAX_GAME_LENGTH_ENV)
    return nothing
  end
  cap = configured_temp_max_game_length()
  cap > 0 || return nothing
  return cap
end

function AlphaZero.self_play_step!(
  env::AlphaZero.Env{TricTracGameSpec, N, TricTracState},
  handler
) where {N}
  params = env.params.self_play
  AlphaZero.Handlers.self_play_started(handler)
  make_oracle() =
    AlphaZero.Network.copy(env.bestnn, on_gpu = params.sim.use_gpu, test_mode = true)
  simulator = AlphaZero.Simulator(make_oracle, AlphaZero.self_play_measurements) do oracle
    return AlphaZero.MctsPlayer(env.gspec, oracle, params.mcts)
  end

  schedule_installed = false
  if aecrire_like_variant(env.gspec)
    install_partie_length_schedule!(env.gspec)
    schedule_installed = true
  end

  try
    results, elapsed = @timed AlphaZero.simulate_distributed(
      simulator,
      env.gspec,
      params.sim,
      game_simulated = () -> AlphaZero.Handlers.game_played(handler),
      straggler_policy = AlphaZero.self_play_straggler_policy(env.gspec)
    )

    AlphaZero.new_batch!(env.memory)
    for x in results
      AlphaZero.push_trace!(env.memory, x.trace, params.mcts.gamma)
    end

    dropped_games = params.sim.num_games - length(results)
    if dropped_games > 0
      @warn "$dropped_games self-play game(s) were aborted before completion and omitted from the replay buffer."
    end

    speed = iszero(elapsed) ? 0.0 : AlphaZero.cur_batch_size(env.memory) / elapsed
    edepth = isempty(results) ? 0.0 : sum(x.edepth for x in results) / length(results)
    mem_footprint = isempty(results) ? 0 : maximum(x.mem for x in results)
    memsize, memdistinct = AlphaZero.simple_memory_stats(env)
    report = AlphaZero.Report.SelfPlay(
      speed, edepth, mem_footprint, memsize, memdistinct
    )
    AlphaZero.Handlers.self_play_finished(handler, report)
    return report
  finally
    schedule_installed && remove_partie_length_schedule!(env.gspec)
  end
end

function GI.vectorize_state(gspec::TricTracGameSpec, state::TricTracState)
  features = zeros(Float32, feature_shape(gspec))
  runtime = state_runtime(state)
  white_to_play = state_white_to_play(state)
  myself, opponent = perspective_colors(state)

  board = runtime["board"]
  turn = get(get(runtime, "trictrac", Dict{String, Any}()), "turn", Dict{String, Any}())
  start_board = get(turn, "start_board", nothing)
  opening = get(get(runtime, "trictrac", Dict{String, Any}()), "opening", Dict{String, Any}())

  add_board_planes!(features, 1, board, white_to_play, myself, opponent)
  add_board_planes!(features, 9, start_board, white_to_play, myself, opponent)

  fill_scalar!(features, 17, bar_for(board, myself) / 15)
  fill_scalar!(features, 18, bar_for(board, opponent) / 15)
  fill_scalar!(features, 19, outside_for(board, myself) / 15)
  fill_scalar!(features, 20, outside_for(board, opponent) / 15)
  fill_scalar!(features, 21, points_for(runtime, myself) / 11)
  fill_scalar!(features, 22, points_for(runtime, opponent) / 11)
  fill_scalar!(features, 23, trous_for(runtime, myself) / 12)
  fill_scalar!(features, 24, trous_for(runtime, opponent) / 12)
  fill_scalar!(features, 25, bool01(score_flag(runtime, myself, "doubling_active")))
  fill_scalar!(features, 26, bool01(score_flag(runtime, opponent, "doubling_active")))
  fill_scalar!(features, 27, bool01(score_flag(runtime, myself, "bredouille")))
  fill_scalar!(features, 28, bool01(score_flag(runtime, opponent, "bredouille")))
  fill_scalar!(features, 29, bool01(score_flag(runtime, myself, "grande_bredouille")))
  fill_scalar!(features, 30, bool01(score_flag(runtime, opponent, "grande_bredouille")))
  fill_scalar!(features, 31, bool01(score_flag(runtime, myself, "etendard")))
  fill_scalar!(features, 32, bool01(score_flag(runtime, opponent, "etendard")))

  dice = get(runtime, "dice", nothing)
  dice_values = dice === nothing ? Any[] : get(dice, "values", Any[])
  fill_scalar!(features, 33, die_value(dice_values, 1) / 6)
  fill_scalar!(features, 34, die_value(dice_values, 2) / 6)

  moves_left = dice === nothing ? Any[] : get(dice, "moves_left", Any[])
  for die in 1:6
    fill_scalar!(features, 34 + die, count(==(die), moves_left) / 2)
  end

  fill_scalar!(features, 41, bool01(get(opening, "jan_rencontre_checked", false)))
  fill_scalar!(features, 42, get(opening, "releve_count", 0) / 12)
  fill_scalar!(features, 43, coups_by_type(opening, myself) / 20)
  fill_scalar!(features, 44, coups_by_type(opening, opponent) / 20)
  fill_scalar!(features, 45, depart_done(opening, myself, "two_tables"))
  fill_scalar!(features, 46, depart_done(opening, myself, "meseas"))
  fill_scalar!(features, 47, depart_done(opening, myself, "six_tables"))
  fill_scalar!(features, 48, depart_done(opening, opponent, "two_tables"))
  fill_scalar!(features, 49, depart_done(opening, opponent, "meseas"))
  fill_scalar!(features, 50, depart_done(opening, opponent, "six_tables"))

  first_type = get(opening, "first_type", nothing)
  fill_scalar!(features, 51, bool01(first_type == myself))
  fill_scalar!(features, 52, bool01(first_type == opponent))
  fill_scalar!(features, 53, bool01(isnothing(first_type)))

  first_values = get(opening, "first_values", Any[])
  fill_scalar!(features, 54, die_value(first_values, 1) / 6)
  fill_scalar!(features, 55, die_value(first_values, 2) / 6)

  score_by_type = get(turn, "score_by_type", Dict{String, Any}())
  trous_before = get(turn, "trous_before", Dict{String, Any}())
  trous_after = get(turn, "trous_after", Dict{String, Any}())
  fill_scalar!(features, 56, get(score_by_type, myself, 0) / 12)
  fill_scalar!(features, 57, get(score_by_type, opponent, 0) / 12)
  fill_scalar!(features, 58, get(trous_before, myself, 0) / 12)
  fill_scalar!(features, 59, get(trous_before, opponent, 0) / 12)
  fill_scalar!(features, 60, get(trous_after, myself, 0) / 12)
  fill_scalar!(features, 61, get(trous_after, opponent, 0) / 12)
  fill_scalar!(features, 62, bool01(get(turn, "can_reprise", false)))
  fill_scalar!(features, 63, bool01(get(turn, "pile_misere_pending", false)))
  fill_scalar!(features, 64, bool01(!isnothing(get(turn, "pile_misere_candidate", nothing))))

  obligations = get(turn, "obligations", Dict{String, Any}())
  must_fill = Set(String.(get(obligations, "must_fill", Any[])))
  must_conserve = Set(map(candidate_key, get(obligations, "must_conserve", Any[])))
  fill_scalar!(features, 65, bool01("petit" in must_fill))
  fill_scalar!(features, 66, bool01("grand" in must_fill))
  fill_scalar!(features, 67, bool01("retour" in must_fill))
  fill_scalar!(features, 68, bool01("petit" in must_conserve))
  fill_scalar!(features, 69, bool01("grand" in must_conserve))
  fill_scalar!(features, 70, bool01("retour" in must_conserve))

  phase = state_phase(state)
  fill_scalar!(features, 71, bool01(phase == "roll"))
  fill_scalar!(features, 72, bool01(phase == "move"))
  fill_scalar!(features, 73, bool01(phase == "decision"))
  fill_scalar!(features, 74, bool01(phase == "terminal"))
  fill_scalar!(features, 75, bool01(white_to_play))
  fill_scalar!(features, 76, get(runtime, "turn_number", 0) / 100)

  if aecrire_like_variant(gspec)
    fill_aecrire_like_features!(features, runtime, gspec, myself, opponent)
  end

  return features
end

function GI.render(game::TricTracGameEnv)
  runtime = state_runtime(game.state)
  myself, opponent = perspective_colors(game.state)
  println("phase=", state_phase(game.state), " turn=", get(runtime, "turn_number", 0))
  println("white_to_play=", state_white_to_play(game.state), " reward=", game.last_reward)
  println(
    "score: ",
    myself,
    " trous=",
    trous_for(runtime, myself),
    " points=",
    points_for(runtime, myself),
    " | ",
    opponent,
    " trous=",
    trous_for(runtime, opponent),
    " points=",
    points_for(runtime, opponent)
  )
  dice = get(runtime, "dice", nothing)
  println("dice=", dice === nothing ? "none" : dice)
end

GI.action_string(::TricTracGameSpec, action::TricTracAction) = action_label(action)
GI.parse_action(::TricTracGameSpec, str::String) = parse_action_label(str)

function perspective_colors(state::TricTracState)
  return state_white_to_play(state) ? ("white", "black") : ("black", "white")
end

function initial_white_reward(
  gspec::TricTracGameSpec,
  state::TricTracState;
  fallback::Float64 = 0.0
)
  if aecrire_like_variant(gspec)
    return 0.0
  end
  return terminal_white_reward(gspec, state; fallback)
end

function transition_white_reward(
  gspec::TricTracGameSpec,
  previous_state::TricTracState,
  next_state::TricTracState;
  fallback::Float64 = 0.0
)
  family = variant_family(gspec)
  if family == :aecrire
    return aecrire_step_reward(state_runtime(previous_state), state_runtime(next_state))
  elseif family == :combine
    return combine_step_reward(state_runtime(previous_state), state_runtime(next_state))
  else
    return terminal_white_reward(gspec, next_state; fallback)
  end
end

function add_board_planes!(features, start_channel::Int, board, white_to_play::Bool, myself::String, opponent::String)
  if board === nothing
    return features
  end

  for norm_point in 0:23
    raw_point = white_to_play ? norm_point : 23 - norm_point
    point = board["points"][raw_point + 1]
    self_count = get(point, myself, 0)
    opp_count = get(point, opponent, 0)

    for level in 1:4
      features[norm_point + 1, 1, start_channel + level - 1] = self_count >= level ? 1f0 : 0f0
      features[norm_point + 1, 1, start_channel + 4 + level - 1] = opp_count >= level ? 1f0 : 0f0
    end
  end

  return features
end

function fill_scalar!(features, channel::Int, value)
  features[:, :, channel] .= Float32(value)
  return features
end

bool01(value) = value ? 1.0f0 : 0.0f0

safe_ratio(value, scale) = iszero(scale) ? 0.0 : Float64(value) / Float64(scale)

function fill_aecrire_like_features!(features, runtime, gspec::TricTracGameSpec, myself::String, opponent::String)
  trictrac = get(runtime, "trictrac", Dict{String, Any}())
  track = get(trictrac, "track_aecrire", Dict{String, Any}())
  current_coup = get(track, "current_coup", Dict{String, Any}())
  current_partie = get(get(trictrac, "track_classique_honneurs", Dict{String, Any}()), "current_partie", Dict{String, Any}())
  suspension = get(trictrac, "suspension_state", Dict{String, Any}())
  last_partie_result = get(get(trictrac, "track_classique_honneurs", Dict{String, Any}()), "last_partie_result", nothing)
  partie_length = aecrire_partie_length(runtime)
  total_scale = settlement_total_scale(runtime)
  margin_scale = settlement_margin_scale(runtime)
  honneur_scale = max(1.0, Float64(partie_length))
  suspended_track = get(suspension, "suspended_track", nothing)
  frozen_by = normalize_color_name(get(suspension, "frozen_by", nothing))
  last_partie_class = get(last_partie_result isa Dict ? last_partie_result : Dict{String, Any}(), "class", nothing)
  last_partie_winner = normalize_color_name(get(last_partie_result isa Dict ? last_partie_result : Dict{String, Any}(), "winner", nothing))
  channel = 77

  fill_scalar!(features, channel, bool01(variant_family(gspec) == :aecrire)); channel += 1
  fill_scalar!(features, channel, bool01(variant_family(gspec) == :combine)); channel += 1
  fill_scalar!(features, channel, bool01(margot_enabled(gspec))); channel += 1
  fill_scalar!(features, channel, safe_ratio(official_total(runtime, myself), total_scale)); channel += 1
  fill_scalar!(features, channel, safe_ratio(official_total(runtime, opponent), total_scale)); channel += 1
  fill_scalar!(features, channel, safe_ratio(official_margin(runtime, myself, opponent), margin_scale)); channel += 1
  fill_scalar!(features, channel, safe_ratio(color_map_get(current_coup, "trous", myself), 12)); channel += 1
  fill_scalar!(features, channel, safe_ratio(color_map_get(current_coup, "trous", opponent), 12)); channel += 1
  fill_scalar!(features, channel, safe_ratio(color_map_get(current_coup, "run_trous", myself), 12)); channel += 1
  fill_scalar!(features, channel, safe_ratio(color_map_get(current_coup, "run_trous", opponent), 12)); channel += 1
  fill_scalar!(features, channel, bool01(color_map_bool(current_coup, "legal_exit_by", myself))); channel += 1
  fill_scalar!(features, channel, bool01(color_map_bool(current_coup, "legal_exit_by", opponent))); channel += 1
  fill_scalar!(features, channel, bool01(color_map_bool(current_coup, "obligation_reached_by", myself))); channel += 1
  fill_scalar!(features, channel, bool01(color_map_bool(current_coup, "obligation_reached_by", opponent))); channel += 1
  fill_scalar!(features, channel, bool01(color_map_bool(current_coup, "sans_lever_by", myself))); channel += 1
  fill_scalar!(features, channel, bool01(color_map_bool(current_coup, "sans_lever_by", opponent))); channel += 1
  fill_scalar!(features, channel, bool01(color_map_bool(current_coup, "ever_lifted_by", myself))); channel += 1
  fill_scalar!(features, channel, bool01(color_map_bool(current_coup, "ever_lifted_by", opponent))); channel += 1
  fill_scalar!(features, channel, safe_ratio(interrupted_run_trous(current_coup, myself), 12)); channel += 1
  fill_scalar!(features, channel, safe_ratio(interrupted_run_trous(current_coup, opponent), 12)); channel += 1
  fill_scalar!(features, channel, safe_ratio(color_map_get(track, "marques", myself), partie_length)); channel += 1
  fill_scalar!(features, channel, safe_ratio(color_map_get(track, "marques", opponent), partie_length)); channel += 1
  fill_scalar!(features, channel, safe_ratio(color_map_get(track, "points_total", myself), total_scale)); channel += 1
  fill_scalar!(features, channel, safe_ratio(color_map_get(track, "points_total", opponent), total_scale)); channel += 1
  fill_scalar!(features, channel, safe_ratio(color_map_get(track, "marque_streak", myself), partie_length)); channel += 1
  fill_scalar!(features, channel, safe_ratio(color_map_get(track, "marque_streak", opponent), partie_length)); channel += 1
  fill_scalar!(features, channel, bool01(color_map_bool(track, "petite_bredouille", myself))); channel += 1
  fill_scalar!(features, channel, bool01(color_map_bool(track, "petite_bredouille", opponent))); channel += 1
  fill_scalar!(features, channel, bool01(color_map_bool(track, "grande_bredouille", myself))); channel += 1
  fill_scalar!(features, channel, bool01(color_map_bool(track, "grande_bredouille", opponent))); channel += 1
  fill_scalar!(features, channel, safe_ratio(get(track, "coups_played", 0), partie_length)); channel += 1
  fill_scalar!(features, channel, safe_ratio(get(track, "coup_count", 0), partie_length)); channel += 1
  fill_scalar!(features, channel, safe_ratio(partie_length, 24)); channel += 1
  fill_scalar!(features, channel, safe_ratio(get(track, "refait_streak", 0), partie_length)); channel += 1
  fill_scalar!(features, channel, bool01(normalize_color_name(get(track, "coup_starter", nothing)) == myself)); channel += 1
  fill_scalar!(features, channel, bool01(normalize_color_name(get(track, "coup_starter", nothing)) == opponent)); channel += 1
  fill_scalar!(features, channel, bool01(isnothing(normalize_color_name(get(track, "coup_starter", nothing))))); channel += 1
  fill_scalar!(features, channel, safe_ratio(combine_honneurs(runtime, myself), honneur_scale)); channel += 1
  fill_scalar!(features, channel, safe_ratio(combine_honneurs(runtime, opponent), honneur_scale)); channel += 1
  fill_scalar!(features, channel, safe_ratio(combine_honneurs(runtime, myself) - combine_honneurs(runtime, opponent), honneur_scale)); channel += 1
  fill_scalar!(features, channel, safe_ratio(color_map_get(current_partie, "trous", myself), 12)); channel += 1
  fill_scalar!(features, channel, safe_ratio(color_map_get(current_partie, "trous", opponent), 12)); channel += 1
  fill_scalar!(features, channel, bool01(color_map_bool(current_partie, "uninterrupted_by", myself))); channel += 1
  fill_scalar!(features, channel, bool01(color_map_bool(current_partie, "uninterrupted_by", opponent))); channel += 1
  fill_scalar!(features, channel, bool01(get(suspension, "resume_pending", false))); channel += 1
  fill_scalar!(features, channel, bool01(suspended_track == "classique")); channel += 1
  fill_scalar!(features, channel, bool01(suspended_track == "a_ecrire")); channel += 1
  fill_scalar!(features, channel, bool01(frozen_by == myself)); channel += 1
  fill_scalar!(features, channel, bool01(frozen_by == opponent)); channel += 1
  fill_scalar!(features, channel, bool01(last_partie_class == "simple")); channel += 1
  fill_scalar!(features, channel, bool01(last_partie_class == "double")); channel += 1
  fill_scalar!(features, channel, bool01(last_partie_class == "triple")); channel += 1
  fill_scalar!(features, channel, bool01(last_partie_class == "quadruple")); channel += 1
  fill_scalar!(features, channel, bool01(isnothing(last_partie_class))); channel += 1
  fill_scalar!(features, channel, bool01(last_partie_winner == myself)); channel += 1
  fill_scalar!(features, channel, bool01(last_partie_winner == opponent)); channel += 1

  @assert channel - 1 == AECRIRE_LIKE_FEATURE_CHANNELS
  return features
end

function bar_for(board, color::String)
  board === nothing && return 0
  return get(get(board, "bar", Dict{String, Any}()), color, 0)
end

function outside_for(board, color::String)
  board === nothing && return 0
  return get(get(board, "outside", Dict{String, Any}()), color, 0)
end

function score_entry(runtime, color::String)
  trictrac = get(runtime, "trictrac", Dict{String, Any}())
  score = get(trictrac, "score", Any[])
  if length(score) >= 2
    return color == "white" ? score[1] : score[2]
  end
  return Dict{String, Any}()
end

score_total(runtime, color::String) = 12.0 * trous_for(runtime, color) + points_for(runtime, color)
white_score_margin(runtime) = score_total(runtime, "white") - score_total(runtime, "black")

function score_margin_unit(value)
  denom = configured_score_margin_denominator()
  denom > 0 || return 0.0
  return clamp(Float64(value) / denom, -1.0, 1.0)
end

function shape_margin_value(value)
  x = clamp(Float64(value), -1.0, 1.0)
  mode = configured_value_target_mode()
  if mode == "linear"
    return x
  end

  gain = configured_value_target_gain()
  gain <= 0 && return x
  scale = tanh(gain)
  iszero(scale) && return x
  return tanh(gain * x) / scale
end

function terminal_white_reward(
  gspec::TricTracGameSpec,
  state::TricTracState;
  fallback::Float64 = 0.0
)
  state_terminal(state) || return 0.0
  runtime = state_runtime(state)
  isempty(runtime) && return clamp(fallback, -1.0, 1.0)
  aecrire_like_variant(gspec) && return clamp(fallback, -1.0, 1.0)
  return shape_margin_value(score_margin_unit(white_score_margin(runtime)))
end

points_for(runtime, color::String) = get(score_entry(runtime, color), "points", 0)
trous_for(runtime, color::String) = get(score_entry(runtime, color), "trous", 0)
score_flag(runtime, color::String, key::String) = get(score_entry(runtime, color), key, false)
normalize_color_name(value) = value in ("white", :white) ? "white" : value in ("black", :black) ? "black" : nothing

function color_map_get(container, key::String, color::String, default = 0)
  mapping = get(container, key, Dict{String, Any}())
  return get(mapping, color, default)
end

function color_map_bool(container, key::String, color::String)
  return Bool(get(get(container, key, Dict{String, Any}()), color, false))
end

function interrupted_run_trous(current_coup, color::String)
  entry = get(get(current_coup, "interrupted_run_by", Dict{String, Any}()), color, nothing)
  if entry isa Dict
    return get(entry, "trous", 0)
  end
  return 0
end

trictrac_state(runtime) = get(runtime, "trictrac", Dict{String, Any}())

function aecrire_partie_length(runtime)
  track = get(trictrac_state(runtime), "track_aecrire", Dict{String, Any}())
  return max(1, Int(get(track, "partie_length", 16)))
end

settlement_margin_scale(runtime) = max(1.0, 4.0 * aecrire_partie_length(runtime))
settlement_total_scale(runtime) = max(24.0, 8.0 * aecrire_partie_length(runtime))

function official_total(runtime, color::String)
  ledger = get(trictrac_state(runtime), "settlement_ledger", Dict{String, Any}())
  entry = get(ledger, color, Dict{String, Any}())
  return get(entry, "final_total", 0)
end

official_margin(runtime) = official_total(runtime, "white") - official_total(runtime, "black")
official_margin(runtime, myself::String, opponent::String) = official_total(runtime, myself) - official_total(runtime, opponent)

function aecrire_potential(runtime, myself::String, opponent::String)
  track = get(trictrac_state(runtime), "track_aecrire", Dict{String, Any}())
  current_coup = get(track, "current_coup", Dict{String, Any}())
  trous_margin = color_map_get(current_coup, "trous", myself) - color_map_get(current_coup, "trous", opponent)
  run_margin = color_map_get(current_coup, "run_trous", myself) - color_map_get(current_coup, "run_trous", opponent)
  exit_margin = bool01(color_map_bool(current_coup, "legal_exit_by", myself)) - bool01(color_map_bool(current_coup, "legal_exit_by", opponent))
  return Float64(trous_margin) + 0.5 * Float64(run_margin) + Float64(exit_margin)
end

function aecrire_step_reward(before_runtime, after_runtime)
  Δofficial = official_margin(after_runtime) - official_margin(before_runtime)
  Δphi = aecrire_potential(after_runtime, "white", "black") - aecrire_potential(before_runtime, "white", "black")
  return Float64(Δofficial) + configured_aecrire_shaping_weight() * Δphi
end

function combine_honneurs(runtime, color::String)
  track = get(trictrac_state(runtime), "track_classique_honneurs", Dict{String, Any}())
  return color_map_get(track, "honneurs", color)
end

function combine_partie_progress(runtime, myself::String, opponent::String)
  track = get(trictrac_state(runtime), "track_classique_honneurs", Dict{String, Any}())
  current_partie = get(track, "current_partie", Dict{String, Any}())
  trous_margin = safe_ratio(
    color_map_get(current_partie, "trous", myself) - color_map_get(current_partie, "trous", opponent),
    12
  )
  uninterrupted_margin =
    bool01(color_map_bool(current_partie, "uninterrupted_by", myself)) -
    bool01(color_map_bool(current_partie, "uninterrupted_by", opponent))
  return trous_margin + 0.25 * uninterrupted_margin
end

function combine_scalar_utility(runtime, myself::String, opponent::String)
  official = official_margin(runtime, myself, opponent)
  honneurs = combine_honneurs(runtime, myself) - combine_honneurs(runtime, opponent)
  partie = combine_partie_progress(runtime, myself, opponent)
  return Float64(official) +
         configured_combine_honneur_weight() * Float64(honneurs) +
         configured_combine_partie_weight() * Float64(partie)
end

function combine_step_reward(before_runtime, after_runtime)
  Δofficial = official_margin(after_runtime) - official_margin(before_runtime)
  Δhonneurs =
    (combine_honneurs(after_runtime, "white") - combine_honneurs(after_runtime, "black")) -
    (combine_honneurs(before_runtime, "white") - combine_honneurs(before_runtime, "black"))
  Δpartie =
    combine_partie_progress(after_runtime, "white", "black") -
    combine_partie_progress(before_runtime, "white", "black")
  return Float64(Δofficial) +
         configured_combine_honneur_weight() * Float64(Δhonneurs) +
         configured_combine_partie_weight() * Float64(Δpartie)
end

function aecrire_like_value_target(value, runtime)
  scale = settlement_margin_scale(runtime)
  return tanh(Float64(value) / scale)
end

function value_target(gspec::TricTracGameSpec, state::TricTracState, raw_return::Float64)
  if aecrire_like_variant(gspec)
    return aecrire_like_value_target(raw_return, state_runtime(state))
  end
  return raw_return
end

margot_enabled(gspec::TricTracGameSpec) = Bool(get(gspec.match_options, "margotEnabled", false))

die_value(::Nothing, ::Int) = 0
die_value(values, index::Int) = length(values) >= index ? values[index] : 0
coups_by_type(opening, color::String) = get(get(opening, "coups_by_type", Dict{String, Any}()), color, 0)

function depart_done(opening, color::String, key::String)
  depart = get(get(opening, "depart_done_by_type", Dict{String, Any}()), color, Dict{String, Any}())
  return bool01(get(depart, key, false))
end

function candidate_key(candidate)
  if candidate isa Dict
    return String(get(candidate, "key", ""))
  end
  return ""
end

function AlphaZero.push_trace!(
  mem::AlphaZero.MemoryBuffer{TricTracGameSpec, TricTracState},
  trace,
  gamma
)
  n = length(trace)
  wr = 0.0
  for i in reverse(1:n)
    wr = gamma * wr + trace.rewards[i]
    s = trace.states[i]
    π = trace.policies[i]
    wp = GI.white_playing(GI.init(mem.gspec, s))
    raw_target = wp ? wr : -wr
    z = value_target(mem.gspec, s, raw_target)
    t = float(n - i + 1)
    push!(mem.buf, AlphaZero.TrainingSample(s, π, z, t, 1))
  end
  mem.cur_batch_size += n
end

const MCTS_FOOTPRINT_CACHE = Dict{Tuple{String, String}, Int}()

function AlphaZero.MCTS.memory_footprint_per_node(gspec::TricTracGameSpec)
  key = (gspec.repo_root, gspec.bridge_script)
  return get!(MCTS_FOOTPRINT_CACHE, key) do
    state_size = Base.summarysize(GI.current_state(GI.init(gspec)))
    stats_arity = estimated_sparse_stats_arity(gspec)
    size_key = 2 * (state_size + sizeof(Int))
    dummy_stats = AlphaZero.MCTS.StateInfo([
      AlphaZero.MCTS.ActionStats(0, 0, 0) for _ in 1:stats_arity
    ], 0)
    size_key + Base.summarysize(dummy_stats)
  end
end

function estimated_sparse_stats_arity(gspec::TricTracGameSpec; max_states::Int = 64)
  counts = Int[]
  game = GI.init(gspec)
  while length(counts) < max_states
    if GI.game_terminated(game)
      game = GI.init(gspec)
      continue
    end
    actions = GI.available_actions(game)
    push!(counts, length(actions))
    index = mod1(length(counts), length(actions))
    GI.play!(game, actions[index])
  end
  return max(1, ceil(Int, sum(counts) / length(counts)))
end
