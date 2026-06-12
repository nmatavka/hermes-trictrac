using Sockets
using SHA

mutable struct BridgeConnection
  io::IO
  lock::ReentrantLock
  next_id::Int
end

mutable struct BridgeService
  key::NTuple{4, Any}
  state_dir::String
  socket_path::String
  ready_path::String
  pid_path::String
  log_path::String
  launch_lock::ReentrantLock
  control::Union{Nothing, BridgeConnection}
  fallback::Union{Nothing, BridgeConnection}
  step_queue::Channel{Any}
  step_tasks::Vector{Task}
  daemon_proc::Union{Nothing, Base.Process}
  transport::Symbol
end

struct BridgeClient
  service::BridgeService
end

struct BridgeBatchRequest
  request_key::Any
  payload::Dict{String, Any}
  reply_channel::Channel{Any}
end

const BRIDGE_EXECUTABLE_ENV = "TRICTRAC_ZERO_BRIDGE_EXECUTABLE"
const BRIDGE_EBIN_ROOT_ENV = "TRICTRAC_ZERO_BRIDGE_EBIN_ROOT"
const BRIDGE_MODE_ENV = "TRICTRAC_ZERO_BRIDGE_MODE"
const BRIDGE_ERL_FLAGS_ENV = "TRICTRAC_ZERO_BRIDGE_ERL_FLAGS"
const BRIDGE_CACHE_LOCK = ReentrantLock()
const BRIDGE_CACHE = Dict{NTuple{4, Any}, BridgeClient}()
const STEP_RESPONSE_CACHE_LOCK = ReentrantLock()
const STEP_RESPONSE_CACHE = Dict{Any, Dict{String, Any}}()
const STEP_RESPONSE_CACHE_ORDER = Any[]
const STEP_RESPONSE_CACHE_ORDER_HEAD = Ref(1)
const STEP_RESPONSE_CACHE_LIMIT = 4_096
const STEP_RESPONSE_CACHE_TRIM = 1_024
const BRIDGE_BATCH_STOP = :__trictrac_bridge_batch_stop__
const BRIDGE_BATCH_CAPACITY = 4096
const BRIDGE_BATCH_LIMIT = 16
const BRIDGE_BATCH_FLUSH_SECONDS = 0.005
const SHARED_BRIDGE_BATCH_WORKERS = 22
const BRIDGE_ATEXIT_REGISTERED = Ref(false)
const MIX_COMPILE_LOCK = ReentrantLock()
const MIX_COMPILE_CACHE = Dict{String, String}()

function bridge_worker_slot()
  slot = try
    Base.task_local_storage(AlphaZero.Util.WORKER_SLOT_TLS_KEY)
  catch
    nothing
  end
  return slot isa Integer && slot > 0 ? Int(slot) : 0
end

function configured_bridge_mode()
  raw = lowercase(strip(get(ENV, BRIDGE_MODE_ENV, "shared")))
  raw in ("shared", "worker", "stdio") && return Symbol(raw)
  error("$BRIDGE_MODE_ENV must be one of shared, worker, or stdio; got $(repr(raw)).")
end

bridge_scope_slot(mode::Symbol) = mode == :shared ? 0 : bridge_worker_slot()

function bridge_erl_flags()
  haskey(ENV, "ERL_FLAGS") && return nothing
  if haskey(ENV, BRIDGE_ERL_FLAGS_ENV)
    flags = strip(ENV[BRIDGE_ERL_FLAGS_ENV])
    return isempty(flags) ? nothing : flags
  end
  return configured_bridge_mode() == :worker ? "+S 2:2" : nothing
end

function apply_bridge_runtime_env(cmd::Cmd)
  flags = bridge_erl_flags()
  isnothing(flags) && return cmd
  env = copy(ENV)
  env["ERL_FLAGS"] = flags
  return setenv(cmd, env)
end

function bridge_service_key(spec)
  mode = configured_bridge_mode()
  return (spec.repo_root, spec.bridge_script, mode, bridge_scope_slot(mode))
end

