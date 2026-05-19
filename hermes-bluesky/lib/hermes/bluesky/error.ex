defmodule Hermes.Bluesky.Error do
  @moduledoc """
  Normalized request error returned by the Hermes Bluesky SDK.
  """

  defexception [:status, :body, :reason, :message, :response]

  @type t :: %__MODULE__{
          status: non_neg_integer() | nil,
          body: any(),
          reason: any(),
          message: String.t() | nil,
          response: Req.Response.t() | nil
        }

  @spec from_response(Req.Response.t()) :: t()
  def from_response(%Req.Response{} = response) do
    body = response.body

    %__MODULE__{
      status: response.status,
      body: body,
      response: response,
      message: extract_message(body) || "XRPC request failed with status #{response.status}"
    }
  end

  @spec from_reason(any()) :: t()
  def from_reason(reason) do
    %__MODULE__{
      reason: reason,
      message: "XRPC request failed: #{inspect(reason)}"
    }
  end

  defp extract_message(%{"message" => message}) when is_binary(message), do: message
  defp extract_message(%{message: message}) when is_binary(message), do: message
  defp extract_message(%{"error" => error}) when is_binary(error), do: error
  defp extract_message(%{error: error}) when is_binary(error), do: error
  defp extract_message(_), do: nil
end
