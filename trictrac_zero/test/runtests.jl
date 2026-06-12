using Test
using Random
using TricTracZero
using AlphaZero
import AlphaZero.GI
import AlphaZero.UserInterface

include(joinpath(@__DIR__, "..", "scripts", "cpu_config.jl"))

function tactical_off_config()
  return Dict(
    "enabled" => false,
    "horizon_own_turns" => 0,
    "reward_weight" => 0.0,
    "heuristic_weight" => 0.0,
    "version" => "classique-tactical-v3"
  )
end

classique_test_spec() = TricTracGameSpec(tactical_config = tactical_off_config())

function dense_available_actions(game)
  return GI.actions(GI.spec(game))[GI.actions_mask(game)]
end

function sample_states(spec; n::Int, seed::Int = 1)
  Random.seed!(seed)
  states = TricTracState[]
  game = GI.init(spec)

  while length(states) < n
    GI.game_terminated(game) && (game = GI.init(spec); continue)
    push!(states, GI.current_state(game))
    GI.play!(game, rand(GI.available_actions(game)))
  end

  return states
end

function sample_training_examples(spec; n::Int, seed::Int = 1)
  states = sample_states(spec; n = n, seed = seed)
  return [
    AlphaZero.TrainingSample(
      state,
      fill(
        1.0 / length(TricTracZero.state_catalog_actions(state)),
        length(TricTracZero.state_catalog_actions(state))
      ),
      0.0,
      1.0,
      1
    )
    for state in states
  ]
end

struct ForcedChainSpec <: GI.AbstractGameSpec end

mutable struct ForcedChainEnv <: GI.AbstractGameEnv
  spec::ForcedChainSpec
  state::Int
  last_reward::Float64
end

GI.two_players(::ForcedChainSpec) = false
GI.actions(::ForcedChainSpec) = [1, 2]
GI.vectorize_state(::ForcedChainSpec, _state) = zeros(Float32, 1, 1, 1)
GI.init(spec::ForcedChainSpec) = ForcedChainEnv(spec, 0, 0.0)
GI.spec(game::ForcedChainEnv) = game.spec
GI.set_state!(game::ForcedChainEnv, state) = (game.state = state; game.last_reward = 0.0; game)
GI.current_state(game::ForcedChainEnv) = game.state
GI.game_terminated(game::ForcedChainEnv) = game.state == 3
GI.white_playing(::ForcedChainEnv) = true
function GI.actions_mask(game::ForcedChainEnv)
  if game.state == 0 || game.state == 1
    return Bool[true, false]
  elseif game.state == 2
    return Bool[true, true]
  else
    return Bool[false, false]
  end
end
function GI.play!(game::ForcedChainEnv, action)
  if game.state == 0 && action == 1
    game.state = 1
    game.last_reward = 0.0
  elseif game.state == 1 && action == 1
    game.state = 2
    game.last_reward = 0.0
  elseif game.state == 2 && (action == 1 || action == 2)
    game.state = 3
    game.last_reward = action == 1 ? 1.0 : -1.0
  else
    error("Invalid action $action from state $(game.state)")
  end
  return game
end
GI.white_reward(game::ForcedChainEnv) = game.last_reward
GI.heuristic_value(::ForcedChainEnv) = 0.0

function find_duplicate_move_state(spec; max_states::Int = 1_000, seed::Int = 7)
  Random.seed!(seed)
  game = GI.init(spec)

  for _ in 1:max_states
    state = GI.current_state(game)
    grouped = Dict{Tuple{Int8, Int8}, Vector{TricTracAction}}()
    for action in TricTracZero.state_catalog_actions(state)
      action.kind == TricTracZero.MOVE_ACTION || continue
      push!(get!(grouped, (action.from, action.to), TricTracAction[]), action)
    end

    duplicate_group = findfirst(actions -> length(actions) > 1, collect(values(grouped)))
    if !isnothing(duplicate_group)
      groups = collect(values(grouped))
      return state, groups[duplicate_group]
    end

    GI.game_terminated(game) && (game = GI.init(spec); continue)
    GI.play!(game, rand(GI.available_actions(game)))
  end

  error("Could not find a state with duplicate from/to move identities.")
end

function confirm_listed(state::TricTracState)
  return any(TricTracZero.state_legal_actions(state)) do action
    get(action, "type", nothing) == "special" && get(action, "id", nothing) == "CONFIRM"
  end
end

function synthetic_state(
  runtime::Dict{String, Any};
  phase::String = "move",
  terminal::Bool = false,
  white_to_play::Bool = true,
  runtime_term::String = string(rand(UInt)),
  legal_actions = Any[]
)
  return TricTracState(Dict(
    "runtime_term" => runtime_term,
    "phase" => phase,
    "terminal" => terminal,
    "white_to_play" => white_to_play,
    "runtime" => runtime,
    "legal_actions" => legal_actions
  ))
end

function find_decision_state(spec; max_steps::Int = 120, seed::Int = 1)
  rng = Random.MersenneTwister(seed)
  game = GI.init(spec)

  for _ in 1:max_steps
    state = GI.current_state(game)
    TricTracZero.state_phase(state) == "decision" && return state
    GI.game_terminated(game) && break
    actions = GI.available_actions(game)
    isempty(actions) && break
    GI.play!(game, rand(rng, actions))
  end

  return nothing
end

function follow_single_action_chain(spec, state::TricTracState, action::TricTracAction)
  bridge = TricTracZero.bridge_client(spec)
  total_reward = 0.0
  current_state = state
  current_action = action
  chained_labels = String[]

  while true
    response = TricTracZero.step!(
      bridge,
      spec,
      current_state,
      TricTracZero.catalog_action_to_bridge_action(
        current_action,
        TricTracZero.state_white_to_play(current_state)
      )
    )
    next_state = TricTracState(response["state"])
    total_reward += TricTracZero.transition_white_reward(
      spec,
      current_state,
      next_state;
      fallback = Float64(response["reward"])
    )

    if TricTracZero.state_terminal(next_state)
      return next_state, chained_labels, total_reward
    end

    actions = TricTracZero.state_catalog_actions(next_state)
    if length(actions) != 1
      return next_state, chained_labels, total_reward
    end

    forced = only(actions)
    push!(chained_labels, TricTracZero.action_label(forced))
    current_state = next_state
    current_action = forced
  end
end

function find_single_action_followup(spec; max_steps::Int = 120, seed::Int = 1)
  rng = Random.MersenneTwister(seed)
  game = GI.init(spec)

  for _ in 1:max_steps
    state = GI.current_state(game)
    for action in GI.available_actions(game)
      next_state, chained_labels, total_reward = follow_single_action_chain(spec, state, action)
      isempty(chained_labels) && continue
      return state, action, next_state, chained_labels, total_reward
    end

    GI.game_terminated(game) && (game = GI.init(spec); continue)
    actions = GI.available_actions(game)
    isempty(actions) && break
    GI.play!(game, rand(rng, actions))
  end

  return nothing
end

function completed_random_trace(spec; attempts::Int = 4, seed::Int = 1)
  Random.seed!(seed)
  for _ in 1:attempts
    trace = AlphaZero.play_game(spec, AlphaZero.RandomPlayer())
    !isnothing(trace) && return trace
  end
  return nothing
end

@testset "Runtime Term Identity" begin
  state_a = Dict(
    "runtime_term" => "opaque-runtime",
    "phase" => "move",
    "terminal" => false,
    "white_to_play" => true,
    "runtime" => Dict("turn_number" => 1),
    "legal_actions" => Any[Dict("type" => "special", "id" => "CONFIRM")]
  )

  state_b = Dict(
    "runtime_term" => "opaque-runtime",
    "phase" => "terminal",
    "terminal" => true,
    "white_to_play" => false,
    "runtime" => Dict("turn_number" => 99),
    "legal_actions" => Any[]
  )

  a = TricTracState(state_a)
  b = TricTracState(state_b)
  @test a == b
  @test hash(a) == hash(b)
end

@testset "Bridge Backed Game" begin
  spec = classique_test_spec()
  AlphaZero.Scripts.test_game(spec; n = 4)

  game = GI.init(spec)
  @test GI.white_playing(game)
  @test !GI.game_terminated(game)
  @test any(GI.actions_mask(game))
  @test Set(GI.available_actions(game)) == Set(dense_available_actions(game))
  sampled_states = sample_states(spec; n = 64, seed = 19)
  @test all(!isempty(TricTracZero.state_catalog_actions(state)) for state in sampled_states)

  bridge = TricTracZero.bridge_client(spec)
  confirm_payload = Dict{String, Any}("type" => "special", "id" => "CONFIRM")
  sampled_move_states = 0
  for state in sampled_states
    TricTracZero.state_phase(state) == "move" || continue
    sampled_move_states += 1
    listed = confirm_listed(state)
    succeeds = try
      TricTracZero.step!(bridge, spec, state, confirm_payload)
      true
    catch
      false
    end
    @test listed == succeeds
  end
  @test sampled_move_states > 0
end

