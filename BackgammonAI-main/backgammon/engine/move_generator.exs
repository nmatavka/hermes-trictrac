defmodule MoveGenerator do
  defstruct board: nil, player: nil, opponent: nil, dice_roll: nil

  # Creates a new GameState struct.
  def new(board, player, opponent, dice_roll) do
    %MoveGenerator{
      board: board,
      player: player,
      opponent: opponent,
      dice_roll: dice_roll
    }
  end

  # Generates all the moves the player struct inside a given game state can play.
  # It returns a list of tuples containing the type of move, the old column and the
  # new column of a checker.
  def generate_moves(game_state) do
    dice_roll = if Enum.at(game_state.dice_roll, 0) == Enum.at(game_state.dice_roll, 1) do
      List.duplicate(Enum.at(game_state.dice_roll, 0), 4)
    else
      game_state.dice_roll
    end

    if Player.get_hit_pieces(game_state.player) > 0 do
      generate_reenter_moves(game_state.player, game_state.board, dice_roll)
    else
      regular_moves = generate_regular_moves(game_state.player, game_state.board, dice_roll)
      bearing_off_moves = generate_bearing_off_moves(game_state.player, game_state.board, dice_roll)

      regular_moves ++ bearing_off_moves
    end
  end

  # Generates moves to re-enter hit pieces onto the board.
  defp generate_reenter_moves(player, board, dice_roll) do
    piece_colour = Player.get_piece_colour(player)
    {start_col, direction} = if piece_colour == "W", do: {0, 1}, else: {25, -1}

    Enum.flat_map(dice_roll, fn dice_number ->
      new_col = start_col + direction * dice_number
      if GameValidator.can_reenter?(board, piece_colour, new_col) do
        [{:reenter, dice_number, new_col}]
      else
        []
      end
    end)
  end

  # Generates regular moves for pieces on the board.
  defp generate_regular_moves(player, board, dice_roll) do
    piece_colour = Player.get_piece_colour(player)
    invalid_col = case piece_colour do
      "W" ->
        0
      "B" ->
        25
    end

    Enum.flat_map(1..24, fn col ->
      col_data = Board.get_col(board, 0, col)
      if Enum.any?(col_data, &(&1 == piece_colour)) do
        Enum.flat_map(dice_roll, fn dice_number ->
          new_col = find_new_col(piece_colour, col, dice_number)
          if GameValidator.can_move?(board, piece_colour, col, new_col) and new_col != invalid_col do
            [{:move, col, new_col}]
          else
            []
          end
        end)
      else
        []
      end
    end)
  end

  # Generates moves to bear off pieces.
  defp generate_bearing_off_moves(player, board, dice_roll) do
    piece_colour = Player.get_piece_colour(player)

    if GameValidator.all_pieces_in_homebase?(board, piece_colour) do
      Enum.flat_map(dice_roll, fn dice_number ->
        Enum.flat_map(1..24, fn col ->
          col_data = Board.get_col(board, 0, col)
          if Enum.any?(col_data, &(&1 == piece_colour)) do
            if GameValidator.is_valid_bearing_off_move?(piece_colour, col, dice_number) do
              [{:bear_off, col}]
            else
              []
            end
          else
            []
          end
        end)
      end)
    else
      []
    end
  end

  # Calculates the new column for a piece based on its current column and the dice roll.
  defp find_new_col(piece_colour, current_col, dice_number) do
    cond do
      piece_colour == "W" -> current_col - dice_number
      piece_colour == "B" -> current_col + dice_number
      true -> current_col
    end
  end
end
