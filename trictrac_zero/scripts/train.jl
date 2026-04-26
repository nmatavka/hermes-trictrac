include(joinpath(@__DIR__, "cpu_config.jl"))

const STARTUP = TricTracScriptCPU.prepare_startup(:train, abspath(@__FILE__), ARGS)

include(joinpath(@__DIR__, "bootstrap.jl"))

using TricTracZero

function main(config::TricTracScriptCPU.StartupConfig)
  positional = config.positional
  profile = isempty(positional) ? "default" : positional[1]
  dir = length(positional) >= 2 ? positional[2] : nothing
  smoke = profile == "smoke"

  self_play_workers = TricTracScriptCPU.worker_override(config.self_play_workers)
  arena_workers = TricTracScriptCPU.worker_override(config.arena_workers)
  num_iters = TricTracScriptCPU.iterations_override(config.num_iters)
  partie_length_repeats = TricTracScriptCPU.partie_length_repeats_override(config.partie_length_repeats)
  preset = config.game.value
  worker_settings = TricTracZero.resolve_worker_settings(
    smoke = smoke,
    self_play_workers = self_play_workers,
    arena_workers = arena_workers
  )
  gspec = TricTracZero.game_spec_for_preset(preset = preset)
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
    smoke = smoke,
    use_gpu = config.use_gpu,
    partie_length_repeats = partie_length_repeats
  )

  TricTracScriptCPU.print_startup_summary(
    config;
    self_play_workers = worker_settings.self_play,
    arena_workers = worker_settings.arena,
    game = preset,
    move_cap = effective_move_cap,
    value_target_gain = effective_value_target_gain,
    partie_length_repeats = effective_partie_length_repeats,
    self_play_clamped = worker_settings.self_play_clamped,
    arena_clamped = worker_settings.arena_clamped
  )

  return TricTracZero.run_train(
    profile = profile,
    preset = preset,
    dir = dir,
    use_gpu = config.use_gpu,
    reset_memory = config.reset_memory,
    num_iters = num_iters,
    self_play_workers = self_play_workers,
    arena_workers = arena_workers,
    partie_length_repeats = partie_length_repeats
  )
end

main(STARTUP)