@testset "Single-Action Follow-Up Collapse" begin
  spec = classique_test_spec()
  found = find_single_action_followup(spec; max_steps = 160, seed = 7)
  @test !isnothing(found)

  state, action, expected_state, chained_labels, expected_reward = found
  @test !isempty(chained_labels)

  game = GI.init(spec, state)
  GI.play!(game, action)

  @test GI.current_state(game) == expected_state
  @test GI.white_reward(game) ≈ expected_reward atol = 1e-6

  if !GI.game_terminated(game)
    actions = GI.available_actions(game)
    @test length(actions) != 1
  end
end

@testset "Trace Skips Single-Action States" begin
  spec = classique_test_spec()
  trace = completed_random_trace(spec; attempts = 4, seed = 11)
  @test !isnothing(trace)

  for state in trace.states[1:(end - 1)]
    game = GI.init(spec, state)
    GI.game_terminated(game) && continue
    @test length(GI.available_actions(game)) != 1
  end
end

@testset "Self-Play Straggler Policy" begin
  spec = classique_test_spec()
  aecrire_spec = TricTracGameSpec(variant_id = "trictrac_aecrire")
  combine_spec = TricTracGameSpec(variant_id = "trictrac_combine")
  policy = AlphaZero.self_play_straggler_policy(spec)
  @test !isnothing(policy)
  @test policy.timeout_seconds == TricTracZero.DEFAULT_STRAGGLER_TIMEOUT_SECONDS
  @test policy.remaining_games == TricTracZero.DEFAULT_STRAGGLER_REMAINING_GAMES
  checkpoint_policy = AlphaZero.checkpoint_straggler_policy(spec)
  @test !isnothing(checkpoint_policy)
  @test checkpoint_policy.timeout_seconds == TricTracZero.DEFAULT_CHECKPOINT_STRAGGLER_TIMEOUT_SECONDS
  @test checkpoint_policy.remaining_games == TricTracZero.DEFAULT_CHECKPOINT_STRAGGLER_REMAINING_GAMES
  @test isnothing(AlphaZero.max_game_length(spec))
  @test isnothing(AlphaZero.self_play_straggler_policy(aecrire_spec))
  @test isnothing(AlphaZero.checkpoint_straggler_policy(aecrire_spec))
  @test isnothing(AlphaZero.max_game_length(aecrire_spec))
  @test isnothing(AlphaZero.self_play_straggler_policy(combine_spec))
  @test isnothing(AlphaZero.checkpoint_straggler_policy(combine_spec))
  @test isnothing(AlphaZero.max_game_length(combine_spec))

  original_cap = get(ENV, TricTracZero.TEMP_MAX_GAME_LENGTH_ENV, nothing)
  try
    ENV[TricTracZero.TEMP_MAX_GAME_LENGTH_ENV] = "620"
    @test AlphaZero.max_game_length(spec) == 620
    @test AlphaZero.max_game_length(aecrire_spec) == 620
    @test AlphaZero.max_game_length(combine_spec) == 620
  finally
    isnothing(original_cap) ?
      delete!(ENV, TricTracZero.TEMP_MAX_GAME_LENGTH_ENV) :
      (ENV[TricTracZero.TEMP_MAX_GAME_LENGTH_ENV] = original_cap)
  end

  control = AlphaZero.make_self_play_straggler_control(
    4,
    AlphaZero.SelfPlayStragglerPolicy(timeout_seconds = 0.01, remaining_games = 1)
  )
  @test !isnothing(control)
  @test !AlphaZero.should_abort_tail_game(control)
  AlphaZero.mark_game_finished!(control)
  AlphaZero.mark_game_finished!(control)
  @test !AlphaZero.should_abort_tail_game(control)
  AlphaZero.mark_game_finished!(control)
  control.last_completion_at = time() - 1.0
  @test AlphaZero.should_abort_tail_game(control)

  late_state = TricTracState(Dict(
    "runtime_term" => "late-turn",
    "phase" => "move",
    "terminal" => false,
    "white_to_play" => true,
    "runtime" => Dict("turn_number" => 200),
    "legal_actions" => Any[Dict("type" => "special", "id" => "CONFIRM")]
  ))
  game = TricTracGameEnv(spec, TricTracZero.bridge_client(spec), late_state, 0.0)
  @test !GI.game_terminated(game)
end

@testset "Combine Suspension Decision Actions" begin
  spec = TricTracGameSpec(variant_id = "trictrac_combine")
  rng = Random.MersenneTwister(1)
  game = GI.init(spec)
  seen_decision = false

  for _ in 1:80
    state = GI.current_state(game)
    actions = TricTracZero.state_catalog_actions(state)
    if TricTracZero.state_phase(state) == "decision"
      seen_decision = true
      @test !isempty(actions)
      @test all(startswith(TricTracZero.action_label(action), "DECISION_") for action in actions)
    end
    GI.game_terminated(game) && break
    isempty(actions) && break
    GI.play!(game, rand(rng, GI.available_actions(game)))
  end

  @test seen_decision
  @test GI.parse_action(spec, "DECISION_SUSPEND_CLASSIQUE") == TricTracZero.DECISION_SUSPEND_CLASSIQUE
  @test GI.parse_action(spec, "DECISION_SUSPEND_A_ECRIRE") == TricTracZero.DECISION_SUSPEND_A_ECRIRE
  @test GI.parse_action(spec, "DECISION_NONE") == TricTracZero.DECISION_NONE
end

@testset "Sparse Policy Utilities" begin
  spec = classique_test_spec()
  states = sample_states(spec; n = 6)
  samples = sample_training_examples(spec; n = 6)
  dense_sets_match = all(states) do state
    game = GI.init(spec, state)
    Set(GI.available_actions(game)) == Set(dense_available_actions(game))
  end
  @test dense_sets_match

  data = AlphaZero.convert_samples(spec, AlphaZero.LOG_WEIGHT, samples)
  @test keys(data) == (:W, :X, :F, :M, :P, :V)
  @test size(data.X, 4) == length(samples)
  @test size(data.F, 3) == length(samples)
  @test size(data.M, 2) == length(samples)
  @test size(data.P, 2) == length(samples)

  for (index, sample) in pairs(samples)
    valid = Int(round(sum(data.M[:, index])))
    @test valid == length(sample.π)
    @test isapprox(sum(data.P[:, index]), 1f0; atol = 1f-5)
    if valid < size(data.M, 1)
      @test all(iszero, data.M[valid + 1:end, index])
      @test all(iszero, data.P[valid + 1:end, index])
    end
  end

  duplicate_state, duplicate_actions = find_duplicate_move_state(spec)
  duplicate_features = TricTracZero.legal_action_features(duplicate_actions)
  feature_columns = [Tuple(col) for col in eachcol(duplicate_features)]
  @test length(duplicate_actions) >= 2
  @test length(unique((action.s1, action.s2) for action in duplicate_actions)) == length(duplicate_actions)
  @test length(unique(feature_columns)) == length(duplicate_actions)

  nn = TricTracSparseNet(spec, TricTracZero.netparams())
  single_policy, single_value = AlphaZero.Network.evaluate(nn, states[1])
  @test length(single_policy) == length(TricTracZero.state_catalog_actions(states[1]))
  @test isfinite(single_value)

  batched = AlphaZero.Network.evaluate_batch(nn, states)
  @test length(batched) == length(states)
  @test all(isfinite(value) for (_, value) in batched)
  @test all(
    length(policy) == length(TricTracZero.state_catalog_actions(state))
    for ((policy, _), state) in zip(batched, states)
  )
end

@testset "MCTS Empty Action Regression" begin
  spec = classique_test_spec()
  empty_state = TricTracState(Dict(
    "runtime_term" => "empty-actions",
    "phase" => "move",
    "terminal" => false,
    "white_to_play" => true,
    "runtime" => Dict("turn_number" => 9),
    "legal_actions" => Any[]
  ))

  game = GI.init(spec, empty_state)
  oracle(_state) = (Float32[], 0.0f0)
  mcts = AlphaZero.MCTS.Env(spec, oracle)

  AlphaZero.MCTS.explore!(mcts, game, 2)
  actions, π = AlphaZero.MCTS.policy(mcts, game)

  @test isempty(actions)
  @test isempty(π)
end

@testset "MCTS Forced Action Bypass" begin
  spec = classique_test_spec()
  counter = Ref(0)
  oracle = function(_state)
    counter[] += 1
    return [1.0], 0.0
  end

  params = AlphaZero.MctsParams(
    num_iters_per_turn = 32,
    cpuct = 1.5,
    gamma = 1.0,
    temperature = AlphaZero.ConstSchedule(1.0),
    dirichlet_noise_ϵ = 0.20,
    dirichlet_noise_α = 0.35,
    prior_temperature = 1.0
  )
  player = AlphaZero.MctsPlayer(spec, oracle, params)
  game = GI.init(spec)

  actions, π = AlphaZero.think(player, game)

  @test length(actions) == 1
  @test π == [1.0]
  @test counter[] == 0
  @test player.mcts.total_simulations == 0
end

@testset "MCTS Forced Chain Oracle Bypass" begin
  spec = ForcedChainSpec()
  counter = Ref(0)
  oracle = function(state)
    counter[] += 1
    state == 2 && return ([0.75, 0.25], 0.0)
    return ([1.0], 0.0)
  end

  game = GI.init(spec)
  mcts = AlphaZero.MCTS.Env(spec, oracle)
  AlphaZero.MCTS.explore!(mcts, game, 5)

  @test counter[] == 1
  @test haskey(mcts.tree, 2)
  @test !haskey(mcts.tree, 0)
  @test !haskey(mcts.tree, 1)
