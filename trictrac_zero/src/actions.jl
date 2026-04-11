@enum ActionKind::UInt8 begin
  MOVE_ACTION = 1
  ROLL_ACTION = 2
  CONFIRM_ACTION = 3
  DECISION_TENIR_ACTION = 4
  DECISION_SEN_ALLER_ACTION = 5
end

const BAR_POS = Int8(-1)
const HOME_POS = Int8(24)
const NO_POS = Int8(-2)
const NO_SEQ = Int8(0)

const ACTION_KIND_FEATURES = 5
const ACTION_FROM_FEATURES = 26
const ACTION_TO_FEATURES = 26
const ACTION_SEQUENCE_FEATURES = 37
const NUM_ACTION_FEATURES =
  ACTION_KIND_FEATURES +
  ACTION_FROM_FEATURES +
  ACTION_TO_FEATURES +
  ACTION_SEQUENCE_FEATURES

struct TricTracAction
  kind::ActionKind
  from::Int8
  to::Int8
  s1::Int8
  s2::Int8
end

TricTracAction(kind::ActionKind) = TricTracAction(kind, NO_POS, NO_POS, NO_SEQ, NO_SEQ)

special_action(kind::ActionKind) = TricTracAction(kind)

const DECISION_SUSPEND_CLASSIQUE = TricTracAction(DECISION_TENIR_ACTION, BAR_POS, HOME_POS, 1, 1)
const DECISION_SUSPEND_A_ECRIRE = TricTracAction(DECISION_TENIR_ACTION, BAR_POS, HOME_POS, 1, 2)
const DECISION_NONE = TricTracAction(DECISION_TENIR_ACTION, BAR_POS, HOME_POS, 1, 3)

function build_action_catalog()
  actions = TricTracAction[
    special_action(ROLL_ACTION),
    special_action(CONFIRM_ACTION),
    special_action(DECISION_TENIR_ACTION),
    special_action(DECISION_SEN_ALLER_ACTION),
    DECISION_SUSPEND_CLASSIQUE,
    DECISION_SUSPEND_A_ECRIRE,
    DECISION_NONE,
  ]

  from_positions = Int8[BAR_POS; Int8.(collect(0:23))]
  to_positions = Int8[HOME_POS; Int8.(collect(0:23))]
  sequences = Tuple{Int8, Int8}[(NO_SEQ, NO_SEQ)]
  append!(sequences, [(Int8(a), Int8(b)) for a in 1:6 for b in 1:6])

  for from in from_positions, to in to_positions, (s1, s2) in sequences
    push!(actions, TricTracAction(MOVE_ACTION, from, to, s1, s2))
  end

  return actions
end

const ACTION_CATALOG = build_action_catalog()
const ACTION_INDEX = Dict(action => i for (i, action) in enumerate(ACTION_CATALOG))

action_catalog() = ACTION_CATALOG

state_catalog_actions(state) = state.legal_actions

function special_id(kind::ActionKind)
  if kind == ROLL_ACTION
    return "ROLL"
  elseif kind == CONFIRM_ACTION
    return "CONFIRM"
  elseif kind == DECISION_TENIR_ACTION
    return "DECISION_TENIR"
  elseif kind == DECISION_SEN_ALLER_ACTION
    return "DECISION_SEN_ALLER"
  else
    return nothing
  end
end

function special_id(action::TricTracAction)
  action == DECISION_SUSPEND_CLASSIQUE && return "DECISION_SUSPEND_CLASSIQUE"
  action == DECISION_SUSPEND_A_ECRIRE && return "DECISION_SUSPEND_A_ECRIRE"
  action == DECISION_NONE && return "DECISION_NONE"
  return special_id(action.kind)
end

is_move_action(action::TricTracAction) = action.kind == MOVE_ACTION

function normalize_point(point, white_to_play::Bool)
  if point == "bar"
    return BAR_POS
  elseif point == "home"
    return HOME_POS
  elseif point isa Integer
    return Int8(white_to_play ? point : 23 - point)
  else
    error("Unsupported point: $point")
  end
end

function denormalize_point(point::Int8, white_to_play::Bool)
  if point == BAR_POS
    return "bar"
  elseif point == HOME_POS
    return "home"
  elseif 0 <= point <= 23
    value = Int(point)
    return white_to_play ? value : 23 - value
  else
    error("Unsupported normalized point: $point")
  end
end

