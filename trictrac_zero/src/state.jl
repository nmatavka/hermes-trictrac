struct TricTracState
  runtime_term::String
  runtime::Dict{String, Any}
  phase::String
  terminal::Bool
  white_to_play::Bool
  legal_actions_raw::Vector{Dict{String, Any}}
  legal_actions::Vector{TricTracAction}
end

function TricTracState(data::Dict{String, Any})
  runtime_term = String(data["runtime_term"])
  runtime = shallow_string_dict(get(data, "runtime", Dict{String, Any}()))
  phase = String(get(data, "phase", "terminal"))
  terminal = Bool(get(data, "terminal", false))
  white_to_play = Bool(get(data, "white_to_play", true))
  legal_actions_raw = normalize_action_dicts(get(data, "legal_actions", Any[]))
  legal_actions = [
    bridge_action_to_catalog_action(action, white_to_play)
    for action in legal_actions_raw
  ]
  return TricTracState(
    runtime_term,
    runtime,
    phase,
    terminal,
    white_to_play,
    legal_actions_raw,
    legal_actions
  )
end

Base.:(==)(a::TricTracState, b::TricTracState) = a.runtime_term == b.runtime_term
Base.hash(state::TricTracState, h::UInt) = hash(state.runtime_term, h)

state_runtime(state::TricTracState) = state.runtime
state_phase(state::TricTracState) = state.phase
state_terminal(state::TricTracState) = state.terminal
state_white_to_play(state::TricTracState) = state.white_to_play
state_legal_actions(state::TricTracState) = state.legal_actions_raw
state_runtime_term(state::TricTracState) = state.runtime_term

function shallow_string_dict(value)
  dict = Dict{String, Any}()
  for (key, inner) in pairs(value)
    dict[String(key)] = inner
  end
  return dict
end

function normalize_action_dicts(value)
  actions = Dict{String, Any}[]
  for action in value
    push!(actions, shallow_string_dict(action))
  end
  return actions
end
