Code.require_file("backgammon/player/player.exs")

defmodule PlayerBuilder do

  # Creates a new Player struct.
  def build,
    do: %Player{}

  # Creates a default white pieces player with a given name.
  def default_build_white(name) do
    player = PlayerBuilder.build()
    |> PlayerBuilder.set_name(name)
    |> PlayerBuilder.set_status()
    |> PlayerBuilder.set_pieces_white()
    |> PlayerBuilder.set_position_score()
    |> PlayerBuilder.set_beared_pieces()
    |> PlayerBuilder.set_hit_pieces()
    player
  end

  # Creates a default black pieces player with a given name.
  def default_build_black(name) do
    player = PlayerBuilder.build()
    |> PlayerBuilder.set_name(name)
    |> PlayerBuilder.set_status()
    |> PlayerBuilder.set_pieces_black()
    |> PlayerBuilder.set_position_score()
    |> PlayerBuilder.set_beared_pieces()
    |> PlayerBuilder.set_hit_pieces()
    player
  end

  # Sets the name of a player.
  def set_name(player, name),
    do: %{player | name: name}

  # Sets a default name of a player.
  def set_name(player),
    do: %{player | name: "AI"}

  # Sets the status for a player.
  def set_status(player, status),
    do: %{player | status: status}

  # Sets the default status for a player.
  def set_status(player),
    do: %{player | status: "None"}

  # Sets the piece colour of a player to "White"
  def set_pieces_white(player),
    do: %{player | piece_colour: "W"}

  # Sets the piece colour of a player to "Black"
  def set_pieces_black(player),
    do: %{player | piece_colour: "B"}

  # Sets the position score of a player.
  def set_position_score(player, position_score),
    do: %{player | position_score: position_score}

  # Sets the position score of a player to the default value 0.
  def set_position_score(player),
    do: %{player | position_score: 0}

  # Sets the number of hit pieces of a player.
  def set_hit_pieces(player, hit_pieces),
    do: %{player | hit_pieces: hit_pieces}

  # Sets the number of hit pieces of a player to the default value 0.
  def set_hit_pieces(player),
    do: %{player | hit_pieces: 0}

  # Sets the number of bearead off pieces of a player.
  def set_beared_pieces(player, beared_pieces),
    do: %{player | beared_pieces: beared_pieces}

  # Sets the number of beared off pieces of a player to the default value 0.
  def set_beared_pieces(player),
    do: %{player | beared_pieces: 0}
end
