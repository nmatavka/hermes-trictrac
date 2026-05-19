defmodule HermesTrictrac.GameSnapshot do
  def with_chat(snapshot, chat) when is_map(snapshot), do: Map.put(snapshot, "chat", chat)

  def with_bot(snapshot, nil) when is_map(snapshot), do: Map.put(snapshot, "bot", nil)

  def with_bot(snapshot, bot) when is_map(snapshot) and is_map(bot) do
    Map.put(snapshot, "bot", %{
      "enabled" => true,
      "kind" => bot.kind,
      "name" => bot.name,
      "color" => Atom.to_string(bot.color)
    })
  end

  def with_seat_reclaim(snapshot, nil) when is_map(snapshot),
    do: Map.put(snapshot, "seat_reclaim", nil)

  def with_seat_reclaim(snapshot, reclaim) when is_map(snapshot) and is_map(reclaim) do
    public_reclaim =
      reclaim
      |> Map.take([:seat_color, :defender_name, :claimant_name, :expires_at_ms])
      |> Enum.into(%{}, fn {key, value} -> {Atom.to_string(key), value} end)

    Map.put(snapshot, "seat_reclaim", public_reclaim)
  end

  def with_viewer(snapshot, nil) when is_map(snapshot), do: Map.put(snapshot, "viewer", nil)
  def with_viewer(snapshot, viewer) when is_map(snapshot), do: Map.put(snapshot, "viewer", viewer)
end
