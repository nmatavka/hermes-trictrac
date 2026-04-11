const NETWORK = TricTracSparseNet
const BENCHMARKS = Benchmark.Evaluation[]
const SESSION_LAYOUT_VERSION = "sparse-v4-arena96x16"
const DEFAULT_TRAIN_ITERATIONS = 3
const DEFAULT_SMOKE_ITERATIONS = 1
const DEFAULT_PRESET = "classique"
const DEFAULT_TOC_OPTIONS = Dict{String, Any}(
  "holeTarget" => "7",
  "doublesMode" => "off"
)

function normalize_preset_name(preset::Union{String, Symbol})
  return replace(lowercase(String(preset)), '_' => '-')
end

function preset_config(preset::Union{String, Symbol})
  key = normalize_preset_name(preset)

  if key == "classique"
    return (
      key = key,
      experiment = "trictrac-classique",
      variant_id = "trictrac_classique",
      match_options = Dict{String, Any}("margotEnabled" => false),
      warmstart_source = nothing
    )
  elseif key == "classique-margot"
    return (
      key = key,
      experiment = "trictrac-classique-margot",
      variant_id = "trictrac_classique",
      match_options = Dict{String, Any}("margotEnabled" => true),
      warmstart_source = "classique"
    )
  elseif key == "aecrire"
    return (
      key = key,
      experiment = "trictrac-aecrire",
      variant_id = "trictrac_aecrire",
      match_options = Dict{String, Any}("margotEnabled" => false),
      warmstart_source = nothing
    )
  elseif key == "aecrire-margot"
    return (
      key = key,
      experiment = "trictrac-aecrire-margot",
      variant_id = "trictrac_aecrire",
      match_options = Dict{String, Any}("margotEnabled" => true),
      warmstart_source = "aecrire"
    )
  elseif key == "combine"
    return (
      key = key,
      experiment = "trictrac-combine",
      variant_id = "trictrac_combine",
      match_options = Dict{String, Any}("margotEnabled" => false),
      warmstart_source = "aecrire"
    )
  elseif key == "combine-margot"
    return (
      key = key,
      experiment = "trictrac-combine-margot",
      variant_id = "trictrac_combine",
      match_options = Dict{String, Any}("margotEnabled" => true),
      warmstart_source = "combine"
    )
  elseif key == "toc"
    return (
      key = key,
      experiment = "toc",
      variant_id = "toc",
      match_options = merge(copy(DEFAULT_TOC_OPTIONS), Dict{String, Any}("margotEnabled" => false)),
      warmstart_source = "classique"
    )
  elseif key == "toc-margot"
    return (
      key = key,
      experiment = "toc-margot",
      variant_id = "toc",
      match_options = merge(copy(DEFAULT_TOC_OPTIONS), Dict{String, Any}("margotEnabled" => true)),
      warmstart_source = "toc"
    )
  elseif key == "toccategli"
    return (
      key = key,
      experiment = "toccategli",
      variant_id = "toccategli",
      match_options = Dict{String, Any}("margotEnabled" => false),
      warmstart_source = "classique"
    )
  elseif key == "toccategli-margot"
    return (
      key = key,
      experiment = "toccategli-margot",
      variant_id = "toccategli",
      match_options = Dict{String, Any}("margotEnabled" => true),
      warmstart_source = "toccategli"
    )
  else
    error(
      "Unknown TricTrac preset $(repr(String(preset))). Expected one of: " *
      join(available_presets(), ", ")
    )
  end
end