function bridge_identity_hash(spec)
  bridge_executable = get(ENV, BRIDGE_EXECUTABLE_ENV, "")
  ebin_root = get(ENV, BRIDGE_EBIN_ROOT_ENV, joinpath(spec.repo_root, "_build", "dev", "lib"))
  mode = configured_bridge_mode()
  digest = sha1(join([
    spec.repo_root,
    spec.bridge_script,
    bridge_executable,
    ebin_root,
    String(mode),
  ], "\n"))
  return bytes2hex(digest)[1:12]
end

function bridge_state_dir(spec)
  mode = configured_bridge_mode()
  slot = bridge_scope_slot(mode)
  slug = "$(bridge_identity_hash(spec))-$(getpid())-s$(slot)"
  return joinpath(spec.repo_root, "tmp", "trictrac_bridge", slug)
end

function bridge_paths(spec)
  state_dir = bridge_state_dir(spec)
  return (
    state_dir = state_dir,
    socket = joinpath(state_dir, "bridge.sock"),
    ready = joinpath(state_dir, "bridge.ready"),
    pid = joinpath(state_dir, "bridge.pid"),
    log = joinpath(state_dir, "bridge.log"),
  )
end

function daemon_script_path(spec)
  return joinpath(spec.repo_root, "priv", "training", "trictrac_bridge_daemon.exs")
end

function bridge_ebin_root(spec)
  return get(ENV, BRIDGE_EBIN_ROOT_ENV, joinpath(spec.repo_root, "_build", "dev", "lib"))
end

function bridge_ebin_paths(root::AbstractString)
  isdir(root) || return String[]
  paths = String[]
  for entry in sort(readdir(root))
    ebin = joinpath(root, entry, "ebin")
    isdir(ebin) && push!(paths, ebin)
  end
  return paths
end

function native_elixir_executable()
  executable = Sys.which("elixir")
  isnothing(executable) && return nothing
  stripped = strip(String(executable))
  return isempty(stripped) ? nothing : stripped
end

function native_elixir_bridge_command(
  spec,
  script::AbstractString,
  extra_args::Vector{String} = String[]
)
  executable = native_elixir_executable()
  isnothing(executable) && return nothing

  ebin_paths = bridge_ebin_paths(bridge_ebin_root(spec))
  isempty(ebin_paths) && return nothing

  ensure_mix_compiled!(spec)

  args = String[executable]
  for path in ebin_paths
    push!(args, "-pa", path)
  end
  push!(args, String(script))
  append!(args, extra_args)
  return apply_bridge_runtime_env(Cmd(Cmd(args), dir = spec.repo_root))
end

function repo_compile_signature(spec)
  roots = [
    joinpath(spec.repo_root, "mix.exs"),
    joinpath(spec.repo_root, "mix.lock"),
    joinpath(spec.repo_root, "config"),
    joinpath(spec.repo_root, "lib"),
    joinpath(spec.repo_root, "priv"),
  ]
  max_mtime = 0.0

  for path in roots
    if isfile(path)
      max_mtime = max(max_mtime, mtime(path))
    elseif isdir(path)
      for (root, _dirs, files) in walkdir(path)
        max_mtime = max(max_mtime, mtime(root))
        for file in files
          full = joinpath(root, file)
          max_mtime = max(max_mtime, mtime(full))
        end
      end
    end
  end

  return string(round(Int, max_mtime * 1000))
end

function ensure_mix_compiled!(spec)
  signature = repo_compile_signature(spec)
  lock(MIX_COMPILE_LOCK)
  try
    if get(MIX_COMPILE_CACHE, spec.repo_root, nothing) == signature
      return nothing
    end
    run(Cmd(`mix compile`, dir = spec.repo_root))
    MIX_COMPILE_CACHE[spec.repo_root] = signature
    return nothing
  finally
    unlock(MIX_COMPILE_LOCK)
  end
end

function bridge_stdio_command(spec)
  bridge_executable = get(ENV, BRIDGE_EXECUTABLE_ENV, "")
  if !isempty(strip(bridge_executable))
    ebin_paths = bridge_ebin_paths(bridge_ebin_root(spec))
    isempty(ebin_paths) &&
      error("Bridge executable override is set, but no compiled ebin paths were found under $(repr(bridge_ebin_root(spec))).")

    args = String[bridge_executable]
    for path in ebin_paths
      push!(args, "-pa", path)
    end
    push!(args, spec.bridge_script)
    return apply_bridge_runtime_env(Cmd(Cmd(args), dir = spec.repo_root))
  end

  native = native_elixir_bridge_command(spec, spec.bridge_script)
  !isnothing(native) && return native

  rel_script = relpath(spec.bridge_script, spec.repo_root)
  ensure_mix_compiled!(spec)
  return apply_bridge_runtime_env(
    Cmd(`mix run --no-start --no-compile --no-deps-check $rel_script`, dir = spec.repo_root)
  )
