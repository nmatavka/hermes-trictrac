Code.require_file("backgammon/engine/game_state.exs")
Code.require_file("backgammon/player/player.exs")
Code.require_file("backgammon/game/game_validator.exs")
Code.require_file("backgammon/engine/engine_utils.exs")
Code.require_file("backgammon/engine/move_generator.exs")

defmodule GameEngine do
  @max_depth 5
  @positive_infinity 1_000_000
  @negative_infinity -1_000_000

  # Chooses and returns the best move that can be played in a given Game State.
  def choose_best_move(game_state) do

    hit_move = find_hit_move(game_state)
    if hit_move, do: hit_move

    save_move = find_save_move(game_state)
    if save_move, do: save_move

    bear_off_move = find_bear_off_move(game_state)
    if bear_off_move, do: bear_off_move

    find_best_move_with_alphabeta(game_state)
  end

  # Calculates the score of a given position in a game of Backgammon for a given
  # piece colour.
  def calculate_position_score(player, board) do
    homebase_score = GameEngineUtils.compute_homebase_score(player, board)
    vulnerable_score = GameEngineUtils.compute_vulnerable_pieces_score(player, board)
    blocking_score = GameEngineUtils.compute_blocking_positions_score(player, board)
    pip_score = GameEngineUtils.compute_pip_count_score(player, board)
    hit_and_beared_score = GameEngineUtils.compute_hit_and_beared_off_pieces_score(player, board)

    total_score = homebase_score + vulnerable_score + blocking_score + pip_score + hit_and_beared_score
    total_score
  end

  # Finds a move that hits an opponent's piece.
  defp find_hit_move(game_state) do
    valid_moves = MoveGenerator.generate_moves(game_state)

    Enum.find(valid_moves, fn move ->
      case move do
        {:move, from_col, to_col} ->
          col_data = Board.get_col(game_state.board, 0, to_col)
          opponent_colour = Player.get_opposite_colour(game_state.player)
          Enum.count(col_data, &(&1 == opponent_colour)) == 1
        _ ->
          false
      end
    end)
  end

  # Finds a move that saves a vulnerable piece.
  defp find_save_move(game_state) do
    valid_moves = MoveGenerator.generate_moves(game_state)

    Enum.find(valid_moves, fn move ->
      case move do
        {:move, from_col, to_col} ->
          from_col_data = Board.get_col(game_state.board, 0, from_col)
          piece_colour = Player.get_piece_colour(game_state.player)
          Enum.count(from_col_data, &(&1 == piece_colour)) == 1
        _ ->
          false
      end
    end)
  end

  # Finds a move that bears off a piece.
  defp find_bear_off_move(game_state) do
    valid_moves = MoveGenerator.generate_moves(game_state)

    Enum.find(valid_moves, fn move ->
      case move do
        {:bear_off, _col} -> true
        _ -> false
      end
    end)
  end

  # Uses Alpha-Beta to find the best move.
  defp find_best_move_with_alphabeta(game_state) do
    valid_moves = MoveGenerator.generate_moves(game_state)

    {best_move, _best_score} = Enum.reduce(valid_moves, {nil, @negative_infinity}, fn move, {best_move, best_score} ->
      new_board = BoardUtils.apply_move(game_state.board, move)
      new_game_state = %GameState{
        board: new_board,
        player: game_state.opponent,
        opponent: game_state.player,
        dice_roll: game_state.dice_roll,
        depth: @max_depth
      }

      score = alphabeta(new_game_state, @max_depth, @negative_infinity, @positive_infinity, false)

      if score > best_score do
        {move, score}
      else
        {best_move, best_score}
      end
    end)

    best_move
  end

  # Uses the AlphaBeta algorithm to choose which path is best to take in a given game state.
  defp alphabeta(game_state, depth, alpha, beta, maximizing_player) do
    if depth == 0 or game_over?(game_state) do
      GameEngine.calculate_position_score(game_state.player, game_state.board)
    else
      if maximizing_player do
        value = @negative_infinity
        valid_moves = MoveGenerator.generate_moves(game_state)

        Enum.reduce(valid_moves, value, fn move, acc ->
          new_board = BoardUtils.apply_move(game_state.board, move)
          new_game_state = %GameState{
            board: new_board,
            player: game_state.opponent,
            opponent: game_state.player,
            dice_roll: game_state.dice_roll,
            depth: depth - 1
          }

          new_value = alphabeta(new_game_state, depth - 1, alpha, beta, false)
          value = max(value, new_value)
          alpha = max(alpha, value)

          if beta <= alpha do
            acc
          else
            value
          end
        end)
      else
        value = @positive_infinity
        valid_moves = MoveGenerator.generate_moves(game_state)

        Enum.reduce(valid_moves, value, fn move, acc ->
          new_board = BoardUtils.apply_move(game_state.board, move)
          new_game_state = %GameState{
            board: new_board,
            player: game_state.opponent,
            opponent: game_state.player,
            dice_roll: game_state.dice_roll,
            depth: depth - 1
          }

          new_value = alphabeta(new_game_state, depth - 1, alpha, beta, true)
          value = min(value, new_value)
          beta = min(beta, value)

          if beta <= alpha do
            acc
          else
            value
          end
        end)
      end
    end
  end

  defp game_over?(game_state) do
    player = game_state.player
    opponent = game_state.opponent

    if player |> Player.get_beared_pieces == 15 or
       opponent |> Player.get_beared_pieces == 15 do
         true
       end
    false
  end
end
