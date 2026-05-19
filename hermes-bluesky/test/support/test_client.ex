defmodule Hermes.Bluesky.TestClient do
  @behaviour Atex.XRPC.Client

  defstruct responses: %{}, requests: []

  def new(responses \\ %{}) do
    normalized =
      Enum.into(responses, %{}, fn {key, value} ->
        values = if is_list(value), do: value, else: [value]
        {key, values}
      end)

    %__MODULE__{responses: normalized}
  end

  @impl true
  def get(%__MODULE__{} = client, resource, opts \\ []) do
    reply(client, :get, resource, opts)
  end

  @impl true
  def post(%__MODULE__{} = client, resource, opts \\ []) do
    reply(client, :post, resource, opts)
  end

  defp reply(%__MODULE__{} = client, method, resource, opts) do
    key = {method, resource}
    requests = client.requests ++ [{method, resource, opts}]
    {response, responses} = pop_response(client.responses, key)
    client = %{client | requests: requests, responses: responses}

    case response do
      {:ok, body} ->
        {:ok, %Req.Response{status: 200, body: body}, client}

      {:ok, status, body} ->
        {:ok, %Req.Response{status: status, body: body}, client}

      {:error, status, body} ->
        {:error, %Req.Response{status: status, body: body}, client}

      {:error, reason} ->
        {:error, reason, client}

      nil ->
        {:error, :no_mock_response, client}
    end
  end

  defp pop_response(responses, key) do
    case Map.get(responses, key, []) do
      [response | rest] -> {response, Map.put(responses, key, rest)}
      [] -> {nil, responses}
    end
  end
end
