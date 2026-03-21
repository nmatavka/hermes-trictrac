defmodule Matrix do
  # Creates a new matrix with a specified size and populated with a given value.
  def new(row, col, value) do
    List.duplicate(List.duplicate(value, col), row)
  end

 # Creates an identity matrix of size n x n
 def ident(n), do: ident(n, n)

 defp ident(n, index) when index > 0 do
   row = List.duplicate(0, n) |> List.update_at(n - index, fn _ -> 1 end)
   [row | ident(n, index - 1)]
 end

 # Base case: return an empty list
 defp ident(_n, 0), do: []

  # Gets the element from a matrix at a specified position.
  def get(matrix, row, col) do
    matrix
    |> Enum.at(row)
    |> Enum.at(col)
  end

  # Sets the element of a matrix at a specified position with a new given value.
  def set(matrix, row, col, value) do
    List.update_at(matrix, row, fn r ->
      List.update_at(r, col, fn _ -> value end)
    end)
  end

  # Rotates the matrix 180 degrees.
  def rotate(matrix) do
    matrix
    |> Enum.reverse()
    |> Enum.map(&Enum.reverse/1)
  end
end
