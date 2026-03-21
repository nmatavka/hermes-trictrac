Code.require_file("../utils/matrix.exs", __DIR__)
Code.require_file("dice.exs", __DIR__)

defmodule Board do
  # Creates and sets up the initial Backgammon board.
  def create() do
    Matrix.new(5, 26, "-")
    |> Matrix.set(4, 1, "B") |> Matrix.set(3, 1, "B")
    |> Matrix.set(4, 6, "W") |> Matrix.set(3, 6, "W") |> Matrix.set(2, 6, "W") |> Matrix.set(1, 6, "W") |> Matrix.set(0, 6, "W")
    |> Matrix.set(4, 8, "W") |> Matrix.set(3, 8, "W") |> Matrix.set(2, 8, "W")
    |> Matrix.set(4, 12, "B") |> Matrix.set(3, 12, "B") |> Matrix.set(2, 12, "B") |> Matrix.set(1, 12, "B") |> Matrix.set(0, 12, "B")
    |> Matrix.set(4, 13, "W") |> Matrix.set(3, 13, "W") |> Matrix.set(2, 13, "W") |> Matrix.set(1, 13, "W") |> Matrix.set(0, 13, "W")
    |> Matrix.set(4, 17, "B") |> Matrix.set(3, 17, "B") |> Matrix.set(2, 17, "B")
    |> Matrix.set(4, 19, "B") |> Matrix.set(3, 19, "B") |> Matrix.set(2, 19, "B") |> Matrix.set(1, 19, "B") |> Matrix.set(0, 19, "B")
    |> Matrix.set(4, 24, "W") |> Matrix.set(3, 24, "W")
  end

  # Returns the column at a given index.
  def get_col(board, 5, _col), do: []

  # The row should be given the value 0 by default.
  def get_col(board, row, col) do
    [Matrix.get(board, row, col)] ++ get_col(board, row + 1, col)
  end

  # Displays the board in the correct Backgammon format.
  def show(board) do
    IO.puts("\n============== BACKGAMMON BOARD ==============\n")

    top_half = board |> Enum.map(&Enum.slice(&1, 13..24))
    bottom_half = board |> Enum.map(&Enum.slice(&1, 1..12))
    print_column_numbers(13..24)

    formatted_top =
      top_half
      |> Enum.reverse()
      |> Enum.map(&format_row/1)
      |> Enum.join("\n")

    IO.puts(formatted_top)
    IO.puts("==============================================")

    formatted_bottom =
      bottom_half
      |> Enum.map(&Enum.reverse/1)
      |> Enum.map(&format_row/1)
      |> Enum.join("\n")

    IO.puts(formatted_bottom)
    print_column_numbers(12..1)

    IO.puts("\n==============================================\n")
  end

  # Prints column numbers for a given range.
  defp print_column_numbers(range) do
    numbers = range |> Enum.map(&String.pad_leading(Integer.to_string(&1), 2, " "))
    IO.puts(Enum.join(numbers, "  "))
  end

  # Formats a row with vertical dividers between points.
  defp format_row(row) do
    {left, right} = Enum.split(row, div(length(row), 2))
    Enum.join(left, " | ") <> " || " <> Enum.join(right, " | ")
  end
end
