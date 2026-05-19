defmodule Hermes.Bluesky.XRPC do
  @moduledoc """
  Thin wrapper around `Atex.XRPC` that normalizes snake_case request inputs and
  propagates updated client state.
  """

  alias Hermes.Bluesky.Error
  alias Hermes.Bluesky.Session
  alias Hermes.Bluesky.Util

  @type auth_target :: Session.t() | Atex.XRPC.Client.client()

  @spec get(auth_target(), String.t(), keyword()) ::
          {:ok, any(), Session.t() | Atex.XRPC.Client.client()}
          | {:error, Error.t(), Session.t() | Atex.XRPC.Client.client()}
  def get(target, nsid, opts \\ []) do
    target
    |> invoke(:get, nsid, opts)
    |> normalize_result(target)
  end

  @spec post(auth_target(), String.t(), keyword()) ::
          {:ok, any(), Session.t() | Atex.XRPC.Client.client()}
          | {:error, Error.t(), Session.t() | Atex.XRPC.Client.client()}
  def post(target, nsid, opts \\ []) do
    target
    |> invoke(:post, nsid, opts)
    |> normalize_result(target)
  end

  @spec public_get(String.t(), String.t(), keyword()) :: {:ok, any()} | {:error, Error.t()}
  def public_get(endpoint \\ Util.public_endpoint(), nsid, opts \\ []) do
    endpoint
    |> Atex.XRPC.unauthed_get(nsid, Util.camelize_request_opts(opts))
    |> normalize_public_result()
  end

  @spec public_post(String.t(), String.t(), keyword()) :: {:ok, any()} | {:error, Error.t()}
  def public_post(endpoint, nsid, opts \\ []) do
    endpoint
    |> Atex.XRPC.unauthed_post(nsid, Util.camelize_request_opts(opts))
    |> normalize_public_result()
  end

  @spec auth_target?(term()) :: boolean()
  def auth_target?(%Session{}), do: true
  def auth_target?(%{__struct__: _}), do: true
  def auth_target?(_), do: false

  defp invoke(%Session{} = session, method, nsid, opts) do
    invoke(session.client, method, nsid, opts)
  end

  defp invoke(client, :get, nsid, opts),
    do: Atex.XRPC.get(client, nsid, Util.camelize_request_opts(opts))

  defp invoke(client, :post, nsid, opts),
    do: Atex.XRPC.post(client, nsid, Util.camelize_request_opts(opts))

  defp normalize_result({:ok, %Req.Response{body: body}, updated_client}, %Session{} = session) do
    {:ok, body, Session.update_client(session, updated_client)}
  end

  defp normalize_result({:ok, %Req.Response{body: body}, updated_client}, _client) do
    {:ok, body, updated_client}
  end

  defp normalize_result(
         {:error, %Req.Response{} = response, updated_client},
         %Session{} = session
       ) do
    {:error, Error.from_response(response), Session.update_client(session, updated_client)}
  end

  defp normalize_result({:error, %Req.Response{} = response, updated_client}, _client) do
    {:error, Error.from_response(response), updated_client}
  end

  defp normalize_result({:error, reason, updated_client}, %Session{} = session) do
    {:error, Error.from_reason(reason), Session.update_client(session, updated_client)}
  end

  defp normalize_result({:error, reason, updated_client}, _client) do
    {:error, Error.from_reason(reason), updated_client}
  end

  defp normalize_result({:error, reason}, %Session{} = session) do
    {:error, Error.from_reason(reason), session}
  end

  defp normalize_public_result({:ok, %Req.Response{status: status} = response})
       when status in 200..299 do
    {:ok, response.body}
  end

  defp normalize_public_result({:ok, %Req.Response{} = response}) do
    {:error, Error.from_response(response)}
  end

  defp normalize_public_result({:error, reason}) do
    {:error, Error.from_reason(reason)}
  end
end