end

function bridge_daemon_command(spec, paths)
  bridge_executable = get(ENV, BRIDGE_EXECUTABLE_ENV, "")
  script = daemon_script_path(spec)
  if !isempty(strip(bridge_executable))
    ebin_paths = bridge_ebin_paths(bridge_ebin_root(spec))
    isempty(ebin_paths) &&
      error("Bridge executable override is set, but no compiled ebin paths were found under $(repr(bridge_ebin_root(spec))).")

    args = String[bridge_executable]
    for path in ebin_paths
      push!(args, "-pa", path)
    end
    append!(args, [script, paths.socket, paths.ready, paths.pid])
    return apply_bridge_runtime_env(Cmd(Cmd(args), dir = spec.repo_root))
  end

  native = native_elixir_bridge_command(spec, script, String[paths.socket, paths.ready, paths.pid])
  !isnothing(native) && return native

  rel_script = relpath(script, spec.repo_root)
  ensure_mix_compiled!(spec)
  return apply_bridge_runtime_env(Cmd(
    `mix run --no-start --no-compile --no-deps-check $rel_script -- $(paths.socket) $(paths.ready) $(paths.pid)`,
    dir = spec.repo_root
  ))
end

function BridgeConnection(io::IO)
  connection = BridgeConnection(io, ReentrantLock(), 1)
  finalizer(close, connection)
  return connection
end

function BridgeConnection(path::AbstractString)
  return BridgeConnection(connect(path))
end

function BridgeConnection(spec)
  io = open(bridge_stdio_command(spec), "r+")
  connection = BridgeConnection(io)
  ping!(connection)
  return connection
end

function Base.close(connection::BridgeConnection)
  try
    close(connection.io)
  catch
  end
  return nothing
end

function Base.close(client::BridgeClient)
  service = client.service
  lock(service.launch_lock)
  try
    active_step_tasks = Task[task for task in service.step_tasks if !istaskdone(task)]
    for _ in active_step_tasks
      try
        put!(service.step_queue, BRIDGE_BATCH_STOP)
      catch
      end
    end
    for task in active_step_tasks
      try
        wait(task)
      catch
      end
    end
    empty!(service.step_tasks)

    if service.transport == :daemon && service.control !== nothing
      try
        request!(service.control, Dict{String, Any}("cmd" => "shutdown"))
      catch
      end
    end

    if service.control !== nothing
      close(service.control)
      service.control = nothing
    end

    if service.fallback !== nothing
      close(service.fallback)
      service.fallback = nothing
    end

    if service.daemon_proc !== nothing && Base.process_running(service.daemon_proc)
      try
        Base.kill(service.daemon_proc)
      catch
      end
    end
    service.daemon_proc = nothing
    cleanup_daemon_files!(service)
  finally
    unlock(service.launch_lock)
  end
  return nothing
end

function bridge_service(spec)
  key = bridge_service_key(spec)
  paths = bridge_paths(spec)
  lock(BRIDGE_CACHE_LOCK)
  try
    if !BRIDGE_ATEXIT_REGISTERED[]
      atexit(close_cached_bridges!)
      BRIDGE_ATEXIT_REGISTERED[] = true
    end
    return get!(BRIDGE_CACHE, key) do
      service = BridgeService(
        key,
        paths.state_dir,
        paths.socket,
        paths.ready,
        paths.pid,
        paths.log,
        ReentrantLock(),
        nothing,
        nothing,
        Channel{Any}(BRIDGE_BATCH_CAPACITY),
        Task[],
        nothing,
        :unknown,
      )
      BridgeClient(service)
    end
  finally
    unlock(BRIDGE_CACHE_LOCK)
  end
end

bridge_client(spec) = bridge_service(spec)

