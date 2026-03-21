defmodule GameEngineUtils do
  # Computes a weighted score based on the number of pieces that are
  # in the homebase of a given player.
  def compute_homebase_score(player, board) do
    piece_colour = Player.get_piece_colour(player)
    homebase_range = if piece_colour == "W", do: 1..6, else: 19..24

    homebase_pieces = Enum.reduce(homebase_range, 0, fn col, acc ->
      col_data = Board.get_col(board, 0, col)
      acc + Enum.count(col_data, fn cell -> cell == piece_colour end)
    end)

    homebase_pieces * 10
  end

  # Computes the weighted score based on the number of pieces that
  # could be captured for a given player.
  def compute_vulnerable_pieces_score(player, board) do
    piece_colour = Player.get_piece_colour(player)

    vulnerable_pieces = Enum.reduce(1..24, 0, fn col, acc ->
      col_data = Board.get_col(board, 0, col)
      if Enum.count(col_data, fn cell -> cell == piece_colour end) == 1 do
        acc + 1
      else
        acc
      end
    end)

    -vulnerable_pieces * 5
  end

  # Computes the weighted score based on the number of pieces that form a
  # blockade or anchor.
  def compute_blocking_positions_score(player, board) do
    piece_colour = Player.get_piece_colour(player)

    blocking_positions = Enum.reduce(1..24, 0, fn col, acc ->
      col_data = Board.get_col(board, 0, col)
      if Enum.count(col_data, fn cell -> cell == piece_colour end) >= 2 do
        acc + 1
      else
        acc
      end
    end)

    blocking_positions * 7
  end

  # Computes the weighted score based on the distance (pips) the pieces must travel
  # before they can bear off.
  def compute_pip_count_score(player, board) do
    piece_colour = Player.get_piece_colour(player)

    pip_count = Enum.reduce(1..24, 0, fn col, acc ->
      col_data = Board.get_col(board, 0, col)
      pieces = Enum.count(col_data, fn cell -> cell == piece_colour end)
      distance = if piece_colour == "W", do: col, else: 25 - col
      acc + pieces * distance
    end)

    -pip_count
  end

  # Computes the weighted score based on the number of hit pieces a player has and
  # the number of pieces they have beared off.
  def compute_hit_and_beared_off_pieces_score(player, board) do
    piece_colour = Player.get_piece_colour(player)

    hit_pieces = Player.get_hit_pieces(player)
    beared_off_pieces = Player.get_beared_pieces(player)

    -hit_pieces * 3 + beared_off_pieces * 10
  end

  # Computes the score for hitting an opponent's piece.
  def compute_hit_score(player, board) do
    piece_colour = Player.get_piece_colour(player)
    opponent_colour = Player.get_opposite_colour(player)

    hit_score = Enum.reduce(1..24, 0, fn col, acc ->
      col_data = Board.get_col(board, 0, col)
      if Enum.count(col_data, fn cell -> cell == opponent_colour end) == 1 do
        acc + 1
      else
        acc
      end
    end)

    hit_score * 20
  end

  # Computes the score for saving vulnerable pieces.
  def compute_save_vulnerable_score(player, board) do
    piece_colour = Player.get_piece_colour(player)

    save_score = Enum.reduce(1..24, 0, fn col, acc ->
      col_data = Board.get_col(board, 0, col)
      if Enum.count(col_data, fn cell -> cell == piece_colour end) == 1 do
        acc + 1
      else
        acc
      end
    end)

    save_score * 15
  end

  # Computes the score for bearing off pieces.
  def compute_bearing_off_score(player, board) do
    piece_colour = Player.get_piece_colour(player)

    if GameValidator.all_pieces_in_homebase?(board, piece_colour) do
      beared_off_pieces = Player.get_beared_pieces(player)
      beared_off_pieces * 10
    else
      0
    end
  end
end
