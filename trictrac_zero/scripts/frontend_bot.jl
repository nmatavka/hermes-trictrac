include(joinpath(@__DIR__, "bootstrap.jl"))

using AlphaZero
using JSON3
using Logging
using TricTracZero

import AlphaZero.Network
import Serialization: deserialize

const SESSION_DIR = isempty(ARGS) ? TricTracZero.default_session_dir(TricTracZero.default_experiment()) : ARGS[1]
const GSPEC_FILE = "gspec.data"
const BESTNN_FILE = joinpath(SESSION_DIR, "bestnn.data")

mutable struct FrontendBotState
  session_dir::String
  bestnn_file::String
  signature::Union{Nothing, Tuple{Float64, Int64}}
  gspec::Union{Nothing, TricTracZero.TricTracGameSpec}
  network
end

function FrontendBotState(session_dir::String)
  return FrontendBotState(session_dir, joinpath(session_dir, "bestnn.data"), nothing, nothing, nothing)
end

function session_signature(path::String)
  stat = Base.stat(path)
  return (Float64(stat.mtime), Int64(stat.size))
end

function session_ready(path::String)
  return isfile(path)
end

function action_type(action)
  action isa Dict || return nothing
  return get(action, "type", nothing)
end

function special_action_id(action)
  action isa Dict || return nothing
  return get(action, "id", nothing)
end

is_move_action(action) = action_type(action) == "move"
is_confirm_action(action) = action_type(action) == "special" && special_action_id(action) == "CONFIRM"

function no_checker_moves_played(state_data)
  runtime = get(state_data, "runtime", Dict{String, Any}())
  dice = get(runtime, "dice", nothing)
  dice === nothing && return false
  moves_played = get(dice, "moves_played", Any[])
  return isempty(moves_played)
end

function choose_frontend_action_index(policy, raw_actions, state_data)
  isempty(raw_actions) && error("No raw legal actions available for the requested state.")

  if isempty(policy)
    selected = 1
    n = 1
  else
    n = min(length(policy), length(raw_actions))
    selected = argmax(policy[1:n])
  end

  if is_confirm_action(raw_actions[selected]) && no_checker_moves_played(state_data)
    move_indices = [index for index in 1:n if is_move_action(raw_actions[index])]
    if !isempty(move_indices)
      isempty(policy) && return first(move_indices)
      return move_indices[argmax(policy[move_indices])]
    end
  end

  return selected
end

function load_network!(state::FrontendBotState)
  session_ready(state.bestnn_file) || error("No trained best network found at $(state.bestnn_file).")
  state.gspec = deserialize(joinpath(state.session_dir, GSPEC_FILE))
  bestnn = deserialize(state.bestnn_file)
  state.network = Network.copy(bestnn, on_gpu = false, test_mode = true)
  state.signature = session_signature(state.bestnn_file)
  return state
end

function maybe_reload!(state::FrontendBotState)
  signature = session_ready(state.bestnn_file) ? session_signature(state.bestnn_file) : nothing

  if isnothing(signature)
    isnothing(state.network) && error("No trained best network found at $(state.bestnn_file).")
    return state
  elseif isnothing(state.network) || state.signature != signature
    try
      return load_network!(state)
    catch err
      if isnothing(state.network)
        rethrow(err)
      else
        println(stderr, "warning: failed to reload TricTrac frontend bot: ", sprint(showerror, err))
        return state
      end
    end
  else
    return state
  end
end

function choose_action!(state::FrontendBotState, payload)
  maybe_reload!(state)
  state_data = TricTracZero.to_plain(payload)
  game_state = TricTracZero.TricTracState(state_data)
  legal_actions = TricTracZero.state_catalog_actions(game_state)
  raw_actions = TricTracZero.state_legal_actions(game_state)

  isempty(legal_actions) && error("No legal actions available for the requested state.")

  policy, value = Network.evaluate(state.network, game_state)
  index = choose_frontend_action_index(policy, raw_actions, state_data)

  return Dict{String, Any}(
    "action" => raw_actions[index],
    "policy" => [Float64(probability) for probability in policy],
    "value" => value
  )
end

function respond(id, ok, result)
  message = Dict{String, Any}("id" => id, "ok" => ok)

  if ok
    message["result"] = result
  else
    message["error"] = result
  end

  println(stdout, JSON3.write(message))
  flush(stdout)
end

function handle_request!(state::FrontendBotState, request)
  request = TricTracZero.to_plain(request)
  id = Int(request["id"])
  cmd = String(request["cmd"])

  try
    result =
      if cmd == "ping"
        maybe_reload!(state)
        Dict{String, Any}("ready" => true, "model_name" => "TricTracZero")
      elseif cmd == "choose_action"
        choose_action!(state, request["state"])
      else
        error("Unknown command: $cmd")
      end

    respond(id, true, result)
  catch err
    respond(id, false, sprint(showerror, err))
  end
end

function main()
  state = FrontendBotState(SESSION_DIR)

  while !eof(stdin)
    line = try
      readline(stdin)
    catch
      break
    end

    isempty(strip(line)) && continue
    request = JSON3.read(line)
    handle_request!(state, request)
  end
end

if !isempty(PROGRAM_FILE) && abspath(PROGRAM_FILE) == abspath(@__FILE__)
  main()
end