function close_cached_bridges!()
  lock(BRIDGE_CACHE_LOCK)
  try
    for client in values(BRIDGE_CACHE)
      close(client)
    end
    empty!(BRIDGE_CACHE)
  finally
    unlock(BRIDGE_CACHE_LOCK)
  end
  return nothing
end

function daemon_pid(service::BridgeService)
  isfile(service.pid_path) || return nothing
  raw = try
    strip(read(service.pid_path, String))
  catch
    return nothing
  end
  isempty(raw) && return nothing
  try
    return parse(Int, raw)
  catch
    return nothing
  end
end

function cleanup_daemon_files!(service::BridgeService)
  for path in (service.socket_path, service.ready_path, service.pid_path)
    try
      rm(path; force = true)
    catch
    end
  end
  try
    if isdir(service.state_dir) && isempty(readdir(service.state_dir))
      rm(service.state_dir; recursive = true, force = true)
    end
  catch
  end
  return nothing
end

function launch_daemon_process!(service::BridgeService, spec)
  cleanup_daemon_files!(service)
  mkpath(service.state_dir)
  cmd = bridge_daemon_command(spec, bridge_paths(spec))
  open(service.log_path, "a") do io
    service.daemon_proc = run(pipeline(cmd, stdout = io, stderr = io); wait = false)
  end
  return service.daemon_proc
end

function wait_for_daemon_ready!(service::BridgeService; timeout_seconds::Float64 = 90.0)
  deadline = time() + timeout_seconds
  while time() < deadline
    if service.daemon_proc !== nothing && Base.process_exited(service.daemon_proc)
      error("Bridge daemon exited before becoming ready. See $(service.log_path).")
    end

    if isfile(service.ready_path) && ispath(service.socket_path)
      try
        connection = BridgeConnection(service.socket_path)
        try
          ping!(connection)
          close(connection)
          return nothing
        catch
          close(connection)
        end
      catch
      end
    end
    sleep(0.05)
  end

  error("Timed out waiting for bridge daemon readiness at $(service.ready_path).")
end

function ensure_stdio_fallback!(service::BridgeService, spec)
  if service.fallback === nothing
    service.fallback = BridgeConnection(spec)
  end
  service.transport = :stdio
  return service.fallback
end

function bridge_batch_worker_count()
  return configured_bridge_mode() == :shared ? SHARED_BRIDGE_BATCH_WORKERS : 1
end

function ensure_step_coordinators!(service::BridgeService, spec)
  active = Task[task for task in service.step_tasks if !istaskdone(task)]
  service.step_tasks = active
  missing = bridge_batch_worker_count() - length(active)
  for _ in 1:max(missing, 0)
    push!(service.step_tasks, @async bridge_step_coordinator(service, spec))
  end
  return nothing
end

function maybe_restore_daemon!(service::BridgeService, spec)
  configured_bridge_mode() == :stdio && return nothing
  service.transport == :stdio || return nothing

  try
    reset_daemon_connections!(service)
  catch
  end

  try
    ensure_daemon_running!(service, spec)
  catch
  end

  return nothing
end

function ensure_daemon_running!(service::BridgeService, spec)
  lock(service.launch_lock)
  try
    if configured_bridge_mode() == :stdio
      ensure_stdio_fallback!(service, spec)
      return nothing
    end
    shared_mode = configured_bridge_mode() == :shared
    if service.transport == :stdio
      if service.fallback !== nothing
        close(service.fallback)
        service.fallback = nothing
      end
      service.transport = :unknown
    end
    if shared_mode
      if service.daemon_proc !== nothing &&
           Base.process_running(service.daemon_proc) &&
           isfile(service.ready_path) &&
           ispath(service.socket_path)
        ensure_step_coordinators!(service, spec)
        return nothing
      end
    elseif service.control !== nothing
      ensure_step_coordinators!(service, spec)
      return nothing
    end

    launch_daemon_process!(service, spec)
    wait_for_daemon_ready!(service)
    if shared_mode
      if service.control !== nothing
        close(service.control)
        service.control = nothing
      end
    else
      service.control = BridgeConnection(service.socket_path)
      ping!(service.control)
    end
    service.transport = :daemon
    ensure_step_coordinators!(service, spec)
    return nothing
  catch err
    bt = catch_backtrace()
    service.control = nothing
    service.transport = :stdio
    try
      cleanup_daemon_files!(service)
    catch
    end
    if configured_bridge_mode() != :stdio
      @warn "Bridge daemon launch or handshake failed; falling back to stdio for now." exception = (err, bt) state_dir = service.state_dir
    end
    ensure_stdio_fallback!(service, spec)
    return nothing
  finally
    unlock(service.launch_lock)
  end
