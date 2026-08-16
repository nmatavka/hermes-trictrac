defmodule HermesTrictrac.Training.RaceTrainingBridge do
  @moduledoc """
  JSON bridge used by the Julia race-game trainers.

  It deliberately owns an `Engine` rather than reimplementing a race-game
  transition.  The Julia process receives a compact JSON view plus an opaque
  engine term; every legal action and settlement still comes from the normal
  game engine.
  """

  alias HermesTrictrac.Rules.Engine

  @white {"RaceZero White", "race-zero-white"}
  @black {"RaceZero Black", "race-zero-black"}
  @max_auto_steps 32
  @supported_variants ~w(backgammon tapa jacquet garanguet tavli brade)
  @dice_outcomes (for a <- 1..6, b <- a..6 do
                    %{
                      "dice" => [a, b],
                      "weight" => if(a == b, do: 1.0 / 36.0, else: 2.0 / 36.0)
                    }
                  end)

  def ping(config \\ %{}), do: {:ok, %{"pong" => true, "game" => variant_id(config)}}
  def shutdown, do: {:ok, %{"shutdown" => true}}
  def dice_outcomes, do: {:ok, %{"outcomes" => @dice_outcomes}}

  def roll_with_dice(state, dice) do
    with {:ok, engine} <- engine_from_state(state),
         {:ok, values} <- normalize_dice(dice),
         {:ok, engine} <- Engine.roll_for_training(engine, engine.turn_color, values) do
      {:ok, response(engine, 0.0)}
    end
  end

  def rpc(request) when is_map(request) do
    with {:ok, result} <- dispatch(normalize(request)) do
      %{"id" => Map.get(request, "id"), "ok" => true, "result" => result}
    else
      {:error, message} -> %{"id" => Map.get(request, "id"), "ok" => false, "error" => message}
    end
  rescue
    error -> %{"id" => Map.get(request, "id"), "ok" => false, "error" => Exception.message(error)}
  end

  def new_game(config \\ %{}) do
    with {:ok, engine} <- new_engine(config) do
      {:ok, response(engine, 0.0)}
    end
  end

  def state(state, config \\ %{})

  def state(%{"runtime_term" => term}, _config) when is_binary(term) do
    with {:ok, engine} <- decode_engine(term) do
      {:ok, response(engine, 0.0)}
    end
  end

  def state(_state, _config), do: {:error, "Invalid race training state."}

  def step(state, action, _config \\ %{}) do
    with {:ok, engine} <- engine_from_state(state),
         {:ok, action} <- normalize_action(action),
         before <- utility(engine),
         {:ok, engine} <- apply_action(engine, action),
         {:ok, engine} <- auto_advance(engine),
         after_utility <- utility(engine) do
      {:ok, response(engine, after_utility - before)}
    end
  end

  def step_batch(items) when is_list(items) do
    {:ok,
     Enum.map(items, fn item ->
       item = normalize(item)
       item_id = Map.get(item, "item_id")

       case step(Map.get(item, "state"), Map.get(item, "action"), Map.get(item, "config", %{})) do
         {:ok, result} -> %{"item_id" => item_id, "ok" => true, "result" => result}
         {:error, message} -> %{"item_id" => item_id, "ok" => false, "error" => message}
       end
     end)}
  end

  def step_batch(_items), do: {:error, "Invalid race training batch."}

  def serialize_state(engine), do: response(engine, 0.0)["state"]

  # Model Lab reconstructs a legal current turn from XGID and applies its
  # choices through RaceCore.  It still needs the exact trainer feature/action
  # payload, but not an Engine term for stepping.
  def serialize_runtime(runtime) when is_map(runtime) do
    %{
      "runtime_term" => runtime |> :erlang.term_to_binary() |> Base.encode64(),
      "runtime" => runtime_payload(runtime),
      "phase" => if(is_nil(runtime.dice), do: "roll", else: "move"),
      "terminal" => get_in(runtime, [:match, :is_over]) == true,
      "white_to_play" => runtime.turn_color == :white,
      "legal_actions" => runtime.legal_moves |> Kernel.||([]) |> Enum.map(&move_action/1)
    }
  end

  def decode_engine(term) when is_binary(term) do
    try do
      {:ok, term |> Base.decode64!() |> :erlang.binary_to_term([:safe])}
    rescue
      ArgumentError -> {:error, "Invalid race-game training state."}
    end
  end

  defp dispatch(%{"cmd" => "ping"} = request), do: ping(Map.get(request, "config", %{}))
  defp dispatch(%{"cmd" => "shutdown"}), do: shutdown()
  defp dispatch(%{"cmd" => "dice_outcomes"}), do: dice_outcomes()

  defp dispatch(%{"cmd" => "roll_with_dice", "state" => state, "dice" => dice}),
    do: roll_with_dice(state, dice)

  defp dispatch(%{"cmd" => "new_game", "config" => config}), do: new_game(config)

  defp dispatch(%{"cmd" => "state", "state" => state} = request),
    do: state(state, Map.get(request, "config", %{}))

  defp dispatch(%{"cmd" => "step", "state" => state, "action" => action} = request),
    do: step(state, action, Map.get(request, "config", %{}))

  defp dispatch(%{"cmd" => "step_batch", "items" => items}), do: step_batch(items)
  defp dispatch(_), do: {:error, "Unknown race bridge command."}

  defp new_engine(config) do
    variant_id = variant_id(config)
    engine = Engine.new("#{variant_id}-training", variant_id)

    with {:ok, engine, _} <- Engine.join(engine, elem(@white, 0), elem(@white, 1)),
         {:ok, engine, _} <- Engine.join(engine, elem(@black, 0), elem(@black, 1)),
         {:ok, engine} <- configure_match(engine, variant_id, config),
         {:ok, engine} <- auto_advance(engine) do
      {:ok, engine}
    else
      {:error, message} -> {:error, message}
    end
  end

  defp engine_from_state(%{"runtime_term" => term}), do: decode_engine(term)
  defp engine_from_state(_), do: {:error, "Invalid race training state."}

  # Opening rolls, normal rolls, confirmations, and forced transitions are
  # chance/rules transitions. They never become learned policy decisions.
  defp auto_advance(engine, remaining \\ @max_auto_steps)
  defp auto_advance(_engine, 0), do: {:error, "Race-game automatic transition did not settle."}
  defp auto_advance(%{match: %{is_over: true}} = engine, _remaining), do: {:ok, engine}

  defp auto_advance(engine, remaining) do
    cond do
      opening_roll_pending?(engine) ->
        color = opening_color(engine)

        with {:ok, engine} <- roll(engine, color) do
          auto_advance(engine, remaining - 1)
        end

      is_nil(engine.dice) and engine.turn_color in [:white, :black] ->
        with {:ok, engine} <- roll(engine, engine.turn_color) do
          auto_advance(engine, remaining - 1)
        end

      not is_nil(engine.dice) and engine.legal_moves == [] ->
        with {:ok, engine} <- confirm(engine, engine.turn_color) do
          auto_advance(engine, remaining - 1)
        end

      true ->
        {:ok, engine}
    end
  end

  defp apply_action(engine, %{"type" => "move"} = action) do
    actor = actor_for(engine.turn_color)

    Engine.move(
      engine,
      Map.take(action, ["from", "to", "die", "dice_used", "sequence"]),
      elem(actor, 0),
      elem(actor, 1)
    )
  end

  defp apply_action(engine, %{"type" => "special", "id" => "ROLL"}),
    do: roll(engine, engine.turn_color)

  defp apply_action(engine, %{"type" => "special", "id" => "CONFIRM"}),
    do: confirm(engine, engine.turn_color)

  defp apply_action(_engine, _action), do: {:error, "Unsupported race-game training action."}

  defp roll(engine, color) when color in [:white, :black] do
    actor = actor_for(color)
    Engine.roll(engine, elem(actor, 0), elem(actor, 1))
  end

  defp roll(_engine, _color), do: {:error, "No race-game player can roll now."}

  defp confirm(engine, color) when color in [:white, :black] do
    actor = actor_for(color)
    Engine.confirm(engine, elem(actor, 0), elem(actor, 1))
  end

  defp confirm(_engine, _color), do: {:error, "No race-game player can confirm now."}

  defp actor_for(:white), do: @white
  defp actor_for(:black), do: @black

  defp opening_roll_pending?(engine) do
    engine.status == :playing and is_nil(engine.turn_color) and is_nil(engine.dice) and
      engine.turn_number == 0 and engine.match.results == []
  end

  defp opening_color(engine) do
    key = if(engine.variant.id == "brade", do: :brade_teker_rolls, else: :opening_rolls)
    rolls = get_in(engine.runtime, [:variant_state, key]) || %{}
    if is_nil(Map.get(rolls, :white)), do: :white, else: :black
  end

  defp response(engine, reward) do
    %{"state" => state_payload(engine), "reward" => reward}
  end

  defp state_payload(engine) do
    runtime = Engine.runtime_view(engine)

    %{
      "variant_id" => engine.variant.id,
      "runtime_term" => engine |> :erlang.term_to_binary() |> Base.encode64(),
      "runtime" => runtime_payload(runtime),
      "phase" => phase(engine),
      "terminal" => engine.match.is_over == true,
      "white_to_play" => engine.turn_color == :white,
      "legal_actions" => legal_actions(engine)
    }
  end

  defp runtime_payload(runtime) do
    %{
      "board" => json_value(runtime.board),
      "variant_state" => json_value(runtime.variant_state),
      "match" => json_value(runtime.match),
      "turn_color" => json_value(runtime.turn_color),
      "turn_number" => runtime.turn_number || 0,
      "dice" => json_value(runtime.dice),
      "legal_moves" => json_value(runtime.legal_moves || [])
    }
  end

  defp legal_actions(%{match: %{is_over: true}}), do: []

  defp legal_actions(engine) do
    case engine.legal_moves do
      [] when not is_nil(engine.dice) -> [%{"type" => "special", "id" => "CONFIRM"}]
      [] -> [%{"type" => "special", "id" => "ROLL"}]
      moves -> Enum.map(moves, &move_action/1)
    end
  end

  defp move_action(move) do
    %{
      "type" => "move",
      "from" => json_value(Map.get(move, :from)),
      "to" => json_value(Map.get(move, :to)),
      "die" => Map.get(move, :die),
      "dice_used" => json_value(Map.get(move, :dice_used)),
      "sequence" => json_value(Map.get(move, :sequence))
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp phase(%{match: %{is_over: true}}), do: "terminal"
  defp phase(%{dice: nil, turn_color: nil}), do: "opening"
  defp phase(%{dice: nil}), do: "roll"
  defp phase(_engine), do: "move"

  # This bounded potential is entirely derived from official Engine output.
  # The score term teaches settlement value, while the terminal winner keeps
  # the match objective primary and includes Engine tiebreak resolution.
  defp utility(engine) do
    length = max(engine.match.length || 5, 1)
    score = engine.match.score || %{}
    white = Map.get(score, :white, Map.get(score, "white", 0)) || 0
    black = Map.get(score, :black, Map.get(score, "black", 0)) || 0
    score_term = (white - black) / (6.0 * length)

    winner_term =
      case engine.match.winner do
        "white" -> 1.0
        :white -> 1.0
        "black" -> -1.0
        :black -> -1.0
        _ -> 0.0
      end

    0.5 * score_term + 0.5 * winner_term
  end

  defp normalize_action(action) when is_map(action), do: {:ok, normalize(action)}
  defp normalize_action(_), do: {:error, "Invalid race training action."}

  defp normalize_dice(values) when is_list(values) and values != [] do
    if Enum.all?(values, &(&1 in 1..6)), do: {:ok, values}, else: {:error, "Invalid forced dice."}
  end

  defp normalize_dice(_dice), do: {:error, "Invalid forced dice."}

  defp configure_match(engine, "brade", config) do
    options = match_options(config, %{"matchLength" => "5"})
    Engine.submit_match_options(engine, options, elem(@white, 0), elem(@white, 1))
  end

  defp configure_match(engine, "tavli", config) do
    target = Map.get(match_options(config, %{}), "tavliTarget", "7") |> to_string()

    with {:ok, engine} <-
           Engine.submit_match_options(
             engine,
             %{"tavliTargetConsent" => target},
             elem(@white, 0),
             elem(@white, 1)
           ) do
      Engine.submit_match_options(
        engine,
        %{"tavliTargetConsent" => target},
        elem(@black, 0),
        elem(@black, 1)
      )
    end
  end

  defp configure_match(engine, _variant_id, _config), do: {:ok, engine}

  defp match_options(config, defaults) do
    config = normalize(config)
    options = config |> Map.get("match_options", config) |> normalize()
    Map.merge(defaults, options)
  end

  defp variant_id(config) do
    config = normalize(config)
    candidate = Map.get(config, "variant_id", "brade") |> to_string()
    if candidate in @supported_variants, do: candidate, else: "brade"
  end

  defp normalize(map) when is_map(map),
    do: Map.new(map, fn {key, value} -> {to_string(key), normalize(value)} end)

  defp normalize(list) when is_list(list), do: Enum.map(list, &normalize/1)
  defp normalize(value), do: value

  defp json_value(nil), do: nil
  defp json_value(value) when is_atom(value), do: Atom.to_string(value)

  defp json_value(value) when is_map(value),
    do: Map.new(value, fn {key, inner} -> {to_string(key), json_value(inner)} end)

  defp json_value(value) when is_list(value), do: Enum.map(value, &json_value/1)
  defp json_value(value), do: value
end