end

@testset "Batchifier Partial Flush" begin
  reqc = AlphaZero.Batchifier.launch_server(; num_workers = 4, batch_size = 4) do batch
    return [value * 2 for value in batch]
  end

  oracle = AlphaZero.Batchifier.BatchedOracle(reqc)
  task = @async oracle(21)

  waited = timedwait(() -> istaskdone(task), 1.0; pollint = 0.01)
  @test waited == :ok
  @test fetch(task) == 42

  for _ in 1:4
    AlphaZero.Batchifier.client_done!(reqc)
  end
end

@testset "Batchifier Concurrent Query Stress" begin
  reqc = AlphaZero.Batchifier.launch_server(; num_workers = 16, batch_size = 8) do batch
    return [(value = value, doubled = value * 2) for value in batch]
  end

  start_gate = Base.Event()
  tasks = [
    Threads.@spawn begin
      wait(start_gate)
      oracle = AlphaZero.Batchifier.BatchedOracle(reqc)
      try
        for turn in 1:256
          query = worker_id * 1_000 + turn
          response = oracle(query)
          @test response.value == query
          @test response.doubled == query * 2
        end
      finally
        AlphaZero.Batchifier.client_done!(reqc)
      end
      return nothing
    end for worker_id in 1:16
  ]

  notify(start_gate)
  foreach(wait, tasks)
  @test all(istaskdone, tasks)
end

@testset "Adam Learning Regression" begin
  spec = classique_test_spec()
  nn = TricTracSparseNet(spec, TricTracZero.netparams())
  samples = sample_training_examples(spec; n = 8, seed = 11)
  params = LearningParams(
    use_gpu = false,
    use_position_averaging = true,
    samples_weighing_policy = LOG_WEIGHT,
    batch_size = 4,
    loss_computation_batch_size = 4,
    optimiser = Adam(lr = 1e-3),
    l2_regularization = 1f-4,
    nonvalidity_penalty = 1f0,
    min_checkpoints_per_epoch = 1,
    max_batches_per_checkpoint = 1,
    num_checkpoints = 1
  )

  trainer = AlphaZero.Trainer(spec, nn, samples, params)
  losses = AlphaZero.batch_updates!(trainer, 1)
  @test length(losses) == 1
  @test isfinite(losses[1])
end

@testset "Corrupted Replay Buffer Recovery" begin
  mktempdir() do dir
    spec = classique_test_spec()
    params = TricTracZero.build_params(smoke = true, use_gpu = false)
    nn = TricTracSparseNet(spec, TricTracZero.netparams())
    samples = sample_training_examples(spec; n = 3, seed = 17)
    env = AlphaZero.Env(spec, params, nn, copy(nn), samples, 1)

    UserInterface.save_env(env, dir)

    mem_path = joinpath(dir, UserInterface.MEM_FILE)
    bytes = read(mem_path)
    open(mem_path, "w") do io
      write(io, bytes[1:min(length(bytes), 32)])
    end

    recovered = UserInterface.load_env(dir)
    @test recovered.itc == 1
    @test isempty(AlphaZero.get_experience(recovered))
    recovered_again = UserInterface.load_env(dir)
    @test isempty(AlphaZero.get_experience(recovered_again))
  end
end

@testset "CPU Startup Parsing" begin
  env = Dict(
    TricTracScriptCPU.ENV_CPU_POLICY => "max",
    TricTracScriptCPU.ENV_CPU_THREADS => "4",
    TricTracScriptCPU.ENV_SELF_PLAY_WORKERS => "3",
    TricTracScriptCPU.ENV_ARENA_WORKERS => "2",
    TricTracScriptCPU.ENV_NUM_ITERS => "9",
    TricTracScriptCPU.ENV_MOVE_CAP => "620",
    TricTracScriptCPU.ENV_VALUE_TARGET_GAIN => "1.75",
    TricTracScriptCPU.ENV_PARTIE_LENGTH_REPEATS => "4",
    TricTracScriptCPU.ENV_GAME => "toc",
    TricTracScriptCPU.ENV_TACTICAL_SHAPING => "off",
    TricTracScriptCPU.ENV_TACTICAL_HORIZON_OWN_TURNS => "1",
    TricTracScriptCPU.ENV_TACTICAL_REWARD_WEIGHT => "0.25",
    TricTracScriptCPU.ENV_TACTICAL_HEURISTIC_WEIGHT => "0.75"
  )

  parsed = TricTracScriptCPU.parse_startup(
    :train,
    [
      "--device",
      "metal",
      "--cpu-threads=auto",
      "--self-play-workers",
      "auto",
      "--iterations",
      "5",
      "--move-cap",
      "0",
      "--target-gain",
      "0.5",
      "--partie-length-repeats",
      "auto",
      "--game",
      "combine-margot",
      "--tactical-shaping",
      "on",
      "--tactical-horizon-own-turns",
      "3",
      "--tactical-reward-weight",
      "1.5",
      "--tactical-heuristic-weight",
      "2.5",
      "--gpu",
      "--reset-memory",
      "default",
      "/tmp/session"
    ];
    env
  )
  @test parsed.device.value == :auto
  @test parsed.device.source == :cli
  @test parsed.reset_memory
  @test parsed.positional == ["default", "/tmp/session"]
  @test parsed.cpu_policy.value == :max
  @test parsed.cpu_policy.source == :env
  @test parsed.cpu_threads.value == TricTracScriptCPU.AUTO
  @test parsed.cpu_threads.source == :cli
  @test parsed.self_play_workers.value == TricTracScriptCPU.AUTO
  @test parsed.self_play_workers.source == :cli
  @test parsed.arena_workers.value == 2
  @test parsed.arena_workers.source == :env
  @test parsed.num_iters.value == 5
  @test parsed.num_iters.source == :cli
  @test parsed.move_cap.value == 0
  @test parsed.move_cap.source == :cli
  @test parsed.value_target_gain.value == 0.5
  @test parsed.value_target_gain.source == :cli
  @test parsed.partie_length_repeats.value == TricTracScriptCPU.AUTO
  @test parsed.partie_length_repeats.source == :cli
  @test parsed.game.value == "combine-margot"
  @test parsed.game.source == :cli
  @test parsed.tactical_shaping.value == true
  @test parsed.tactical_shaping.source == :cli
  @test parsed.tactical_horizon_own_turns.value == 3
  @test parsed.tactical_horizon_own_turns.source == :cli
  @test parsed.tactical_reward_weight.value == 1.5
  @test parsed.tactical_reward_weight.source == :cli
  @test parsed.tactical_heuristic_weight.value == 2.5
  @test parsed.tactical_heuristic_weight.source == :cli

  default_cfg = TricTracScriptCPU.parse_startup(:train, String[]; env = Dict{String, String}())
  @test TricTracScriptCPU.resolve_target_threads(default_cfg; visible_cpu_threads = 8, current_threads = 1) == 6
  @test TricTracScriptCPU.relaunch_status(default_cfg; visible_cpu_threads = 8, current_threads = 1, env = Dict{String, String}()) == :would_relaunch
  @test TricTracScriptCPU.relaunch_status(
    default_cfg;
    visible_cpu_threads = 8,
    current_threads = 1,
    env = Dict(TricTracScriptCPU.INTERNAL_REEXEC_ENV => "1")
  ) == :skipped_by_guard

  off_cfg = TricTracScriptCPU.parse_startup(:train, ["--cpu-policy=off"]; env = Dict{String, String}())
  @test TricTracScriptCPU.resolve_target_threads(off_cfg; visible_cpu_threads = 8, current_threads = 1) == 1
  @test TricTracScriptCPU.relaunch_status(off_cfg; visible_cpu_threads = 8, current_threads = 1, env = Dict{String, String}()) == :none

  help_text = TricTracScriptCPU.usage_text(:train, "/Users/nick/hermes_trictrac/trictrac_zero/scripts/train.jl")
  @test occursin("--device", help_text)
  @test occursin("--cpu-policy", help_text)
  @test occursin("--cpu-threads", help_text)
  @test occursin("--self-play-workers", help_text)
  @test occursin("--iterations", help_text)
  @test occursin("--move-cap", help_text)
  @test occursin("--target-gain", help_text)
  @test occursin("--partie-length-repeats", help_text)
  @test occursin("--game", help_text)
  @test occursin("--tactical-shaping", help_text)
  @test occursin("--tactical-horizon-own-turns", help_text)
  @test occursin("--tactical-reward-weight", help_text)
  @test occursin("--tactical-heuristic-weight", help_text)
  @test occursin("--reset-memory", help_text)
  @test occursin("CLI values override environment variables", help_text)

  @test_throws ArgumentError TricTracScriptCPU.parse_startup(:train, ["--cpu-policy=bogus"]; env = Dict{String, String}())
  @test_throws ArgumentError TricTracScriptCPU.parse_startup(:train, ["--cpu-threads=0"]; env = Dict{String, String}())
  @test_throws ArgumentError TricTracScriptCPU.parse_startup(:train, ["--iterations=0"]; env = Dict{String, String}())
  @test_throws ArgumentError TricTracScriptCPU.parse_startup(:train, ["--move-cap=-1"]; env = Dict{String, String}())
  @test_throws ArgumentError TricTracScriptCPU.parse_startup(:train, ["--target-gain=-1"]; env = Dict{String, String}())
  @test_throws ArgumentError TricTracScriptCPU.parse_startup(:train, ["--partie-length-repeats=0"]; env = Dict{String, String}())
  @test_throws ArgumentError TricTracScriptCPU.parse_startup(:train, ["--tactical-shaping=bogus"]; env = Dict{String, String}())
  @test_throws ArgumentError TricTracScriptCPU.parse_startup(:train, ["--tactical-horizon-own-turns=4"]; env = Dict{String, String}())
  @test_throws ArgumentError TricTracScriptCPU.parse_startup(:train, ["--tactical-reward-weight=-1"]; env = Dict{String, String}())
  @test_throws ArgumentError TricTracScriptCPU.parse_startup(:train, ["--tactical-heuristic-weight=-1"]; env = Dict{String, String}())
  @test_throws ArgumentError TricTracScriptCPU.parse_startup(:train, ["--device=bogus"]; env = Dict{String, String}())
  @test_throws ArgumentError TricTracScriptCPU.parse_startup(:train, ["--game=bogus"]; env = Dict{String, String}())

  cuda_cfg = TricTracScriptCPU.prepare_startup(
    :train,
    "/Users/nick/hermes_trictrac/trictrac_zero/scripts/train.jl",
    ["--device=cuda"];
    env = Dict{String, String}(),
    allow_relaunch = false
  )
  cuda_workers = TricTracZero.resolve_worker_settings(smoke = false)
  cuda_runtime_workers = TricTracZero.resolve_runtime_workers(
    smoke = false,
    backend = TricTracZero.DEVICE_CUDA,
    worker_settings = cuda_workers
  )
  cuda_batch_sizes = TricTracZero.resolve_batch_sizes(
    smoke = false,
    backend = TricTracZero.DEVICE_CUDA,
    self_play_workers = cuda_runtime_workers.self_play,
    arena_workers = cuda_runtime_workers.arena
  )
  summary_io = IOBuffer()
  TricTracScriptCPU.print_startup_summary(
    summary_io,
    cuda_cfg;
    self_play_workers = cuda_runtime_workers.self_play,
    arena_workers = cuda_runtime_workers.arena,
    self_play_batch_size = cuda_batch_sizes.self_play,
    arena_batch_size = cuda_batch_sizes.arena,
    learning_batch_size = cuda_batch_sizes.learning
  )
  summary_text = String(take!(summary_io))
  @test occursin("Self-play workers: $(cuda_runtime_workers.self_play)", summary_text)
  @test occursin("Arena workers: $(cuda_runtime_workers.arena)", summary_text)
  @test occursin("Self-play batch size: $(cuda_batch_sizes.self_play)", summary_text)
  @test occursin("Arena batch size: $(cuda_batch_sizes.arena)", summary_text)
  @test occursin("Learning batch size: 128", summary_text)