end

function reset_daemon_connections!(service::BridgeService)
  lock(service.launch_lock)
  try
    if service.control !== nothing
      close(service.control)
      service.control = nothing
    end
    if service.daemon_proc !== nothing
      if Base.process_running(service.daemon_proc)
        try
          Base.kill(service.daemon_proc)
        catch
        end
      end
      service.daemon_proc = nothing
    end
    cleanup_daemon_files!(service)
  finally
    unlock(service.launch_lock)
  end
  return nothing
end

function reset_control_connection!(service::BridgeService)
  lock(service.launch_lock)
  try
    if service.control !== nothing
      close(service.control)
      service.control = nothing
    end
  finally
    unlock(service.launch_lock)
  end
  return nothing
end

function ensure_control_connection!(service::BridgeService, spec)
  if service.transport == :stdio
    return ensure_stdio_fallback!(service, spec)
  end
  ensure_daemon_running!(service, spec)
  service.transport == :stdio && return ensure_stdio_fallback!(service, spec)
  if service.control === nothing
    lock(service.launch_lock)
    try
      service.control = BridgeConnection(service.socket_path)
    finally
      unlock(service.launch_lock)
    end
  end
  return service.control
end

function bridge_request!(service::BridgeService, spec, payload::Dict{String, Any})
  maybe_restore_daemon!(service, spec)
  if service.transport == :stdio
    return request!(ensure_stdio_fallback!(service, spec), payload)
  end

  if configured_bridge_mode() == :shared
    if service.control !== nothing
      reset_control_connection!(service)
    end
    return daemon_control_request!(service, spec, payload)
  end

  try
    return request!(ensure_control_connection!(service, spec), payload)
  catch first_err
    first_bt = catch_backtrace()

    try
      reset_control_connection!(service)
      return request!(ensure_control_connection!(service, spec), payload)
    catch second_err
      second_bt = catch_backtrace()

      if configured_bridge_mode() == :shared
        @warn "Bridge daemon control request failed; retrying shared-mode request without persistent stdio fallback." first_exception = (first_err, first_bt) second_exception = (second_err, second_bt) state_dir = service.state_dir

        try
          return daemon_control_request!(service, spec, payload)
        catch third_err
          third_bt = catch_backtrace()
          @warn "Bridge daemon control request still failed in shared mode; using one-off stdio fallback for this request only." exception = (third_err, third_bt) state_dir = service.state_dir
          return request_stdio_once(spec, payload)
        end
      end

      reset_daemon_connections!(service)
      try
        return request!(ensure_control_connection!(service, spec), payload)
      catch
        return request!(ensure_stdio_fallback!(service, spec), payload)
      end
    end
  end
end

function bridge_config(spec; match_options = spec.match_options, include_tactical_summary = true)
  return Dict{String, Any}(
    "variant_id" => spec.variant_id,
    "match_options" => copy(match_options),
    "tactical_config" => copy(spec.tactical_config),
    "include_tactical_summary" => include_tactical_summary
  )
end

bridge_config_signature(spec; include_tactical_summary = true) =
  JSON3.write(bridge_config(spec; include_tactical_summary))

ping!(connection::BridgeConnection) =
  request!(connection, Dict{String, Any}("cmd" => "ping"))

function ping!(client::BridgeClient, spec)
  return bridge_request!(client.service, spec, Dict{String, Any}("cmd" => "ping"))
end

function new_game!(client::BridgeClient, spec)
  match_options = resolved_match_options_for_new_game(spec)
  return bridge_request!(
    client.service,
    spec,
    Dict{String, Any}(
      "cmd" => "new_game",
      "config" => bridge_config(spec; match_options)
    )
  )
end

