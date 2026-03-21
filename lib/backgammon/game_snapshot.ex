defmodule Backgammon.GameSnapshot do
  def with_chat(snapshot, chat) when is_map(snapshot), do: Map.put(snapshot, "chat", chat)
end
