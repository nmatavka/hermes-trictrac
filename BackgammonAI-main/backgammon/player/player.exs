defmodule Player do

  # Defines the struture for the player and the attributes a player has.
  defstruct name: nil, status: nil, piece_colour: nil, position_score: 0,
  hit_pieces: 0, beared_pieces: 0

  # Getter for the name of a player.
  def get_name(player) do
    Map.get(player |> Map.from_struct, :name)
  end

  # Getter for the status of a player.
  def get_status(player) do
    Map.get(player |> Map.from_struct, :status)
  end

  # Getter for the piece colour of a player.
  def get_piece_colour(player) do
    Map.get(player |> Map.from_struct, :piece_colour)
  end

  # Getter for the opposite piece colour of a player.
  def get_opposite_colour(player) do
    colour = Map.get(player |> Map.from_struct, :piece_colour)
    case colour do
      "W" ->
        "B"
      "B" ->
        "W"
    end
  end

  # Getter for the position score of a player.
  def get_position_score(player) do
    Map.get(player |> Map.from_struct, :position_score)
  end

  # Getter for the number of hit pieces of a player.
  def get_hit_pieces(player) do
    Map.get(player |> Map.from_struct, :hit_pieces)
  end

   # Increments the number of hit pieces for a player.
   def increment_hit_pieces(player) do
    if Map.has_key?(player, :hit_pieces) do
      %{player | hit_pieces: player.hit_pieces + 1}
    else
      raise ArgumentError, "Player struct is missing the :hit_pieces key"
    end
  end

  # Decrements the number of hit pieces of a player.
  def decrement_hit_pieces(player) do
    if Map.has_key?(player, :hit_pieces) do
      %{player | hit_pieces: player.hit_pieces - 1}
    else
      raise ArgumentError, "Player struct is missing the :hit_pieces key"
    end
  end

  # Getter for the number of beared off pieces of a player.
  def get_beared_pieces(player) do
    Map.get(player |> Map.from_struct, :beared_pieces)
  end

  # Gets the name of the first player (white pieces player) from the player data file.
  def get_player1(filename) do
    case File.read(filename) do
      {:ok, content} ->
        content |> String.split("\n") |> Enum.at(0)
        |> String.split(":") |> Enum.at(1) |> String.trim()

      {:error, reason} ->
        IO.puts("Error reading file!")
    end
  end

  # Gets the name of the second player (black pieces player) from the player data file.
  def get_player2(filename) do
    case File.read(filename) do
      {:ok, content} ->
        content |> String.split("\n") |> Enum.at(1)
        |> String.split(":") |> Enum.at(1) |> String.trim()

      {:error, reason} ->
        IO.puts("Error reading file!")
    end
  end

  def get_opposite_player(player, players) do
    opposite_colour = get_opposite_colour(player)
    Enum.find(players, fn p -> get_piece_colour(p) == opposite_colour end)
  end

  # Shows the data of a player. This includes the name and the number of hit and beared off
  # pieces in case they are not 0.
  def show_data(player) do
    IO.write(Player.get_name(player) <> " (#{Player.get_piece_colour(player)})")

    if Player.get_hit_pieces(player) > 0 do
      IO.write(" | Hit: " <> Integer.to_string(Player.get_hit_pieces(player)))
    end

    if Player.get_beared_pieces(player) > 0 do
      IO.write(" | Beared off: " <> Integer.to_string(Player.get_beared_pieces(player)))
    end

    IO.write("\n")
  end
end