available_presets() = [
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

gpu_available() = AlphaZero.FluxLib.CUDA.functional()

function require_gpu_available()
  gpu_available() && return nothing
  error("GPU training requested, but CUDA.functional() is false in this environment.")
end

function netparams()
  return TricTracSparseNetHP(
    num_filters = 32,
    num_blocks = 2,
    conv_kernel_size = (3, 1),
    num_policy_head_filters = 16,
    num_value_head_filters = 16,
    policy_hidden_dim = 64,
    batch_norm_momentum = 0.1
  )
end

function source_session_dir_for_preset(preset::Union{String, Symbol})
  config = preset_config(preset)
  isnothing(config.warmstart_source) && return nothing
  source = preset_config(config.warmstart_source)
  return joinpath(
    DEFAULT_SESSIONS_ROOT,
    string(source.experiment, "-", SESSION_LAYOUT_VERSION)
  )
end

function warmstart_network(gspec::TricTracGameSpec, hyper::TricTracSparseNetHP, source_dir::String)
  if !AlphaZero.UserInterface.valid_session_dir(source_dir)
    @warn "Warm-start source session $source_dir is not available; starting from random weights."
    return NETWORK(gspec, hyper)
  end

  source_env = AlphaZero.UserInterface.load_env(source_dir)
  if JSON3.write(AlphaZero.Network.hyperparams(source_env.bestnn)) != JSON3.write(hyper)
    @warn "Warm-start source session $source_dir has incompatible network hyperparameters; starting from random weights."
    return NETWORK(gspec, hyper)
  end
  if GI.state_dim(source_env.gspec) != GI.state_dim(gspec)
    @warn "Warm-start source session $source_dir has incompatible input dimensions; starting from random weights."
    return NETWORK(gspec, hyper)
  end

  network = AlphaZero.Network.copy(source_env.bestnn, on_gpu = false, test_mode = false)
  network.gspec = gspec
  return network
end

function network_factory(;
  source_dir::Union{Nothing, String} = nothing
)
  if isnothing(source_dir)
    return NETWORK
  end

  return function(gspec::TricTracGameSpec, hyper::TricTracSparseNetHP)
    return warmstart_network(gspec, hyper, source_dir)
  end
end

default_num_iters(; smoke::Bool) = smoke ? DEFAULT_SMOKE_ITERATIONS : DEFAULT_TRAIN_ITERATIONS

function max_local_worker_count()
  return max(1, Threads.nthreads() - 1)
end

function default_worker_counts(; smoke::Bool)
  if smoke
    return (self_play = 1, arena = 1)
  else
    return (
      self_play = min(4, max(1, Threads.nthreads() - 1)),
      arena = min(2, max(1, Threads.nthreads() ÷ 2))
    )
  end
end

function resolve_worker_settings(;
  smoke::Bool,
  self_play_workers::Union{Nothing, Int} = nothing,
  arena_workers::Union{Nothing, Int} = nothing
)
  defaults = default_worker_counts(smoke = smoke)
  cap = max_local_worker_count()

  requested_self_play = self_play_workers
  requested_arena = arena_workers
  resolved_self_play = isnothing(self_play_workers) ? defaults.self_play : clamp(self_play_workers, 1, cap)
  resolved_arena = isnothing(arena_workers) ? defaults.arena : clamp(arena_workers, 1, cap)

  return (
    self_play = resolved_self_play,
    arena = resolved_arena,
    self_play_requested = requested_self_play,
    arena_requested = requested_arena,
    self_play_clamped = !isnothing(requested_self_play) && requested_self_play != resolved_self_play,
    arena_clamped = !isnothing(requested_arena) && requested_arena != resolved_arena,
    cap = cap
  )
end

function warn_on_clamped_workers(worker_settings)
  if worker_settings.self_play_clamped
    @warn "Requested self-play workers $(worker_settings.self_play_requested) exceed local capacity $(worker_settings.cap); using $(worker_settings.self_play)."
  end
  if worker_settings.arena_clamped
    @warn "Requested arena workers $(worker_settings.arena_requested) exceed local capacity $(worker_settings.cap); using $(worker_settings.arena)."
  end
  return nothing
end
function build_params(;
  smoke::Bool,
  use_gpu::Bool = false,
  num_iters::Union{Nothing, Int} = nothing,
  self_play_workers::Union{Nothing, Int} = nothing,
  arena_workers::Union{Nothing, Int} = nothing
)
  worker_settings = resolve_worker_settings(
    smoke = smoke,
    self_play_workers = self_play_workers,
    arena_workers = arena_workers
  )
  warn_on_clamped_workers(worker_settings)

  cpu_mode = !use_gpu

  self_play_mcts =
    smoke ?
      MctsParams(
        num_iters_per_turn = 4,
        cpuct = 1.5,
        dirichlet_noise_ϵ = 0.15,
        dirichlet_noise_α = 0.5,
        temperature = ConstSchedule(1.0)
      ) :
      MctsParams(
        num_iters_per_turn = cpu_mode ? 32 : 32,
        cpuct = 1.5,
        dirichlet_noise_ϵ = 0.20,
        dirichlet_noise_α = 0.35,
        temperature = PLSchedule([0, 6, 12], [1.0, 0.7, 0.3])
      )

  # CPU strategy:
  # - self-play: hot, long, smooth
  #   * keep batch_size = 1 on CPU
  #   * use several workers
  #   * make it much longer with more games
  #
  # - arena: hot, short
  #   * use more than 1 worker
  #   * keep game count low
  #   * keep batch_size = 1 on CPU
  resolved_self_play_workers =
    smoke ? worker_settings.self_play : (cpu_mode ? min(worker_settings.cap, 6) : worker_settings.self_play)

  resolved_arena_workers =
    smoke ? worker_settings.arena : (cpu_mode ? min(worker_settings.cap, 6) : worker_settings.arena)

  self_play_sim =
    smoke ?
      SimParams(
        num_games = 4,
        num_workers = resolved_self_play_workers,
        batch_size = 1,
        use_gpu = use_gpu,
        fill_batches = use_gpu,
        reset_every = 1,
        flip_probability = 0.0,
        alternate_colors = false
      ) :
      SimParams(
        num_games = cpu_mode ? 96 : 32,
        num_workers = resolved_self_play_workers,
        batch_size = cpu_mode ? 1 : 4,
        use_gpu = use_gpu,
        fill_batches = use_gpu,
        reset_every = 1,
        flip_probability = 0.0,
        alternate_colors = false
      )

  self_play = SelfPlayParams(sim = self_play_sim, mcts = self_play_mcts)

  arena_sim =
    smoke ?
      SimParams(
        num_games = 2,
        num_workers = resolved_arena_workers,
        batch_size = 1,
        use_gpu = use_gpu,
        fill_batches = use_gpu,
        reset_every = 1,
        flip_probability = 0.0,
        alternate_colors = true
      ) :
      SimParams(
        num_games = cpu_mode ? 8 : 16,
        num_workers = resolved_arena_workers,
        batch_size = 1,
        use_gpu = use_gpu,
        fill_batches = false,
        reset_every = 1,
        flip_probability = 0.0,
        alternate_colors = true
      )

  arena_mcts =
    MctsParams(
      self_play_mcts,
      num_iters_per_turn = smoke ? 8 : 96,
      temperature = ConstSchedule(smoke ? 0.3 : 0.05),
      dirichlet_noise_ϵ = 0.0
    )

  arena = ArenaParams(sim = arena_sim, mcts = arena_mcts, update_threshold = 0.0)

  learning =
    smoke ?
      LearningParams(
        use_gpu = use_gpu,
        use_position_averaging = true,
        samples_weighing_policy = LOG_WEIGHT,
        batch_size = 8,
        loss_computation_batch_size = 8,
        optimiser = Adam(lr = 1e-3),
        l2_regularization = 1f-4,
        nonvalidity_penalty = 1f0,
        min_checkpoints_per_epoch = 1,
        max_batches_per_checkpoint = 4,
        num_checkpoints = 1
      ) :
      LearningParams(
        use_gpu = use_gpu,
        use_position_averaging = true,
        samples_weighing_policy = LOG_WEIGHT,
        batch_size = 64,
        loss_computation_batch_size = 64,
        optimiser = Adam(lr = 8e-4),
        l2_regularization = 1f-4,
        nonvalidity_penalty = 1f0,
        min_checkpoints_per_epoch = 1,
        max_batches_per_checkpoint = 32,
        num_checkpoints = 1
      )

  return Params(
    arena = arena,
    self_play = self_play,
    learning = learning,
    num_iters = isnothing(num_iters) ? default_num_iters(smoke = smoke) : num_iters,
    ternary_outcome = false,
    use_symmetries = false,
    memory_analysis = nothing,
    mem_buffer_size =
      smoke ?
        PLSchedule([0, 1], [256, 512]) :
        PLSchedule([0, 1, 3], [10_000, 25_000, 50_000])
  )
end
function session_iteration_count(dir::String)
  path = joinpath(dir, "iter.txt")
  isfile(path) || return nothing
  return open(JSON3.read, path, "r")
end

function adjust_experiment_for_resume(
  experiment::Experiment,
  session_dir::String;
  auto_extend::Bool = true
)
  auto_extend || return experiment
  session_itc = session_iteration_count(session_dir)
  isnothing(session_itc) && return experiment
  session_itc < experiment.params.num_iters && return experiment

  extension = max(1, default_num_iters(smoke = false))
  new_num_iters = session_itc + extension
  @info "Existing session at $session_dir already reached iteration $(session_itc)/$(experiment.params.num_iters); extending training target to $new_num_iters."
  new_params = Params(experiment.params; num_iters = new_num_iters)
  return Experiment(
    experiment.name,
    experiment.gspec,
    new_params,
    experiment.mknet,
    experiment.netparams,
    experiment.benchmark
  )
end

function default_experiment(;
  repo_root::String = REPO_ROOT,
  preset::Union{String, Symbol} = DEFAULT_PRESET,
  use_gpu::Bool = false,
  num_iters::Union{Nothing, Int} = nothing,
  self_play_workers::Union{Nothing, Int} = nothing,
  arena_workers::Union{Nothing, Int} = nothing
)
  config = preset_config(preset)
  gspec = game_spec_for_preset(repo_root = repo_root, preset = preset)
  return Experiment(
    config.experiment,
    gspec,
    build_params(
      smoke = false,
      use_gpu = use_gpu,
      num_iters = num_iters,
      self_play_workers = self_play_workers,
      arena_workers = arena_workers
    ),
    network_factory(source_dir = source_session_dir_for_preset(config.key)),
    netparams(),
    BENCHMARKS
  )
end

function smoke_experiment(;
  repo_root::String = REPO_ROOT,
  preset::Union{String, Symbol} = DEFAULT_PRESET,
  use_gpu::Bool = false,
  num_iters::Union{Nothing, Int} = nothing,
  self_play_workers::Union{Nothing, Int} = nothing,
  arena_workers::Union{Nothing, Int} = nothing
)
  config = preset_config(preset)
  gspec = game_spec_for_preset(repo_root = repo_root, preset = preset)
  return Experiment(
    string(config.experiment, "-smoke"),
    gspec,
    build_params(
      smoke = true,
      use_gpu = use_gpu,
      num_iters = num_iters,
      self_play_workers = self_play_workers,
      arena_workers = arena_workers
    ),
    network_factory(source_dir = source_session_dir_for_preset(config.key)),
    netparams(),
    BENCHMARKS
  )
end

function game_spec_for_preset(;
  repo_root::String = REPO_ROOT,
  preset::Union{String, Symbol} = DEFAULT_PRESET
)
  config = preset_config(preset)
  return TricTracGameSpec(
    repo_root = repo_root,
    variant_id = config.variant_id,
    match_options = config.match_options
  )
end

session_dir_name(exp::Experiment) = string(exp.name, "-", SESSION_LAYOUT_VERSION)

function default_session_dir(exp::Experiment)
  return joinpath(DEFAULT_SESSIONS_ROOT, session_dir_name(exp))
end

function empty_replay_buffer()
  return AlphaZero.TrainingSample{TricTracState}[]
end

function reset_session_memory!(dir::String)
  AlphaZero.UserInterface.valid_session_dir(dir) || return false
  path = joinpath(dir, AlphaZero.UserInterface.MEM_FILE)
  AlphaZero.UserInterface.serialize_atomic(path, empty_replay_buffer())
  return true
end

function register_experiments!(;
  use_gpu::Bool = false,
  num_iters::Union{Nothing, Int} = nothing,
  self_play_workers::Union{Nothing, Int} = nothing,
  arena_workers::Union{Nothing, Int} = nothing
)
  for preset in available_presets()
    config = preset_config(preset)
    AlphaZero.Examples.games[config.experiment] = TricTracGameSpec(
      variant_id = config.variant_id,
      match_options = config.match_options
    )
    AlphaZero.Examples.experiments[config.experiment] =
      default_experiment(
        preset = config.key,
        use_gpu = use_gpu,
        num_iters = num_iters,
        self_play_workers = self_play_workers,
        arena_workers = arena_workers
      )
    AlphaZero.Examples.experiments[string(config.experiment, "-smoke")] =
      smoke_experiment(
        preset = config.key,
        use_gpu = use_gpu,
        num_iters = num_iters,
        self_play_workers = self_play_workers,
        arena_workers = arena_workers
      )
  end
  return nothing
end

function run_train(;
  profile::String = "default",
  preset::Union{String, Symbol} = DEFAULT_PRESET,
  dir::Union{Nothing, String} = nothing,
  test_game::Bool = false,
  use_gpu::Bool = false,
  reset_memory::Bool = false,
  num_iters::Union{Nothing, Int} = nothing,
  self_play_workers::Union{Nothing, Int} = nothing,
  arena_workers::Union{Nothing, Int} = nothing
)
  use_gpu && require_gpu_available()
  experiment =
    profile == "smoke" ?
      smoke_experiment(
        preset = preset,
        use_gpu = use_gpu,
        num_iters = num_iters,
        self_play_workers = self_play_workers,
        arena_workers = arena_workers
      ) :
      default_experiment(
        preset = preset,
        use_gpu = use_gpu,
        num_iters = num_iters,
        self_play_workers = self_play_workers,
        arena_workers = arena_workers
      )
  register_experiments!(
    use_gpu = use_gpu,
    num_iters = num_iters,
    self_play_workers = self_play_workers,
    arena_workers = arena_workers
  )
  session_dir = isnothing(dir) ? default_session_dir(experiment) : dir
  if reset_memory
    if reset_session_memory!(session_dir)
      @info "Reset replay buffer in $session_dir before training."
    else
      @info "No existing session at $session_dir; replay buffer reset skipped."
    end
  end
  experiment = adjust_experiment_for_resume(
    experiment,
    session_dir;
    auto_extend = profile != "smoke" && isnothing(num_iters)
  )
  test_game && AlphaZero.Scripts.test_game(experiment.gspec; n = 4)
  return AlphaZero.Scripts.train(experiment; dir = session_dir, autosave = true, save_intermediate = false)
end

function run_smoke(;
  dir::Union{Nothing, String} = nothing,
  preset::Union{String, Symbol} = DEFAULT_PRESET,
  use_gpu::Bool = false,
  reset_memory::Bool = false,
  num_iters::Union{Nothing, Int} = nothing,
  self_play_workers::Union{Nothing, Int} = nothing,
  arena_workers::Union{Nothing, Int} = nothing
)
  session_dir =
    isnothing(dir) ?
      default_session_dir(
        smoke_experiment(
          preset = preset,
          use_gpu = use_gpu,
          num_iters = num_iters,
          self_play_workers = self_play_workers,
          arena_workers = arena_workers
        )
      ) :
      dir
  return run_train(
    profile = "smoke",
    preset = preset,
    dir = session_dir,
    test_game = true,
    use_gpu = use_gpu,
    reset_memory = reset_memory,
    num_iters = num_iters,
    self_play_workers = self_play_workers,
    arena_workers = arena_workers
  )
end

function run_explore(;
  dir::Union{Nothing, String} = nothing,
  preset::Union{String, Symbol} = DEFAULT_PRESET
)
  experiment = default_experiment(preset = preset)
  register_experiments!()
  session_dir = isnothing(dir) ? default_session_dir(experiment) : dir
  return AlphaZero.Scripts.explore(experiment; dir = session_dir)
end
