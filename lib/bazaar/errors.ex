defmodule Bazaar.Errors do
  @moduledoc """
  Error formatting utilities for UCP API responses.

  Converts Ecto changesets and error reasons into UCP-compliant
  error response formats.
  """

  @doc """
  Converts an Ecto changeset to a UCP error response.

  ## Example

      changeset = Bazaar.Checkout.new(%{})
      Bazaar.Errors.from_changeset(changeset)
      # => %{
      #   "error" => "validation_error",
      #   "message" => "Validation failed",
      #   "details" => [
      #     %{"field" => "currency", "message" => "can't be blank"}
      #   ]
      # }
  """
  def from_changeset(%Ecto.Changeset{} = changeset) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
          opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
        end)
      end)

    details =
      errors
      |> flatten_errors()
      |> Enum.map(fn {field, message} ->
        %{"field" => to_string(field), "message" => message}
      end)

    %{
      "error" => "validation_error",
      "message" => "Validation failed",
      "details" => details
    }
  end

  @doc """
  Creates a not found error response.

  ## Example

      Bazaar.Errors.not_found("checkout_session", "sess_123")
      # => %{
      #   "error" => "not_found",
      #   "message" => "checkout_session not found",
      #   "resource_type" => "checkout_session",
      #   "resource_id" => "sess_123"
      # }
  """
  def not_found(resource_type, resource_id) do
    %{
      "error" => "not_found",
      "message" => "#{resource_type} not found",
      "resource_type" => resource_type,
      "resource_id" => resource_id
    }
  end

  @doc """
  Converts an error reason atom or string to a UCP error response.
  """
  def from_reason(:not_found), do: %{"error" => "not_found", "message" => "Resource not found"}

  def from_reason(:unauthorized),
    do: %{"error" => "unauthorized", "message" => "Authentication required"}

  def from_reason(:forbidden), do: %{"error" => "forbidden", "message" => "Access denied"}

  def from_reason(:invalid_state),
    do: %{"error" => "invalid_state", "message" => "Operation not allowed in current state"}

  def from_reason(:already_cancelled),
    do: %{"error" => "already_cancelled", "message" => "Resource is already cancelled"}

  def from_reason(:expired), do: %{"error" => "expired", "message" => "Resource has expired"}

  def from_reason(reason) when is_binary(reason) do
    %{"error" => "error", "message" => reason}
  end

  def from_reason(reason) when is_atom(reason) do
    %{"error" => to_string(reason), "message" => humanize(reason)}
  end

  def from_reason(reason) do
    %{"error" => "error", "message" => inspect(reason)}
  end

  # Helpers

  defp flatten_errors(errors, prefix \\ []) do
    Enum.flat_map(errors, fn
      {field, messages} when is_list(messages) ->
        field_path = prefix ++ [field]

        Enum.flat_map(messages, fn
          message when is_binary(message) ->
            [{Enum.join(field_path, "."), message}]

          nested when is_map(nested) ->
            flatten_errors(nested, field_path)
        end)

      {field, nested} when is_map(nested) ->
        flatten_errors(nested, prefix ++ [field])
    end)
  end

  defp humanize(atom) do
    atom
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end
end
