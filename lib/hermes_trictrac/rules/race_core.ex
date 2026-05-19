defmodule HermesTrictrac.Rules.RaceCore do
  alias HermesTrictrac.Rules.{Dice, EnglishBackgammon, Registry}
  alias HermesTrictrac.Rules.Trictrac.Classique
  @point_count 24
  @tavli_legs ["backgammon", "tapa", "jacquet"]
  @tapa_talon %{"white" => 23, "black" => 0, white: 23, black: 0}

  def new(variant) do
    board = %{
      points: Enum.map(0..(@point_count - 1), fn _ -> %{white: 0, black: 0} end),
      bar: %{white: 0, black: 0},
      outside: %{white: 0, black: 0}
    }

    board =
      Enum.reduce(variant.start_points, board, fn {color, entries}, acc ->
        Enum.reduce(entries, acc, fn {point, count}, inner ->
          update_in(inner, [:points, Access.at(point), color], &((&1 || 0) + count))
        end)
      end)

    %{
      board: board,
      trictrac: trictrac_state(variant),
      pending_turn_decision: nil,
      variant_state:
        Map.merge(
          %{
            options: %{},
            last_roll_double: false,
            results: [],
            game_number: 1,
            starter: :white,
            game_just_reset: false,
            brade_turn_cause: brade_turn_causes(),
            brade_teker_rolls: brade_teker_rolls()
          },
          Map.merge(tavli_variant_state(variant), jacquet_variant_state(variant))
        )
    }
  end

  def apply_opening_setup(runtime, variant, starter) do
    effective_variant = active_variant(runtime, variant)
    runtime = put_variant_state(runtime, :starter, starter)

    runtime =
      case Map.get(effective_variant, :opening_setup) do
        :sbaraglino_strict ->
          apply_sbaraglio_starter(runtime, starter)

        _ ->
          runtime
      end

    case Map.get(effective_variant, :opening_setup) do
      :garanguet_seed_turn ->
        seed_garanguet_opening_turn(runtime, effective_variant, starter)

      _ ->
        runtime
    end
  end

  def active_variant(runtime, %{id: "tavli"}) do
    runtime
    |> tavli_active_leg_id()
    |> Registry.fetch!()
  end

  def active_variant(_runtime, variant), do: variant

  def pending_options(%{id: "trictrac_aecrire"}) do
    %{
      "rule" => "RuleFrTrictracAEcrire",
      "options" => [
        %{"key" => "margotEnabled", "label" => "Enable Margot", "defaultValue" => false}
      ]
    }
  end

  def pending_options(%{id: "trictrac_combine"}) do
    %{
      "rule" => "RuleFrTrictracCombine",
      "options" => [
        %{"key" => "margotEnabled", "label" => "Enable Margot", "defaultValue" => false}
      ]
    }
  end

  def pending_options(%{id: "toc"}) do
    %{
      "rule" => "Toc",
      "options" => [
        %{
          "key" => "holeTarget",
          "label" => "Target Holes",
          "defaultValue" => "1",
          "choices" =>
            Enum.map(1..12, fn value ->
              %{"value" => Integer.to_string(value), "label" => Integer.to_string(value)}
            end)
        },
        %{
          "key" => "doublesMode",
          "label" => "Double Scoring",
          "defaultValue" => "on",
          "choices" => [
            %{"value" => "on", "label" => "Doubles On"},
            %{"value" => "off", "label" => "Doubles Off"}
          ]
        },
        %{
          "key" => "margotEnabled",
          "label" => "Enable Margot",
          "defaultValue" => false
        }
      ]
    }
  end

  def pending_options(%{id: "brade"}) do
    %{
      "rule" => "Brade",
      "options" => [
        %{
          "key" => "matchLength",
          "label" => "Best Of",
          "defaultValue" => "5",
          "choices" => [
            %{"value" => "3", "label" => "Best of 3"},
            %{"value" => "5", "label" => "Best of 5"},
            %{"value" => "7", "label" => "Best of 7"}
          ]
        }
      ]
    }
  end

  def pending_options(_variant), do: nil

  def submit_options(runtime, variant, options) do
    normalized = normalize_options(variant, options)

    runtime =
      update_in(runtime, [:variant_state, :options], fn current ->
        Map.merge(current, normalized)
      end)

    runtime =
      case variant.id do
        "toc" ->
          runtime
          |> put_in([:trictrac, :score], [%{points: 0, trous: 0}, %{points: 0, trous: 0}])
          |> put_in([:match, :length], String.to_integer(normalized["holeTarget"] || "1"))

        "brade" ->
          put_in(runtime, [:match, :length], String.to_integer(normalized["matchLength"] || "5"))

        "tavli" ->
          put_in(runtime, [:match, :length], String.to_integer(normalized["tavliTarget"] || "7"))

        _ ->
          runtime
      end

    runtime
  end

  def roll(runtime, variant, color) do
    effective_variant = active_variant(runtime, variant)

    if runtime.dice do
      {:error, "Dice already rolled."}
    else
      values = roll_values(effective_variant)
      moves_left = build_moves_left(effective_variant, values)

      runtime =
        runtime
        |> Map.put(:turn_moves, [])
        |> put_in([:variant_state, :last_roll_double], Enum.uniq(values) |> length() == 1)
        |> maybe_put_garanguet_force_mode(effective_variant, values)
        |> Map.put(:dice, %{
          values: values,
          moves: moves_left,
          moves_left: moves_left,
          moves_played: []
        })

      {:ok, recalc_legal_moves(runtime, effective_variant, color)}
    end
  end

  def undo(runtime, variant, color) do
    case runtime.history do
      [previous | rest] ->
        restored = Map.put(previous, :history, rest)
        {:ok, recalc_legal_moves(restored, active_variant(restored, variant), color)}

      [] ->
        {:error, "Nothing to undo."}
    end
  end

  def confirm(runtime, variant, color) do
    effective_variant = active_variant(runtime, variant)

    if is_nil(runtime.dice) do
      {:error, "No rolled dice to confirm."}
    else
      runtime =
        runtime
        |> maybe_finish_game(variant, effective_variant, color)
        |> remember_completed_turn_moves()
        |> queue_turn_decision_if_needed(effective_variant, color)
        |> advance_turn_if_needed(effective_variant, color)

      {:ok, runtime}
    end
  end

  defp confirm_sequence_match?(candidate, move) do
    sequence = move_value(move, "sequence")
    die = move_value(move, "die")
    dice_used = move_value(move, "dice_used")

    candidate.from == move["from"] and candidate.to == move["to"] and
      (is_nil(sequence) or Map.get(candidate, :sequence) == sequence) and
      (is_nil(die) or Map.get(candidate, :die) == die) and
      (is_nil(dice_used) or
         Map.get(candidate, :dice_used, [Map.get(candidate, :die)]) == dice_used)
  end

  defp move_value(move, key) do
    Map.get(move, key, Map.get(move, String.to_atom(key)))
  end

  def move(runtime, variant, color, move) do
    effective_variant = active_variant(runtime, variant)

    legal_move =
      Enum.find(runtime.legal_moves, fn candidate ->
        confirm_sequence_match?(candidate, move)
      end)

    if is_nil(legal_move) do
      {:error, "Invalid move."}
    else
      next =
        runtime
        |> push_history()
        |> apply_move(effective_variant, color, legal_move)
        |> Map.put(:last_move, last_move_payload(color, legal_move))
        |> append_turn_move(color, legal_move)
        |> recalc_legal_moves(effective_variant, color)
        |> maybe_end_game_on_move(variant, effective_variant, color)

      {:ok, next}
    end
  end

  defp last_move_payload(color, move) do
    %{
      color: Atom.to_string(color),
      from: move.from,
      to: move.to,
      die: move.die,
      dice_used: Map.get(move, :dice_used),
      sequence: Map.get(move, :sequence),
      via: Map.get(move, :via)
    }
  end

  defp append_turn_move(runtime, color, move) do
    payload = last_move_payload(color, move)
    Map.update(runtime, :turn_moves, [payload], fn moves -> (moves || []) ++ [payload] end)
  end

  def submit_turn_decision(runtime, variant, color, decision) do
    payload = runtime.pending_turn_decision

    cond do
      is_nil(payload) ->
        {:error, "No pending turn decision."}

      decision not in payload["choices"] ->
        {:error, "Invalid turn decision."}

      turn_decision_answered?(runtime, color, payload["key"]) ->
        {:error, "Turn decision already resolved."}

      true ->
        runtime = mark_turn_decision_answered(runtime, color, payload["key"])

        updated =
          case {variant.id, decision} do
            {id, "tenir"} when id in ["trictrac_aecrire", "trictrac_combine"] ->
              runtime
              |> Map.put(:pending_turn_decision, nil)
              |> put_in([:variant_state, :last_trous_gained], 0)
              |> Map.put(:dice, nil)
              |> Map.put(:legal_moves, [])
              |> Map.put(:history, [])
              |> Map.put(:turn_color, opposite(runtime.turn_color))
              |> Map.put(:turn_number, runtime.turn_number + 1)

            {id, "s'en aller"} when id in ["trictrac_aecrire", "trictrac_combine"] ->
              fresh = new(variant)
              current = score_entry(runtime.trictrac, color)

              score =
                put_score(runtime.trictrac, color, %{
                  current
                  | trous: (current.trous || 0) + 1
                })

              runtime
              |> Map.put(:board, fresh.board)
              |> Map.put(:trictrac, score)
              |> Map.put(:pending_turn_decision, nil)
              |> put_in([:variant_state, :last_trous_gained], 0)
              |> Map.put(:dice, nil)
              |> Map.put(:legal_moves, [])
              |> Map.put(:history, [])
              |> Map.put(:turn_color, color)
              |> Map.put(:turn_number, runtime.turn_number + 1)

            _ ->
              Map.put(runtime, :pending_turn_decision, nil)
          end

        {:ok, updated}
    end
  end

  def legal_moves(runtime, %{family: :trictrac} = variant, color) do
    Classique.legal_moves(runtime, variant, color)
  end

  def legal_moves(runtime, %{id: "backgammon"} = variant, color) do
    EnglishBackgammon.legal_moves(
      runtime,
      variant,
      color,
      &raw_generic_legal_moves/4,
      &apply_branch_move/4
    )
  end

  def legal_moves(runtime, %{id: "jacquet"} = variant, color) do
    jacquet_legal_moves(runtime, variant, color)
  end

  def legal_moves(runtime, %{id: "tavli"} = variant, color) do
    legal_moves(runtime, active_variant(runtime, variant), color)
  end

  def legal_moves(runtime, variant, color) do
    generic_legal_moves(runtime, variant, color)
  end

  def generic_legal_moves(runtime, variant, color) do
    moves_left = if runtime.dice, do: runtime.dice.moves_left, else: []

    raw_generic_legal_moves(runtime.board, variant, color, moves_left)
    |> filter_race_forced_usage(runtime, variant, color, moves_left)
  end

  def raw_generic_legal_moves(board, variant, color, moves_left) do
    if uses_bar?(variant) and board.bar[color] > 0 do
      bar_moves(board, variant, color, moves_left)
    else
      point_moves(board, variant, color, moves_left)
    end
    |> Enum.uniq_by(fn move ->
      {move.from, move.to, move.die, Map.get(move, :dice_used), Map.get(move, :via)}
    end)
  end

  defp roll_values(%{turn_dice_mode: :three_dice}) do
    Dice.roll_three()
  end

  defp roll_values(%{turn_dice_mode: :garanguet_three}) do
    Dice.roll_three()
  end

  defp roll_values(%{turn_dice_mode: :two_plus_virtual_six}) do
    [d1, d2] = Dice.roll_two()
    [6, d1, d2]
  end

  defp roll_values(%{doubles_mode: :two_dice}) do
    Dice.roll_two()
  end

  defp roll_values(_variant) do
    [d1, d2] = Dice.roll_two()

    if d1 == d2 do
      [d1, d2, d1, d2]
    else
      [d1, d2]
    end
  end

  defp build_moves_left(%{id: "tourne_case"}, values) do
    [Enum.min(values)]
  end

  defp build_moves_left(%{id: "garanguet"}, values), do: garanguet_expand_moves(values)

  defp build_moves_left(_variant, values), do: values

  defp recalc_legal_moves(runtime, variant, color) do
    %{runtime | legal_moves: legal_moves(runtime, variant, color)}
  end

  defp remember_completed_turn_moves(runtime) do
    case Map.get(runtime, :turn_moves) do
      moves when is_list(moves) and moves != [] -> Map.put(runtime, :last_turn_moves, moves)
      _ -> runtime
    end
  end

  defp push_history(runtime) do
    snapshot =
      runtime
      |> Map.drop([:history, :legal_moves])
      |> Map.put(:legal_moves, [])

    update(runtime.history, &[snapshot | &1])
    |> then(&%{runtime | history: &1})
  end

  defp update(value, fun), do: fun.(value)

  defp point_moves(board, variant, color, moves_left) do
    route = route_for(variant, color)

    0..(@point_count - 1)
    |> Enum.flat_map(fn point ->
      source_count = source_piece_count(board, variant, color, point)

      if source_count > 0 do
        case Enum.find_index(route, &(&1 == point)) do
          nil ->
            []

          route_index ->
            single_moves =
              Enum.flat_map(moves_left, fn die ->
                case destination_for(
                       variant,
                       route,
                       board,
                       color,
                       point,
                       route_index,
                       die,
                       source_count
                     ) do
                  {:ok, destination, hit?, count, coin_mode} ->
                    [
                      %{
                        from: point,
                        to: destination,
                        die: die,
                        hit?: hit?,
                        count: count,
                        coin_mode: coin_mode
                      }
                    ]

                  :error ->
                    []
                end
              end)

            single_moves ++
              trictrac_combined_moves(
                board,
                variant,
                color,
                point,
                route_index,
                source_count,
                moves_left,
                route
              )
        end
      else
        []
      end
    end)
    |> filter_trictrac_coin_priority(variant)
  end

  defp bar_moves(board, variant, color, moves_left) do
    route = route_for(variant, color)

    Enum.flat_map(moves_left, fn die ->
      entry_index = die - 1

      if entry_index < length(route) do
        destination = Enum.at(route, entry_index)

        case bar_entry_allowed?(board, variant, color, destination) do
          {:ok, hit?, count} ->
            [%{from: "bar", to: destination, die: die, hit?: hit?, count: count}]

          :error ->
            []
        end
      else
        []
      end
    end)
  end

  defp destination_for(variant, route, board, color, source, route_index, die, source_count) do
    destination_index = route_index + die

    cond do
      destination_index < length(route) ->
        raw_destination = Enum.at(route, destination_index)

        case landing_allowed?(board, variant, color, source, source_count, raw_destination) do
          {:ok, hit?, count} ->
            {:ok, raw_destination, hit?, count, :normal}

          :error ->
            :error
        end

      variant.can_bear_off and can_bear_off?(board, variant, color) and
          bear_off_allowed?(board, variant, color, route_index, die) ->
        {:ok, "home", false,
         bear_off_count(board, variant, color, Enum.at(route, route_index), source_count),
         :normal}

      true ->
        :error
    end
  end

  defp landing_allowed?(
         board,
         %{id: "backgammon"} = variant,
         color,
         source,
         source_count,
         destination
       ) do
    EnglishBackgammon.landing_allowed(
      board,
      color,
      source,
      source_count,
      destination,
      fn point, who -> pieces_at(board, point, who) end,
      fn source_point, source_pieces, landing_point ->
        move_count_for_landing(board, variant, color, source_point, source_pieces, landing_point)
      end
    )
  end

  defp landing_allowed?(board, %{id: "tapa"} = variant, color, source, source_count, destination),
    do: tapa_landing_result(board, variant, color, source, source_count, destination)

  defp landing_allowed?(
         board,
         %{id: "jacquet"} = variant,
         color,
         source,
         source_count,
         destination
       ) do
    if pieces_at(board, destination, opposite(color)) > 0 do
      :error
    else
      with {:ok, count} <-
             move_count_for_landing(board, variant, color, source, source_count, destination) do
        next_board =
          board
          |> remove_piece(color, source, count)
          |> add_piece(color, destination, count)

        if jacquet_position_allowed?(next_board, variant, color) do
          {:ok, false, count}
        else
          :error
        end
      end
    end
  end

  defp landing_allowed?(
         board,
         %{id: "brade"} = variant,
         color,
         source,
         source_count,
         destination
       ),
       do: brade_landing_result(board, variant, color, source, source_count, destination)

  defp landing_allowed?(board, %{can_hit: false}, color, source, source_count, destination) do
    if pieces_at(board, destination, opposite(color)) > 0 do
      :error
    else
      with {:ok, count} <-
             move_count_for_landing(
               board,
               %{orientation: :split_home},
               color,
               source,
               source_count,
               destination
             ) do
        {:ok, false, count}
      end
    end
  end

  defp landing_allowed?(board, variant, color, source, source_count, destination) do
    if forbidden_coin_destination?(board, variant, color, destination) do
      :error
    else
      opp_count = pieces_at(board, destination, opposite(color))

      cond do
        opp_count >= 2 ->
          :error

        opp_count == 1 ->
          with {:ok, count} <-
                 move_count_for_landing(board, variant, color, source, source_count, destination) do
            {:ok, true, count}
          end

        true ->
          with {:ok, count} <-
                 move_count_for_landing(board, variant, color, source, source_count, destination) do
            {:ok, false, count}
          end
      end
    end
  end

  defp bar_entry_allowed?(board, %{id: "backgammon"} = variant, color, destination),
    do: landing_allowed?(board, variant, color, "bar", 1, destination)

  defp bar_entry_allowed?(board, %{id: "brade"} = variant, color, destination),
    do: brade_landing_result(board, variant, color, "bar", 1, destination)

  defp bar_entry_allowed?(board, %{id: "tapa"} = variant, color, destination) do
    if board.bar[color] > 0 do
      tapa_landing_result(board, variant, color, "bar", 1, destination)
    else
      :error
    end
  end

  defp bar_entry_allowed?(board, variant, color, destination),
    do: landing_allowed?(board, variant, color, "bar", 1, destination)

  defp brade_landing_result(board, variant, color, source, source_count, destination) do
    own_count = pieces_at(board, destination, color)

    if source == "bar" and own_count > 0 do
      :error
    else
      opp_count = pieces_at(board, destination, opposite(color))

      cond do
        own_count > 0 and not brade_case_allowed_on_point?(variant, color, destination) ->
          :error

        opp_count >= 2 and brade_can_explode?(board, color, source, destination) ->
          with {:ok, count} <-
                 move_count_for_landing(board, variant, color, source, source_count, destination) do
            {:ok, true, count}
          end

        opp_count >= 2 ->
          :error

        opp_count == 1 ->
          with {:ok, count} <-
                 move_count_for_landing(board, variant, color, source, source_count, destination) do
            {:ok, true, count}
          end

        true ->
          with {:ok, count} <-
                 move_count_for_landing(board, variant, color, source, source_count, destination) do
            {:ok, false, count}
          end
      end
    end
  end

  defp brade_case_allowed_on_point?(variant, color, destination) do
    route = route_for(variant, color)

    case Enum.find_index(route, &(&1 == destination)) do
      nil ->
        false

      11 ->
        true

      route_index ->
        route_index >= 12
    end
  end

  defp can_bear_off?(board, variant, color) do
    route = route_for(variant, color)
    unsafe_points = Enum.drop(route, -6)

    Enum.all?(unsafe_points, fn point -> pieces_at(board, point, color) == 0 end)
  end

  defp bear_off_allowed?(board, %{id: "brade"}, color, route_index, die) do
    route = route_for(%{orientation: :split_home}, color)
    current_point = Enum.at(route, route_index)
    home_zone = Enum.take(route, -6)
    furthest_point = Enum.find(home_zone, &(pieces_at(board, &1, color) > 0))
    distance = length(route) - route_index

    cond do
      is_nil(furthest_point) ->
        false

      current_point != furthest_point ->
        false

      true ->
        distance <= die
    end
  end

  defp bear_off_allowed?(board, %{id: "backgammon"} = variant, color, route_index, die) do
    route = route_for(variant, color)

    EnglishBackgammon.bear_off_allowed?(
      route,
      route_index,
      die,
      &(pieces_at(board, &1, color) > 0)
    )
  end

  defp bear_off_allowed?(board, variant, color, route_index, die) do
    route = route_for(variant, color)
    current_point = Enum.at(route, route_index)
    home_zone = Enum.take(route, -6)
    furthest_point = Enum.find(home_zone, &(pieces_at(board, &1, color) > 0))
    distance = length(route) - route_index

    cond do
      is_nil(furthest_point) ->
        false

      distance == die ->
        true

      distance < die ->
        current_point == furthest_point

      true ->
        false
    end
  end

  defp apply_move(runtime, %{id: "tapa"} = variant, color, move) do
    dice_used = Map.get(move, :dice_used, [move.die])

    board = tapa_apply_move(runtime.board, color, move)

    dice =
      runtime.dice
      |> update_in([:moves_left], &remove_all_used(&1, dice_used))
      |> update_in([:moves_played], &(&1 ++ dice_used))

    %{runtime | board: board, dice: dice}
    |> recalc_legal_moves(variant, color)
  end

  defp apply_move(runtime, %{id: "jacquet"} = variant, color, move) do
    count = Map.get(move, :count, 1)
    dice_used = Map.get(move, :dice_used, [move.die])

    board =
      runtime.board
      |> remove_piece(color, move.from, count)
      |> add_piece(color, move.to, count)

    dice =
      runtime.dice
      |> update_in([:moves_left], &remove_all_used(&1, dice_used))
      |> update_in([:moves_played], &(&1 ++ dice_used))

    runtime
    |> Map.put(:board, board)
    |> Map.put(:dice, dice)
    |> jacquet_update_after_move(variant, color, move)
  end

  defp apply_move(runtime, %{id: "brade"}, color, move) do
    before_board = runtime.board
    count = Map.get(move, :count, 1)
    dice_used = Map.get(move, :dice_used, [move.die])

    board =
      before_board
      |> remove_piece(color, move.from, count)
      |> maybe_hit_brade(color, move)
      |> add_piece(color, move.to, count)

    dice =
      runtime.dice
      |> update_in([:moves_left], &remove_all_used(&1, dice_used))
      |> update_in([:moves_played], &(&1 ++ dice_used))

    runtime =
      %{runtime | board: board, dice: dice}

    put_in(
      runtime,
      [:variant_state, :brade_turn_cause, color],
      update_brade_turn_cause(
        brade_turn_cause(runtime.variant_state, color),
        before_board,
        board,
        color,
        move
      )
    )
  end

  defp apply_move(runtime, _variant, color, move) do
    count = Map.get(move, :count, 1)
    dice_used = Map.get(move, :dice_used, [move.die])

    board =
      runtime.board
      |> remove_piece(color, move.from, count)
      |> maybe_hit(color, move)
      |> add_piece(color, move.to, count)

    dice =
      runtime.dice
      |> update_in([:moves_left], &remove_all_used(&1, dice_used))
      |> update_in([:moves_played], &(&1 ++ dice_used))

    %{runtime | board: board, dice: dice}
  end

  defp maybe_hit_brade(board, color, %{to: destination, hit?: true}) when destination != "home" do
    opp = opposite(color)
    opp_count = pieces_at(board, destination, opp)

    board
    |> put_in([:points, Access.at(destination), opp], 0)
    |> update_in([:bar, opp], &(&1 + max(opp_count, 1)))
  end

  defp maybe_hit_brade(board, _color, _move), do: board

  defp maybe_hit(board, color, %{to: "home"} = move),
    do: maybe_intermediate_hit(board, color, move)

  defp maybe_hit(board, color, move) do
    board =
      case move do
        %{to: destination, hit?: true} ->
          hit_one(board, color, destination)

        _ ->
          board
      end

    maybe_intermediate_hit(board, color, move)
  end

  defp maybe_intermediate_hit(board, color, move) do
    case Map.get(move, :intermediate_hit) do
      nil -> board
      destination -> hit_one(board, color, destination)
    end
  end

  defp hit_one(board, color, destination) do
    opp = opposite(color)

    board
    |> put_in([:points, Access.at(destination), opp], 0)
    |> update_in([:bar, opp], &(&1 + 1))
  end

  defp trictrac_combined_moves(
         _board,
         _variant,
         _color,
         _point,
         _route_index,
         _source_count,
         _moves_left,
         _route
       ),
       do: []

  defp remove_piece(board, color, "bar", count),
    do: update_in(board, [:bar, color], &max(&1 - count, 0))

  defp remove_piece(board, color, point, count),
    do: update_in(board, [:points, Access.at(point), color], &max((&1 || 0) - count, 0))

  defp add_piece(board, color, "home", count),
    do: update_in(board, [:outside, color], &(&1 + count))

  defp add_piece(board, color, point, count),
    do: update_in(board, [:points, Access.at(point), color], &((&1 || 0) + count))

  defp pieces_at(board, point, color), do: get_in(board, [:points, Access.at(point), color]) || 0

  defp route_for(%{orientation: :ascending}, :white), do: Enum.to_list(0..23)
  defp route_for(%{orientation: :ascending}, :black), do: Enum.to_list(23..0//-1)
  defp route_for(%{orientation: :split_home}, :white), do: Enum.to_list(23..0//-1)
  defp route_for(%{orientation: :split_home}, :black), do: Enum.to_list(0..23)
  defp route_for(%{orientation: :parallel}, _color), do: Enum.to_list(23..0//-1)
  defp route_for(%{orientation: :parallel_toward_1}, _color), do: Enum.to_list(0..23)
  defp route_for(%{orientation: :parallel_toward_24}, _color), do: Enum.to_list(23..0//-1)
  defp route_for(%{orientation: :jacquet_parallel}, :white), do: Enum.to_list(23..0//-1)
  defp route_for(%{orientation: :jacquet_parallel}, :black), do: [0 | Enum.to_list(23..1//-1)]

  defp maybe_finish_game(runtime, %{score_mode: :tavli} = variant, effective_variant, color) do
    case tavli_leg_outcome(runtime, effective_variant, color) do
      nil ->
        runtime

      outcome ->
        settle_tavli_leg(runtime, variant, effective_variant, outcome)
    end
  end

  defp maybe_finish_game(runtime, _variant, effective_variant, color) do
    winner_kind = detect_winner_kind(runtime, effective_variant, color)

    if winner_kind do
      settle_game(runtime, effective_variant, color, winner_kind)
    else
      runtime
    end
  end

  defp detect_winner_kind(runtime, variant, color) do
    cond do
      variant.score_mode == :plein and plein_complete?(runtime.board, variant, color) ->
        "plein"

      variant.score_mode == :brade ->
        brade_winner_kind(runtime.board, variant.total_pieces, color, runtime.variant_state)

      variant.score_mode == :sbaraglio ->
        sbaraglio_winner_kind(runtime.board, variant, color)

      variant.score_mode == :garanguet ->
        garanguet_winner_kind(runtime.board, variant, color)

      runtime.board.outside[color] >= variant.total_pieces ->
        "race"

      true ->
        nil
    end
  end

  defp plein_complete?(board, variant, color) do
    route_for(variant, color)
    |> Enum.take(-6)
    |> Enum.all?(fn point ->
      pieces_at(board, point, color) >= 2
    end)
  end

  defp sbaraglio_winner_kind(board, variant, color) do
    if board.outside[color] >= variant.total_pieces do
      opp = opposite(color)

      if board.bar[opp] > 0 or checkers_outside_home_quadrant?(board, variant, opp) do
        "marcio"
      else
        "race"
      end
    end
  end

  defp checkers_outside_home_quadrant?(board, variant, color) do
    home_quadrant =
      variant
      |> route_for(color)
      |> Enum.take(-6)
      |> MapSet.new()

    Enum.any?(0..(@point_count - 1), fn point ->
      not MapSet.member?(home_quadrant, point) and pieces_at(board, point, color) > 0
    end)
  end

  defp settle_game(runtime, variant, color, winner_kind) do
    opp = opposite(color)

    case variant.score_mode do
      :toc ->
        delta =
          if runtime.variant_state.last_roll_double and
               runtime.variant_state.options["doublesMode"] == "on", do: 2, else: 1

        target = String.to_integer(runtime.variant_state.options["holeTarget"] || "1")
        score = Map.update!(runtime.match.score, color, &(&1 + delta))
        over? = score[color] >= target

        runtime
        |> put_in([:match, :score], score)
        |> put_in([:match, :winner], if(over?, do: Atom.to_string(color), else: nil))
        |> put_in([:match, :winner_kind], if(over?, do: "toc_holes", else: winner_kind))
        |> put_in([:match, :is_over], over?)
        |> put_in([:trictrac, :score], [
          %{points: 0, trous: score.white},
          %{points: 0, trous: score.black}
        ])
        |> maybe_reset_for_next_game(variant, over?, opp)

      :brade ->
        delta = brade_points_for_kind(winner_kind)

        results =
          runtime.variant_state.results ++
            [%{winner: Atom.to_string(color), points: delta, kind: winner_kind}]

        game_limit = String.to_integer(runtime.variant_state.options["matchLength"] || "5")
        over? = length(results) >= game_limit

        score = Map.update!(runtime.match.score, color, &(&1 + delta))

        runtime
        |> put_in([:match, :score], score)
        |> put_in([:match, :winner], if(over?, do: leading_color(score, results), else: nil))
        |> put_in([:match, :winner_kind], if(over?, do: "brade_match", else: winner_kind))
        |> put_in([:match, :is_over], over?)
        |> put_in([:match, :results], results)
        |> put_in([:variant_state, :results], results)
        |> maybe_reset_for_next_game(variant, over?, opp)

      _ ->
        runtime
        |> put_in([:match, :winner], Atom.to_string(color))
        |> put_in([:match, :winner_kind], winner_kind)
        |> put_in([:match, :is_over], true)
    end
  end

  defp settle_tavli_leg(runtime, _variant, effective_variant, outcome) do
    results = (runtime.match.results || []) ++ [tavli_result_entry(effective_variant, outcome)]
    score = apply_tavli_awards(runtime.match.score, outcome.awards)
    target = tavli_target(runtime)
    over? = tavli_match_over?(score, target)
    winner = if(over?, do: Atom.to_string(leading_score_color(score)), else: nil)

    runtime =
      runtime
      |> put_in([:match, :score], score)
      |> put_in([:match, :results], results)
      |> put_in([:match, :winner], winner)
      |> put_in([:match, :winner_kind], if(over?, do: "tavli_match", else: nil))
      |> put_in([:match, :is_over], over?)

    if over? do
      runtime
    else
      reset_tavli_leg(runtime, tavli_next_leg(effective_variant.id))
    end
  end

  defp tavli_leg_outcome(runtime, %{id: "backgammon"} = variant, color) do
    tavli_bear_off_outcome(runtime.board, variant, color, true)
  end

  defp tavli_leg_outcome(runtime, %{id: "jacquet"} = variant, color) do
    tavli_bear_off_outcome(runtime.board, variant, color, false)
  end

  defp tavli_leg_outcome(runtime, %{id: "tapa"} = variant, color) do
    cond do
      tapa_mutual_last_checker_draw?(runtime.board) ->
        %{winner: nil, kind: "draw", awards: %{white: 1, black: 1}}

      tapa_talon_gammon_color(runtime.board) == :white ->
        %{winner: :white, kind: "talon_gammon", awards: %{white: 2, black: 0}}

      tapa_talon_gammon_color(runtime.board) == :black ->
        %{winner: :black, kind: "talon_gammon", awards: %{white: 0, black: 2}}

      true ->
        tavli_bear_off_outcome(runtime.board, variant, color, false)
    end
  end

  defp tavli_leg_outcome(_runtime, _variant, _color), do: nil

  defp tavli_bear_off_outcome(board, variant, color, include_bar?) do
    if board.outside[color] >= variant.total_pieces do
      loser = opposite(color)
      kind = tavli_bear_off_kind(board, variant, loser, include_bar?)
      %{winner: color, kind: kind, awards: tavli_awards(color, kind)}
    end
  end

  defp tavli_bear_off_kind(board, variant, loser, include_bar?) do
    cond do
      board.outside[loser] > 0 ->
        "single"

      tavli_backgammon?(board, variant, loser, include_bar?) ->
        "backgammon"

      true ->
        "gammon"
    end
  end

  defp tavli_backgammon?(board, variant, loser, include_bar?) do
    (include_bar? and board.bar[loser] > 0) or
      checker_in_home_quadrant?(board, variant, loser, opposite(loser))
  end

  defp checker_in_home_quadrant?(board, variant, color, winner) do
    variant
    |> route_for(winner)
    |> Enum.take(-6)
    |> Enum.any?(fn point -> pieces_at(board, point, color) > 0 end)
  end

  defp tavli_awards(winner, "single"), do: score_award(winner, 1)
  defp tavli_awards(winner, "gammon"), do: score_award(winner, 2)
  defp tavli_awards(winner, "talon_gammon"), do: score_award(winner, 2)
  defp tavli_awards(winner, "backgammon"), do: score_award(winner, 3)
  defp tavli_awards(_winner, "draw"), do: %{white: 1, black: 1}

  defp score_award(:white, points), do: %{white: points, black: 0}
  defp score_award(:black, points), do: %{white: 0, black: points}

  defp apply_tavli_awards(score, awards) do
    %{
      white: (score.white || 0) + (awards.white || 0),
      black: (score.black || 0) + (awards.black || 0)
    }
  end

  defp tavli_result_entry(variant, outcome) do
    %{
      leg: variant.id,
      winner: if(outcome.winner, do: Atom.to_string(outcome.winner), else: nil),
      kind: outcome.kind,
      awards: outcome.awards
    }
  end

  defp tavli_target(runtime) do
    (runtime.variant_state.options["tavliTarget"] || "7")
    |> String.to_integer()
  end

  defp tavli_match_over?(score, target) do
    (score.white >= target or score.black >= target) and score.white != score.black
  end

  defp leading_score_color(score) when score.white > score.black, do: :white
  defp leading_score_color(_score), do: :black

  defp tavli_next_leg(current_leg) do
    current_index = Enum.find_index(@tavli_legs, &(&1 == current_leg)) || 0
    Enum.at(@tavli_legs, rem(current_index + 1, length(@tavli_legs)))
  end

  defp reset_tavli_leg(runtime, next_leg_id) do
    next_variant = Registry.fetch!(next_leg_id)
    fresh = new(next_variant)

    runtime
    |> Map.put(:board, fresh.board)
    |> Map.put(:trictrac, fresh.trictrac)
    |> Map.put(:pending_turn_decision, nil)
    |> Map.put(:dice, nil)
    |> Map.put(:legal_moves, [])
    |> Map.put(:history, [])
    |> Map.put(:turn_color, nil)
    |> Map.put(:turn_number, 0)
    |> Map.put(
      :variant_state,
      tavli_variant_state_for_leg(runtime.variant_state, fresh.variant_state, next_leg_id)
    )
  end

  defp tavli_variant_state_for_leg(current_state, fresh_state, leg_id) do
    fresh_state
    |> Map.put(:options, Map.get(current_state, :options, %{}))
    |> Map.put(:tavli_active_leg, leg_id)
    |> Map.put(:game_just_reset, true)
  end

  defp tapa_mutual_last_checker_draw?(board) do
    tapa_last_checker_pinned_on_talon?(board, :white) and
      tapa_last_checker_pinned_on_talon?(board, :black)
  end

  defp tapa_talon_gammon_color(board) do
    cond do
      tapa_last_checker_pinned_on_talon?(board, :white) and
          not tapa_last_checker_pinned_on_talon?(board, :black) ->
        :black

      tapa_last_checker_pinned_on_talon?(board, :black) and
          not tapa_last_checker_pinned_on_talon?(board, :white) ->
        :white

      true ->
        nil
    end
  end

  defp tapa_last_checker_pinned_on_talon?(board, color) do
    talon = Map.fetch!(@tapa_talon, color)
    point = board.points |> Enum.at(talon) |> normalize_tapa_point()

    pieces_at(board, talon, color) == 1 and tapa_top_owner(point) == opposite(color)
  end

  defp brade_winner_kind(board, total_pieces, color, variant_state \\ %{}) do
    cond do
      board.outside[color] >= total_pieces ->
        if board.bar[opposite(color)] > 0, do: "home_munk", else: "home"

      brade_pattern?(board, color, :stack) ->
        if board.bar[opposite(color)] > 0, do: "stack_munk", else: "stack"

      brade_pattern?(board, color, :stair) ->
        if board.bar[opposite(color)] > 0, do: "stair_munk", else: "stair"

      brade_pattern?(board, color, :double_crown) ->
        if board.bar[opposite(color)] > 0, do: "double_crown_munk", else: "double_crown"

      brade_pattern?(board, color, :crown) ->
        if board.bar[opposite(color)] > 0, do: "crown_munk", else: "crown"

      brade_jan?(board, color) and brade_sprangjan?(variant_state, color, board) ->
        "sprangjan"

      brade_jan?(board, color) ->
        "jan"

      true ->
        nil
    end
  end

  defp filter_race_forced_usage(moves, _runtime, %{id: "garanguet"}, _color, _moves_left)
       when moves == [],
       do: []

  defp filter_race_forced_usage(moves, runtime, %{id: "garanguet"} = variant, color, moves_left) do
    mode =
      get_in(runtime, [:variant_state, :garanguet_force_mode]) || garanguet_force_mode(moves_left)

    scored_moves =
      Enum.map(moves, fn move ->
        used = Map.get(move, :dice_used, [move.die])
        next_board = apply_branch_move(runtime.board, variant, color, move)
        remaining = remove_all_used(moves_left, used)

        best_branch =
          next_board
          |> enumerate_garanguet_branches(variant, color, remaining, used)
          |> garanguet_best_branch(mode)

        %{move: move, branch: best_branch}
      end)

    best_key =
      scored_moves
      |> Enum.map(&garanguet_branch_key(&1.branch, mode))
      |> Enum.max(fn -> nil end)

    scored_moves
    |> Enum.filter(&(garanguet_branch_key(&1.branch, mode) == best_key))
    |> Enum.map(& &1.move)
    |> Enum.uniq_by(fn move ->
      {move.from, move.to, move.die, Map.get(move, :dice_used), Map.get(move, :via)}
    end)
  end

  defp filter_race_forced_usage(moves, _runtime, _variant, _color, _moves_left) when moves == [],
    do: []

  defp filter_race_forced_usage(moves, runtime, variant, color, moves_left) do
    scored_moves =
      Enum.map(moves, fn move ->
        used = Map.get(move, :dice_used, [move.die])
        next_board = apply_branch_move(runtime.board, variant, color, move)
        branch_reduction = reduction_for_move(variant, color, move)

        branches =
          if race_branch_finished?(next_board, variant, color) do
            [%{played: length(used), reduction: branch_reduction, can_finish?: true}]
          else
            remaining = remove_all_used(moves_left, used)

            enumerate_race_branches(
              next_board,
              variant,
              color,
              remaining,
              length(used),
              branch_reduction
            )
          end

        best = best_branch(branches, variant)

        %{
          move: move,
          played: best.played,
          reduction: best.reduction,
          finishes?: best.can_finish?
        }
      end)

    finishing_moves = Enum.filter(scored_moves, & &1.finishes?)

    continuing_moves =
      scored_moves
      |> Enum.reject(& &1.finishes?)
      |> keep_maximum_played()
      |> keep_minimum_reduction(variant)
      |> keep_highest_single_die()

    (continuing_moves ++ finishing_moves)
    |> Enum.map(& &1.move)
    |> Enum.uniq_by(fn move ->
      {move.from, move.to, move.die, Map.get(move, :dice_used), Map.get(move, :via)}
    end)
  end

  defp enumerate_race_branches(board, variant, color, moves_left, played, reduction) do
    moves = raw_generic_legal_moves(board, variant, color, moves_left)

    cond do
      moves_left == [] ->
        [%{played: played, reduction: reduction, can_finish?: false}]

      moves == [] ->
        [%{played: played, reduction: reduction, can_finish?: false}]

      true ->
        Enum.flat_map(moves, fn move ->
          used = Map.get(move, :dice_used, [move.die])
          next_board = apply_branch_move(board, variant, color, move)
          next_played = played + length(used)
          next_reduction = reduction + reduction_for_move(variant, color, move)

          if race_branch_finished?(next_board, variant, color) do
            [%{played: next_played, reduction: next_reduction, can_finish?: true}]
          else
            remaining = remove_all_used(moves_left, used)

            enumerate_race_branches(
              next_board,
              variant,
              color,
              remaining,
              next_played,
              next_reduction
            )
          end
        end)
    end
  end

  defp best_branch([], _variant), do: %{played: 0, reduction: 0, can_finish?: false}

  defp best_branch([branch | rest], variant) do
    Enum.reduce(rest, branch, fn candidate, best ->
      if better_branch?(candidate, best, variant), do: candidate, else: best
    end)
  end

  defp better_branch?(%{can_finish?: true}, %{can_finish?: false}, _variant), do: true
  defp better_branch?(%{can_finish?: false}, %{can_finish?: true}, _variant), do: false

  defp better_branch?(left, right, _variant) when left.can_finish? and right.can_finish? do
    left.played < right.played or
      (left.played == right.played and left.reduction < right.reduction)
  end

  defp better_branch?(left, right, %{id: "brade"}) do
    left.played > right.played or
      (left.played == right.played and left.reduction < right.reduction)
  end

  defp better_branch?(left, right, _variant), do: left.played > right.played

  defp keep_maximum_played([]), do: []

  defp keep_maximum_played(scored_moves) do
    max_played = scored_moves |> Enum.map(& &1.played) |> Enum.max(fn -> 0 end)
    Enum.filter(scored_moves, &(&1.played == max_played))
  end

  defp keep_minimum_reduction(scored_moves, %{id: "brade"}) do
    min_reduction = scored_moves |> Enum.map(& &1.reduction) |> Enum.min(fn -> 0 end)
    Enum.filter(scored_moves, &(&1.reduction == min_reduction))
  end

  defp keep_minimum_reduction(scored_moves, _variant), do: scored_moves

  defp keep_highest_single_die([]), do: []

  defp keep_highest_single_die(scored_moves) do
    max_played = scored_moves |> Enum.map(& &1.played) |> Enum.max(fn -> 0 end)

    if max_played == 1 do
      highest_die = scored_moves |> Enum.map(& &1.move.die) |> Enum.max(fn -> nil end)
      Enum.filter(scored_moves, &(&1.move.die == highest_die))
    else
      scored_moves
    end
  end

  defp garanguet_best_branch([], _mode), do: garanguet_branch([])

  defp garanguet_best_branch([branch | rest], mode) do
    Enum.reduce(rest, branch, fn candidate, best ->
      if garanguet_branch_key(candidate, mode) > garanguet_branch_key(best, mode),
        do: candidate,
        else: best
    end)
  end

  defp enumerate_garanguet_branches(_board, _variant, _color, [], used_dice),
    do: [garanguet_branch(used_dice)]

  defp enumerate_garanguet_branches(board, variant, color, moves_left, used_dice) do
    moves = raw_generic_legal_moves(board, variant, color, moves_left)

    if moves == [] do
      [garanguet_branch(used_dice)]
    else
      Enum.flat_map(moves, fn move ->
        used = Map.get(move, :dice_used, [move.die])
        next_board = apply_branch_move(board, variant, color, move)
        remaining = remove_all_used(moves_left, used)
        enumerate_garanguet_branches(next_board, variant, color, remaining, used_dice ++ used)
      end)
    end
  end

  defp garanguet_branch(used_dice) do
    combo = Enum.sort(used_dice, :desc)
    %{played: length(combo), pips: Enum.sum(combo), combo: combo}
  end

  defp garanguet_branch_key(branch, :max_pips), do: {branch.pips, branch.played, branch.combo}
  defp garanguet_branch_key(branch, _mode), do: {branch.played, branch.combo}

  defp garanguet_winner_kind(board, variant, color) do
    if board.outside[color] >= variant.total_pieces do
      loser = opposite(color)

      cond do
        board.outside[loser] > 0 ->
          "single"

        garanguet_checker_in_jan_de_retour?(board, variant, loser) ->
          "triple"

        true ->
          "double"
      end
    end
  end

  defp garanguet_checker_in_jan_de_retour?(board, variant, color) do
    variant
    |> route_for(color)
    |> Enum.take(-6)
    |> Enum.any?(fn point -> pieces_at(board, point, color) > 0 end)
  end

  defp race_branch_finished?(board, %{id: "brade", total_pieces: total_pieces}, color) do
    not is_nil(brade_winner_kind(board, total_pieces, color))
  end

  defp race_branch_finished?(_board, _variant, _color), do: false

  defp reduction_for_move(%{id: "brade"}, color, %{from: point, to: "home", die: die})
       when is_integer(point) do
    route = route_for(%{orientation: :split_home}, color)

    case Enum.find_index(route, &(&1 == point)) do
      nil ->
        0

      route_index ->
        distance = length(route) - route_index
        max(die - distance, 0)
    end
  end

  defp reduction_for_move(_variant, _color, _move), do: 0

  defp apply_branch_move(board, %{id: "tapa"}, color, move) do
    tapa_apply_move(board, color, move)
  end

  defp apply_branch_move(board, %{id: "brade"}, color, move) do
    board
    |> remove_piece(color, move.from, Map.get(move, :count, 1))
    |> maybe_hit_brade(color, move)
    |> add_piece(color, move.to, Map.get(move, :count, 1))
  end

  defp apply_branch_move(board, _variant, color, move) do
    board
    |> remove_piece(color, move.from, Map.get(move, :count, 1))
    |> maybe_hit(color, move)
    |> add_piece(color, move.to, Map.get(move, :count, 1))
  end

  defp maybe_end_game_on_move(
         runtime,
         %{score_mode: :tavli} = variant,
         %{id: "tapa"} = effective_variant,
         color
       ) do
    case tavli_leg_outcome(runtime, effective_variant, color) do
      nil ->
        runtime

      outcome ->
        runtime
        |> Map.put(:dice, nil)
        |> Map.put(:legal_moves, [])
        |> settle_tavli_leg(variant, effective_variant, outcome)
    end
  end

  defp maybe_end_game_on_move(runtime, _top_variant, %{score_mode: :garanguet} = variant, color) do
    case garanguet_winner_kind(runtime.board, variant, color) do
      nil ->
        runtime

      winner_kind ->
        runtime
        |> Map.put(:dice, nil)
        |> Map.put(:legal_moves, [])
        |> settle_game(variant, color, winner_kind)
    end
  end

  defp maybe_end_game_on_move(runtime, _top_variant, %{id: "brade"} = variant, color) do
    case brade_winner_kind(runtime.board, variant.total_pieces, color, runtime.variant_state) do
      nil ->
        runtime

      winner_kind ->
        runtime
        |> Map.put(:dice, nil)
        |> Map.put(:legal_moves, [])
        |> settle_game(variant, color, winner_kind)
    end
  end

  defp maybe_end_game_on_move(runtime, _top_variant, _effective_variant, _color), do: runtime

  defp brade_pattern?(board, color, :stack) do
    pieces_at(board, brade_last_point(color), color) >= 15 and board.outside[color] == 0
  end

  defp brade_pattern?(board, color, :stair) do
    [p22, p23, p24] = brade_last_three(color)

    pieces_at(board, p24, color) >= 7 and pieces_at(board, p23, color) >= 5 and
      pieces_at(board, p22, color) >= 3 and board.outside[color] == 0
  end

  defp brade_pattern?(board, color, :double_crown) do
    brade_last_three(color)
    |> Enum.all?(&(pieces_at(board, &1, color) >= 5)) and board.outside[color] == 0
  end

  defp brade_pattern?(board, color, :crown) do
    brade_last_five(color)
    |> Enum.all?(&(pieces_at(board, &1, color) >= 3)) and board.outside[color] == 0
  end

  defp brade_jan?(board, color) do
    victim = opposite(color)
    board.bar[victim] > brade_jan_capacity(board, victim)
  end

  defp brade_reentry_slots(board, :white) do
    Enum.count(18..23, fn point ->
      pieces_at(board, point, :white) == 0 and pieces_at(board, point, :black) <= 1
    end)
  end

  defp brade_reentry_slots(board, :black) do
    Enum.count(0..5, fn point ->
      pieces_at(board, point, :black) == 0 and pieces_at(board, point, :white) <= 1
    end)
  end

  defp brade_jan_capacity(board, :white) do
    Enum.count(18..23, fn point ->
      pieces_at(board, point, :white) == 0
    end)
  end

  defp brade_jan_capacity(board, :black) do
    Enum.count(0..5, fn point ->
      pieces_at(board, point, :black) == 0
    end)
  end

  defp brade_entry_points(:white), do: 18..23
  defp brade_entry_points(:black), do: 0..5

  defp brade_last_point(:white), do: 0
  defp brade_last_point(:black), do: 23
  defp brade_last_three(:white), do: [2, 1, 0]
  defp brade_last_three(:black), do: [21, 22, 23]
  defp brade_last_five(:white), do: [4, 3, 2, 1, 0]
  defp brade_last_five(:black), do: [19, 20, 21, 22, 23]

  defp brade_points_for_kind("sprangjan"), do: 6
  defp brade_points_for_kind("jan"), do: 4

  defp brade_points_for_kind(kind)
       when kind in ["crown_munk", "double_crown_munk", "stair_munk", "stack_munk"], do: 3

  defp brade_points_for_kind("home_munk"), do: 2
  defp brade_points_for_kind(kind) when kind in ["crown", "double_crown", "stair", "stack"], do: 2
  defp brade_points_for_kind(_kind), do: 1

  defp forbidden_coin_destination?(_board, _variant, _color, _destination), do: false

  defp move_count_for_landing(_board, _variant, _color, _source, _source_count, _destination),
    do: {:ok, 1}

  defp bear_off_count(_board, _variant, _color, _source, _source_count), do: 1

  defp filter_trictrac_coin_priority(moves, _variant), do: moves

  def normalize_tapa_point(point) do
    white = Map.get(point, :white, 0)
    black = Map.get(point, :black, 0)
    top = Map.get(point, :top)

    normalized_top =
      cond do
        white > 0 and black == 0 ->
          :white

        black > 0 and white == 0 ->
          :black

        white > 0 and black > 0 and top in [:white, :black] ->
          top

        true ->
          nil
      end

    Map.put(point, :top, normalized_top)
  end

  defp source_piece_count(board, %{id: "tapa"}, color, point) do
    point_data = board.points |> Enum.at(point) |> normalize_tapa_point()

    case tapa_top_owner(point_data) do
      ^color ->
        pieces_at(board, point, color)

      nil ->
        if Map.get(point_data, opposite(color), 0) > 0 and Map.get(point_data, color, 0) > 0 do
          0
        else
          pieces_at(board, point, color)
        end

      _ ->
        0
    end
  end

  defp source_piece_count(board, _variant, color, point), do: pieces_at(board, point, color)

  defp tapa_landing_result(board, variant, color, source, source_count, destination) do
    if tapa_blocked_destination?(board, color, destination) do
      :error
    else
      with {:ok, count} <-
             move_count_for_landing(board, variant, color, source, source_count, destination) do
        {:ok, false, count}
      end
    end
  end

  defp tapa_blocked_destination?(board, color, destination) do
    point_data = board.points |> Enum.at(destination) |> normalize_tapa_point()
    opp = opposite(color)
    own = Map.get(point_data, color, 0)
    enemy = Map.get(point_data, opp, 0)
    top = tapa_top_owner(point_data)

    cond do
      enemy == 0 ->
        false

      enemy == 1 and own == 0 and top == opp ->
        false

      top == color ->
        false

      true ->
        true
    end
  end

  defp tapa_top_owner(point), do: point |> normalize_tapa_point() |> Map.get(:top)

  defp tapa_remove_piece(board, color, "bar", count), do: remove_piece(board, color, "bar", count)

  defp tapa_remove_piece(board, color, point, count) do
    updated =
      board
      |> remove_piece(color, point, count)

    point_data = updated.points |> Enum.at(point) |> normalize_tapa_point()
    put_in(updated, [:points, Access.at(point)], point_data)
  end

  defp tapa_add_piece(board, color, "home", count), do: add_piece(board, color, "home", count)

  defp tapa_add_piece(board, color, point, count) do
    updated = add_piece(board, color, point, count)

    point_data =
      updated.points |> Enum.at(point) |> normalize_tapa_point() |> Map.put(:top, color)

    put_in(updated, [:points, Access.at(point)], point_data)
  end

  defp tapa_apply_move(board, color, move) do
    count = Map.get(move, :count, 1)

    board
    |> tapa_remove_piece(color, move.from, count)
    |> tapa_add_piece(color, move.to, count)
  end

  defp brade_can_explode?(board, color, "bar", _destination) do
    not brade_explosion_blocked?(board, color) and
      board.bar[color] > brade_reentry_slots(board, color)
  end

  defp brade_can_explode?(board, color, source, destination) when is_integer(source) do
    opp = opposite(color)

    if brade_explosion_blocked?(board, color) do
      false
    else
      route = route_for(%{orientation: :split_home}, color)
      source_index = Enum.find_index(route, &(&1 == source))
      destination_index = Enum.find_index(route, &(&1 == destination))

      cond do
        is_nil(source_index) or is_nil(destination_index) or destination_index <= source_index ->
          false

        true ->
          blocked_run =
            route
            |> Enum.slice((source_index + 1)..-1//1)
            |> Enum.take_while(&(pieces_at(board, &1, opp) >= 2))

          length(blocked_run) > 5 and destination in blocked_run
      end
    end
  end

  defp brade_can_explode?(_board, _color, _source, _destination), do: false

  defp brade_explosion_blocked?(board, color) do
    brade_junker?(board, color) or brade_junker?(board, opposite(color))
  end

  defp brade_junker?(board, color) do
    board.outside[color] >= 14 and total_on_board(board, color) + board.bar[color] <= 1
  end

  defp brade_inward_explosion?(board, color, %{to: destination, hit?: true})
       when is_integer(destination) do
    victim = opposite(color)
    pieces_at(board, destination, victim) >= 2 and destination in brade_entry_points(victim)
  end

  defp brade_inward_explosion?(_board, _color, _move), do: false

  defp brade_move_cause(board, color, move) do
    if brade_inward_explosion?(board, color, move), do: :inward_explosion, else: nil
  end

  defp brade_turn_cause(variant_state, color) do
    variant_state
    |> Map.get(:brade_turn_cause, brade_turn_causes())
    |> Map.get(color)
    |> normalize_brade_turn_cause()
  end

  defp brade_turn_causes do
    %{white: brade_empty_turn_cause(), black: brade_empty_turn_cause()}
  end

  defp brade_teker_rolls do
    %{white: nil, black: nil}
  end

  defp brade_empty_turn_cause do
    %{last_inward_signature: nil, qualifying_signature: nil}
  end

  defp normalize_brade_turn_cause(%{} = cause) do
    Map.merge(
      brade_empty_turn_cause(),
      Map.take(cause, [:last_inward_signature, :qualifying_signature])
    )
  end

  defp normalize_brade_turn_cause(_legacy), do: brade_empty_turn_cause()

  defp update_brade_turn_cause(existing, before_board, after_board, color, move) do
    existing = normalize_brade_turn_cause(existing)

    case brade_move_cause(before_board, color, move) do
      :inward_explosion ->
        signature = brade_board_signature(after_board)

        %{
          existing
          | last_inward_signature: signature,
            qualifying_signature:
              if(brade_jan?(after_board, color),
                do: signature,
                else: existing.qualifying_signature
              )
        }

      _ ->
        existing
    end
  end

  defp brade_sprangjan?(variant_state, color, board) do
    brade_turn_cause(variant_state, color).qualifying_signature == brade_board_signature(board)
  end

  defp brade_board_signature(board) do
    :erlang.phash2({board.points, board.bar, board.outside})
  end

  defp total_on_board(board, color) do
    Enum.reduce(board.points, 0, fn point, acc -> acc + Map.get(point, color, 0) end)
  end

  defp apply_sbaraglio_starter(runtime, :white) do
    runtime
    |> update_in([:board, :points, Access.at(11), :white], &max((&1 || 0) - 1, 0))
    |> update_in([:board, :points, Access.at(9), :white], &((&1 || 0) + 1))
  end

  defp apply_sbaraglio_starter(runtime, :black) do
    runtime
    |> update_in([:board, :points, Access.at(12), :black], &max((&1 || 0) - 1, 0))
    |> update_in([:board, :points, Access.at(14), :black], &((&1 || 0) + 1))
  end

  defp put_variant_state(runtime, key, value) do
    variant_state = Map.get(runtime, :variant_state) || %{}
    Map.put(runtime, :variant_state, Map.put(variant_state, key, value))
  end

  defp maybe_reset_for_next_game(runtime, variant, false, starter) do
    fresh = new(variant)

    runtime
    |> Map.put(:board, fresh.board)
    |> Map.put(:dice, nil)
    |> Map.put(:legal_moves, [])
    |> Map.put(:history, [])
    |> Map.put(:status, :playing)
    |> Map.put(:turn_color, starter)
    |> Map.put(:turn_number, runtime.turn_number + 1)
    |> put_in([:variant_state, :starter], starter)
    |> put_in([:variant_state, :game_just_reset], true)
    |> put_in([:variant_state, :last_roll_double], false)
    |> put_in([:variant_state, :brade_turn_cause], brade_turn_causes())
    |> put_in([:variant_state, :brade_teker_rolls], brade_teker_rolls())
    |> put_in([:trictrac], fresh.trictrac || runtime.trictrac)
  end

  defp maybe_reset_for_next_game(runtime, _variant, true, _starter), do: runtime

  defp leading_color(score, results) do
    cond do
      score.white > score.black -> "white"
      score.black > score.white -> "black"
      true -> tie_break(results)
    end
  end

  defp tie_break(results) do
    strengths =
      results
      |> Enum.group_by(& &1.winner)
      |> Enum.into(%{}, fn {winner, winner_results} ->
        ranked =
          winner_results
          |> Enum.map(fn result -> brade_tie_strength(result.kind, result.points) end)
          |> Enum.sort(:desc)

        {winner, ranked}
      end)

    compare_strength_lists(Map.get(strengths, "white", []), Map.get(strengths, "black", []))
  end

  defp brade_tie_strength(kind, fallback_points) do
    order = %{
      "sprangjan" => 12,
      "jan" => 11,
      "crown_munk" => 10,
      "double_crown_munk" => 10,
      "stair_munk" => 10,
      "stack_munk" => 10,
      "crown" => 9,
      "double_crown" => 9,
      "stair" => 9,
      "stack" => 9,
      "home_munk" => 8,
      "home" => 7,
      "race" => 7,
      "plein" => 9
    }

    Map.get(order, kind, fallback_points)
  end

  defp compare_strength_lists([], []), do: "white"

  defp compare_strength_lists([left | _rest_left], [right | _rest_right]) when left > right,
    do: "white"

  defp compare_strength_lists([left | _rest_left], [right | _rest_right]) when right > left,
    do: "black"

  defp compare_strength_lists([_ | rest_left], [_ | rest_right]),
    do: compare_strength_lists(rest_left, rest_right)

  defp compare_strength_lists([left | _], []), do: if(left > 0, do: "white", else: "black")
  defp compare_strength_lists([], [right | _]), do: if(right > 0, do: "black", else: "white")

  defp advance_turn_if_needed(runtime, _variant, _color) do
    cond do
      runtime.match.is_over ->
        runtime
        |> Map.put(:dice, nil)
        |> Map.put(:legal_moves, [])
        |> put_in([:variant_state, :last_trous_gained], 0)

      runtime.pending_turn_decision ->
        runtime
        |> Map.put(:dice, nil)
        |> Map.put(:legal_moves, [])
        |> Map.put(:history, [])
        |> put_in([:variant_state, :last_trous_gained], 0)

      get_in(runtime, [:variant_state, :game_just_reset]) ->
        runtime
        |> Map.put(:dice, nil)
        |> Map.put(:legal_moves, [])
        |> Map.put(:history, [])
        |> put_in([:variant_state, :last_trous_gained], 0)
        |> put_in([:variant_state, :game_just_reset], false)

      true ->
        runtime
        |> Map.put(:dice, nil)
        |> Map.put(:legal_moves, [])
        |> Map.put(:history, [])
        |> Map.put(:turn_color, opposite(runtime.turn_color))
        |> Map.put(:turn_number, runtime.turn_number + 1)
        |> put_in([:variant_state, :last_trous_gained], 0)
        |> put_in([:variant_state, :brade_turn_cause], brade_turn_causes())
    end
  end

  defp queue_turn_decision_if_needed(runtime, %{id: id}, color)
       when id in ["trictrac_aecrire", "trictrac_combine"] do
    if runtime.match.is_over do
      %{runtime | dice: nil, legal_moves: []}
    else
      gained = get_in(runtime, [:variant_state, :last_trous_gained]) || 0

      if gained > 0 and not turn_decision_answered?(runtime, color, "reprise") do
        Map.put(runtime, :pending_turn_decision, %{
          "key" => "reprise",
          "prompt" => "Choose how to continue the marque.",
          "choices" => ["tenir", "s'en aller"]
        })
      else
        runtime
      end
    end
  end

  defp queue_turn_decision_if_needed(runtime, _variant, _color), do: runtime

  defp turn_decision_answered?(runtime, color, key) do
    signature = turn_decision_signature(runtime, color, key)

    runtime
    |> get_in([:variant_state, :answered_turn_decisions])
    |> Kernel.||([])
    |> Enum.member?(signature)
  end

  defp mark_turn_decision_answered(runtime, color, key) do
    signature = turn_decision_signature(runtime, color, key)
    existing = get_in(runtime, [:variant_state, :answered_turn_decisions]) || []

    put_in(
      runtime,
      [:variant_state, :answered_turn_decisions],
      Enum.take(Enum.uniq([signature | existing]), 64)
    )
  end

  defp turn_decision_signature(runtime, color, key) do
    "#{runtime.turn_number}:#{normalize_color(color)}:#{key}"
  end

  defp normalize_color(color) when is_atom(color), do: Atom.to_string(color)
  defp normalize_color(color), do: to_string(color)

  defp trictrac_state(%{id: id})
       when id in ["trictrac_classique", "trictrac_aecrire", "trictrac_combine", "toc", "plein"] do
    %{score: [%{points: 0, trous: 0}, %{points: 0, trous: 0}]}
  end

  defp trictrac_state(_variant), do: nil

  defp normalize_options(variant, options) do
    base =
      options
      |> Enum.into(%{}, fn {key, value} -> {to_string(key), normalize_value(value)} end)

    case variant.id do
      "toc" ->
        base
        |> Map.put_new("holeTarget", "1")
        |> Map.put_new("doublesMode", "on")

      "brade" ->
        Map.put_new(base, "matchLength", "5")

      "tavli" ->
        Map.put_new(base, "tavliTarget", "7")

      _ ->
        base
    end
  end

  defp normalize_value(value) when is_boolean(value), do: value
  defp normalize_value(value) when is_integer(value), do: Integer.to_string(value)
  defp normalize_value(value), do: value

  defp tavli_variant_state(%{id: "tavli"}) do
    %{tavli_active_leg: hd(@tavli_legs)}
  end

  defp tavli_variant_state(_variant), do: %{}

  defp jacquet_variant_state(%{id: "jacquet"}) do
    %{
      jacquet_postillon_entered: %{white: false, black: false},
      jacquet_courier_points: %{white: nil, black: nil}
    }
  end

  defp jacquet_variant_state(_variant), do: %{}

  defp uses_bar?(%{id: id}) when id in ["tapa", "jacquet", "garanguet"], do: false
  defp uses_bar?(_variant), do: true

  defp maybe_put_garanguet_force_mode(runtime, %{id: "garanguet"}, values) do
    put_in(runtime, [:variant_state, :garanguet_force_mode], garanguet_force_mode(values))
  end

  defp maybe_put_garanguet_force_mode(runtime, _variant, _values), do: runtime

  defp garanguet_expand_moves(values) do
    counts = Enum.frequencies(values)

    cond do
      map_size(counts) == 1 ->
        List.duplicate(hd(values), 6)

      map_size(counts) == 2 ->
        {repeated, isolated} = garanguet_doublet_parts(counts)

        if isolated < repeated do
          List.duplicate(repeated, 4) ++ [isolated]
        else
          Enum.sort(values, :desc)
        end

      true ->
        Enum.sort(values, :desc)
    end
  end

  defp garanguet_force_mode(values) do
    counts = Enum.frequencies(values)

    cond do
      map_size(counts) == 1 ->
        :max_pips

      map_size(counts) == 2 ->
        {repeated, isolated} = garanguet_doublet_parts(counts)
        if isolated < repeated, do: :max_pips, else: :max_dice

      true ->
        :max_dice
    end
  end

  defp garanguet_doublet_parts(counts) do
    repeated =
      counts
      |> Enum.find_value(fn {value, count} -> if count == 2, do: value end)

    isolated =
      counts
      |> Enum.find_value(fn {value, count} -> if count == 1, do: value end)

    {repeated, isolated}
  end

  defp seed_garanguet_opening_turn(runtime, variant, starter) do
    case roll(runtime, variant, starter) do
      {:ok, seeded} -> seeded
      _ -> runtime
    end
  end

  defp tavli_active_leg_id(runtime) do
    get_in(runtime, [:variant_state, :tavli_active_leg]) || hd(@tavli_legs)
  end

  defp jacquet_legal_moves(runtime, variant, color) do
    moves_left = if runtime.dice, do: runtime.dice.moves_left, else: []

    cond do
      moves_left == [] ->
        []

      runtime.board.bar[color] > 0 ->
        []

      jacquet_postillon_entered?(runtime, color) ->
        generic_legal_moves(runtime, variant, color)

      true ->
        source = jacquet_courier_source(runtime, variant, color)

        runtime.board
        |> jacquet_single_step_candidates(variant, color, source, moves_left)
        |> jacquet_filter_postillon_usage(runtime, variant, color, moves_left)
    end
  end

  defp jacquet_single_step_candidates(board, variant, color, source, moves_left) do
    route = route_for(variant, color)
    source_count = source_piece_count(board, variant, color, source)

    cond do
      source_count <= 0 ->
        []

      true ->
        case Enum.find_index(route, &(&1 == source)) do
          nil ->
            []

          route_index ->
            Enum.flat_map(moves_left, fn die ->
              case destination_for(
                     variant,
                     route,
                     board,
                     color,
                     source,
                     route_index,
                     die,
                     source_count
                   ) do
                {:ok, destination, hit?, count, coin_mode} ->
                  [
                    %{
                      from: source,
                      to: destination,
                      die: die,
                      hit?: hit?,
                      count: count,
                      coin_mode: coin_mode
                    }
                  ]

                :error ->
                  []
              end
            end)
            |> Enum.uniq_by(fn move ->
              {move.from, move.to, move.die, Map.get(move, :dice_used), Map.get(move, :via)}
            end)
        end
    end
  end

  defp jacquet_filter_postillon_usage([], _runtime, _variant, _color, _moves_left), do: []

  defp jacquet_filter_postillon_usage(candidates, runtime, variant, color, moves_left) do
    candidates
    |> Enum.map(fn move ->
      remaining = remove_all_used(moves_left, [move.die])
      next_runtime = jacquet_preview_runtime_after_move(runtime, variant, color, move)

      %{
        move: move,
        played: 1 + jacquet_followup_count(next_runtime, variant, color, remaining)
      }
    end)
    |> keep_maximum_played()
    |> keep_highest_single_die()
    |> Enum.map(& &1.move)
  end

  defp jacquet_followup_count(_runtime, _variant, _color, []), do: 0

  defp jacquet_followup_count(runtime, variant, color, moves_left) do
    cond do
      jacquet_postillon_entered?(runtime, color) ->
        enumerate_race_branches(runtime.board, variant, color, moves_left, 0, 0)
        |> best_branch(variant)
        |> Map.get(:played, 0)

      true ->
        source = jacquet_courier_source(runtime, variant, color)

        candidates =
          jacquet_single_step_candidates(runtime.board, variant, color, source, moves_left)

        if candidates == [] do
          0
        else
          candidates
          |> Enum.map(fn move ->
            remaining = remove_all_used(moves_left, [move.die])
            next_runtime = jacquet_preview_runtime_after_move(runtime, variant, color, move)
            1 + jacquet_followup_count(next_runtime, variant, color, remaining)
          end)
          |> Enum.max(fn -> 0 end)
        end
    end
  end

  defp jacquet_preview_runtime_after_move(runtime, variant, color, move) do
    runtime
    |> Map.put(:board, apply_branch_move(runtime.board, variant, color, move))
    |> jacquet_update_after_move(variant, color, move)
  end

  defp jacquet_update_after_move(runtime, %{id: "jacquet"} = variant, color, %{to: destination}) do
    cond do
      jacquet_postillon_entered?(runtime, color) ->
        runtime

      destination in jacquet_home_zone(variant, color) ->
        runtime
        |> put_in([:variant_state, :jacquet_postillon_entered, color], true)
        |> put_in([:variant_state, :jacquet_courier_points, color], nil)

      destination == "home" ->
        runtime

      true ->
        put_in(runtime, [:variant_state, :jacquet_courier_points, color], destination)
    end
  end

  defp jacquet_update_after_move(runtime, _variant, _color, _move), do: runtime

  defp jacquet_postillon_entered?(runtime, color) do
    get_in(runtime, [:variant_state, :jacquet_postillon_entered, color]) || false
  end

  defp jacquet_courier_source(runtime, variant, color) do
    get_in(runtime, [:variant_state, :jacquet_courier_points, color]) ||
      route_for(variant, color) |> List.first()
  end

  defp jacquet_position_allowed?(board, variant, color) do
    jacquet_has_returner_rights?(board, variant, color) or
      (jacquet_departure_compartment_open?(board, variant, color) and
         not jacquet_has_forbidden_bouchon?(board, variant, color))
  end

  defp jacquet_has_returner_rights?(board, variant, color) do
    variant
    |> jacquet_home_zone(color)
    |> Enum.take(-2)
    |> Enum.all?(fn point -> pieces_at(board, point, color) > 0 end)
  end

  defp jacquet_departure_compartment_open?(board, variant, color) do
    variant
    |> route_for(color)
    |> Enum.take(6)
    |> Enum.any?(fn point -> pieces_at(board, point, color) == 0 end)
  end

  defp jacquet_has_forbidden_bouchon?(board, variant, color) do
    variant
    |> route_for(color)
    |> Enum.chunk_every(6, 1, :discard)
    |> Enum.any?(fn points ->
      Enum.all?(points, fn point -> pieces_at(board, point, color) > 0 end)
    end)
  end

  defp jacquet_home_zone(variant, color) do
    variant
    |> route_for(color)
    |> Enum.take(-6)
  end

  defp remove_first([value | rest], value), do: rest
  defp remove_first([head | rest], value), do: [head | remove_first(rest, value)]
  defp remove_first([], _value), do: []

  defp remove_all_used(values, used) do
    Enum.reduce(used, values, fn die, acc -> remove_first(acc, die) end)
  end

  defp score_entry(trictrac, :white), do: Enum.at(trictrac.score, 0) || %{points: 0, trous: 0}
  defp score_entry(trictrac, :black), do: Enum.at(trictrac.score, 1) || %{points: 0, trous: 0}

  defp put_score(trictrac, :white, value),
    do: %{trictrac | score: [value, Enum.at(trictrac.score, 1) || %{points: 0, trous: 0}]}

  defp put_score(trictrac, :black, value),
    do: %{trictrac | score: [Enum.at(trictrac.score, 0) || %{points: 0, trous: 0}, value]}

  defp opposite(:white), do: :black
  defp opposite(:black), do: :white
end
