using Test
using Random
using TricTracZero
using AlphaZero
import AlphaZero.GI
import AlphaZero.UserInterface

include(joinpath(@__DIR__, "..", "scripts", "cpu_config.jl"))

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
  spec = TricTracGameSpec()
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

@testset "Self-Play Straggler Policy" begin
  spec = TricTracGameSpec()
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
  @test AlphaZero.max_game_length(spec) == TricTracZero.DEFAULT_TEMP_MAX_GAME_LENGTH
  @test isnothing(AlphaZero.self_play_straggler_policy(aecrire_spec))
  @test isnothing(AlphaZero.checkpoint_straggler_policy(aecrire_spec))
  @test isnothing(AlphaZero.max_game_length(aecrire_spec))
  @test isnothing(AlphaZero.self_play_straggler_policy(combine_spec))
  @test isnothing(AlphaZero.checkpoint_straggler_policy(combine_spec))
  @test isnothing(AlphaZero.max_game_length(combine_spec))

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
  spec = TricTracGameSpec()
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
  spec = TricTracGameSpec()
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

@testset "Adam Learning Regression" begin
  spec = TricTracGameSpec()
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
    spec = TricTracGameSpec()
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
    TricTracScriptCPU.ENV_GAME => "toc"
  )

  parsed = TricTracScriptCPU.parse_startup(
    :train,
    [
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
      "--gpu",
      "--reset-memory",
      "default",
      "/tmp/session"
    ];
    env
  )
  @test parsed.use_gpu
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
  @test occursin("--cpu-policy", help_text)
  @test occursin("--cpu-threads", help_text)
  @test occursin("--self-play-workers", help_text)
  @test occursin("--iterations", help_text)
  @test occursin("--move-cap", help_text)
  @test occursin("--target-gain", help_text)
  @test occursin("--partie-length-repeats", help_text)
  @test occursin("--game", help_text)
  @test occursin("--reset-memory", help_text)
  @test occursin("CLI values override environment variables", help_text)

  @test_throws ArgumentError TricTracScriptCPU.parse_startup(:train, ["--cpu-policy=bogus"]; env = Dict{String, String}())
  @test_throws ArgumentError TricTracScriptCPU.parse_startup(:train, ["--cpu-threads=0"]; env = Dict{String, String}())
  @test_throws ArgumentError TricTracScriptCPU.parse_startup(:train, ["--iterations=0"]; env = Dict{String, String}())
  @test_throws ArgumentError TricTracScriptCPU.parse_startup(:train, ["--move-cap=-1"]; env = Dict{String, String}())
  @test_throws ArgumentError TricTracScriptCPU.parse_startup(:train, ["--target-gain=-1"]; env = Dict{String, String}())
  @test_throws ArgumentError TricTracScriptCPU.parse_startup(:train, ["--partie-length-repeats=0"]; env = Dict{String, String}())
  @test_throws ArgumentError TricTracScriptCPU.parse_startup(:train, ["--game=bogus"]; env = Dict{String, String}())
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
    spec = TricTracGameSpec()
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
end

@testset "Completed Session Extension" begin
  mktempdir() do dir
    spec = TricTracGameSpec()
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

  classique_yes = TricTracZero.default_experiment(preset = "classique-margot")
  @test classique_yes.name == "trictrac-classique-margot"
  @test classique_yes.gspec.variant_id == "trictrac_classique"
  @test classique_yes.gspec.match_options["margotEnabled"] == true

  aecrire = TricTracZero.default_experiment(preset = "aecrire")
  @test aecrire.name == "trictrac-aecrire"
  @test aecrire.gspec.variant_id == "trictrac_aecrire"
  @test aecrire.gspec.match_options["margotEnabled"] == false

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
    "trictrac-aecrire-$(TricTracZero.SESSION_LAYOUT_VERSION)",
    TricTracZero.source_session_dir_for_preset("combine")
  )
  @test occursin(
    "trictrac-classique-$(TricTracZero.SESSION_LAYOUT_VERSION)",
    TricTracZero.source_session_dir_for_preset("toc")
  )
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
    source_spec = TricTracGameSpec()
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
    warmed = TricTracZero.warmstart_network(target_spec, hyper, dir)
    @test warmed.gspec.variant_id == "toc"
    @test warmed.gspec.match_options["margotEnabled"] == true
    @test AlphaZero.Network.hyperparams(warmed) == hyper
  end
end

@testset "Session Uses Modified Params" begin
  mktempdir() do dir
    spec = TricTracGameSpec()
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
      TricTracZero.NETWORK,
      TricTracZero.netparams(),
      TricTracZero.BENCHMARKS
    )
    session = UserInterface.Session(experiment; dir = dir, autosave = false, nostdout = true)
    @test session.env.params.num_iters == updated_params.num_iters
  end
end
