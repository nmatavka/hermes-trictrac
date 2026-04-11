defmodule HermesTrictrac.BackgammonAiBot do
  @moduledoc """
  In-tree English backgammon bot adapted from the `BackgammonAI-main` checkout.

  The original project scored positions using home-board occupancy, vulnerable
  blots, blocking points, pip count, hit checkers, and borne-off checkers. This
  module keeps that evaluation style, but runs it against the product engine's
  own legal move list so the bot never depends on a second rules implementation.
  """

  alias HermesTrictrac.Rules.RaceCore

  @positive_terminal 100_000
  @negative_terminal -100_000

  def model_name, do: "BackgammonAI"
  def model_name(_preset), do: model_name()

  def ready, do: :ok
  def ready(_preset), do: :ok

  def serialize_state(runtime, variant) do
    runtime = recalc_legal_moves(runtime, variant)

    %{
      "phase" => phase(runtime),
      "color" => Atom.to_string(runtime.turn_color),
      "runtime" => runtime,
      "variant" => variant,
      "legal_actions" => legal_actions(runtime)
    }
  end

  def choose_action(_preset, serialized_state), do: choose_action(serialized_state)

  def choose_action(%{"legal_actions" => actions} = serialized_state) when is_list(actions) do
    moves = Enum.filter(actions, &(&1["type"] == "move"))

    cond do
      moves != [] ->
        {:ok, choose_move(serialized_state, moves)}

      action = Enum.find(actions, &special?(&1, "CONFIRM")) ->
        {:ok, action}

      action = Enum.find(actions, &special?(&1, "ROLL")) ->
        {:ok, action}

      true ->
        {:error, "No legal actions available for BackgammonAI."}
    end
  end

  def choose_action(_serialized_state), do: {:error, "Invalid BackgammonAI state."}

  defp recalc_legal_moves(%{dice: nil} = runtime, _variant), do: %{runtime | legal_moves: []}

  defp recalc_legal_moves(%{turn_color: color} = runtime, variant)
       when color in [:white, :black] do
    %{runtime | legal_moves: RaceCore.legal_moves(runtime, variant, color)}
  end

  defp recalc_legal_moves(runtime, _variant), do: runtime

  defp phase(%{match: %{is_over: true}}), do: "terminal"
  defp phase(%{dice: nil}), do: "roll"
  defp phase(_runtime), do: "move"

  defp legal_actions(%{match: %{is_over: true}}), do: []
  defp legal_actions(%{dice: nil}), do: [%{"type" => "special", "id" => "ROLL"}]

  defp legal_actions(runtime) do
    move_actions = Enum.map(runtime.legal_moves || [], &move_action/1)

    case move_actions do
      [] -> [%{"type" => "special", "id" => "CONFIRM"}]
      actions -> Enum.sort_by(actions, &move_sort_key/1)
    end
  end

  defp move_action(move) do
    %{
      "type" => "move",
      "from" => Map.get(move, :from),
      "to" => Map.get(move, :to),
      "die" => Map.get(move, :die),
      "count" => Map.get(move, :count, 1),
      "hit" => Map.get(move, :hit?, false)
    }
  end

  defp choose_move(%{"runtime" => runtime, "variant" => variant}, moves) do
    color = runtime.turn_color

    Enum.max_by(moves, fn action ->
      score_action(runtime, variant, color, action)
    end)
  end

  defp score_action(runtime, variant, color, action) do
    case RaceCore.move(runtime, variant, color, move_payload(action)) do
      {:ok, next_runtime} ->
        terminal_score(next_runtime, color) ||
          position_score(next_runtime.board, color) +
            action_bonus(runtime, next_runtime, color, action)

      {:error, _reason} ->
        @negative_terminal
    end
  end

  defp move_payload(action) do
    %{
      "from" => action["from"],
      "to" => action["to"]
    }
  end

  defp terminal_score(runtime, color) do
    color = Atom.to_string(color)

    case get_in(runtime, [:match, :winner]) do
      nil -> nil
      ^color -> @positive_terminal
      _other -> @negative_terminal
    end
  end

  defp position_score(board, color) do
    score_side(board, color) - score_side(board, opposite(color))
  end

  defp score_side(board, color) do
    borne_off = get_in(board, [:outside, color]) || 0
    on_bar = get_in(board, [:bar, color]) || 0

    borne_off * 40 -
      on_bar * 25 -
      pip_count(board, color) +
      home_checkers(board, color) * 8 +
      made_points(board, color) * 7 -
      blots(board, color) * 5
  end

  defp action_bonus(before_runtime, after_runtime, color, action) do
    source_count = pieces_at(before_runtime.board, action["from"], color)
    destination = action["to"]
    before_destination_count = pieces_at(before_runtime.board, destination, color)
    after_destination_count = pieces_at(after_runtime.board, destination, color)

    0
    |> add_if(action["hit"] == true, 30)
    |> add_if(destination == "home", 45)
    |> add_if(source_count == 1, 12)
    |> add_if(before_destination_count == 1 and after_destination_count >= 2, 10)
    |> add_if(destination != "home" and after_destination_count == 1, -4)
  end

  defp add_if(score, true, delta), do: score + delta
  defp add_if(score, false, _delta), do: score

  defp pip_count(board, color) do
    color
    |> route()
    |> Enum.with_index(1)
    |> Enum.reduce((get_in(board, [:bar, color]) || 0) * 25, fn {point, distance}, acc ->
      acc + pieces_at(board, point, color) * distance
    end)
  end

  defp home_checkers(board, color) do
    color
    |> route()
    |> Enum.take(-6)
    |> Enum.reduce(0, fn point, acc -> acc + pieces_at(board, point, color) end)
  end

  defp made_points(board, color) do
    Enum.count(0..23, &(pieces_at(board, &1, color) >= 2))
  end

  defp blots(board, color) do
    Enum.count(0..23, &(pieces_at(board, &1, color) == 1))
  end

  defp pieces_at(_board, "bar", _color), do: 1
  defp pieces_at(_board, "home", _color), do: 0
  defp pieces_at(board, point, color), do: get_in(board, [:points, Access.at(point), color]) || 0

  defp route(:white), do: Enum.to_list(23..0//-1)
  defp route(:black), do: Enum.to_list(0..23)

  defp opposite(:white), do: :black
  defp opposite(:black), do: :white

  defp special?(%{"type" => "special", "id" => id}, id), do: true
  defp special?(_action, _id), do: false

  defp move_sort_key(action) do
    {space_key(action["from"]), space_key(action["to"]), action["die"] || 0}
  end

  defp space_key("bar"), do: -1
  defp space_key("home"), do: 24
  defp space_key(value), do: value
end
