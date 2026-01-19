defmodule Bazaar.Phoenix.Controller do
  @moduledoc """
  Phoenix controller that dispatches to your UCP handler.

  This controller is used internally by `Bazaar.Phoenix.Router`.
  You don't need to use it directly.
  """

  use Phoenix.Controller, formats: [:json]

  alias Bazaar.Schemas.DiscoveryProfile

  # Discovery

  def discovery(conn, _params) do
    handler = conn.assigns.bazaar_handler
    base_url = get_base_url(conn)

    profile =
      DiscoveryProfile.from_handler(handler, base_url: base_url)
      |> Ecto.Changeset.apply_changes()

    json(conn, profile)
  end

  # Checkout

  def create_checkout(conn, params) do
    handler = conn.assigns.bazaar_handler

    case handler.create_checkout(params, conn) do
      {:ok, checkout} ->
        conn
        |> put_status(:created)
        |> json(checkout)

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.from_changeset(changeset))

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.from_reason(reason))
    end
  end

  def get_checkout(conn, %{"id" => id}) do
    handler = conn.assigns.bazaar_handler

    case handler.get_checkout(id, conn) do
      {:ok, checkout} ->
        json(conn, checkout)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(Bazaar.Errors.not_found("checkout_session", id))

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.from_reason(reason))
    end
  end

  def update_checkout(conn, %{"id" => id} = params) do
    handler = conn.assigns.bazaar_handler
    update_params = Map.delete(params, "id")

    case handler.update_checkout(id, update_params, conn) do
      {:ok, checkout} ->
        json(conn, checkout)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(Bazaar.Errors.not_found("checkout_session", id))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.from_changeset(changeset))

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.from_reason(reason))
    end
  end

  def cancel_checkout(conn, %{"id" => id}) do
    handler = conn.assigns.bazaar_handler

    case handler.cancel_checkout(id, conn) do
      {:ok, checkout} ->
        json(conn, checkout)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(Bazaar.Errors.not_found("checkout_session", id))

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.from_reason(reason))
    end
  end

  # Orders

  def get_order(conn, %{"id" => id}) do
    handler = conn.assigns.bazaar_handler

    case handler.get_order(id, conn) do
      {:ok, order} ->
        json(conn, order)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(Bazaar.Errors.not_found("order", id))

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.from_reason(reason))
    end
  end

  def cancel_order(conn, %{"id" => id}) do
    handler = conn.assigns.bazaar_handler

    case handler.cancel_order(id, conn) do
      {:ok, order} ->
        json(conn, order)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(Bazaar.Errors.not_found("order", id))

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.from_reason(reason))
    end
  end

  # Identity

  def link_identity(conn, params) do
    handler = conn.assigns.bazaar_handler

    case handler.link_identity(params, conn) do
      {:ok, result} ->
        json(conn, result)

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.from_reason(reason))
    end
  end

  # Webhooks

  def webhook(conn, params) do
    handler = conn.assigns.bazaar_handler

    case handler.handle_webhook(params) do
      {:ok, _result} ->
        conn
        |> put_status(:ok)
        |> json(%{status: "processed"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.from_reason(reason))
    end
  end

  # Helpers

  defp get_base_url(conn) do
    scheme = if conn.scheme == :https, do: "https", else: "http"
    port_suffix = if conn.port in [80, 443], do: "", else: ":#{conn.port}"
    "#{scheme}://#{conn.host}#{port_suffix}"
  end
end
