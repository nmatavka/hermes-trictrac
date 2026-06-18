defmodule HermesTrictrac.Rules.TrictracMargotTest do
  use ExUnit.Case, async: true

  alias HermesTrictrac.Rules.Registry
  alias HermesTrictrac.Rules.Trictrac.Classique.Events

  defp point(white \\ 0, black \\ 0), do: %{white: white, black: black}

  defp board(points) do
    %{
      points: points,
      outside: %{white: 0, black: 0},
      bar: %{white: 0, black: 0}
    }
  end

  defp points(spec) do
    Enum.map(0..23, fn index ->
      Map.get(spec, index, point())
    end)
  end

  defp margot_events(start_points, end_points) do
    variant = Registry.fetch!("trictrac_classique")
    dice = %{values: [4, 2], moves: [4, 2], moves_left: [], moves_played: [4, 2]}
    trictrac = %{options: %{"margotEnabled" => true}}

    board(start_points)
    |> Events.detect_turn_events(board(end_points), variant, :black, dice, trictrac)
    |> Map.fetch!(:events)
    |> Enum.filter(&(&1.rule == :margot))
  end

  test "Margot scores when the moved checker lands in the empty gap between two blots" do
    start_points =
      points(%{
        6 => point(0, 1),
        9 => point(1, 0),
        11 => point(1, 0)
      })

    end_points =
      points(%{
        9 => point(1, 0),
        10 => point(0, 1),
        11 => point(1, 0)
      })

    assert [%{beneficiary: "white", points: 2, metadata: %{matches: [%{target: 10}]}}] =
             margot_events(start_points, end_points)
  end

  test "Margot does not score when the moved checker lands between covered points" do
    start_points =
      points(%{
        6 => point(0, 1),
        9 => point(2, 0),
        11 => point(2, 0),
        13 => point(1, 0),
        15 => point(1, 0)
      })

    end_points =
      points(%{
        9 => point(2, 0),
        10 => point(0, 1),
        11 => point(2, 0),
        13 => point(1, 0),
        15 => point(1, 0)
      })

    assert [] = margot_events(start_points, end_points)
  end
end
