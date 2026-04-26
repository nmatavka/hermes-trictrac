module TricTracScriptCPU

import Base.Threads

const AUTO = :auto
const DEFAULT_CPU_POLICY = :headroom
const INTERNAL_REEXEC_ENV = "TRICTRAC_ZERO_INTERNAL_REEXEC"
const ENV_CPU_POLICY = "TRICTRAC_ZERO_CPU_POLICY"
const ENV_CPU_THREADS = "TRICTRAC_ZERO_CPU_THREADS"
const ENV_SELF_PLAY_WORKERS = "TRICTRAC_ZERO_SELF_PLAY_WORKERS"
const ENV_ARENA_WORKERS = "TRICTRAC_ZERO_ARENA_WORKERS"
const ENV_NUM_ITERS = "TRICTRAC_ZERO_NUM_ITERS"
const ENV_MOVE_CAP = "TRICTRAC_ZERO_TEMP_MAX_GAME_LENGTH"
const ENV_VALUE_TARGET_GAIN = "TRICTRAC_ZERO_VALUE_TARGET_GAIN"
const ENV_PARTIE_LENGTH_REPEATS = "TRICTRAC_ZERO_PARTIE_LENGTH_REPEATS"
const ENV_GAME = "TRICTRAC_ZERO_GAME"
const VALID_GAMES = (
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
)

Base.@kwdef struct Setting{T}
  value::T
  source::Symbol
end

Base.@kwdef struct StartupConfig
  command::Symbol
  positional::Vector{String}
  use_gpu::Bool
  reset_memory::Bool
  show_help::Bool
  cpu_policy::Setting{Symbol}
  cpu_threads::Setting
  self_play_workers::Setting
  arena_workers::Setting
  num_iters::Setting
  move_cap::Setting
  value_target_gain::Setting
  partie_length_repeats::Setting
  game::Setting{String}
  target_threads::Int
  relaunch_status::Symbol
end

normalize_symbol(raw::AbstractString) = Symbol(lowercase(strip(raw)))

function parse_policy(raw::AbstractString, source_name::AbstractString)
  policy = normalize_symbol(raw)
  policy in (:headroom, :max, :conservative, :off) && return policy
  throw(ArgumentError("Invalid value for $source_name: $(repr(raw)). Expected one of: headroom, max, conservative, off."))
end

function parse_auto_or_int(raw::AbstractString, source_name::AbstractString)
  value = strip(raw)
  lowercase(value) == "auto" && return AUTO
  parsed = tryparse(Int, value)
  isnothing(parsed) && throw(ArgumentError("Invalid value for $source_name: $(repr(raw)). Expected 'auto' or an integer >= 1."))
  parsed >= 1 && return parsed
  throw(ArgumentError("Invalid value for $source_name: $(repr(raw)). Expected an integer >= 1."))
end

function parse_positive_int(raw::AbstractString, source_name::AbstractString)
  parsed = tryparse(Int, strip(raw))
  isnothing(parsed) && throw(ArgumentError("Invalid value for $source_name: $(repr(raw)). Expected an integer >= 1."))
  parsed >= 1 && return parsed
  throw(ArgumentError("Invalid value for $source_name: $(repr(raw)). Expected an integer >= 1."))
end

function parse_nonnegative_int(raw::AbstractString, source_name::AbstractString)
  parsed = tryparse(Int, strip(raw))
  isnothing(parsed) && throw(ArgumentError("Invalid value for $source_name: $(repr(raw)). Expected an integer >= 0."))
  parsed >= 0 && return parsed
  throw(ArgumentError("Invalid value for $source_name: $(repr(raw)). Expected an integer >= 0."))
end

function parse_nonnegative_float(raw::AbstractString, source_name::AbstractString)
  parsed = tryparse(Float64, strip(raw))
  isnothing(parsed) && throw(ArgumentError("Invalid value for $source_name: $(repr(raw)). Expected a number >= 0."))
  parsed >= 0 && return parsed
  throw(ArgumentError("Invalid value for $source_name: $(repr(raw)). Expected a number >= 0."))
end

function parse_game(raw::AbstractString, source_name::AbstractString)
  game = replace(lowercase(strip(raw)), '_' => '-')
  game in VALID_GAMES && return game
  choices = join(VALID_GAMES, ", ")
  throw(ArgumentError("Invalid value for $source_name: $(repr(raw)). Expected one of: $choices."))
end

