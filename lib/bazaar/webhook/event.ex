defmodule Bazaar.Webhook.Event do
  @moduledoc """
  One order event to deliver: the order document encoded once, with the
  `Webhook-Id` and `Webhook-Timestamp` that identify it. Nothing here changes
  between delivery attempts, which is what lets the platform deduplicate
  retries.
  """

  @enforce_keys [:id, :timestamp, :url, :order, :body]
  defstruct [:id, :timestamp, :url, :order, :body]

  @type t :: %__MODULE__{
          id: String.t(),
          timestamp: integer(),
          url: String.t(),
          order: map(),
          body: binary()
        }

  @doc false
  def new(order, url) when is_map(order) and is_binary(url) do
    %__MODULE__{
      id: uuid(),
      timestamp: System.os_time(:second),
      url: url,
      order: order,
      body: JSON.encode!(order)
    }
  end

  defp uuid do
    <<a::32, b::16, c::16, d::16, e::48>> = :crypto.strong_rand_bytes(16)

    [a, b, c, d, e]
    |> Enum.zip([8, 4, 4, 4, 12])
    |> Enum.map_join("-", fn {part, width} ->
      part |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(width, "0")
    end)
  end
end
