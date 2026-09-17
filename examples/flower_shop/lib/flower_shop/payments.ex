defmodule FlowerShop.Payments do
  @moduledoc """
  A mock payment handler. Tokens spelled `fail_token` are declined, everything
  else (tokens, raw cards, bound tokens, AP2 mandates) is authorized.
  """

  @doc "Authorizes the instruments in a complete request."
  def authorize([]), do: {:error, "No payment instrument was provided"}

  def authorize(instruments) when is_list(instruments) do
    if Enum.any?(instruments, &declined?/1) do
      {:error, "Payment was declined by the payment handler"}
    else
      :ok
    end
  end

  def authorize(_), do: {:error, "Payment instruments must be a list"}

  defp declined?(%{"credential" => %{"token" => "fail_token"}}), do: true
  defp declined?(_instrument), do: false
end