function bridge_step_request_key(
  spec,
  state::TricTracState,
  action::Dict{String, Any};
  include_tactical_summary::Bool = true
)
  return (
    state_runtime_term(state),
    JSON3.write(action),
    bridge_config_signature(spec; include_tactical_summary)
  )
end

function bridge_step_payload(
  spec,
  state::TricTracState,
  action::Dict{String, Any};
  include_tactical_summary::Bool = true
)
  return Dict{String, Any}(
    "cmd" => "step",
    "state" => Dict{String, Any}("runtime_term" => state_runtime_term(state)),
    "action" => action,
    "config" => bridge_config(spec; include_tactical_summary)
  )
end

function bridge_state_payload(spec, state::TricTracState; include_tactical_summary::Bool = true)
  return Dict{String, Any}(
    "cmd" => "state",
    "state" => Dict{String, Any}("runtime_term" => state_runtime_term(state)),
    "config" => bridge_config(spec; include_tactical_summary)
  )
end

function bridge_batch_request!(service::BridgeService, spec, request::BridgeBatchRequest)
  maybe_restore_daemon!(service, spec)
  if service.transport == :stdio
    return request!(ensure_stdio_fallback!(service, spec), request.payload)
  end

  ensure_daemon_running!(service, spec)
  if service.transport == :stdio
    return request!(ensure_stdio_fallback!(service, spec), request.payload)
  end

  put!(service.step_queue, request)
  reply = take!(request.reply_channel)
  reply isa Exception && throw(reply)
  return reply
end

function bridge_step_cache_get(request_key)
  lock(STEP_RESPONSE_CACHE_LOCK)
  try
    return get(STEP_RESPONSE_CACHE, request_key, nothing)
  finally
    unlock(STEP_RESPONSE_CACHE_LOCK)
  end
end

function trim_step_response_cache!()
  removed = 0
  head = STEP_RESPONSE_CACHE_ORDER_HEAD[]
  while length(STEP_RESPONSE_CACHE) > STEP_RESPONSE_CACHE_LIMIT - STEP_RESPONSE_CACHE_TRIM &&
        head <= length(STEP_RESPONSE_CACHE_ORDER) &&
        removed < STEP_RESPONSE_CACHE_TRIM
    key = STEP_RESPONSE_CACHE_ORDER[head]
    head += 1
    if delete!(STEP_RESPONSE_CACHE, key) !== nothing
      removed += 1
    end
  end
  STEP_RESPONSE_CACHE_ORDER_HEAD[] = head
  maybe_compact_step_response_cache_order!()
  return nothing
end

function maybe_compact_step_response_cache_order!()
  head = STEP_RESPONSE_CACHE_ORDER_HEAD[]
  if head > STEP_RESPONSE_CACHE_TRIM && head > cld(length(STEP_RESPONSE_CACHE_ORDER), 2)
    remaining =
      head <= length(STEP_RESPONSE_CACHE_ORDER) ? STEP_RESPONSE_CACHE_ORDER[head:end] : Any[]
    empty!(STEP_RESPONSE_CACHE_ORDER)
    append!(STEP_RESPONSE_CACHE_ORDER, remaining)
    STEP_RESPONSE_CACHE_ORDER_HEAD[] = 1
  end
  return nothing
end

function bridge_step_cache_put!(request_key, response::Dict{String, Any})
  lock(STEP_RESPONSE_CACHE_LOCK)
  try
    if !haskey(STEP_RESPONSE_CACHE, request_key)
      STEP_RESPONSE_CACHE[request_key] = response
      push!(STEP_RESPONSE_CACHE_ORDER, request_key)
      if length(STEP_RESPONSE_CACHE) > STEP_RESPONSE_CACHE_LIMIT
        trim_step_response_cache!()
      end
    end
    return STEP_RESPONSE_CACHE[request_key]
  finally
    unlock(STEP_RESPONSE_CACHE_LOCK)
  end
end

function clear_step_response_cache!()
  lock(STEP_RESPONSE_CACHE_LOCK)
  try
    empty!(STEP_RESPONSE_CACHE)
    empty!(STEP_RESPONSE_CACHE_ORDER)
    STEP_RESPONSE_CACHE_ORDER_HEAD[] = 1
  finally
    unlock(STEP_RESPONSE_CACHE_LOCK)
  end
  return nothing
end

