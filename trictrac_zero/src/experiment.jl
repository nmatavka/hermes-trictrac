const DEFAULT_NETWORK = TricTracSparseNet
const METAL_FALLBACK_NETWORK = TricTracMetalSparseNet
const BENCHMARKS = Benchmark.Evaluation[]
const CONV_SESSION_LAYOUT_VERSION = "sparse-v4-arena96x16"
const METAL_DENSE_SESSION_LAYOUT_VERSION = "metal-dense-v1"
const METAL_CONV_PROBE_RESULT = Ref{Any}(nothing)
const DEFAULT_DEVICE = DEVICE_CPU
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

function resolve_requested_device(;
  device::Union{Symbol, AbstractString} = DEFAULT_DEVICE,
  use_gpu::Union{Nothing, Bool} = nothing
)
  requested = normalize_device_backend(device)
  if !isnothing(use_gpu) && requested == DEFAULT_DEVICE
    requested = use_gpu ? DEVICE_AUTO : DEVICE_CPU
  end
  return requested
end

gpu_available() = resolve_device_backend(DEVICE_AUTO) != DEVICE_CPU

function require_gpu_available()
  gpu_available() && return nothing
  error("GPU training requested, but no supported GPU backend is functional in this environment.")
end

function conv_netparams()
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

function metal_netparams()
  return TricTracMetalSparseNetHP(
    trunk_width = 256,
    num_blocks = 4,
    state_latent_dim = 128,
    action_hidden_dim = 128,
    value_hidden_dim = 128
  )
end

network_type_for_netparams(::TricTracSparseNetHP) = TricTracSparseNet
network_type_for_netparams(::TricTracMetalSparseNetHP) = TricTracMetalSparseNet

network_family_name(::Type{<:TricTracSparseNet}) = "sparse-conv"
network_family_name(::Type{<:TricTracMetalSparseNet}) = "metal-dense"
network_family_name(network) = network_family_name(typeof(network))

session_layout_version(::TricTracSparseNetHP) = CONV_SESSION_LAYOUT_VERSION
session_layout_version(::TricTracMetalSparseNetHP) = METAL_DENSE_SESSION_LAYOUT_VERSION

function probe_sparse_conv_on_metal()
  cached = METAL_CONV_PROBE_RESULT[]
  !isnothing(cached) && return cached

  if !device_available(DEVICE_METAL)
    result = (supported = false, error = "Metal.functional() is false in this environment.")
    METAL_CONV_PROBE_RESULT[] = result
    return result
  end

  previous_backend = active_device_backend()
  try
    set_runtime_device!(DEVICE_METAL)
    for preset in ("classique", "aecrire")
      config = preset_config(preset)
      gspec = TricTracGameSpec(variant_id = config.variant_id, match_options = config.match_options)
      nn = AlphaZero.Network.to_gpu(TricTracSparseNet(gspec, conv_netparams()))
      dims = GI.state_dim(gspec)
      X = rand(Float32, dims..., 2)
      F = rand(Float32, NUM_ACTION_FEATURES, 5, 2)
      M = ones(Float32, 5, 2)
      Xnet, Fnet, Mnet = AlphaZero.Network.convert_input_tuple(nn, (X, F, M))
      Flux.withgradient(nn -> begin
        P, V, _ = sparse_policy_forward(nn, Xnet, Fnet, Mnet)
        return sum(P) + sum(V)
      end, nn)
    end
    result = (supported = true, error = nothing)
    METAL_CONV_PROBE_RESULT[] = result
    return result
  catch err
    result = (supported = false, error = sprint(showerror, err))
    METAL_CONV_PROBE_RESULT[] = result
    return result
  finally
    set_runtime_device!(previous_backend)
  end
end

metal_conv_supported() = probe_sparse_conv_on_metal().supported

function summarize_probe_error(detail::Union{Nothing, AbstractString}; limit::Int = 200)
  isnothing(detail) && return nothing
  summary = first(split(String(detail), '\n'; limit = 2))
  return ncodeunits(summary) <= limit ? summary : string(summary[1:limit], "...")
end

