Code.require_file("backgammon/player/player.exs")

defmodule GameValidator do
  # Finds the first empty space from the bottom of a column.
  def get_first_empty_from_bottom(_max_height, col_data) do
    col_data
    |> Enum.reverse()
    |> Enum.with_index()
    |> Enum.find_value(fn {cell, index} -> if cell == "-", do: 4 - index end)
  end

  # Finds the highest occupied position in a column.
  def get_highest_occupied_index(_max_height, col_data) do
    col_data
    |> Enum.with_index()
    |> Enum.find_value(fn {cell, index} -> if cell != "-", do: index end)
  end

  # Finds the index of the first empty space in a column.
  def get_top_index(max_height, col_data) when is_list(col_data) do
    col_data
    |> Enum.with_index()
    |> Enum.find_value(fn {cell, index} -> if cell == "-", do: index end)
  end

  def get_top_index(_max_height, _col_data), do: nil

  # Calculates the number of occupied spaces in a column.
  def get_occupied_places(board, index, col) do
    cond do
      Enum.at(col, index) in ["W", "B"] -> 1 + get_occupied_places(board, index - 1, col)
      index == 0 -> 0
      true -> get_occupied_places(board, index - 1, col)
    end
  end

  # Checks if a piece can move to the specified new column.
  def can_move?(board, piece_colour, _old_col, new_col) do
    col = Board.get_col(board, 0, new_col)

    top_occupied_index = get_highest_occupied_index(4, col)

    if is_nil(top_occupied_index) do
      true
    else
      top_occupied_colour = Enum.at(col, top_occupied_index)
      top_occupied_colour == piece_colour
    end
  end

  # Checks if a piece can capture another piece in the specified new column.
  def can_capture?(board, piece_colour, _old_col, new_col) do
    col = Board.get_col(board, 0, new_col)

    top_occupied_index = get_highest_occupied_index(4, col)

    if is_nil(top_occupied_index) do
      false
    else
      top_occupied_colour = Enum.at(col, top_occupied_index)
      top_occupied_colour != piece_colour and get_occupied_places(board, 4, col) == 1
    end
  end

  # Checks if a hit piece can reenter the board.
  def can_reenter?(board, piece_colour, new_col) do
    col = Board.get_col(board, 0, new_col)
    top_occupied_index = get_highest_occupied_index(4, col)

    if is_nil(top_occupied_index) do
      false
    else
      top_occupied_colour = Enum.at(col, top_occupied_index)
      top_occupied_colour == piece_colour
    end
  end

  # Checks if any piece of the given colour can bear off using either of the two dice rolls.
  def can_bear_off(board, piece_colour, dice_rolls) do
    if all_pieces_in_homebase?(board, piece_colour) do
      Enum.any?(dice_rolls, fn dice_roll ->
        can_bear_off_with_dice?(board, piece_colour, dice_roll)
      end)
    else
      false
    end
  end

  # Checks if a move is a valid bearing-off move
  def is_valid_bearing_off_move?(piece_colour, old_col, dice_number) do
    case piece_colour do
      "W" -> old_col - dice_number == 0
      "B" -> old_col + dice_number == 25
      _ -> false
    end
  end

  # Checks if any piece of the given colour can bear off using a specific dice roll.
  def can_bear_off_with_dice?(board, piece_colour, dice_roll) do
    homebase_range = if piece_colour == "W", do: 1..6, else: 19..24

    Enum.any?(homebase_range, fn col ->
      col_data = Board.get_col(board, 0, col)
      if Enum.any?(col_data, fn cell -> cell == piece_colour end) do
        target_col = if piece_colour == "W", do: col - dice_roll, else: col + dice_roll

        case piece_colour do
          "W" -> target_col == 0
          "B" -> target_col == 25
          _ -> false
        end
      else
        false
      end
    end)
  end

  # Checks if all pieces of a given colour are in their homebase
  def all_pieces_in_homebase?(board, piece_colour) do
    homebase_range = if piece_colour == "W", do: 1..6, else: 19..24

    homebase_pieces = Enum.reduce(homebase_range, 0, fn col, acc ->
      col_data = Board.get_col(board, 0, col)
      acc + Enum.count(col_data, fn cell -> cell == piece_colour end)
    end)

    total_pieces = GameValidator.count_pieces(board)[piece_colour]
    homebase_pieces == total_pieces
  end

  # Checks if a piece of a given colour is in its homebase.
  def is_in_homebase(board, piece_colour) do
    homebase_range = if piece_colour == "W", do: 1..6, else: 19..24

    Enum.any?(homebase_range, fn col ->
      col_data = Board.get_col(board, 0, col)
      Enum.any?(col_data, fn cell -> cell == piece_colour end)
    end)
  end

  # Counts the number of "W" and "B" pieces on the board
  def count_pieces(board) do
    Enum.reduce(board, %{"W" => 0, "B" => 0}, fn row, acc ->
      Enum.reduce(row, acc, fn cell, acc ->
        case cell do
          "W" -> Map.update!(acc, "W", &(&1 + 1))
          "B" -> Map.update!(acc, "B", &(&1 + 1))
          _ -> acc
        end
      end)
    end)
  end

  # Calculates the number of hit pieces for a player
  def calculate_hit_pieces(board, player) do
    piece_colour = Player.get_piece_colour(player) |> String.trim()
    max_pieces = 15

    piece_count = count_pieces(board)[piece_colour]
    max_pieces - piece_count
  end
end