function resolve_setting(cli_value, env::AbstractDict, env_name::String, default_value, parser::Function)
  if !isnothing(cli_value)
    return Setting(cli_value, :cli)
  elseif haskey(env, env_name)
    return Setting(parser(env[env_name], env_name), :env)
  else
    return Setting(default_value, :default)
  end
end

function take_flag_value(args::Vector{String}, index::Int, flag::String)
  arg = args[index]
  if occursin('=', arg)
    _, value = split(arg, '='; limit = 2)
    isempty(value) && throw(ArgumentError("Flag $flag requires a value."))
    return value, index
  end

  index == length(args) && throw(ArgumentError("Flag $flag requires a value."))
  value = args[index + 1]
  startswith(value, "--") && throw(ArgumentError("Flag $flag requires a value."))
  return value, index + 1
end

function validate_positional_args(command::Symbol, positional::Vector{String})
  if command == :train
    length(positional) <= 2 && return nothing
    throw(ArgumentError("train accepts at most 2 positional arguments: [profile] [dir]."))
  elseif command == :smoke
    length(positional) <= 1 && return nothing
    throw(ArgumentError("smoke accepts at most 1 positional argument: [dir]."))
  else
    throw(ArgumentError("Unknown command kind: $command"))
  end
end

function parse_startup(command::Symbol, args::Vector{String}; env::AbstractDict = ENV)
  positional = String[]
  use_gpu = false
  reset_memory = false
  show_help = false
  cli_policy = nothing
  cli_threads = nothing
  cli_self_play_workers = nothing
  cli_arena_workers = nothing
  cli_num_iters = nothing
  cli_move_cap = nothing
  cli_value_target_gain = nothing
  cli_partie_length_repeats = nothing
  cli_game = nothing

  index = 1
  while index <= length(args)
    arg = args[index]
    if arg == "--gpu"
      use_gpu = true
    elseif arg == "--reset-memory"
      reset_memory = true
    elseif arg == "--help"
      show_help = true
    elseif startswith(arg, "--cpu-policy")
      value, index = take_flag_value(args, index, "--cpu-policy")
      cli_policy = parse_policy(value, "--cpu-policy")
    elseif startswith(arg, "--cpu-threads")
      value, index = take_flag_value(args, index, "--cpu-threads")
      cli_threads = parse_auto_or_int(value, "--cpu-threads")
    elseif startswith(arg, "--self-play-workers")
      value, index = take_flag_value(args, index, "--self-play-workers")
      cli_self_play_workers = parse_auto_or_int(value, "--self-play-workers")
    elseif startswith(arg, "--arena-workers")
      value, index = take_flag_value(args, index, "--arena-workers")
      cli_arena_workers = parse_auto_or_int(value, "--arena-workers")
    elseif startswith(arg, "--iterations")
      value, index = take_flag_value(args, index, "--iterations")
      cli_num_iters = parse_positive_int(value, "--iterations")
    elseif startswith(arg, "--move-cap")
      value, index = take_flag_value(args, index, "--move-cap")
      cli_move_cap = parse_nonnegative_int(value, "--move-cap")
    elseif startswith(arg, "--target-gain")
      value, index = take_flag_value(args, index, "--target-gain")
      cli_value_target_gain = parse_nonnegative_float(value, "--target-gain")
    elseif startswith(arg, "--value-target-gain")
      value, index = take_flag_value(args, index, "--value-target-gain")
      cli_value_target_gain = parse_nonnegative_float(value, "--value-target-gain")
    elseif startswith(arg, "--partie-length-repeats")
      value, index = take_flag_value(args, index, "--partie-length-repeats")
      cli_partie_length_repeats = parse_auto_or_int(value, "--partie-length-repeats")
    elseif startswith(arg, "--game")
      value, index = take_flag_value(args, index, "--game")
      cli_game = parse_game(value, "--game")
    elseif startswith(arg, "--")
      throw(ArgumentError("Unknown flag: $arg"))
    else
      push!(positional, arg)
    end
    index += 1
  end

  validate_positional_args(command, positional)

  return StartupConfig(
    command = command,
    positional = positional,
    use_gpu = use_gpu,
    reset_memory = reset_memory,
    show_help = show_help,
    cpu_policy = resolve_setting(cli_policy, env, ENV_CPU_POLICY, DEFAULT_CPU_POLICY, parse_policy),
    cpu_threads = resolve_setting(cli_threads, env, ENV_CPU_THREADS, AUTO, parse_auto_or_int),
    self_play_workers = resolve_setting(cli_self_play_workers, env, ENV_SELF_PLAY_WORKERS, AUTO, parse_auto_or_int),
    arena_workers = resolve_setting(cli_arena_workers, env, ENV_ARENA_WORKERS, AUTO, parse_auto_or_int),
    num_iters = resolve_setting(cli_num_iters, env, ENV_NUM_ITERS, nothing, parse_positive_int),
    move_cap = resolve_setting(cli_move_cap, env, ENV_MOVE_CAP, nothing, parse_nonnegative_int),
    value_target_gain = resolve_setting(cli_value_target_gain, env, ENV_VALUE_TARGET_GAIN, nothing, parse_nonnegative_float),
    partie_length_repeats = resolve_setting(cli_partie_length_repeats, env, ENV_PARTIE_LENGTH_REPEATS, AUTO, parse_auto_or_int),
    game = resolve_setting(cli_game, env, ENV_GAME, "classique", parse_game),
    target_threads = Threads.nthreads(),
    relaunch_status = :none
  )
