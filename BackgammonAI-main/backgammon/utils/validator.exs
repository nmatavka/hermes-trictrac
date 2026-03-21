defmodule Validator do

  # Helper function to get a valid integer from the user.
  def get_valid_integer(prompt) do
    case IO.gets(prompt) |> String.trim() |> Integer.parse() do
      {num, ""} ->
        num
      _ ->
        IO.puts("Invalid integer!")
        get_valid_integer(prompt)
    end
  end

  # Helper funtion to validate that an integer is between a range [min, max].
  def validate_interval(num, min, max) do
    cond do
      num < min -> false
      num > max -> false
      true -> true
    end
  end

end