function network_type_for_device(device::Union{Symbol, AbstractString} = DEFAULT_DEVICE)
  resolved_device = resolve_device_backend(device)
  if resolved_device == DEVICE_METAL && !metal_conv_supported()
    return METAL_FALLBACK_NETWORK
  end
  return DEFAULT_NETWORK
end

function netparams(;
  device::Union{Symbol, AbstractString} = DEFAULT_DEVICE,
  network_type::Union{Nothing, Type} = nothing
)
  NetworkType = isnothing(network_type) ? network_type_for_device(device) : network_type
  if NetworkType == TricTracSparseNet
    return conv_netparams()
  elseif NetworkType == TricTracMetalSparseNet
    return metal_netparams()
  else
    error("Unsupported TricTrac network type $(NetworkType).")
  end
end

function source_session_dir_for_preset(
  preset::Union{String, Symbol};
  device::Union{Symbol, AbstractString} = DEFAULT_DEVICE,
  network_type::Union{Nothing, Type} = nothing
)
  config = preset_config(preset)
  isnothing(config.warmstart_source) && return nothing
  source = preset_config(config.warmstart_source)
  hyper = netparams(device = device, network_type = network_type)
  return joinpath(
    DEFAULT_SESSIONS_ROOT,
    string(source.experiment, "-", session_layout_version(hyper))
  )
end

function warmstart_network(
  NetworkType::Type{<:TricTracSparsePolicyNet},
  gspec::TricTracGameSpec,
  hyper,
  source_dir::String
)
  if !AlphaZero.UserInterface.valid_session_dir(source_dir)
    @warn "Warm-start source session $source_dir is not available; starting from random weights."
    return NetworkType(gspec, hyper)
  end

  source_env = AlphaZero.UserInterface.load_env(source_dir)
  if !(source_env.bestnn isa NetworkType)
    @warn "Warm-start source session $source_dir uses $(network_family_name(source_env.bestnn)) weights, but this run expects $(network_family_name(NetworkType)); starting from random weights."
    return NetworkType(gspec, hyper)
  end
  if JSON3.write(AlphaZero.Network.hyperparams(source_env.bestnn)) != JSON3.write(hyper)
    @warn "Warm-start source session $source_dir has incompatible network hyperparameters; starting from random weights."
    return NetworkType(gspec, hyper)
  end
  if GI.state_dim(source_env.gspec) != GI.state_dim(gspec)
    @warn "Warm-start source session $source_dir has incompatible input dimensions; starting from random weights."
    return NetworkType(gspec, hyper)
  end

  network = AlphaZero.Network.copy(source_env.bestnn, on_gpu = false, test_mode = false)
  network.gspec = gspec
  return network
end

function network_factory(;
  source_dir::Union{Nothing, String} = nothing,
  network_type::Type{<:TricTracSparsePolicyNet} = DEFAULT_NETWORK
)
  if isnothing(source_dir)
    return network_type
  end

  return function(gspec::TricTracGameSpec, hyper)
    return warmstart_network(network_type, gspec, hyper, source_dir)
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

gpu_batching_backend(backend::Symbol) = backend == DEVICE_CUDA

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

function partie_length_mix_enabled(preset::Union{String, Symbol})
  return preset_config(preset).variant_id in ("trictrac_aecrire", "trictrac_combine")
end

function base_self_play_game_count(; smoke::Bool, use_gpu::Bool)
  if smoke
    return 4
  elseif use_gpu
    return 32
  else
    return 96
  end
end

function default_partie_length_repeats(; smoke::Bool, use_gpu::Bool)
  if smoke
    return 1
  elseif use_gpu
    return 4
  else
    return 10
  end
end

function resolve_partie_length_repeats(;
  preset::Union{String, Symbol},
  smoke::Bool,
  use_gpu::Bool,
  partie_length_repeats::Union{Nothing, Int} = nothing
)
  partie_length_mix_enabled(preset) || return nothing
  if !isnothing(partie_length_repeats)
    return partie_length_repeats
  end
  return default_partie_length_repeats(smoke = smoke, use_gpu = use_gpu)
end