end

@testset "Tactical Tariff Shaping" begin
  @test TricTracGameSpec().tactical_config["enabled"] == true
  @test TricTracGameSpec().tactical_config["horizon_own_turns"] == 3

  runtime = Dict(
    "turn_number" => 12,
    "trictrac" => Dict(
      "score" => Any[
        Dict("points" => 2, "trous" => 1),
        Dict("points" => 1, "trous" => 0)
      ]
    ),
    "tactical_tariffs" => Dict(
      "white" => Dict("h1" => 4.0 / 144.0, "h2" => 6.0 / 144.0, "h3" => 10.0 / 144.0),
      "black" => Dict("h1" => 1.0 / 144.0, "h2" => 2.0 / 144.0, "h3" => 4.0 / 144.0)
    )
  )

  current = synthetic_state(runtime; runtime_term = "tactical-current", white_to_play = true)
  black_turn = synthetic_state(runtime; runtime_term = "tactical-black", white_to_play = false)
  next_runtime = deepcopy(runtime)
  next_runtime["tactical_tariffs"] = Dict(
    "white" => Dict("h1" => 6.0 / 144.0, "h2" => 8.0 / 144.0, "h3" => 8.0 / 144.0),
    "black" => Dict("h1" => 1.0 / 144.0, "h2" => 2.0 / 144.0, "h3" => 4.0 / 144.0)
  )
  next_state = synthetic_state(next_runtime; runtime_term = "tactical-next", white_to_play = false)

  spec_on = TricTracGameSpec(tactical_config = Dict(
    "enabled" => true,
    "horizon_own_turns" => 3,
    "reward_weight" => 1.5,
    "heuristic_weight" => 2.0
  ))
  spec_off = TricTracGameSpec(tactical_config = Dict(
    "enabled" => false,
    "horizon_own_turns" => 0,
    "reward_weight" => 1.5,
    "heuristic_weight" => 2.0
  ))
  spec_h0 = TricTracGameSpec(tactical_config = Dict(
    "enabled" => true,
    "horizon_own_turns" => 0,
    "reward_weight" => 1.5,
    "heuristic_weight" => 2.0
  ))

  expected_equity = (3.0 + 0.5 * 4.0 + 0.25 * 6.0) / 144.0
  expected_next_equity = (5.0 + 0.5 * 6.0 + 0.25 * 4.0) / 144.0

  @test isapprox(TricTracZero.white_tactical_equity(spec_on, current), expected_equity; atol = 1e-8)
  @test isapprox(TricTracZero.side_to_move_tactical_equity(spec_on, current), expected_equity; atol = 1e-8)
  @test isapprox(TricTracZero.side_to_move_tactical_equity(spec_on, black_turn), -expected_equity; atol = 1e-8)
  @test TricTracZero.white_tactical_equity(spec_h0, current) == 0.0
  @test TricTracZero.tactical_shaping_enabled(TricTracGameSpec(
    variant_id = "toc",
    match_options = Dict("holeTarget" => "7", "doublesMode" => "off", "margotEnabled" => false),
    tactical_config = Dict("enabled" => true, "horizon_own_turns" => 3)
  )) == false

  heuristic_off = GI.heuristic_value(GI.init(spec_off, current))
  heuristic_on = GI.heuristic_value(GI.init(spec_on, current))
  heuristic_h0 = GI.heuristic_value(GI.init(spec_h0, current))
  @test isapprox(heuristic_on, heuristic_off + 2.0 * expected_equity; atol = 1e-8)
  @test isapprox(heuristic_h0, heuristic_off; atol = 1e-8)

  reward = TricTracZero.transition_white_reward(spec_on, current, next_state)
  @test isapprox(reward, 1.5 * (expected_next_equity - expected_equity); atol = 1e-8)
  @test TricTracZero.transition_white_reward(spec_h0, current, next_state) == 0.0
end

@testset "Bridge Worker Slot Metadata" begin
  spec = TricTracGameSpec()

  @test TricTracZero.bridge_worker_slot() == 0

  Base.task_local_storage(AlphaZero.Util.WORKER_SLOT_TLS_KEY, 7)
  try
    @test TricTracZero.bridge_worker_slot() == 7
  finally
    Base.task_local_storage(AlphaZero.Util.WORKER_SLOT_TLS_KEY, nothing)
  end

  original_mode = get(ENV, "TRICTRAC_ZERO_BRIDGE_MODE", nothing)
  try
    ENV["TRICTRAC_ZERO_BRIDGE_MODE"] = "worker"
    TricTracZero.close_cached_bridges!()
    game = GI.init(classique_test_spec())
    @test game.bridge.service.key[end] == 0

    Base.task_local_storage(AlphaZero.Util.WORKER_SLOT_TLS_KEY, 7)
    try
      clone = GI.clone(game)
      @test clone.bridge.service.key[end] == 7
      GI.play!(clone, first(GI.available_actions(clone)))
      @test clone.bridge.service.key[end] == 7
    finally
      Base.task_local_storage(AlphaZero.Util.WORKER_SLOT_TLS_KEY, nothing)
    end
  finally
    TricTracZero.close_cached_bridges!()
    isnothing(original_mode) ? delete!(ENV, "TRICTRAC_ZERO_BRIDGE_MODE") : (ENV["TRICTRAC_ZERO_BRIDGE_MODE"] = original_mode)
  end
end

@testset "Self-Play Prewarm Pass" begin
  tactile_sim = AlphaZero.SimParams(
    num_games = 32,
    num_workers = 8,
    batch_size = 8,
    use_gpu = true,
    fill_batches = true
  )

  classique_spec = TricTracGameSpec(
    tactical_config = Dict(
      "enabled" => true,
      "horizon_own_turns" => 1,
      "reward_weight" => 1.0,
      "heuristic_weight" => 1.0
    )
  )
  quiet_spec = TricTracGameSpec(
    tactical_config = Dict(
      "enabled" => false,
      "horizon_own_turns" => 0,
      "reward_weight" => 1.0,
      "heuristic_weight" => 1.0
    )
  )

  @test TricTracZero.self_play_prewarm_plies(classique_spec, tactile_sim) == 4

  cpu_sim = AlphaZero.SimParams(
    num_games = 32,
    num_workers = 8,
    batch_size = 1,
    use_gpu = false,
    fill_batches = false
  )

  @test TricTracZero.self_play_prewarm_plies(classique_spec, cpu_sim) == 0
  @test TricTracZero.self_play_prewarm_plies(quiet_spec, tactile_sim) == 0