end

function default_target_threads(policy::Symbol; visible_cpu_threads::Int)
  if policy == :headroom
    return max(2, visible_cpu_threads - 2)
  elseif policy == :max
    return visible_cpu_threads
  elseif policy == :conservative
    return min(4, visible_cpu_threads)
  elseif policy == :off
    return Threads.nthreads()
  else
    throw(ArgumentError("Unsupported CPU policy: $policy"))
  end
end

function resolve_target_threads(
  config::StartupConfig;
  visible_cpu_threads::Int = Sys.CPU_THREADS,
  current_threads::Int = Threads.nthreads()
)
  if config.cpu_threads.value isa Int
    return config.cpu_threads.value
  else
    return config.cpu_policy.value == :off ? current_threads : default_target_threads(config.cpu_policy.value; visible_cpu_threads)
  end
end

function relaunch_status(
  config::StartupConfig;
  env::AbstractDict = ENV,
  visible_cpu_threads::Int = Sys.CPU_THREADS,
  current_threads::Int = Threads.nthreads()
)
  target = resolve_target_threads(config; visible_cpu_threads, current_threads)
  has_guard = get(env, INTERNAL_REEXEC_ENV, "") == "1"

  if has_guard
    return current_threads < target ? :skipped_by_guard : :performed
  elseif config.show_help || target <= current_threads
    return :none
  else
    return :would_relaunch
  end
end

function project_dir(script_path::AbstractString)
  active = Base.active_project()
  if isnothing(active)
    return normpath(joinpath(dirname(script_path), ".."))
  else
    return dirname(active)
  end
end

function build_relaunch_cmd(script_path::AbstractString, args::Vector{String}, target_threads::Int)
  proj = project_dir(script_path)
  words = vcat(
    collect(Base.julia_cmd()),
    ["--project=$(proj)", "--threads=$(target_threads)", script_path],
    args
  )
  return Cmd(words)
end

function maybe_relaunch!(config::StartupConfig, script_path::AbstractString, args::Vector{String})
  status = relaunch_status(config)
  status == :would_relaunch || return status

  cmd = addenv(build_relaunch_cmd(script_path, args, config.target_threads), INTERNAL_REEXEC_ENV => "1")
  process = run(ignorestatus(cmd))
  exit(process.exitcode)
end

function source_label(source::Symbol)
  source == :cli && return "CLI"
  source == :env && return "env"
  source == :default && return "default"
  return string(source)
end

function effective_thread_source(config::StartupConfig)
  return config.cpu_threads.value isa Int ? config.cpu_threads.source : config.cpu_policy.source
end

worker_override(setting::Setting) = setting.value === AUTO ? nothing : setting.value
iterations_override(setting::Setting) = isnothing(setting.value) ? nothing : setting.value
move_cap_override(setting::Setting) = isnothing(setting.value) ? nothing : setting.value
partie_length_repeats_override(setting::Setting) = setting.value === AUTO ? nothing : setting.value

function positional_usage(command::Symbol)
  command == :train && return "[profile] [dir]"
  command == :smoke && return "[dir]"
  return ""
end