function step_response_cache_size()
  lock(STEP_RESPONSE_CACHE_LOCK)
  try
    return length(STEP_RESPONSE_CACHE)
  finally
    unlock(STEP_RESPONSE_CACHE_LOCK)
  end
end

function step!(
  client::BridgeClient,
  spec,
  state::TricTracState,
  action::Dict{String, Any};
  include_tactical_summary::Bool = true
)
  request_key = bridge_step_request_key(spec, state, action; include_tactical_summary)
  cached = bridge_step_cache_get(request_key)
  cached !== nothing && return cached

  payload = bridge_step_payload(spec, state, action; include_tactical_summary)
  request = BridgeBatchRequest(request_key, payload, Channel{Any}(1))
  response = bridge_batch_request!(client.service, spec, request)
  return bridge_step_cache_put!(request_key, response)
end

function state!(
  client::BridgeClient,
  spec,
  state::TricTracState;
  include_tactical_summary::Bool = true
)
  payload = bridge_state_payload(spec, state; include_tactical_summary)
  return bridge_request!(client.service, spec, payload)
end

function bridge_stats(spec)
  client = bridge_client(spec)
  service = client.service
  payload = Dict{String, Any}("cmd" => "stats")
  stats = bridge_request!(service, spec, payload)
  stats["transport"] = String(service.transport)
  stats["state_dir"] = service.state_dir
  stats["julia_step_cache_size"] = step_response_cache_size()
  return stats
end

function flush_pending_step_batch!(
  service::BridgeService,
  spec,
  pending::Vector{BridgeBatchRequest},
  connection::Union{Nothing, BridgeConnection}
)
  isempty(pending) && return connection

  grouped = Dict{Any, Tuple{Dict{String, Any}, Vector{Channel{Any}}}}()
  for request in pending
    if haskey(grouped, request.request_key)
      push!(grouped[request.request_key][2], request.reply_channel)
    else
      grouped[request.request_key] = (request.payload, Channel{Any}[request.reply_channel])
    end
  end

  unique_entries = collect(grouped)
  items = Dict{String, Any}[]
  replies_by_id = Dict{String, Vector{Channel{Any}}}()
  for (index, (_key, (payload, reply_channels))) in pairs(unique_entries)
    item_id = string(index)
    push!(items, Dict{String, Any}(
      "item_id" => item_id,
      "state" => payload["state"],
      "action" => payload["action"],
      "config" => payload["config"],
    ))
    replies_by_id[item_id] = reply_channels
  end

  response = nothing
  last_error = nothing
  last_backtrace = nothing
  for attempt in 1:2
    try
      if connection === nothing
        ensure_daemon_running!(service, spec)
        connection = BridgeConnection(service.socket_path)
      end
      response = request!(connection, Dict{String, Any}("cmd" => "step_batch", "items" => items))
      break
    catch err
      last_error = err
      last_backtrace = catch_backtrace()
      if connection !== nothing
        close(connection)
      end
      connection = nothing
      if attempt == 2
        try
          reset_daemon_connections!(service)
        catch
        end
      end
    end
  end

  if response === nothing
    dispatch_failed_step_batch!(service, spec, pending, last_error, last_backtrace)
    return connection
  end

  items_response = get(response, "items", Any[])
  seen_ids = Set{String}()
  for item in items_response
    item_id = String(item["item_id"])
    push!(seen_ids, item_id)
    reply_channels = get(replies_by_id, item_id, Channel{Any}[])
    if Bool(item["ok"])
      result = item["result"]
      for channel in reply_channels
        put!(channel, result)
      end
    else
      err = ErrorException(String(item["error"]))
      for channel in reply_channels
        put!(channel, err)
      end
    end
  end

  for (item_id, reply_channels) in pairs(replies_by_id)
    if !(item_id in seen_ids)
      err = last_error isa Exception ? last_error : ErrorException("Bridge batch response omitted item $(repr(item_id)).")
      for channel in reply_channels
        put!(channel, err)
      end
    end
  end

  return connection
end