end

@testset "Bridge Mode Selection" begin
  original_mode = get(ENV, "TRICTRAC_ZERO_BRIDGE_MODE", nothing)
  original_erl_flags = get(ENV, "ERL_FLAGS", nothing)
  original_bridge_erl_flags = get(ENV, "TRICTRAC_ZERO_BRIDGE_ERL_FLAGS", nothing)
  try
    @test TricTracZero.preferred_bridge_mode(:cpu) == "worker"
    @test TricTracZero.preferred_bridge_mode(:cuda) == "shared"
    @test TricTracZero.preferred_bridge_mode(:metal) == "shared"

    delete!(ENV, "ERL_FLAGS")
    delete!(ENV, "TRICTRAC_ZERO_BRIDGE_ERL_FLAGS")
    ENV["TRICTRAC_ZERO_BRIDGE_MODE"] = "worker"
    @test TricTracZero.bridge_erl_flags() == "+S 2:2"

    ENV["TRICTRAC_ZERO_BRIDGE_MODE"] = "shared"
    @test isnothing(TricTracZero.bridge_erl_flags())

    ENV["TRICTRAC_ZERO_BRIDGE_ERL_FLAGS"] = "+S 1:1"
    @test TricTracZero.bridge_erl_flags() == "+S 1:1"

    ENV["ERL_FLAGS"] = "+S 8:8"
    @test isnothing(TricTracZero.bridge_erl_flags())
  finally
    isnothing(original_mode) ? delete!(ENV, "TRICTRAC_ZERO_BRIDGE_MODE") : (ENV["TRICTRAC_ZERO_BRIDGE_MODE"] = original_mode)
    isnothing(original_erl_flags) ? delete!(ENV, "ERL_FLAGS") : (ENV["ERL_FLAGS"] = original_erl_flags)
    isnothing(original_bridge_erl_flags) ? delete!(ENV, "TRICTRAC_ZERO_BRIDGE_ERL_FLAGS") : (ENV["TRICTRAC_ZERO_BRIDGE_ERL_FLAGS"] = original_bridge_erl_flags)
  end
end

@testset "Native Elixir Bridge Launcher" begin
  spec = classique_test_spec()
  original_executable = get(ENV, "TRICTRAC_ZERO_BRIDGE_EXECUTABLE", nothing)
  try
    delete!(ENV, "TRICTRAC_ZERO_BRIDGE_EXECUTABLE")
    native = TricTracZero.native_elixir_executable()
    ebin_paths = TricTracZero.bridge_ebin_paths(TricTracZero.bridge_ebin_root(spec))

    if !isnothing(native) && !isempty(ebin_paths)
      stdio_cmd = TricTracZero.bridge_stdio_command(spec)
      daemon_cmd = TricTracZero.bridge_daemon_command(spec, TricTracZero.bridge_paths(spec))

      @test stdio_cmd.exec[1] == native
      @test daemon_cmd.exec[1] == native
      @test !("mix" in stdio_cmd.exec)
      @test !("mix" in daemon_cmd.exec)
    end
  finally
    isnothing(original_executable) ? delete!(ENV, "TRICTRAC_ZERO_BRIDGE_EXECUTABLE") : (ENV["TRICTRAC_ZERO_BRIDGE_EXECUTABLE"] = original_executable)
  end
end

@testset "Shared Bridge Daemon" begin
  spec = classique_test_spec()
  original_stats_env = get(ENV, "TRICTRAC_ZERO_BRIDGE_COLLECT_STATS", nothing)
  TricTracZero.close_cached_bridges!()
  TricTracZero.clear_step_response_cache!()
  try
    ENV["TRICTRAC_ZERO_BRIDGE_COLLECT_STATS"] = "1"
    stats1 = TricTracZero.bridge_stats(spec)
    stats2 = TricTracZero.bridge_stats(spec)
    service = TricTracZero.bridge_client(spec).service
    @test stats1["transport"] == "daemon"
    @test stats1["pid"] == stats2["pid"]
    @test stats1["state_dir"] == stats2["state_dir"]
    @test stats2["julia_step_cache_size"] == 0
    @test isnothing(service.control)
    @test length(service.step_tasks) == TricTracZero.SHARED_BRIDGE_BATCH_WORKERS

    game = GI.init(spec)
    state = GI.current_state(game)
    roll_action = Dict{String, Any}("type" => "special", "id" => "ROLL")
    response1 = TricTracZero.step!(TricTracZero.bridge_client(spec), spec, state, roll_action)
    response2 = TricTracZero.step!(TricTracZero.bridge_client(spec), spec, state, roll_action)
    @test response1 == response2
    @test TricTracZero.step_response_cache_size() == 1

    stats_step = TricTracZero.bridge_stats(spec)
    @test get(stats_step["metrics"], "step_batch_singleton_requests", 0) >= 1

    cheap_key = TricTracZero.bridge_step_request_key(
      spec,
      state,
      roll_action;
      include_tactical_summary = false
    )
    full_key = TricTracZero.bridge_step_request_key(spec, state, roll_action)
    @test cheap_key != full_key

    cheap_response = TricTracZero.step!(
      TricTracZero.bridge_client(spec),
      spec,
      state,
      roll_action;
      include_tactical_summary = false
    )
    @test !haskey(cheap_response["state"]["runtime"], "tactical_tariffs")

    hydrated = TricTracZero.state!(TricTracZero.bridge_client(spec), spec, TricTracState(cheap_response["state"]))
    @test haskey(hydrated["state"]["runtime"], "tactical_tariffs")
    @test isnothing(service.control)

    payload = Dict(
      "cmd" => "step_batch",
      "items" => Any[
        Dict(
          "item_id" => "a",
          "state" => Dict{String, Any}("runtime_term" => TricTracZero.state_runtime_term(state)),
          "action" => roll_action,
          "config" => TricTracZero.bridge_config(spec)
        ),
        Dict(
          "item_id" => "b",
          "state" => Dict{String, Any}("runtime_term" => TricTracZero.state_runtime_term(state)),
          "action" => roll_action,
          "config" => TricTracZero.bridge_config(spec)
        )
      ]
    )

    response = TricTracZero.bridge_request!(TricTracZero.bridge_client(spec).service, spec, payload)
    items = response["items"]
    @test length(items) == 2
    @test all(item["ok"] for item in items)
    @test items[1]["result"] == items[2]["result"]

    stats3 = TricTracZero.bridge_stats(spec)
    @test stats3["step_cache_size"] >= 1
    @test stats3["julia_step_cache_size"] >= 2

    TricTracZero.clear_step_response_cache!()
    service.transport = :stdio
    if service.fallback !== nothing
      close(service.fallback)
      service.fallback = nothing
    end

    response3 = TricTracZero.step!(TricTracZero.bridge_client(spec), spec, state, roll_action)
    @test response3["state"]["phase"] == "move"
    @test !response3["terminal"]
    @test !isempty(response3["legal_actions"])

    stats4 = TricTracZero.bridge_stats(spec)
    @test stats4["transport"] == "daemon"
    @test stats4["julia_step_cache_size"] == 1

    broken_connection = TricTracZero.BridgeConnection(service.socket_path)
    close(broken_connection)
    failed_request = TricTracZero.BridgeBatchRequest(
      TricTracZero.bridge_step_request_key(spec, state, roll_action),
      TricTracZero.bridge_step_payload(spec, state, roll_action),
      Channel{Any}(1)
    )

    TricTracZero.flush_pending_step_batch!(service, spec, [failed_request], broken_connection)
    recovered = take!(failed_request.reply_channel)
    @test recovered isa Dict{String, Any}
    @test recovered["state"]["phase"] == "move"

    stats5 = TricTracZero.bridge_stats(spec)
    @test stats5["transport"] == "daemon"

    broken_control = TricTracZero.BridgeConnection(service.socket_path)
    close(broken_control)
    service.control = broken_control
    service.transport = :daemon

    recovered_state = TricTracZero.state!(TricTracZero.bridge_client(spec), spec, state)
    @test recovered_state["state"]["phase"] == TricTracZero.state_phase(state)
    @test !haskey(recovered_state, "error")
    @test isnothing(service.control)

    fake_proc = run(`sleep 60`; wait = false)
    try
      TricTracZero.reset_daemon_connections!(service)
      service.daemon_proc = fake_proc
      service.transport = :daemon
      mkpath(service.state_dir)
      write(service.ready_path, "ready\n")
      write(service.pid_path, string(getpid()))
      open(service.socket_path, "w") do io
        write(io, "")
      end

      recovered_again = TricTracZero.state!(TricTracZero.bridge_client(spec), spec, state)
      @test recovered_again["state"]["phase"] == TricTracZero.state_phase(state)
      @test !haskey(recovered_again, "error")
      @test isnothing(service.control)
    finally
      try
        Base.kill(fake_proc)
      catch
      end
    end

    stats6 = TricTracZero.bridge_stats(spec)
    @test stats6["transport"] == "daemon"
    @test isnothing(service.fallback)
    @test isnothing(service.control)
  finally
    TricTracZero.close_cached_bridges!()
    TricTracZero.clear_step_response_cache!()
    isnothing(original_stats_env) ? delete!(ENV, "TRICTRAC_ZERO_BRIDGE_COLLECT_STATS") : (ENV["TRICTRAC_ZERO_BRIDGE_COLLECT_STATS"] = original_stats_env)
  end
