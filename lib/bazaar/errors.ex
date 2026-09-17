defmodule Bazaar.Errors do
  @moduledoc """
  Error documents for API responses.

  UCP errors are the spec's error response: a `ucp` envelope with
  `status: "error"` and a list of `messages`. ACP errors are the ACP `Error`
  object with `type`, `code` and `message`. `response/2` renders either from a
  changeset or an error reason.

  ## Example

      Bazaar.Errors.response(:not_found)
      # => %{
      #   "ucp" => %{"version" => "2026-08-25", "status" => "error"},
      #   "messages" => [
      #     %{"type" => "error", "code" => "not_found", "content" => "Resource not found",
      #       "severity" => "unrecoverable"}
      #   ]
      # }

      Bazaar.Errors.response(:not_found, protocol: :acp)
      # => %{"type" => "invalid_request", "code" => "not_found", "message" => "Resource not found"}
  """

  @known_reasons %{
    not_found: {"Resource not found", "unrecoverable"},
    invalid_state: {"Operation not allowed in current state", "unrecoverable"},
    idempotency_conflict:
      {"Idempotency-Key was already used with a different request", "unrecoverable"},
    unauthorized: {"Authentication required", "unrecoverable"},
    forbidden: {"Access denied", "unrecoverable"},
    already_cancelled: {"Resource is already cancelled", "unrecoverable"},
    expired: {"Resource has expired", "unrecoverable"}
  }

  @doc """
  Renders an error document for a changeset or an error reason.

  ## Options

  - `:protocol` - `:ucp` (default) or `:acp`
  """
  def response(reason_or_changeset, opts \\ []) do
    messages = messages(reason_or_changeset)

    case Keyword.get(opts, :protocol, :ucp) do
      :ucp -> ucp_document(messages)
      :acp -> acp_document(reason_or_changeset, messages)
    end
  end

  @doc """
  Flattens a changeset's errors into `%{"field" => "a.b", "message" => "..."}`
  entries, with interpolated messages.
  """
  def changeset_details(%Ecto.Changeset{} = changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> flatten_errors()
    |> Enum.map(fn {field, message} -> %{"field" => field, "message" => message} end)
  end

  # UCP messages, one per problem

  defp messages(%Ecto.Changeset{} = changeset) do
    changeset
    |> changeset_details()
    |> Enum.map(fn %{"field" => field, "message" => message} ->
      error_message(
        "invalid_request",
        "#{field} #{message}",
        "requires_buyer_input",
        "$." <> field
      )
    end)
  end

  defp messages({:unsupported_version, requested, supported}) do
    [
      error_message(
        "unsupported_version",
        "UCP version #{requested} is not supported, this server speaks #{supported}",
        "unrecoverable"
      )
    ]
  end

  defp messages(reason) when is_map_key(@known_reasons, reason) do
    {content, severity} = Map.fetch!(@known_reasons, reason)
    [error_message(to_string(reason), content, severity)]
  end

  defp messages(reason) when is_atom(reason) do
    [error_message(to_string(reason), humanize(reason), "unrecoverable")]
  end

  defp messages(reason) when is_binary(reason),
    do: [error_message("error", reason, "unrecoverable")]

  defp messages(reason), do: [error_message("error", inspect(reason), "unrecoverable")]

  defp error_message(code, content, severity, path \\ nil) do
    %{"type" => "error", "code" => code, "content" => content, "severity" => severity}
    |> then(fn message -> if path, do: Map.put(message, "path", path), else: message end)
  end

  defp ucp_document(messages) do
    %{
      "ucp" => %{"version" => Bazaar.DiscoveryProfile.version(), "status" => "error"},
      "messages" => messages
    }
  end

  # ACP has one error object per response; its `type` classifies the failure.

  defp acp_document(reason, messages) do
    [first | _] = messages

    %{
      "type" => acp_type(reason),
      "code" => first["code"],
      "message" => Enum.map_join(messages, "; ", & &1["content"])
    }
    |> then(fn error ->
      if first["path"], do: Map.put(error, "param", first["path"]), else: error
    end)
  end

  defp acp_type(%Ecto.Changeset{}), do: "invalid_request"
  defp acp_type(reason) when reason in [:not_found, :invalid_state], do: "invalid_request"
  defp acp_type(:idempotency_conflict), do: "request_not_idempotent"
  defp acp_type({:unsupported_version, _, _}), do: "invalid_request"
  defp acp_type(_), do: "processing_error"

  defp flatten_errors(errors, prefix \\ []) do
    Enum.flat_map(errors, fn
      {field, messages} when is_list(messages) ->
        field_path = prefix ++ [field]

        Enum.flat_map(messages, fn
          message when is_binary(message) -> [{Enum.join(field_path, "."), message}]
          nested when is_map(nested) -> flatten_errors(nested, field_path)
        end)

      {field, nested} when is_map(nested) ->
        flatten_errors(nested, prefix ++ [field])
    end)
  end

  defp humanize(atom) do
    atom |> to_string() |> String.replace("_", " ") |> String.capitalize()
  end
end
