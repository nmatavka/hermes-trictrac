defmodule HermesTrictrac.Rules.Trictrac.Classique.Dice do
  @type t :: %{
          optional(:values) => [integer()],
          optional(:moves) => [integer()],
          optional(:moves_left) => [integer()],
          optional(:moves_played) => [integer()]
        }

  @spec values(t() | nil) :: [integer()]
  def values(%{values: values}) when is_list(values), do: values
  def values(_dice), do: []

  @spec normalized_throw(t() | nil) :: [integer()]
  def normalized_throw(dice), do: dice |> values() |> Enum.sort()

  @spec double?(t() | nil) :: boolean()
  def double?(dice) do
    case values(dice) do
      [first, second | rest] -> Enum.all?([second | rest], &(&1 == first))
      _ -> false
    end
  end

  @spec faces(t() | nil) :: {:ok, {integer(), integer()}} | :error
  def faces(dice) do
    case dice |> values() |> Enum.take(2) do
      [first, second] -> {:ok, {first, second}}
      _ -> :error
    end
  end

  @spec first(t() | nil) :: integer() | nil
  def first(dice), do: List.first(values(dice))

  @spec last(t() | nil) :: integer() | nil
  def last(dice), do: List.last(values(dice))

  @spec low(t() | nil) :: integer() | nil
  def low(dice), do: dice |> values() |> Enum.min(fn -> nil end)

  @spec total(t() | nil) :: integer()
  def total(dice), do: Enum.sum(values(dice))

  @spec has_two_faces?(t() | nil) :: boolean()
  def has_two_faces?(dice), do: match?({:ok, _faces}, faces(dice))
end
