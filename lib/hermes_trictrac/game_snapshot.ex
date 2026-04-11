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
end
