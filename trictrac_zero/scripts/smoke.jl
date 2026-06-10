include(joinpath(@__DIR__, "cpu_config.jl"))

const STARTUP = TricTracScriptCPU.prepare_startup(:smoke, abspath(@__FILE__), ARGS)

include(joinpath(@__DIR__, "bootstrap.jl"))

using TricTracZero

function main(config::TricTracScriptCPU.StartupConfig)
  dir = isempty(config.positional) ? nothing : config.positional[1]
  self_play_workers = TricTracScriptCPU.worker_override(config.self_play_workers)
  arena_workers = TricTracScriptCPU.worker_override(config.arena_workers)
  num_iters = TricTracScriptCPU.iterations_override(config.num_iters)
  tactical_shaping = TricTracScriptCPU.tactical_shaping_override(config.tactical_shaping)
  tactical_horizon_own_turns = TricTracScriptCPU.tactical_horizon_override(config.tactical_horizon_own_turns)
  tactical_reward_weight = TricTracScriptCPU.tactical_weight_override(config.tactical_reward_weight)
  tactical_heuristic_weight = TricTracScriptCPU.tactical_weight_override(config.tactical_heuristic_weight)
  partie_length_repeats = TricTracScriptCPU.partie_length_repeats_override(config.partie_length_repeats)
  preset = config.game.value
  resolved_device = TricTracZero.resolve_device_backend(config.device.value)
  worker_settings = TricTracZero.resolve_worker_settings(
    smoke = true,
    self_play_workers = self_play_workers,
    arena_workers = arena_workers
  )
  runtime_workers = TricTracZero.resolve_runtime_workers(
    smoke = true,
    backend = resolved_device,
    worker_settings = worker_settings
  )
  batch_sizes = TricTracZero.resolve_batch_sizes(
    smoke = true,
    backend = resolved_device,
    self_play_workers = runtime_workers.self_play,
    arena_workers = runtime_workers.arena
  )
  gspec = TricTracZero.game_spec_for_preset(
    preset = preset,
    tactical_shaping = tactical_shaping,
    tactical_horizon_own_turns = tactical_horizon_own_turns,
    tactical_reward_weight = tactical_reward_weight,
    tactical_heuristic_weight = tactical_heuristic_weight
  )
  effective_move_cap =
    isnothing(TricTracScriptCPU.move_cap_override(config.move_cap)) ?
    something(TricTracZero.AlphaZero.max_game_length(gspec), 0) :
    config.move_cap.value
  effective_value_target_gain =
    isnothing(config.value_target_gain.value) ?
    TricTracZero.configured_value_target_gain() :
    config.value_target_gain.value
  effective_partie_length_repeats = TricTracZero.resolve_partie_length_repeats(
    preset = preset,
    smoke = true,
    use_gpu = TricTracZero.is_gpu_backend(resolved_device),
    partie_length_repeats = partie_length_repeats
  )

  TricTracScriptCPU.print_startup_summary(
    config;
    self_play_workers = runtime_workers.self_play,
    arena_workers = runtime_workers.arena,
    self_play_batch_size = batch_sizes.self_play,
    arena_batch_size = batch_sizes.arena,
    learning_batch_size = batch_sizes.learning,
    game = preset,
    move_cap = effective_move_cap,
    value_target_gain = effective_value_target_gain,
    tactical_shaping = get(gspec.tactical_config, "enabled", false),
    tactical_horizon_own_turns = get(gspec.tactical_config, "horizon_own_turns", 0),
    tactical_reward_weight = get(gspec.tactical_config, "reward_weight", 0.0),
    tactical_heuristic_weight = get(gspec.tactical_config, "heuristic_weight", 0.0),
    partie_length_repeats = effective_partie_length_repeats,
    self_play_clamped = worker_settings.self_play_clamped,
    arena_clamped = worker_settings.arena_clamped
  )

  return TricTracZero.run_smoke(
    dir = dir,
    preset = preset,
    device = config.device.value,
    reset_memory = config.reset_memory,
    num_iters = num_iters,
    self_play_workers = self_play_workers,
    arena_workers = arena_workers,
    partie_length_repeats = partie_length_repeats,
    tactical_shaping = tactical_shaping,
    tactical_horizon_own_turns = tactical_horizon_own_turns,
    tactical_reward_weight = tactical_reward_weight,
    tactical_heuristic_weight = tactical_heuristic_weight
  )
end

main(STARTUP)