end

@testset "Worker Bridge Daemon" begin
  spec = classique_test_spec()
  original_mode = get(ENV, "TRICTRAC_ZERO_BRIDGE_MODE", nothing)
  TricTracZero.close_cached_bridges!()
  TricTracZero.clear_step_response_cache!()
  try
    ENV["TRICTRAC_ZERO_BRIDGE_MODE"] = "worker"
    stats = TricTracZero.bridge_stats(spec)
    @test stats["transport"] == "daemon"
    @test occursin("-s0", stats["state_dir"])
    @test length(TricTracZero.bridge_client(spec).service.step_tasks) == 1
  finally
    TricTracZero.close_cached_bridges!()
    TricTracZero.clear_step_response_cache!()
    isnothing(original_mode) ? delete!(ENV, "TRICTRAC_ZERO_BRIDGE_MODE") : (ENV["TRICTRAC_ZERO_BRIDGE_MODE"] = original_mode)
  end
end

@testset "Julia Step Cache Trim" begin
  TricTracZero.clear_step_response_cache!()
  limit = TricTracZero.STEP_RESPONSE_CACHE_LIMIT
  trim = TricTracZero.STEP_RESPONSE_CACHE_TRIM

  try
    total = limit + trim + 32
    for i in 1:total
      TricTracZero.bridge_step_cache_put!(("req", i), Dict{String, Any}("value" => i))
    end

    @test TricTracZero.step_response_cache_size() <= limit
    @test isnothing(TricTracZero.bridge_step_cache_get(("req", 1)))
    @test TricTracZero.bridge_step_cache_get(("req", total)) ==
      Dict{String, Any}("value" => total)

    for i in (total + 1):(total + trim + 32)
      TricTracZero.bridge_step_cache_put!(("req", i), Dict{String, Any}("value" => i))
    end

    @test TricTracZero.step_response_cache_size() <= limit
    @test TricTracZero.bridge_step_cache_get(("req", total + trim + 32)) ==
      Dict{String, Any}("value" => total + trim + 32)
  finally
    TricTracZero.clear_step_response_cache!()
  end
end

@testset "Device Resolution" begin
  @test TricTracZero.resolve_device_backend(:cpu) == :cpu
  @test TricTracZero.resolve_device_backend("cuda") == :cuda
  @test TricTracZero.device_available(:cpu)
  @test TricTracZero.network_type_for_device(:cpu) == TricTracSparseNet
  @test_throws ErrorException TricTracZero.resolve_device_backend("bogus")

  if TricTracZero.device_available(:metal)
    probe = TricTracZero.probe_sparse_conv_on_metal()
    expected = probe.supported ? TricTracSparseNet : TricTracMetalSparseNet
    @test TricTracZero.network_type_for_device(:metal) == expected
    expected_hyper = probe.supported ? TricTracSparseNetHP : TricTracMetalSparseNetHP
    @test TricTracZero.default_experiment(device = :metal).netparams isa expected_hyper
  end
end

@testset "AEcrire Partie-Length Scheduling" begin
  spec = TricTracGameSpec(variant_id = "trictrac_aecrire")
  try
    TricTracZero.install_partie_length_schedule!(spec)
    seen = [
      TricTracZero.resolved_match_options_for_new_game(spec)["aEcrirePartieLength"]
      for _ in 1:30
    ]
    counts = Dict(length => count(==(length), seen) for length in TricTracZero.AECRIRE_PARTIE_LENGTH_CHOICES)
    @test all(get(counts, length, 0) == 3 for length in TricTracZero.AECRIRE_PARTIE_LENGTH_CHOICES)
  finally
    TricTracZero.remove_partie_length_schedule!(spec)
  end
end

@testset "AEcrire Partie-Length Training Counts" begin
  @test isnothing(TricTracZero.resolve_partie_length_repeats(
    preset = "classique",
    smoke = false,
    use_gpu = false
  ))
  @test TricTracZero.resolve_partie_length_repeats(
    preset = "aecrire",
    smoke = false,
    use_gpu = false
  ) == 10
  @test TricTracZero.resolve_partie_length_repeats(
    preset = "aecrire",
    smoke = false,
    use_gpu = true
  ) == 4
  @test TricTracZero.resolve_partie_length_repeats(
    preset = "combine",
    smoke = true,
    use_gpu = false
  ) == 1

  @test TricTracZero.build_params(
    smoke = false,
    preset = "classique",
    use_gpu = false,
    partie_length_repeats = 4
  ).self_play.sim.num_games == 96

  @test TricTracZero.build_params(
    smoke = false,
    preset = "aecrire",
    use_gpu = false
  ).self_play.sim.num_games == 100

  @test TricTracZero.build_params(
    smoke = false,
    preset = "aecrire",
    use_gpu = true
  ).self_play.sim.num_games == 40

  @test TricTracZero.build_params(
    smoke = false,
    preset = "combine",
    use_gpu = false,
    partie_length_repeats = 4
  ).self_play.sim.num_games == 40

  @test TricTracZero.build_params(
    smoke = true,
    preset = "combine",
    use_gpu = false
  ).self_play.sim.num_games == 10
end

@testset "Replay Buffer Schedule" begin
  cpu_params = TricTracZero.build_params(smoke = false, preset = "classique", use_gpu = false)
  gpu_params = TricTracZero.build_params(smoke = false, preset = "classique", use_gpu = true)
  smoke_params = TricTracZero.build_params(smoke = true, preset = "classique", use_gpu = false)

  for (offset, target) in enumerate(25_000:25_000:100_000)
    idx = offset - 1
    @test cpu_params.mem_buffer_size[idx] == target
    @test gpu_params.mem_buffer_size[idx] == target
  end

  @test smoke_params.mem_buffer_size[0] == 256
  @test smoke_params.mem_buffer_size[1] == 512
end

@testset "CUDA Throughput Defaults" begin
  worker_settings = TricTracZero.resolve_worker_settings(smoke = false)
  runtime_workers = TricTracZero.resolve_runtime_workers(
    smoke = false,
    backend = TricTracZero.DEVICE_CUDA,
    worker_settings = worker_settings
  )
  batch_sizes = TricTracZero.resolve_batch_sizes(
    smoke = false,
    backend = TricTracZero.DEVICE_CUDA,
    self_play_workers = runtime_workers.self_play,
    arena_workers = runtime_workers.arena
  )

  @test runtime_workers.self_play == min(worker_settings.cap, 8)
  @test runtime_workers.arena == min(worker_settings.cap, 6)
  @test batch_sizes.self_play == min(runtime_workers.self_play, 8)
  @test batch_sizes.arena == min(runtime_workers.arena, 4)
  @test batch_sizes.learning == 128

  explicit_workers = TricTracZero.resolve_worker_settings(
    smoke = false,
    self_play_workers = 3,
    arena_workers = 2
  )
  explicit_runtime = TricTracZero.resolve_runtime_workers(
    smoke = false,
    backend = TricTracZero.DEVICE_CUDA,
    worker_settings = explicit_workers
  )
  explicit_batches = TricTracZero.resolve_batch_sizes(
    smoke = false,
    backend = TricTracZero.DEVICE_CUDA,
    self_play_workers = explicit_runtime.self_play,
    arena_workers = explicit_runtime.arena
  )

  @test explicit_runtime.self_play == explicit_workers.self_play
  @test explicit_runtime.arena == explicit_workers.arena
  @test explicit_batches.self_play == min(explicit_runtime.self_play, 8)
  @test explicit_batches.arena == min(explicit_runtime.arena, 4)

end

@testset "AEcrire Partie-Length Feature Exposure" begin
  spec = TricTracGameSpec(variant_id = "trictrac_aecrire")
  game = GI.init(spec)
  state = GI.current_state(game)
  runtime6 = deepcopy(TricTracZero.state_runtime(state))
  runtime24 = deepcopy(TricTracZero.state_runtime(state))
  runtime6["trictrac"]["track_aecrire"]["partie_length"] = 6
  runtime24["trictrac"]["track_aecrire"]["partie_length"] = 24

  state6 = synthetic_state(
    runtime6;
    phase = TricTracZero.state_phase(state),
    terminal = TricTracZero.state_terminal(state),
    white_to_play = TricTracZero.state_white_to_play(state),
    legal_actions = TricTracZero.state_legal_actions(state)
  )
  state24 = synthetic_state(
    runtime24;
    phase = TricTracZero.state_phase(state),
    terminal = TricTracZero.state_terminal(state),
    white_to_play = TricTracZero.state_white_to_play(state),
    legal_actions = TricTracZero.state_legal_actions(state)
  )

  features6 = GI.vectorize_state(spec, state6)
  features24 = GI.vectorize_state(spec, state24)
  @test features6 != features24
