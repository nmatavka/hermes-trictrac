Code.require_file("backgammon/game/game_validator.exs")
Code.require_file("backgammon/domain/board.exs")
Code.require_file("backgammon/domain/board_utils.exs")
Code.require_file("backgammon/engine/move_generator.exs")
Code.require_file("backgammon/engine/engine.exs")
Code.require_file("backgammon/player/player_builder.exs")
Code.require_file("backgammon/utils/validator.exs")

defmodule GameRound do
  # Starts a new round of Backgammon, initializes the board, and begins the game with the white pieces player.
  def start_round(player, opponent) do
    board = Board.create()
    white_pieces_player_move(player, opponent, board)
  end

  # Starts a new round of Backgammon, initializez the board, and begins the game with the white pieces player
  # against an AI that plays the best moves.
  def start_ai_round(player, opponent) do
    board = Board.create()
    white_pieces_ai_move(player, opponent, board)
  end

  defp white_pieces_ai_move(player, opponent, board) do
    Player.show_data(opponent)
    Board.show(board)
    Player.show_data(player)
    IO.write("\n")

    dice_rolled = dice_roll(player)
    {new_board, updated_player} = player_move(player, dice_rolled, board)
    {updated_player, updated_opponent} = update_hit_pieces(new_board, updated_player, opponent)

    black_pieces_ai_move(updated_player, updated_opponent, new_board)
  end

  defp black_pieces_ai_move(player, opponent, board) do
    Player.show_data(player)
    Board.show(board)
    Player.show_data(opponent)
    IO.write("\n")

    dice_rolled = dice_roll(opponent)

    game_state = MoveGenerator.new(board, opponent, player, dice_rolled)

    first_die = Enum.at(dice_rolled, 0)
    first_die_state = %{game_state | dice_roll: [first_die]}
    best_move_first_die = GameEngine.choose_best_move(first_die_state)

    new_board_after_first_move = if best_move_first_die do
      BoardUtils.apply_move(board, best_move_first_die)
    else
      board
    end

    second_die = Enum.at(dice_rolled, 1)
    second_die_state = %{game_state | board: new_board_after_first_move, dice_roll: [second_die]}
    best_move_second_die = GameEngine.choose_best_move(second_die_state)

    IO.puts("AI's best move for dice 1 (#{first_die}): #{inspect(best_move_first_die)}")
    IO.puts("AI's best move for dice 2 (#{second_die}): #{inspect(best_move_second_die)}")

    {new_board, updated_player} = player_move(opponent, dice_rolled, board)
    {updated_player, updated_opponent} = update_hit_pieces(new_board, updated_player, player)

    white_pieces_ai_move(updated_opponent, updated_player, new_board)
  end

  # Handles the white pieces player's move, displays the board and player data,
  # rolls the dice, and updates the game state.
  defp white_pieces_player_move(player, opponent, board) do
    Player.show_data(opponent)
    Board.show(board)
    Player.show_data(player)
    IO.write("\n")

    dice_rolled = dice_roll(player)
    {new_board, updated_player} = player_move(player, dice_rolled, board)
    {updated_player, updated_opponent} = update_hit_pieces(new_board, updated_player, opponent)
    black_pieces_player_move(updated_player, updated_opponent, new_board)
  end

  # Handles the black pieces player's move, displays the board and player data,
  # rolls the dice, and updates the game state.
  defp black_pieces_player_move(player, opponent, board) do
    Player.show_data(opponent)
    Board.show(board)
    Player.show_data(player)
    IO.write("\n")

    dice_rolled = dice_roll(opponent)
    {new_board, updated_player} = player_move(opponent, dice_rolled, board)
    {updated_player, updated_opponent} = update_hit_pieces(new_board, updated_player, player)
    white_pieces_player_move(updated_opponent, updated_player, new_board)
  end

  # Prompts the player to choose a move based on the dice rolls and handles the move logic.
  defp player_move(player, dice_rolled, board) do
    piece_colour = Player.get_piece_colour(player)

    if GameValidator.all_pieces_in_homebase?(board, piece_colour) do
      IO.puts("All your pieces are in the homebase. You can start bearing off pieces!")
    end

    IO.puts("\nWhat would you like to do?")
    IO.puts("1. Move one checker #{Enum.at(dice_rolled, 0)} spaces and the other #{Enum.at(dice_rolled, 1)} spaces")
    IO.puts("2. Move one checker #{Enum.at(dice_rolled, 0) + Enum.at(dice_rolled, 1)} spaces")

    if player |> Player.get_hit_pieces > 0 do
      move_hit_pieces(player, dice_rolled, board)
    else
      get_choice(player, dice_rolled, board)
    end
  end

  # Updates the number of hit pieces for both players based on the current board state.
  defp update_hit_pieces(board, player, opponent) do
    piece_counts = GameValidator.count_pieces(board)
    player_colour = Player.get_piece_colour(player)
    opponent_colour = Player.get_piece_colour(opponent)

    player_hit_pieces = 15 - piece_counts[player_colour] - Player.get_beared_pieces(player)
    updated_player = %{player | hit_pieces: player_hit_pieces}

    opponent_hit_pieces = 15 - piece_counts[opponent_colour] - Player.get_beared_pieces(opponent)
    updated_opponent = %{opponent | hit_pieces: opponent_hit_pieces}

    {updated_player, updated_opponent}
  end

  # Places a hit piece on the board at the specified column.
  defp place_hit_piece(board, piece_colour, new_col) do
    col_data = Board.get_col(board, 0, new_col)
    new_row = GameValidator.get_first_empty_from_bottom(4, col_data)

    if is_nil(new_row) do
      IO.puts("Invalid move: Column #{new_col} is full.")
      board
    else
      Matrix.set(board, new_row, new_col, piece_colour)
    end
  end

  # Handles the movement of hit pieces for a player based on the dice rolls.
  defp move_hit_pieces(player, dice_rolled, board) do
    piece_colour = Player.get_piece_colour(player)
    {start_col, direction} = if piece_colour == "W", do: {0, 1}, else: {25, -1}

    valid_dice =
      Enum.filter(dice_rolled, fn dice_number ->
        new_col = start_col + direction * dice_number
        GameValidator.can_reenter?(board, piece_colour, new_col)
      end)

    if Enum.empty?(valid_dice) do
      IO.puts("No valid moves for hit pieces. Skipping turn.")
      {board, player}
    else
      IO.puts("Choose a dice roll to re-enter your hit piece:")
      Enum.each(valid_dice, fn dice_number ->
        IO.puts("#{dice_number} -> Column #{start_col + direction * dice_number}")
      end)

      choice = IO.gets("Choice: ") |> String.trim() |> Integer.parse()

      case choice do
        {dice_number, ""} ->
          if dice_number in valid_dice do
            new_col = start_col + direction * dice_number
            updated_board = place_hit_piece(board, piece_colour, new_col)
            updated_player = %{player | hit_pieces: player.hit_pieces - 1}
            {updated_board, updated_player}
          else
            IO.puts("Invalid choice. Skipping turn.")
            {board, player}
          end

        _ ->
          IO.puts("Invalid input. Skipping turn.")
          {board, player}
      end
    end
  end

  #
  defp move_piece(player, dice_number, board, old_col \\ nil) do
    old_col = if is_nil(old_col), do: Validator.get_valid_integer("Column number of the moved piece: "), else: old_col

    if Validator.validate_interval(old_col, 1, 24) == false do
      move_piece_fail(player, dice_number, board, "invalid_space")
      {board, player}
    else
      old_row = GameValidator.get_highest_occupied_index(4, Board.get_col(board, 0, old_col))

      if is_nil(old_row) do
        move_piece_fail(player, dice_number, board, "empty_space")
        {board, player}
      else
        piece_colour = player |> Player.get_piece_colour() |> String.trim()
        opposite_colour = player |> Player.get_opposite_colour() |> String.trim()
        new_col = find_new_col(piece_colour, old_row, old_col, dice_number)

        if GameValidator.all_pieces_in_homebase?(board, piece_colour) do
          if GameValidator.is_valid_bearing_off_move?(piece_colour, old_col, dice_number) do
            IO.puts("Bearing off a piece from column #{old_col}!")
            updated_board = Matrix.set(board, old_row, old_col, "-")
            updated_player = %{player | beared_pieces: player.beared_pieces + 1}
            {updated_board, updated_player}
          else
            IO.puts("Invalid bearing-off move: You must move exactly to the bearing-off column.")
            {board, player}
          end
        else
          if GameValidator.can_capture?(board, piece_colour, old_col, new_col) do
            captured_row = GameValidator.get_highest_occupied_index(4, Board.get_col(board, 0, new_col))
            board = Matrix.set(board, captured_row, new_col, "-")
            updated_player = player |> Player.increment_hit_pieces()
            updated_board = modify_board(old_row, old_col, new_col, dice_number, board)
            {updated_board, updated_player}
          else
            if GameValidator.can_move?(board, piece_colour, old_col, new_col) do
              updated_board = modify_board(old_row, old_col, new_col, dice_number, board)
              {updated_board, player}
            else
              cond do
                board |> Matrix.get(old_row, old_col) == opposite_colour ->
                  move_piece_fail(player, dice_number, board, "wrong_colour")
                  {board, player}

                true ->
                  move_piece_fail(player, dice_number, board, "invalid_move")
                  {board, player}
              end
            end
          end
        end
      end
    end
  end

  # Modifies the board by moving a piece from the old position to the new position.
  defp modify_board(old_row, old_col, new_col, _dice_number, board) do
    piece_colour = Matrix.get(board, old_row, old_col)
    col_data = Board.get_col(board, 0, new_col)
    new_row = GameValidator.get_first_empty_from_bottom(4, col_data)

    if is_nil(new_row) do
      board
    else
      if GameValidator.can_move?(board, piece_colour, old_col, new_col) do
        board
        |> Matrix.set(old_row, old_col, "-")
        |> Matrix.set(new_row, new_col, piece_colour)
      else
        board
      end
    end
  end

  # Calculates the new column for a piece based on its current column and the dice roll.
  defp find_new_col(piece_colour, _current_row, current_col, dice_number) do
    cond do
      piece_colour == "W" -> current_col - dice_number
      piece_colour == "B" -> current_col + dice_number
      true -> current_col
    end
  end

  # Returns the opposite colour of the given piece colour.
  defp get_opposite_colour(piece_colour) do
    case piece_colour do
      "W" -> "B"
      "B" -> "W"
      _ -> "-"
    end
  end

  # Rolls the dice for a player and returns the results.
  defp dice_roll(player) do
    dice1 = Dice.roll(6)
    dice2 = Dice.roll(6)
    IO.puts("#{Player.get_name(player)} rolled:")
    IO.puts("Dice 1: #{dice1}\nDice 2: #{dice2}")
    [dice1, dice2]
  end

  # Prompts the player to choose a move option and handles the choice.
  defp get_choice(player, dice_rolled, board) do
    choice = IO.gets("Choice: ") |> String.trim()

    case Integer.parse(choice) do
      {1, ""} ->
        {updated_board, updated_player} = move_piece(player, Enum.at(dice_rolled, 0), board)
        {final_board, final_player} = move_piece(updated_player, Enum.at(dice_rolled, 1), updated_board)
        {final_board, final_player}

      {2, ""} ->
        move_piece(player, Enum.at(dice_rolled, 0) + Enum.at(dice_rolled, 1), board)

      _ ->
        get_choice_fail(player, dice_rolled, board)
    end
  end

  # Handles invalid choice input and prompts the player to choose again.
  defp get_choice_fail(player, dice_rolled, board) do
    IO.puts("Sorry for this primitive UI! Please choose a valid option (1 or 2)!")
    get_choice(player, dice_rolled, board)
  end

  # Handles move failures and provides feedback to the player.
  defp move_piece_fail(player, dice_number, board, flag) do
    colour = Player.get_piece_colour(player)

    case flag do
      "wrong_colour" ->
        IO.puts("Wrong colour! Please choose a #{if colour == "W", do: "white", else: "black"} piece!")

      "empty_space" ->
        IO.puts("That space is empty! Choose a valid piece.")

      "invalid_space" ->
        IO.puts("That move is not valid!")

      "invalid_move" ->
        IO.puts("You can't move there!")
    end

    {board, player}
  end
end