function usage_text(command::Symbol, script_path::AbstractString)
  relpath = joinpath("scripts", basename(script_path))
  pos = positional_usage(command)
  return """
Usage:
  julia --project $relpath [options] $pos

Options:
  --gpu
      Request GPU training.
  --reset-memory
      Reset only the replay buffer before resuming an existing session.
  --cpu-policy <headroom|max|conservative|off>
      Set the automatic CPU policy. Default: headroom.
  --cpu-threads <auto|N>
      Set Julia master threads directly. Explicit values override policy.
  --self-play-workers <auto|N>
      Set self-play worker count. 'auto' restores derived behavior.
  --arena-workers <auto|N>
      Set arena worker count. 'auto' restores derived behavior.
  --iterations <N>
      Set the total session iteration target explicitly.
  --move-cap <N>
      Set the temporary hard cap on game length. Use 0 to disable.
  --target-gain <N>
      Set the tanh gain used for value-target shaping. Lower is less slope-y.
  --partie-length-repeats <auto|N>
      For a ecrire/combine training, use N self-play games at each marque target.
  --game <$(join(VALID_GAMES, "|"))>
      Choose the training target. Default: classique.
  --help
      Show this help and exit.

Environment:
  $ENV_CPU_POLICY
  $ENV_CPU_THREADS
  $ENV_SELF_PLAY_WORKERS
  $ENV_ARENA_WORKERS
  $ENV_NUM_ITERS
  $ENV_MOVE_CAP
  $ENV_VALUE_TARGET_GAIN
  $ENV_PARTIE_LENGTH_REPEATS
  $ENV_GAME

Precedence:
  CLI values override environment variables; environment variables override defaults.
"""
end

function prepare_startup(
  command::Symbol,
  script_path::AbstractString,
  args::Vector{String};
  env::AbstractDict = ENV,
  allow_relaunch::Bool = true
)
  parsed = parse_startup(command, args; env)
  config = StartupConfig(
    command = parsed.command,
    positional = parsed.positional,
    use_gpu = parsed.use_gpu,
    reset_memory = parsed.reset_memory,
    show_help = parsed.show_help,
    cpu_policy = parsed.cpu_policy,
    cpu_threads = parsed.cpu_threads,
    self_play_workers = parsed.self_play_workers,
    arena_workers = parsed.arena_workers,
    num_iters = parsed.num_iters,
    move_cap = parsed.move_cap,
    value_target_gain = parsed.value_target_gain,
    partie_length_repeats = parsed.partie_length_repeats,
    game = parsed.game,
    target_threads = resolve_target_threads(parsed),
    relaunch_status = relaunch_status(parsed; env)
  )

  if config.show_help
    print(usage_text(command, script_path))
    exit(0)
  end

  if config.move_cap.source == :cli
    ENV[ENV_MOVE_CAP] = string(config.move_cap.value)
  end
  if config.value_target_gain.source == :cli
    ENV[ENV_VALUE_TARGET_GAIN] = string(config.value_target_gain.value)
  end
  if config.partie_length_repeats.source == :cli && config.partie_length_repeats.value !== AUTO
    ENV[ENV_PARTIE_LENGTH_REPEATS] = string(config.partie_length_repeats.value)
  end

  allow_relaunch && maybe_relaunch!(config, script_path, args)
  return config
end

function print_startup_summary(
  io::IO,
  config::StartupConfig;
  self_play_workers::Int,
  arena_workers::Int,
  move_cap = nothing,
  value_target_gain = nothing,
  partie_length_repeats = nothing,
  game::Union{Nothing, String} = nothing,
  self_play_clamped::Bool = false,
  arena_clamped::Bool = false
)
  println(io)
  println(io, "CPU configuration")
  println(io, "  Visible CPUs: ", Sys.CPU_THREADS)
  println(io, "  Julia threads: ", Threads.nthreads())
  if config.cpu_policy.value == :off
    println(io, "  CPU policy: off (honoring existing Julia launch)")
  else
    println(io, "  CPU policy: ", config.cpu_policy.value)
  end
  println(io, "  CPU thread source: ", source_label(effective_thread_source(config)))
  println(io, "  Relaunch: ", replace(string(config.relaunch_status), '_' => '-'))
  println(io, "  Reset memory: ", config.reset_memory ? "yes" : "no")
  println(io, "  Self-play workers: ", self_play_workers, self_play_clamped ? " (clamped)" : "")
  println(io, "  Arena workers: ", arena_workers, arena_clamped ? " (clamped)" : "")
  println(io, "  Iterations: ", isnothing(config.num_iters.value) ? "default" : config.num_iters.value)
  if !isnothing(game)
    println(io, "  Game: ", game)
  end
  if !isnothing(move_cap)
    println(io, "  Move cap: ", move_cap == 0 ? "disabled" : move_cap)
  end
  if !isnothing(value_target_gain)
    println(io, "  Value target gain: ", value_target_gain)
  end
  if !isnothing(partie_length_repeats)
    println(io, "  Partie-length repeats: ", partie_length_repeats)
  end
  println(io)
end

print_startup_summary(config::StartupConfig; kwargs...) = print_startup_summary(stdout, config; kwargs...)

end