end

@testset "Reset Replay Buffer" begin
  mktempdir() do dir
    spec = classique_test_spec()
    params = TricTracZero.build_params(smoke = true, use_gpu = false)
    nn = TricTracSparseNet(spec, TricTracZero.netparams())
    samples = sample_training_examples(spec; n = 3, seed = 23)
    env = AlphaZero.Env(spec, params, nn, copy(nn), samples, 7)

    UserInterface.save_env(env, dir)

    @test TricTracZero.reset_session_memory!(dir)

    recovered = UserInterface.load_env(dir)
    @test recovered.itc == 7
    @test isempty(AlphaZero.get_experience(recovered))
    @test recovered.bestnn isa TricTracSparseNet
    @test recovered.curnn isa TricTracSparseNet
  end

  @test !TricTracZero.reset_session_memory!("/tmp/definitely-not-a-valid-trictrac-session")
end

@testset "Metal Sparse Net Evaluation" begin
  spec = classique_test_spec()
  game = GI.init(spec)
  state = GI.current_state(game)
  nn = TricTracMetalSparseNet(spec, TricTracZero.metal_netparams())

  policy, value = AlphaZero.Network.evaluate(nn, state)
  @test length(policy) == length(GI.available_actions(game))
  @test value isa Float64

  batch = AlphaZero.Network.evaluate_batch(nn, [state, state])
  @test length(batch) == 2
  @test all(length(entry[1]) == length(GI.available_actions(game)) for entry in batch)

  if TricTracZero.device_available(:metal)
    previous_backend = TricTracZero.active_device_backend()
    try
      TricTracZero.set_runtime_device!(:metal)
      nn_metal = AlphaZero.Network.to_gpu(TricTracMetalSparseNet(spec, TricTracZero.metal_netparams()))
      sparse = TricTracZero.sparse_policy_batch(spec, [state, state])
      Xnet, Fnet, Mnet = AlphaZero.Network.convert_input_tuple(nn_metal, (sparse.X, sparse.F, sparse.M))
      P, V, _ = TricTracZero.sparse_policy_forward(nn_metal, Xnet, Fnet, Mnet)
      Pcpu, Vcpu = AlphaZero.Network.convert_output_tuple(nn_metal, (P, V))
      @test size(Pcpu, 2) == 2
      @test size(Vcpu) == (1, 2)
    finally
      TricTracZero.set_runtime_device!(previous_backend)
    end
  end
end

@testset "AEcrire And Combine Rewards" begin
  aecrire_spec = TricTracGameSpec(variant_id = "trictrac_aecrire")
  combine_spec = TricTracGameSpec(variant_id = "trictrac_combine")

  @test GI.state_dim(TricTracGameSpec()) == TricTracZero.BASE_FEATURE_SHAPE
  @test GI.state_dim(aecrire_spec) == TricTracZero.AECRIRE_LIKE_FEATURE_SHAPE
  @test GI.state_dim(combine_spec) == TricTracZero.AECRIRE_LIKE_FEATURE_SHAPE

  aecrire_before = synthetic_state(Dict(
    "turn_number" => 4,
    "trictrac" => Dict(
      "settlement_ledger" => Dict(
        "white" => Dict("final_total" => 10),
        "black" => Dict("final_total" => 4)
      ),
      "track_aecrire" => Dict(
        "partie_length" => 16,
        "current_coup" => Dict(
          "trous" => Dict("white" => 2, "black" => 1),
          "run_trous" => Dict("white" => 2, "black" => 0),
          "legal_exit_by" => Dict("white" => false, "black" => false)
        )
      )
    )
  ))
  aecrire_after = synthetic_state(Dict(
    "turn_number" => 5,
    "trictrac" => Dict(
      "settlement_ledger" => Dict(
        "white" => Dict("final_total" => 12),
        "black" => Dict("final_total" => 4)
      ),
      "track_aecrire" => Dict(
        "partie_length" => 16,
        "current_coup" => Dict(
          "trous" => Dict("white" => 3, "black" => 1),
          "run_trous" => Dict("white" => 3, "black" => 0),
          "legal_exit_by" => Dict("white" => true, "black" => false)
        )
      )
    )
  ))
  expected_aecrire = 2.0 + TricTracZero.DEFAULT_AECRIRE_SHAPING_WEIGHT * 2.5
  @test isapprox(
    TricTracZero.transition_white_reward(aecrire_spec, aecrire_before, aecrire_after),
    expected_aecrire;
    atol = 1e-6
  )

  combine_before = synthetic_state(Dict(
    "turn_number" => 9,
    "trictrac" => Dict(
      "settlement_ledger" => Dict(
        "white" => Dict("final_total" => 30),
        "black" => Dict("final_total" => 18)
      ),
      "track_aecrire" => Dict("partie_length" => 16),
      "track_classique_honneurs" => Dict(
        "honneurs" => Dict("white" => 2, "black" => 1),
        "current_partie" => Dict(
          "trous" => Dict("white" => 3, "black" => 1),
          "uninterrupted_by" => Dict("white" => false, "black" => false)
        )
      )
    )
  ))
  combine_after = synthetic_state(Dict(
    "turn_number" => 10,
    "trictrac" => Dict(
      "settlement_ledger" => Dict(
        "white" => Dict("final_total" => 32),
        "black" => Dict("final_total" => 18)
      ),
      "track_aecrire" => Dict("partie_length" => 16),
      "track_classique_honneurs" => Dict(
        "honneurs" => Dict("white" => 3, "black" => 1),
        "current_partie" => Dict(
          "trous" => Dict("white" => 5, "black" => 1),
          "uninterrupted_by" => Dict("white" => true, "black" => false)
        )
      )
    )
  ))
  expected_combine =
    2.0 +
    TricTracZero.DEFAULT_COMBINE_HONNEUR_WEIGHT * 1.0 +
    TricTracZero.DEFAULT_COMBINE_PARTIE_WEIGHT * ((4 / 12 + 0.25) - (2 / 12))
  @test isapprox(
    TricTracZero.transition_white_reward(combine_spec, combine_before, combine_after),
    expected_combine;
    atol = 1e-6
  )

  trace = AlphaZero.Trace(aecrire_before)
  push!(trace, [1.0], 20.0, aecrire_after)
  mem = AlphaZero.MemoryBuffer(aecrire_spec, 4)
  AlphaZero.push_trace!(mem, trace, 1.0)
  sample = only(AlphaZero.get_experience(mem))
  @test isapprox(sample.z, tanh(20.0 / (4 * 16)); atol = 1e-6)
end

@testset "Runtime Worker Resolution" begin
  defaults = TricTracZero.resolve_worker_settings(smoke = false)
  @test defaults.self_play == min(4, max(1, Threads.nthreads() - 1))
  @test defaults.arena == min(2, max(1, Threads.nthreads() ÷ 2))
  @test !defaults.self_play_clamped
  @test !defaults.arena_clamped

  smoke_defaults = TricTracZero.resolve_worker_settings(smoke = true)
  @test smoke_defaults.self_play == 1
  @test smoke_defaults.arena == 1

  capped = max(1, Threads.nthreads() - 1)
  explicit = TricTracZero.resolve_worker_settings(smoke = false, self_play_workers = 99, arena_workers = 99)
  @test explicit.self_play == capped
  @test explicit.arena == capped
  @test explicit.self_play_clamped
  @test explicit.arena_clamped

  cpu_runtime = TricTracZero.resolve_runtime_workers(
    smoke = false,
    backend = TricTracZero.DEVICE_CPU,
    worker_settings = defaults
  )
  @test cpu_runtime.self_play == defaults.self_play
  @test cpu_runtime.arena == defaults.arena

  cpu_explicit_runtime = TricTracZero.resolve_runtime_workers(
    smoke = false,
    backend = TricTracZero.DEVICE_CPU,
    worker_settings = explicit
  )
  @test cpu_explicit_runtime.self_play == explicit.self_play
  @test cpu_explicit_runtime.arena == explicit.arena
end

@testset "Completed Session Extension" begin
  mktempdir() do dir
    spec = classique_test_spec()
    params = TricTracZero.build_params(smoke = false, use_gpu = false)
    nn = TricTracSparseNet(spec, TricTracZero.netparams())
    env = AlphaZero.Env(spec, params, nn, copy(nn), AlphaZero.TrainingSample{TricTracState}[], params.num_iters)
    UserInterface.save_env(env, dir)

    experiment = TricTracZero.default_experiment()
    adjusted = TricTracZero.adjust_experiment_for_resume(experiment, dir)
    @test adjusted.params.num_iters == params.num_iters * 2

    smoke_experiment = TricTracZero.smoke_experiment()
    smoke_adjusted = TricTracZero.adjust_experiment_for_resume(smoke_experiment, dir; auto_extend = false)
    @test smoke_adjusted.params.num_iters == smoke_experiment.params.num_iters
  end
end