function dispatch_failed_step_batch!(service::BridgeService, spec, pending, last_error, last_backtrace)
  if configured_bridge_mode() == :shared
    if last_error !== nothing
      @warn "Bridge daemon step_batch failed; retrying this batch as individual daemon step requests." exception = (last_error, last_backtrace) state_dir = service.state_dir batch_items = length(pending)
    end

    try
      reset_daemon_connections!(service)
    catch
    end

    for request in pending
      try
        put!(request.reply_channel, daemon_step_request!(service, spec, request.payload))
      catch err
        put!(request.reply_channel, err)
      end
    end

    return nothing
  end

  if last_error !== nothing
    @warn "Bridge daemon step_batch failed; using stdio fallback for this batch." exception = (last_error, last_backtrace) state_dir = service.state_dir batch_items = length(pending)
  end

  fallback = ensure_stdio_fallback!(service, spec)
  for request in pending
    try
      put!(request.reply_channel, request!(fallback, request.payload))
    catch err
      put!(request.reply_channel, err)
    end
  end

  return nothing
end

function daemon_step_request!(service::BridgeService, spec, payload::Dict{String, Any})
  connection = nothing
  last_error = nothing

  for attempt in 1:2
    try
      if attempt == 2
        try
          reset_daemon_connections!(service)
        catch
        end
      end

      ensure_daemon_running!(service, spec)
      connection = BridgeConnection(service.socket_path)
      return request!(connection, payload)
    catch err
      last_error = err
      if connection !== nothing
        close(connection)
      end
      connection = nothing
    end
  end

  throw(something(last_error, ErrorException("Bridge daemon step fallback failed.")))
end

function daemon_control_request!(service::BridgeService, spec, payload::Dict{String, Any})
  connection = nothing
  last_error = nothing

  for attempt in 1:2
    try
      if attempt == 2
        try
          reset_daemon_connections!(service)
        catch
        end
      end

      ensure_daemon_running!(service, spec)
      connection = BridgeConnection(service.socket_path)
      return request!(connection, payload)
    catch err
      last_error = err
      if connection !== nothing
        close(connection)
      end
      connection = nothing
    end
  end

  throw(something(last_error, ErrorException("Bridge daemon control fallback failed.")))
end

function request_stdio_once(spec, payload::Dict{String, Any})
  connection = BridgeConnection(spec)
  try
    return request!(connection, payload)
  finally
    close(connection)
  end
end

function bridge_step_coordinator(service::BridgeService, spec)
  connection = nothing
  stop_after_flush = false
  try
    while true
      request = take!(service.step_queue)
      request === BRIDGE_BATCH_STOP && break

      pending = BridgeBatchRequest[request]
      deadline = time() + BRIDGE_BATCH_FLUSH_SECONDS
      stop_after_flush = false
      while length(pending) < BRIDGE_BATCH_LIMIT && time() < deadline
        if isready(service.step_queue)
          next_request = take!(service.step_queue)
          if next_request === BRIDGE_BATCH_STOP
            stop_after_flush = true
            break
          end
          push!(pending, next_request)
        else
          sleep(0.0001)
        end
      end

      connection = flush_pending_step_batch!(service, spec, pending, connection)
      stop_after_flush && break
    end
  catch
  finally
    if connection !== nothing
      close(connection)
    end
  end
  return nothing
end

function request!(connection::BridgeConnection, payload::Dict{String, Any})
  lock(connection.lock)
  try
    id = connection.next_id
    connection.next_id += 1

    message = Dict{String, Any}("id" => id)
    merge!(message, payload)

    write(connection.io, JSON3.write(message))
    write(connection.io, '\n')
    flush(connection.io)

    line = readline(connection.io)
    response = to_plain(JSON3.read(line))

    if !Bool(response["ok"])
      error(String(response["error"]))
    end

    return response["result"]
  finally
    unlock(connection.lock)
  end
end

to_plain(x::Nothing) = nothing
to_plain(x::Bool) = x
to_plain(x::Integer) = Int(x)
to_plain(x::AbstractFloat) = Float64(x)
to_plain(x::String) = x
to_plain(x::Symbol) = String(x)
to_plain(x) = x

function to_plain(x::JSON3.Array)
  return Any[to_plain(value) for value in x]
end

function to_plain(x::JSON3.Object)
  dict = Dict{String, Any}()
  for (key, value) in pairs(x)
    dict[String(key)] = to_plain(value)
  end
  return dict
end