function resolve_self_play_game_count(;
  preset::Union{String, Symbol},
  smoke::Bool,
  use_gpu::Bool,
  partie_length_repeats::Union{Nothing, Int} = nothing
)
  if !partie_length_mix_enabled(preset)
    return base_self_play_game_count(smoke = smoke, use_gpu = use_gpu)
  end
  repeats = resolve_partie_length_repeats(
    preset = preset,
    smoke = smoke,
    use_gpu = use_gpu,
    partie_length_repeats = partie_length_repeats
  )
  return length(AECRIRE_PARTIE_LENGTH_CHOICES) * repeats
end

function build_params(;
  smoke::Bool,
  preset::Union{String, Symbol} = DEFAULT_PRESET,
  device::Union{Symbol, AbstractString} = DEFAULT_DEVICE,
  use_gpu::Bool = false,
  num_iters::Union{Nothing, Int} = nothing,
  self_play_workers::Union{Nothing, Int} = nothing,
  arena_workers::Union{Nothing, Int} = nothing,
  partie_length_repeats::Union{Nothing, Int} = nothing
)
  requested_device = resolve_requested_device(device = device, use_gpu = use_gpu)
  resolved_device = resolve_device_backend(requested_device)
  worker_settings = resolve_worker_settings(
    smoke = smoke,
    self_play_workers = self_play_workers,
    arena_workers = arena_workers
  )
  warn_on_clamped_workers(worker_settings)

  use_gpu = is_gpu_backend(resolved_device)
  cpu_mode = !use_gpu
  batched_gpu_mode = gpu_batching_backend(resolved_device)
  self_play_games = resolve_self_play_game_count(
    preset = preset,
    smoke = smoke,
    use_gpu = use_gpu,
    partie_length_repeats = partie_length_repeats
  )

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
        num_games = self_play_games,
        num_workers = resolved_self_play_workers,
        batch_size = 1,
        use_gpu = use_gpu,
        fill_batches = batched_gpu_mode,
        reset_every = 1,
        flip_probability = 0.0,
        alternate_colors = false
      ) :
      SimParams(
        num_games = self_play_games,
        num_workers = resolved_self_play_workers,
        batch_size = batched_gpu_mode ? 4 : 1,
        use_gpu = use_gpu,
        fill_batches = batched_gpu_mode,
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
        fill_batches = batched_gpu_mode,
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
  device::Union{Symbol, AbstractString} = DEFAULT_DEVICE,
  use_gpu::Bool = false,
  num_iters::Union{Nothing, Int} = nothing,
  self_play_workers::Union{Nothing, Int} = nothing,
  arena_workers::Union{Nothing, Int} = nothing,
  partie_length_repeats::Union{Nothing, Int} = nothing
)
  config = preset_config(preset)
  resolved_device = resolve_device_backend(resolve_requested_device(device = device, use_gpu = use_gpu))
  NetworkType = network_type_for_device(resolved_device)
  hyper = netparams(device = resolved_device, network_type = NetworkType)
  gspec = game_spec_for_preset(repo_root = repo_root, preset = preset)
  return Experiment(
    config.experiment,
    gspec,
    build_params(
      smoke = false,
      preset = preset,
      device = device,
      use_gpu = use_gpu,
      num_iters = num_iters,
      self_play_workers = self_play_workers,
      arena_workers = arena_workers,
      partie_length_repeats = partie_length_repeats
    ),
    network_factory(
      source_dir = source_session_dir_for_preset(
        config.key;
        device = resolved_device,
        network_type = NetworkType
      ),
      network_type = NetworkType
    ),
    hyper,
    BENCHMARKS
  )
end

