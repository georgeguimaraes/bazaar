defmodule FlowerShop.Http do
  @moduledoc "The HTTP client functions bazaar's platform lookup and webhook delivery call."

  def get(url) do
    case Req.get(url, retry: false, receive_timeout: 5_000) do
      {:ok, %{status: status, body: body}} -> {:ok, %{status: status, body: body}}
      {:error, reason} -> {:error, reason}
    end
  end

  def post(url, body, headers) do
    case Req.post(url, body: body, headers: headers, retry: false, receive_timeout: 5_000) do
      {:ok, %{status: status, body: body}} -> {:ok, %{status: status, body: body}}
      {:error, reason} -> {:error, reason}
    end
  end
end
