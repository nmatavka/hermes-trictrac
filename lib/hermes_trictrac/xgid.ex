defmodule HermesTrictrac.Xgid do
  @moduledoc """
  Minimal XGID parser for analysis/test tooling.

  XGID stores 26 position characters: bar, 24 board points, bar.
  The lab maps the lowercase/top side to White and the uppercase/bottom side
  to Black, so White's talon is point 1.
  """

  @point_count 24
  @total_pieces 15

  def parse(input) when is_binary(input) do
    with {:ok, id} <- extract_id(input),
         {:ok, fields} <- split_fields(id),
         {:ok, board} <- parse_board(Enum.at(fields, 0)),
         {:ok, turn_color} <- parse_turn(Enum.at(fields, 3)),
         {:ok, dice} <- parse_dice_field(Enum.at(fields, 4)) do
      {:ok,
       %{
         id: "XGID=" <> Enum.join(fields, ":"),
         position: Enum.at(fields, 0),
         board: board,
         turn_color: turn_color,
         dice: dice,
         cube_exponent: parse_integer(Enum.at(fields, 1), 0),
         cube_owner: parse_integer(Enum.at(fields, 2), 0),
         score: %{
           black: parse_integer(Enum.at(fields, 5), 0),
           white: parse_integer(Enum.at(fields, 6), 0)
         },
         match_length: parse_integer(Enum.at(fields, 8), 0)
       }}
    end
  end

  def parse(_input), do: {:error, "XGID must be text."}

  def parse_dice(value) when is_list(value) do
    dice =
      value
      |> Enum.map(&parse_die/1)
      |> Enum.reject(&is_nil/1)

    case dice do
      [a, b | _] -> {:ok, [a, b]}
      _ -> {:error, "Choose two dice."}
    end
  end

  def parse_dice(value) when is_binary(value) do
    digits = Regex.scan(~r/[1-6]/, value) |> List.flatten() |> Enum.map(&String.to_integer/1)

    case digits do
      [a, b | _] -> {:ok, [a, b]}
      _ -> {:error, "Choose two dice."}
    end
  end

  def parse_dice(_value), do: {:error, "Choose two dice."}

  defp extract_id(input) do
    input = String.trim(input)

    cond do
      input == "" ->
        {:error, "XGID is required."}

      match = Regex.run(~r/XGID=([^\s]+)/i, input) ->
        {:ok, List.last(match)}

      String.contains?(input, ":") ->
        {:ok, input}

      true ->
        {:error, "Paste an XGID such as XGID=...:..."}
    end
  end

  defp split_fields(id) do
    fields =
      id
      |> String.trim()
      |> String.trim_leading("XGID=")
      |> String.split(":")

    if length(fields) >= 10 do
      {:ok, Enum.take(fields, 10)}
    else
      {:error, "XGID must contain 10 colon-separated fields."}
    end
  end

  defp parse_board(position) when is_binary(position) do
    chars = String.graphemes(position)

    if length(chars) == @point_count + 2 do
      with {:ok, board} <- put_position_chars(empty_board(), chars),
           :ok <- validate_piece_totals(board) do
        {:ok, put_outside_counts(board)}
      end
    else
      {:error, "XGID position field must have 26 characters."}
    end
  end

  defp parse_board(_position), do: {:error, "XGID position field is missing."}

  defp empty_board do
    %{
      points: Enum.map(1..@point_count, fn _ -> %{white: 0, black: 0} end),
      bar: %{white: 0, black: 0},
      outside: %{white: 0, black: 0}
    }
  end

  defp put_position_chars(board, chars) do
    chars
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, board}, fn {char, index}, {:ok, acc} ->
      case decode_point_char(char) do
        {:ok, _color, 0} ->
          {:cont, {:ok, acc}}

        {:ok, color, count} ->
          {:cont, {:ok, put_checker_count(acc, index, color, count)}}

        {:error, msg} ->
          {:halt, {:error, msg}}
      end
    end)
  end

  defp put_checker_count(board, 0, color, count), do: put_in(board, [:bar, color], count)
  defp put_checker_count(board, 25, color, count), do: put_in(board, [:bar, color], count)

  defp put_checker_count(board, index, color, count) when index in 1..24 do
    put_in(board, [:points, Access.at(index - 1), color], count)
  end

  defp validate_piece_totals(board) do
    Enum.find_value([:white, :black], :ok, fn color ->
      total =
        Enum.reduce(board.points, get_in(board, [:bar, color]) || 0, fn point, acc ->
          acc + (Map.get(point, color) || 0)
        end)

      if total > @total_pieces do
        {:error, "XGID has #{total} #{color} men on the board; maximum is #{@total_pieces}."}
      end
    end)
  end

  defp put_outside_counts(board) do
    Enum.reduce([:white, :black], board, fn color, acc ->
      on_points =
        Enum.reduce(acc.points, 0, fn point, total -> total + (Map.get(point, color) || 0) end)

      on_bar = get_in(acc, [:bar, color]) || 0
      outside = max(@total_pieces - on_points - on_bar, 0)
      put_in(acc, [:outside, color], outside)
    end)
  end

  defp decode_point_char("-"), do: {:ok, nil, 0}

  defp decode_point_char(char) when is_binary(char) do
    <<codepoint::utf8>> = char

    cond do
      codepoint in ?A..?O -> {:ok, :black, codepoint - ?A + 1}
      codepoint in ?a..?o -> {:ok, :white, codepoint - ?a + 1}
      true -> {:error, "Unsupported XGID position character: #{inspect(char)}."}
    end
  end

  defp parse_turn("1"), do: {:ok, :black}
  defp parse_turn("-1"), do: {:ok, :white}
  defp parse_turn(_other), do: {:ok, :white}

  defp parse_dice_field(value) when value in [nil, "", "00", "D", "B", "R"], do: {:ok, []}
  defp parse_dice_field(value), do: parse_dice(value)

  defp parse_die(value) when is_integer(value) and value in 1..6, do: value

  defp parse_die(value) when is_binary(value) do
    case Integer.parse(value) do
      {die, ""} when die in 1..6 -> die
      _ -> nil
    end
  end

  defp parse_die(_value), do: nil

  defp parse_integer(value, fallback) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _ -> fallback
    end
  end

  defp parse_integer(_value, fallback), do: fallback
end