function bridge_action_to_catalog_action(raw::Dict{String, Any}, white_to_play::Bool)
  if raw["type"] == "special"
    id = String(raw["id"])
    if id == "ROLL"
      return special_action(ROLL_ACTION)
    elseif id == "CONFIRM"
      return special_action(CONFIRM_ACTION)
    elseif id == "DECISION_TENIR"
      return special_action(DECISION_TENIR_ACTION)
    elseif id == "DECISION_SEN_ALLER"
      return special_action(DECISION_SEN_ALLER_ACTION)
    elseif id == "DECISION_SUSPEND_CLASSIQUE"
      return DECISION_SUSPEND_CLASSIQUE
    elseif id == "DECISION_SUSPEND_A_ECRIRE"
      return DECISION_SUSPEND_A_ECRIRE
    elseif id == "DECISION_NONE"
      return DECISION_NONE
    else
      error("Unknown special action id: $id")
    end
  end

  sequence = get(raw, "sequence", nothing)
  s1, s2 =
    if sequence isa AbstractVector && length(sequence) == 2
      (Int8(sequence[1]), Int8(sequence[2]))
    else
      (NO_SEQ, NO_SEQ)
    end

  return TricTracAction(
    MOVE_ACTION,
    normalize_point(raw["from"], white_to_play),
    normalize_point(raw["to"], white_to_play),
    s1,
    s2
  )
end

function catalog_action_to_bridge_action(action::TricTracAction, white_to_play::Bool)
  if action.kind != MOVE_ACTION
    id = special_id(action)
    isnothing(id) && error("Unsupported special action: $(repr(action))")
    return Dict{String, Any}(
      "type" => "special",
      "id" => id
    )
  end

  payload = Dict{String, Any}(
    "type" => "move",
    "from" => denormalize_point(action.from, white_to_play),
    "to" => denormalize_point(action.to, white_to_play)
  )

  if action.s1 != NO_SEQ && action.s2 != NO_SEQ
    payload["sequence"] = Any[Int(action.s1), Int(action.s2)]
  end

  return payload
end

function action_label(action::TricTracAction)
  if action.kind != MOVE_ACTION
    id = special_id(action)
    return isnothing(id) ? "UNKNOWN_SPECIAL_ACTION" : String(id)
  end

  from = action.from == BAR_POS ? "bar" : string(Int(action.from))
  to = action.to == HOME_POS ? "home" : string(Int(action.to))

  if action.s1 == NO_SEQ && action.s2 == NO_SEQ
    return string(from, "->", to)
  end

  return string(from, "->", to, "[", Int(action.s1), ",", Int(action.s2), "]")
end

function parse_action_label(str::String)
  if str == "ROLL"
    return special_action(ROLL_ACTION)
  elseif str == "CONFIRM"
    return special_action(CONFIRM_ACTION)
  elseif str == "DECISION_TENIR"
    return special_action(DECISION_TENIR_ACTION)
  elseif str == "DECISION_SEN_ALLER"
    return special_action(DECISION_SEN_ALLER_ACTION)
  elseif str == "DECISION_SUSPEND_CLASSIQUE"
    return DECISION_SUSPEND_CLASSIQUE
  elseif str == "DECISION_SUSPEND_A_ECRIRE"
    return DECISION_SUSPEND_A_ECRIRE
  elseif str == "DECISION_NONE"
    return DECISION_NONE
  end

  m = match(r"^(bar|\d+)->(home|\d+)(?:\[(\d),(\d)\])?$", str)
  isnothing(m) && return nothing

  from = m.captures[1] == "bar" ? BAR_POS : Int8(parse(Int, m.captures[1]))
  to = m.captures[2] == "home" ? HOME_POS : Int8(parse(Int, m.captures[2]))
  s1 = isnothing(m.captures[3]) ? NO_SEQ : Int8(parse(Int, m.captures[3]))
  s2 = isnothing(m.captures[4]) ? NO_SEQ : Int8(parse(Int, m.captures[4]))
  return TricTracAction(MOVE_ACTION, from, to, s1, s2)
end

function legal_action_features(actions::AbstractVector{TricTracAction})
  features = zeros(Float32, NUM_ACTION_FEATURES, length(actions))
  for (index, action) in pairs(actions)
    features[action_kind_feature_index(action), index] = 1f0
    features[ACTION_KIND_FEATURES + action_from_feature_index(action), index] = 1f0
    features[ACTION_KIND_FEATURES + ACTION_FROM_FEATURES + action_to_feature_index(action), index] = 1f0
    features[
      ACTION_KIND_FEATURES + ACTION_FROM_FEATURES + ACTION_TO_FEATURES + action_sequence_feature_index(action),
      index
    ] = 1f0
  end
  return features
end

action_kind_feature_index(action::TricTracAction) = Int(action.kind)

function action_from_feature_index(action::TricTracAction)
  action.from == NO_POS && return 1
  action.from == BAR_POS && return 2
  return Int(action.from) + 3
end

function action_to_feature_index(action::TricTracAction)
  action.to == NO_POS && return 1
  action.to == HOME_POS && return 2
  return Int(action.to) + 3
end

function action_sequence_feature_index(action::TricTracAction)
  action.s1 == NO_SEQ && action.s2 == NO_SEQ && return 1
  return 2 + (Int(action.s1) - 1) * 6 + (Int(action.s2) - 1)
end