function smoke_experiment(;
  repo_root::String = REPO_ROOT,
  preset::Union{String, Symbol} = DEFAULT_PRESET,
  device::Union{Symbol, AbstractString} = DEFAULT_DEVICE,
  use_gpu::Bool = false,
  num_iters::Union{Nothing, Int} = nothing,
  self_play_workers::Union{Nothing, Int} = nothing,
  arena_workers::Union{Nothing, Int} = nothing,
  partie_length_repeats::Union{Nothing, Int} = nothing
)
  config = preset_config(preset)
  resolved_device = resolve_device_backend(resolve_requested_device(device = device, use_gpu = use_gpu))
  NetworkType = network_type_for_device(resolved_device)
  hyper = netparams(device = resolved_device, network_type = NetworkType)
  gspec = game_spec_for_preset(repo_root = repo_root, preset = preset)
  return Experiment(
    string(config.experiment, "-smoke"),
    gspec,
    build_params(
      smoke = true,
      preset = preset,
      device = device,
      use_gpu = use_gpu,
      num_iters = num_iters,
      self_play_workers = self_play_workers,
      arena_workers = arena_workers,
      partie_length_repeats = partie_length_repeats
    ),
    network_factory(
      source_dir = source_session_dir_for_preset(
        config.key;
        device = resolved_device,
        network_type = NetworkType
      ),
      network_type = NetworkType
    ),
    hyper,
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

session_dir_name(exp::Experiment) = string(exp.name, "-", session_layout_version(exp.netparams))

function default_session_dir(exp::Experiment)
  return joinpath(DEFAULT_SESSIONS_ROOT, session_dir_name(exp))
end

function expected_network_type(exp::Experiment)
  return network_type_for_netparams(exp.netparams)
end

function load_session_best_network(dir::String)
  path = joinpath(dir, AlphaZero.UserInterface.BESTNN_FILE)
  isfile(path) || return nothing
  return Serialization.deserialize(path)
end

function ensure_session_network_compatible!(
  dir::String,
  exp::Experiment;
  requested_device::Symbol,
  resolved_device::Symbol
)
  AlphaZero.UserInterface.valid_session_dir(dir) || return nothing
  bestnn = load_session_best_network(dir)
  isnothing(bestnn) && return nothing

  expected_type = expected_network_type(exp)
  actual_type = typeof(bestnn)
  actual_type == expected_type && return nothing

  requested_text =
    requested_device == DEVICE_AUTO ?
      "Automatic device selection resolved to $(resolved_device)." :
      "Device $(requested_device) was requested explicitly."
  guidance =
    requested_device == DEVICE_AUTO ?
      "Resume with --device=cpu to keep using the existing session, or start a fresh Metal session directory." :
      "Use a fresh session directory for $(network_family_name(expected_type)) weights, or resume this session with a compatible device."
  error(
    "Session $dir stores $(network_family_name(actual_type)) weights, but this run expects " *
    "$(network_family_name(expected_type)) weights. $requested_text $guidance"
  )
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
  device::Union{Symbol, AbstractString} = DEFAULT_DEVICE,
  use_gpu::Bool = false,
  num_iters::Union{Nothing, Int} = nothing,
  self_play_workers::Union{Nothing, Int} = nothing,
  arena_workers::Union{Nothing, Int} = nothing,
  partie_length_repeats::Union{Nothing, Int} = nothing
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
        device = device,
        use_gpu = use_gpu,
        num_iters = num_iters,
        self_play_workers = self_play_workers,
        arena_workers = arena_workers,
        partie_length_repeats = partie_length_repeats
      )
    AlphaZero.Examples.experiments[string(config.experiment, "-smoke")] =
      smoke_experiment(
        preset = config.key,
        device = device,
        use_gpu = use_gpu,
        num_iters = num_iters,
        self_play_workers = self_play_workers,
        arena_workers = arena_workers,
        partie_length_repeats = partie_length_repeats
      )
  end
  return nothing
end

