defmodule Hermes.Bluesky.Util do
  @moduledoc false

  def camelize_request_opts(opts) when is_list(opts) do
    Enum.map(opts, fn
      {:params, params} -> {:params, camelize_keys(params)}
      {:json, json} -> {:json, camelize_keys(json)}
      other -> other
    end)
  end

  def camelize_keys(value) when is_map(value) do
    value
    |> Enum.map(fn {key, item} -> {camelize_key(key), camelize_keys(item)} end)
    |> Enum.into(%{})
  end

  def camelize_keys(value) when is_list(value) do
    if Keyword.keyword?(value) do
      value
      |> Enum.into(%{})
      |> camelize_keys()
    else
      Enum.map(value, &camelize_keys/1)
    end
  end

  def camelize_keys(value), do: value

  def camelize_key("$type"), do: "$type"

  def camelize_key(key) when is_atom(key) do
    key
    |> Atom.to_string()
    |> camelize_key()
  end

  def camelize_key(key) when is_binary(key) do
    cond do
      key == "" ->
        key

      String.starts_with?(key, "$") ->
        key

      String.contains?(key, "_") ->
        key
        |> Macro.camelize()
        |> lower_first()

      true ->
        key
    end
  end

  def maybe_put(map, _key, nil), do: map
  def maybe_put(map, _key, ""), do: map
  def maybe_put(map, key, value), do: Map.put(map, key, value)

  def map_value(map, atom_key, string_key \\ nil, default \\ nil) when is_map(map) do
    string_key = string_key || Atom.to_string(atom_key)

    cond do
      Map.has_key?(map, atom_key) -> Map.get(map, atom_key)
      Map.has_key?(map, string_key) -> Map.get(map, string_key)
      true -> default
    end
  end

  def compact_map(map) when is_map(map) do
    map
    |> Enum.reject(fn
      {_key, nil} -> true
      {_key, ""} -> true
      {_key, []} -> true
      _ -> false
    end)
    |> Enum.into(%{})
  end

  def iso8601_now do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end

  def to_list(nil), do: []
  def to_list(value) when is_list(value), do: value
  def to_list(value), do: [value]

  def public_endpoint do
    Application.get_env(:hermes_bluesky, :public_endpoint, "https://public.api.bsky.app")
  end

  defp lower_first(<<first::utf8, rest::binary>>) do
    String.downcase(<<first::utf8>>) <> rest
  end
end