@testset "Explicit Iteration Override" begin
  @test TricTracZero.build_params(smoke = false, use_gpu = false, num_iters = 7).num_iters == 7
  @test TricTracZero.build_params(smoke = true, use_gpu = false, num_iters = 2).num_iters == 2
  @test TricTracZero.default_experiment(num_iters = 11).params.num_iters == 11
  @test TricTracZero.smoke_experiment(num_iters = 3).params.num_iters == 3
end

@testset "Preset Experiments" begin
  @test TricTracZero.available_presets() == [
    "classique",
    "classique-margot",
    "aecrire",
    "aecrire-margot",
    "combine",
    "combine-margot",
    "toc",
    "toc-margot",
    "toccategli",
    "toccategli-margot"
  ]

  classique = TricTracZero.default_experiment(preset = "classique")
  @test classique.name == "trictrac-classique"
  @test classique.gspec.variant_id == "trictrac_classique"
  @test classique.gspec.match_options["margotEnabled"] == false
  @test classique.gspec.tactical_config["enabled"] == true
  @test classique.gspec.tactical_config["horizon_own_turns"] == 3

  classique_yes = TricTracZero.default_experiment(preset = "classique-margot")
  @test classique_yes.name == "trictrac-classique-margot"
  @test classique_yes.gspec.variant_id == "trictrac_classique"
  @test classique_yes.gspec.match_options["margotEnabled"] == true
  @test classique_yes.gspec.tactical_config["enabled"] == true
  @test classique_yes.gspec.tactical_config["horizon_own_turns"] == 3

  aecrire = TricTracZero.default_experiment(preset = "aecrire")
  @test aecrire.name == "trictrac-aecrire"
  @test aecrire.gspec.variant_id == "trictrac_aecrire"
  @test aecrire.gspec.match_options["margotEnabled"] == false
  @test aecrire.gspec.tactical_config["enabled"] == false
  @test aecrire.gspec.tactical_config["horizon_own_turns"] == 0

  aecrire_yes = TricTracZero.default_experiment(preset = "aecrire-margot")
  @test aecrire_yes.name == "trictrac-aecrire-margot"
  @test aecrire_yes.gspec.match_options["margotEnabled"] == true

  combine = TricTracZero.default_experiment(preset = "combine")
  @test combine.name == "trictrac-combine"
  @test combine.gspec.variant_id == "trictrac_combine"
  @test combine.gspec.match_options["margotEnabled"] == false

  combine_yes = TricTracZero.default_experiment(preset = "combine-margot")
  @test combine_yes.name == "trictrac-combine-margot"
  @test combine_yes.gspec.match_options["margotEnabled"] == true

  toc = TricTracZero.default_experiment(preset = "toc")
  @test toc.name == "toc"
  @test toc.gspec.variant_id == "toc"
  @test toc.gspec.match_options["margotEnabled"] == false
  @test toc.gspec.match_options["holeTarget"] == "7"
  @test toc.gspec.match_options["doublesMode"] == "off"
  @test toc.gspec.tactical_config["enabled"] == false

  toc_yes = TricTracZero.default_experiment(preset = :toc_margot)
  @test toc_yes.name == "toc-margot"
  @test toc_yes.gspec.match_options["margotEnabled"] == true

  tocc = TricTracZero.smoke_experiment(preset = "toccategli")
  @test tocc.name == "toccategli-smoke"
  @test tocc.gspec.variant_id == "toccategli"
  @test tocc.gspec.match_options["margotEnabled"] == false

  @test TricTracZero.source_session_dir_for_preset("classique") === nothing
  @test TricTracZero.source_session_dir_for_preset("aecrire") === nothing
  @test occursin(
    "trictrac-aecrire-$(TricTracZero.session_layout_version(TricTracZero.conv_netparams()))",
    TricTracZero.source_session_dir_for_preset("combine")
  )
  @test occursin(
    "trictrac-classique-$(TricTracZero.session_layout_version(TricTracZero.conv_netparams()))",
    TricTracZero.source_session_dir_for_preset("toc")
  )
end

@testset "Classique Tactical Replay Reset" begin
  mktempdir() do dir
    old_spec = TricTracGameSpec(tactical_config = Dict(
      "enabled" => false,
      "horizon_own_turns" => 0,
      "reward_weight" => 0.0,
      "heuristic_weight" => 0.0,
      "version" => "classique-tactical-v0"
    ))
    params = TricTracZero.build_params(smoke = true, use_gpu = false)
    nn = TricTracSparseNet(old_spec, TricTracZero.netparams())
    samples = sample_training_examples(old_spec; n = 3, seed = 29)
    env = AlphaZero.Env(old_spec, params, nn, copy(nn), samples, 4)
    UserInterface.save_env(env, dir)

    new_spec = TricTracGameSpec(tactical_config = Dict(
      "enabled" => true,
      "horizon_own_turns" => 3,
      "reward_weight" => 1.0,
      "heuristic_weight" => 1.0
    ))

    @test TricTracZero.apply_session_runtime_metadata!(dir, new_spec)

    recovered = UserInterface.load_env(dir)
    @test isempty(AlphaZero.get_experience(recovered))
    @test recovered.gspec.tactical_config["enabled"] == true
    @test recovered.gspec.tactical_config["horizon_own_turns"] == 3
    @test recovered.itc == 4
    @test recovered.bestnn.common[1].weight == nn.common[1].weight
    @test isfile(TricTracZero.session_runtime_metadata_path(dir))

    metadata = TricTracZero.load_session_runtime_metadata(dir)
    @test metadata["classique_tactical_signature"]["enabled"] == true
    @test !TricTracZero.apply_session_runtime_metadata!(dir, new_spec)

    changed_spec = TricTracGameSpec(tactical_config = Dict(
      "enabled" => true,
      "horizon_own_turns" => 2,
      "reward_weight" => 1.0,
      "heuristic_weight" => 0.5
    ))

    repopulated = AlphaZero.Env(changed_spec, params, recovered.curnn, recovered.bestnn, samples, recovered.itc)
    UserInterface.save_env(repopulated, dir)
    @test TricTracZero.apply_session_runtime_metadata!(dir, changed_spec)
    @test isempty(AlphaZero.get_experience(UserInterface.load_env(dir)))
  end
end

@testset "Variant Bootstrap" begin
  specs = [
    TricTracGameSpec(variant_id = "trictrac_classique", match_options = Dict("margotEnabled" => true)),
    TricTracGameSpec(variant_id = "trictrac_aecrire", match_options = Dict("margotEnabled" => false)),
    TricTracGameSpec(variant_id = "trictrac_combine", match_options = Dict("margotEnabled" => true)),
    TricTracGameSpec(
      variant_id = "toc",
      match_options = Dict("holeTarget" => "7", "doublesMode" => "off", "margotEnabled" => true)
    ),
    TricTracGameSpec(variant_id = "toccategli", match_options = Dict("margotEnabled" => false))
  ]

  for spec in specs
    game = GI.init(spec)
    @test GI.white_playing(game)
    @test !GI.game_terminated(game)
    @test length(GI.available_actions(game)) == 1
    @test only(GI.available_actions(game)).kind == TricTracZero.ROLL_ACTION
  end
end

@testset "Warm-Start Network Factory" begin
  mktempdir() do dir
    source_spec = classique_test_spec()
    hyper = TricTracZero.netparams()
    source_nn = TricTracSparseNet(source_spec, hyper)
    env = AlphaZero.Env(
      source_spec,
      TricTracZero.build_params(smoke = true, use_gpu = false),
      source_nn,
      copy(source_nn),
      AlphaZero.TrainingSample{TricTracState}[],
      0
    )
    AlphaZero.UserInterface.save_env(env, dir)

    target_spec = TricTracGameSpec(
      variant_id = "toc",
      match_options = Dict("holeTarget" => "7", "doublesMode" => "off", "margotEnabled" => true)
    )
    warmed = TricTracZero.warmstart_network(TricTracSparseNet, target_spec, hyper, dir)
    @test warmed.gspec.variant_id == "toc"
    @test warmed.gspec.match_options["margotEnabled"] == true
    @test AlphaZero.Network.hyperparams(warmed) == hyper
  end
end

@testset "Session Uses Modified Params" begin
  mktempdir() do dir
    spec = classique_test_spec()
    params = TricTracZero.build_params(smoke = false, use_gpu = false)
    nn = TricTracSparseNet(spec, TricTracZero.netparams())
    env = AlphaZero.Env(spec, params, nn, copy(nn), AlphaZero.TrainingSample{TricTracState}[], 0)
    UserInterface.save_env(env, dir)
    it0 = joinpath(dir, UserInterface.ITERS_DIR, "0")
    mkpath(it0)
    UserInterface.write_json_atomic(joinpath(it0, UserInterface.BENCHMARK_FILE), AlphaZero.Report.Benchmark())

    updated_params = Params(params; num_iters = params.num_iters + 3)
    experiment = AlphaZero.Experiments.Experiment(
      "trictrac-classique",
      spec,
      updated_params,
      TricTracSparseNet,
      TricTracZero.netparams(),
      TricTracZero.BENCHMARKS
    )
    session = UserInterface.Session(experiment; dir = dir, autosave = false, nostdout = true)
    @test session.env.params.num_iters == updated_params.num_iters
  end
end