function run_train(;
  profile::String = "default",
  preset::Union{String, Symbol} = DEFAULT_PRESET,
  dir::Union{Nothing, String} = nothing,
  test_game::Bool = false,
  device::Union{Symbol, AbstractString} = DEFAULT_DEVICE,
  use_gpu::Bool = false,
  reset_memory::Bool = false,
  num_iters::Union{Nothing, Int} = nothing,
  self_play_workers::Union{Nothing, Int} = nothing,
  arena_workers::Union{Nothing, Int} = nothing,
  partie_length_repeats::Union{Nothing, Int} = nothing
)
  requested_device = resolve_requested_device(device = device, use_gpu = use_gpu)
  requested_device == DEVICE_CUDA && require_device_available(DEVICE_CUDA)
  requested_device == DEVICE_METAL && require_device_available(DEVICE_METAL)
  resolved_device = set_runtime_device!(requested_device)
  if resolved_device == DEVICE_METAL
    probe = probe_sparse_conv_on_metal()
    if !probe.supported
      @info "Metal convolution probe failed on this machine; using the dense Metal sparse-policy network." detail = summarize_probe_error(probe.error)
    end
  end
  use_gpu = is_gpu_backend(resolved_device)
  if !partie_length_mix_enabled(preset) && !isnothing(partie_length_repeats)
    @warn "Partie-length repeats were requested for preset $(normalize_preset_name(preset)), but only trictrac_aecrire and trictrac_combine use marque-length self-play mixing."
  end
  experiment =
    profile == "smoke" ?
      smoke_experiment(
        preset = preset,
        device = resolved_device,
        use_gpu = use_gpu,
        num_iters = num_iters,
        self_play_workers = self_play_workers,
        arena_workers = arena_workers,
        partie_length_repeats = partie_length_repeats
      ) :
      default_experiment(
        preset = preset,
        device = resolved_device,
        use_gpu = use_gpu,
        num_iters = num_iters,
        self_play_workers = self_play_workers,
        arena_workers = arena_workers,
        partie_length_repeats = partie_length_repeats
  )
  register_experiments!(
    device = resolved_device,
    use_gpu = use_gpu,
    num_iters = num_iters,
    self_play_workers = self_play_workers,
    arena_workers = arena_workers,
    partie_length_repeats = partie_length_repeats
  )
  session_dir = isnothing(dir) ? default_session_dir(experiment) : dir
  ensure_session_network_compatible!(
    session_dir,
    experiment;
    requested_device = requested_device,
    resolved_device = resolved_device
  )
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
  device::Union{Symbol, AbstractString} = DEFAULT_DEVICE,
  use_gpu::Bool = false,
  reset_memory::Bool = false,
  num_iters::Union{Nothing, Int} = nothing,
  self_play_workers::Union{Nothing, Int} = nothing,
  arena_workers::Union{Nothing, Int} = nothing,
  partie_length_repeats::Union{Nothing, Int} = nothing
)
  session_dir =
    isnothing(dir) ?
      default_session_dir(
        smoke_experiment(
          preset = preset,
          device = device,
          use_gpu = use_gpu,
          num_iters = num_iters,
          self_play_workers = self_play_workers,
          arena_workers = arena_workers,
          partie_length_repeats = partie_length_repeats
        )
      ) :
      dir
  return run_train(
    profile = "smoke",
    preset = preset,
    dir = session_dir,
    test_game = true,
    device = device,
    use_gpu = use_gpu,
    reset_memory = reset_memory,
    num_iters = num_iters,
    self_play_workers = self_play_workers,
    arena_workers = arena_workers,
    partie_length_repeats = partie_length_repeats
  )
end

function run_explore(;
  dir::Union{Nothing, String} = nothing,
  preset::Union{String, Symbol} = DEFAULT_PRESET,
  device::Union{Symbol, AbstractString} = DEFAULT_DEVICE,
  use_gpu::Union{Nothing, Bool} = nothing
)
  requested_device = resolve_requested_device(device = device, use_gpu = use_gpu)
  requested_device == DEVICE_CUDA && require_device_available(DEVICE_CUDA)
  requested_device == DEVICE_METAL && require_device_available(DEVICE_METAL)
  resolved_device = set_runtime_device!(requested_device)
  if resolved_device == DEVICE_METAL
    probe = probe_sparse_conv_on_metal()
    if !probe.supported
      @info "Metal convolution probe failed on this machine; using the dense Metal sparse-policy network." detail = summarize_probe_error(probe.error)
    end
  end
  experiment = default_experiment(preset = preset, device = resolved_device)
  register_experiments!(device = resolved_device)
  session_dir = isnothing(dir) ? default_session_dir(experiment) : dir
  ensure_session_network_compatible!(
    session_dir,
    experiment;
    requested_device = requested_device,
    resolved_device = resolved_device
  )
  return AlphaZero.Scripts.explore(experiment; dir = session_dir)
end
