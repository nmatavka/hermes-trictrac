Code.require_file("backgammon/game/game_headers.exs")
Code.require_file("backgammon/game/game_round.exs")
Code.require_file("backgammon/player/player_builder.exs")

defmodule GameController do

  # Starts the application and displays the options the user can choose from.
  def start_game() do
    GameHeaders.start_header()
    get_choice()
    GameHeaders.end_header()
  end

  # Starts a Backgammon round played against a human on the same machine.
  defp play_against_human() do
    IO.write("\n")
    filename = get_filename()

    player = PlayerBuilder.default_build_white(Player.get_player1(filename))
    opponent = PlayerBuilder.default_build_black(Player.get_player2(filename))
    GameRound.start_round(player, opponent)

    get_choice()
  end

  # Starts a Backgammon round played against an AI that plays the best moves.
  defp play_against_AI() do
    IO.write("\n")
    filename = get_filename()

    player = PlayerBuilder.default_build_white(Player.get_player1(filename))
    opponent = PlayerBuilder.default_build_black("AI")
    GameRound.start_ai_round(player, opponent)

    get_choice()
  end

  # Allows the user to change the names of the 2 players that are displayed in a
  # game against another human on the same machine. Player1 will play with the
  # white pieces and Player2 will play with the black pieces.
  defp player_settings() do
    IO.write("\n")

    filename = "backgammon/files/player_data.txt"
    if !File.exists?(filename) do
      text = "Player1:\nPlayer2:"
      File.write!(filename, text)
    end

    case File.read(filename) do
      {:ok, content} ->
        player_settings_change(filename, content)
        IO.puts("Settings were saved!\n")
      {:error, reason} ->
        IO.puts("Error reading file: #{reason}")
    end

    get_choice()
  end

  # Auxiliary function to change the settings of the application.
  defp player_settings_change(filename, content) do
    IO.puts("Your current settings are:")
    content
    |> String.split("\n", trim: true)
    |> Enum.each(&IO.puts/1)

    new_content1 = "Player1: " <> IO.gets("New Player1: ") |> to_string |> String.trim()
    new_content2 = "Player2: " <> IO.gets("New Player2: ") |> to_string |> String.trim()

    File.write!(filename, new_content1 <> "\n" <> new_content2)
  end

  # Allows the user to gracefully exit the application.
  defp player_exit() do
    GameHeaders.exit_header()
    System.stop(0)
  end

  # Auxliary function which allows the user to pick from one of the 4 options.
  defp get_choice() do
    choice = IO.gets("Choice: ")
    |> String.trim()

    case Integer.parse(choice) do
      {num, _} when num in 1..4 -> handle_choice(num)
      _ -> get_choice_fail()
    end
  end

  defp handle_choice(1), do: play_against_human()

  defp handle_choice(2), do: play_against_AI()

  defp handle_choice(3), do: player_settings()

  defp handle_choice(4), do: player_exit()

  defp handle_choice(_), do: get_choice_fail()

  # Auxiliary helper function to inform the user in the case they chose an invalid option.
  # Acts as a loop as the user is allowed to choose again after failing.
  defp get_choice_fail() do
    IO.puts("Sorry for this primitive UI! Please choose a valid option (1 - 4)!")
    get_choice()
  end

  # Returns the name of the file in which the player data is stored in.
  defp get_filename() do
    _filename = "backgammon/files/player_data.txt"
  end
end
