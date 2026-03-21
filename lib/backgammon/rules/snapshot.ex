defmodule Backgammon.Rules.Snapshot do
  alias Backgammon.Rules.RaceCore

  def build(engine) do
    variant = engine.variant
    board = engine.board
    current_player = player_for_color(engine, engine.turn_color)

    %{
      "variant" => %{
        "id" => variant.id,
        "title" => variant.title,
        "rule_name" => variant.title
      },
      "status" => Atom.to_string(engine.status),
      "players" => %{
        "host" => serialize_player(engine.players.host),
        "guest" => serialize_player(engine.players.guest)
      },
      "board" => %{
        "points" => serialize_points(board.points),
        "bar" => stringify_keys(board.bar),
        "outside" => stringify_keys(board.outside)
      },
      "turn" =>
        if current_player do
          %{
            "number" => engine.turn_number,
            "color" => Atom.to_string(engine.turn_color),
            "player_name" => current_player.name
          }
        else
          nil
        end,
      "dice" => serialize_dice(engine.dice),
      "legal_moves" => Enum.map(engine.legal_moves, &serialize_move/1),
      "pending_match_options" => engine.pending_match_options,
      "pending_turn_decision" => engine.pending_turn_decision,
      "opening_roll" => serialize_opening_roll(engine),
      "match" => %{
        "is_over" => engine.match.is_over,
        "score" => stringify_keys(engine.match.score),
        "length" => engine.match.length,
        "winner" => engine.match.winner,
        "winner_kind" => engine.match.winner_kind,
        "results" => serialize_nested(engine.match.results || []),
        "options" => serialize_nested(engine.match.options || %{})
      },
      "trictrac" => serialize_trictrac(engine.trictrac),
      "ui_actions" => %{
        "can_roll" =>
          engine.status == :playing and is_nil(engine.dice) and not engine.match.is_over and
            (not is_nil(engine.turn_color) or not is_nil(serialize_opening_roll(engine))),
        "can_undo" =>
          engine.status == :playing and not is_nil(engine.dice) and engine.history != [],
        "can_confirm" => engine.status == :playing and not is_nil(engine.dice),
        "can_submit_match_options" => not is_nil(engine.pending_match_options),
        "can_submit_turn_decision" => not is_nil(engine.pending_turn_decision),
        "can_reset" => true
      }
    }
  end

  defp serialize_player(nil), do: nil

  defp serialize_player(player) do
    %{
      "id" => player.id,
      "name" => player.name,
      "color" => Atom.to_string(player.color)
    }
  end

  defp serialize_points(points) do
    Enum.with_index(points)
    |> Enum.map(fn {point, index} ->
      %{
        "index" => index,
        "pieces" => serialize_point_pieces(point)
      }
    end)
  end

  defp serialize_point_pieces(point) do
    point = RaceCore.normalize_tapa_point(point)
    white = point.white || 0
    black = point.black || 0
    top = Map.get(point, :top)

    cond do
      white > 0 and black > 0 and top == :white ->
        List.duplicate("black", black) ++ List.duplicate("white", white)

      white > 0 and black > 0 and top == :black ->
        List.duplicate("white", white) ++ List.duplicate("black", black)

      true ->
        List.duplicate("white", white) ++ List.duplicate("black", black)
    end
  end

  defp serialize_dice(nil), do: nil

  defp serialize_dice(dice) do
    %{
      "values" => dice.values,
      "moves" => dice.moves,
      "moves_left" => dice.moves_left,
      "moves_played" => dice.moves_played
    }
  end

  defp serialize_move(move) do
    %{
      "from" => move.from,
      "to" => move.to,
      "die" => move.die,
      "count" => Map.get(move, :count),
      "coin_mode" => Map.get(move, :coin_mode),
      "dice_used" => Map.get(move, :dice_used),
      "via" => Map.get(move, :via),
      "sequence" => Map.get(move, :sequence)
    }
  end

  defp stringify_keys(map) do
    Enum.into(map, %{}, fn {key, value} -> {Atom.to_string(key), value} end)
  end

  defp serialize_trictrac(nil), do: nil

  defp serialize_trictrac(trictrac) when is_map(trictrac) do
    Enum.into(trictrac, %{}, fn
      {:score, entries} ->
        {"score", Enum.map(entries, &serialize_nested/1)}

      {key, value} ->
        {to_string(key), serialize_nested(value)}
    end)
  end

  defp serialize_nested(value) when is_struct(value) do
    value
    |> Map.from_struct()
    |> serialize_nested()
  end

  defp serialize_nested(value) when is_map(value) do
    Enum.into(value, %{}, fn {key, inner} -> {to_string(key), serialize_nested(inner)} end)
  end

  defp serialize_nested(value) when is_atom(value) and value not in [true, false, nil],
    do: Atom.to_string(value)

  defp serialize_nested(value) when is_list(value), do: Enum.map(value, &serialize_nested/1)
  defp serialize_nested(value), do: value

  defp player_for_color(_engine, nil), do: nil

  defp player_for_color(engine, color),
    do: Enum.find([engine.players.host, engine.players.guest], &(&1 && &1.color == color))

  defp serialize_opening_roll(engine) do
    case opening_roll_payload(engine) do
      nil -> nil
      payload -> serialize_nested(payload)
    end
  end

  defp opening_roll_payload(%{variant: %{id: "brade"}} = engine) do
    if engine.status == :playing and is_nil(engine.turn_color) and is_nil(engine.dice) and
         engine.turn_number == 0 and
         engine.match.results == [] do
      %{
        pending: true,
        prompt: "Roll one die to decide who starts. The lower die starts.",
        order: :lowest,
        rolls:
          get_in(engine.runtime, [:variant_state, :brade_teker_rolls]) ||
            %{white: nil, black: nil}
      }
    end
  end

  defp opening_roll_payload(%{variant: %{id: id}} = engine)
       when id in ["tourne_case", "dames_rabattues"] do
    if engine.status == :playing and is_nil(engine.turn_color) and is_nil(engine.dice) and
         engine.turn_number == 0 do
      %{
        pending: true,
        prompt: "Roll one die to decide who starts. The higher die starts.",
        order: :highest,
        rolls:
          get_in(engine.runtime, [:variant_state, :opening_rolls]) || %{white: nil, black: nil}
      }
    end
  end

  defp opening_roll_payload(_engine), do: nil
end
