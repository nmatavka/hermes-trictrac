mutable struct BridgeClient
  io::IO
  lock::ReentrantLock
  next_id::Int
end

const BRIDGE_CACHE_LOCK = ReentrantLock()
const BRIDGE_CACHE = Dict{Tuple{String, String, Int}, BridgeClient}()

function BridgeClient(spec)
  rel_script = relpath(spec.bridge_script, spec.repo_root)
  run(Cmd(`mix compile`, dir = spec.repo_root))
  cmd = Cmd(`mix run --no-start --no-compile --no-deps-check $rel_script`, dir = spec.repo_root)
  io = open(cmd, "r+")
  client = BridgeClient(io, ReentrantLock(), 1)
  finalizer(close, client)
  ping!(client)
  return client
end

function Base.close(client::BridgeClient)
  try
    close(client.io)
  catch
  end
  return nothing
end

function bridge_client(spec)
  key = (spec.repo_root, spec.bridge_script, Threads.threadid())
  lock(BRIDGE_CACHE_LOCK)
  try
    return get!(BRIDGE_CACHE, key) do
      BridgeClient(spec)
    end
  finally
    unlock(BRIDGE_CACHE_LOCK)
  end
end

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

function bridge_config(spec)
  return Dict{String, Any}(
    "variant_id" => spec.variant_id,
    "match_options" => copy(spec.match_options)
  )
end

function ping!(client::BridgeClient)
  return request!(client, Dict{String, Any}("cmd" => "ping"))
end

function new_game!(client::BridgeClient, spec)
  return request!(
    client,
    Dict{String, Any}(
      "cmd" => "new_game",
      "config" => bridge_config(spec)
    )
  )
end

function step!(
  client::BridgeClient,
  spec,
  state::TricTracState,
  action::Dict{String, Any}
)
  return request!(
    client,
    Dict{String, Any}(
      "cmd" => "step",
      "state" => Dict{String, Any}("runtime_term" => state_runtime_term(state)),
      "action" => action,
      "config" => bridge_config(spec)
    )
  )
end

function request!(client::BridgeClient, payload::Dict{String, Any})
  lock(client.lock)
  try
    id = client.next_id
    client.next_id += 1

    message = Dict{String, Any}("id" => id)
    merge!(message, payload)

    write(client.io, JSON3.write(message))
    write(client.io, '\n')
    flush(client.io)

    line = readline(client.io)
    response = to_plain(JSON3.read(line))

    if !Bool(response["ok"])
      error(String(response["error"]))
    end

    return response["result"]
  finally
    unlock(client.lock)
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
