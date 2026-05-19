defmodule HermesTrictrac.Identity do
  alias Hermes.Bluesky.Phoenix.Conn, as: BlueskyConn
  alias Hermes.Bluesky.Session, as: BlueskySession

  @type mode :: :manual | :bluesky_oauth

  @type t :: %{
          mode: :bluesky_oauth,
          auth_id: String.t(),
          did: String.t(),
          handle: String.t(),
          name: String.t(),
          session_key: String.t() | nil
        }

  def mode do
    Application.get_env(:hermes_trictrac, :identity_mode, :manual)
    |> normalize_mode()
  end

  def manual?, do: mode() == :manual
  def bluesky_oauth?, do: mode() == :bluesky_oauth
  def manual?(:manual), do: true
  def manual?(_mode), do: false
  def bluesky_oauth?(:bluesky_oauth), do: true
  def bluesky_oauth?(_mode), do: false

  def from_conn(conn) do
    if bluesky_oauth?() do
      case BlueskyConn.current_session_key(conn) do
        session_key when is_binary(session_key) -> from_session_key(session_key)
        _ -> :error
      end
    else
      :error
    end
  end

  def from_session_map(session) when is_map(session) do
    if bluesky_oauth?() do
      case Map.get(session, "atex_active_session") || Map.get(session, :atex_active_session) do
        session_key when is_binary(session_key) -> from_session_key(session_key)
        _ -> :error
      end
    else
      :error
    end
  end

  def from_session_map(_session), do: :error

  def from_session_key(session_key) when is_binary(session_key) do
    with {:ok, session} <- resolve_session(session_key),
         identity when not is_nil(identity) <- build_identity(session, session_key) do
      {:ok, identity}
    else
      :error -> :error
      {:error, _reason} = error -> error
      _ -> :error
    end
  end

  def from_session_key(_session_key), do: :error

  def display_name(%{handle: handle}) when is_binary(handle) and handle != "", do: handle
  def display_name(%{name: name}) when is_binary(name) and name != "", do: name
  def display_name(_identity), do: nil

  def sanitize_return_to(nil), do: "/"
  def sanitize_return_to(""), do: "/"

  def sanitize_return_to(return_to) when is_binary(return_to) do
    if String.starts_with?(return_to, "/") and not String.starts_with?(return_to, "//") do
      return_to
    else
      "/"
    end
  end

  defp normalize_mode(:manual), do: :manual
  defp normalize_mode(:bluesky_oauth), do: :bluesky_oauth
  defp normalize_mode("manual"), do: :manual
  defp normalize_mode("bluesky_oauth"), do: :bluesky_oauth
  defp normalize_mode(_other), do: :manual

  defp resolve_session(session_key) do
    case Application.get_env(:hermes_trictrac, :identity_session_resolver) do
      resolver when is_function(resolver, 1) ->
        resolver.(session_key)

      {module, function, extra_args} when is_atom(module) and is_atom(function) and is_list(extra_args) ->
        apply(module, function, [session_key | extra_args])

      _ ->
        BlueskySession.from_session_key(session_key)
    end
  end

  defp build_identity(%{did: did, handle: handle}, session_key)
       when is_binary(did) and is_binary(handle) and handle != "" do
    %{
      mode: :bluesky_oauth,
      auth_id: did,
      did: did,
      handle: handle,
      name: handle,
      session_key: session_key
    }
  end

  defp build_identity(%{did: did}, session_key) when is_binary(did) do
    %{
      mode: :bluesky_oauth,
      auth_id: did,
      did: did,
      handle: did,
      name: did,
      session_key: session_key
    }
  end

  defp build_identity(_session, _session_key), do: nil
end
