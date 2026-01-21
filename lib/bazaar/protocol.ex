defmodule Bazaar.Protocol do
  @moduledoc """
  Protocol constants and status mappings for UCP and ACP protocols.

  This module provides bidirectional status mapping between UCP (Universal Commerce Protocol)
  and ACP (Agentic Commerce Protocol) checkout statuses.

  ## Status Mappings

  | UCP (Internal)        | ACP                    |
  |-----------------------|------------------------|
  | `incomplete`          | `not_ready_for_payment`|
  | `requires_escalation` | `authentication_required`|
  | `ready_for_complete`  | `ready_for_payment`    |
  | `complete_in_progress`| `in_progress`          |
  | `completed`           | `completed`            |
  | `canceled`            | `canceled`             |

  ## Usage

      # Check protocol validity
      Bazaar.Protocol.valid?(:ucp)  # true
      Bazaar.Protocol.valid?(:acp)  # true

      # Convert status from UCP to ACP
      Bazaar.Protocol.to_acp_status(:incomplete)  # :not_ready_for_payment

      # Convert status from ACP to UCP
      Bazaar.Protocol.to_ucp_status(:ready_for_payment)  # :ready_for_complete
  """

  @type t :: :ucp | :acp

  @ucp_statuses [
    :incomplete,
    :requires_escalation,
    :ready_for_complete,
    :complete_in_progress,
    :completed,
    :canceled
  ]

  @acp_statuses [
    :not_ready_for_payment,
    :authentication_required,
    :ready_for_payment,
    :in_progress,
    :completed,
    :canceled
  ]

  # Bidirectional status mapping
  @ucp_to_acp %{
    incomplete: :not_ready_for_payment,
    requires_escalation: :authentication_required,
    ready_for_complete: :ready_for_payment,
    complete_in_progress: :in_progress,
    completed: :completed,
    canceled: :canceled
  }

  @acp_to_ucp %{
    not_ready_for_payment: :incomplete,
    authentication_required: :requires_escalation,
    ready_for_payment: :ready_for_complete,
    in_progress: :complete_in_progress,
    completed: :completed,
    canceled: :canceled
  }

  @doc """
  Returns the list of valid protocol types.
  """
  @spec types() :: [t()]
  def types, do: [:ucp, :acp]

  @doc """
  Returns true if the given value is a valid protocol type.
  """
  @spec valid?(term()) :: boolean()
  def valid?(:ucp), do: true
  def valid?(:acp), do: true
  def valid?(_), do: false

  @doc """
  Returns the list of UCP checkout statuses.
  """
  @spec ucp_statuses() :: [atom()]
  def ucp_statuses, do: @ucp_statuses

  @doc """
  Returns the list of ACP checkout statuses.
  """
  @spec acp_statuses() :: [atom()]
  def acp_statuses, do: @acp_statuses

  @doc """
  Converts a UCP status to its ACP equivalent.

  Accepts both atom and string input.

  ## Examples

      iex> Bazaar.Protocol.to_acp_status(:incomplete)
      :not_ready_for_payment

      iex> Bazaar.Protocol.to_acp_status("ready_for_complete")
      :ready_for_payment
  """
  @spec to_acp_status(atom() | String.t()) :: atom()
  def to_acp_status(status) when is_binary(status) do
    status |> String.to_existing_atom() |> to_acp_status()
  end

  def to_acp_status(status) when is_atom(status) do
    Map.fetch!(@ucp_to_acp, status)
  end

  @doc """
  Converts an ACP status to its UCP equivalent.

  Accepts both atom and string input.

  ## Examples

      iex> Bazaar.Protocol.to_ucp_status(:not_ready_for_payment)
      :incomplete

      iex> Bazaar.Protocol.to_ucp_status("ready_for_payment")
      :ready_for_complete
  """
  @spec to_ucp_status(atom() | String.t()) :: atom()
  def to_ucp_status(status) when is_binary(status) do
    status |> String.to_existing_atom() |> to_ucp_status()
  end

  def to_ucp_status(status) when is_atom(status) do
    Map.fetch!(@acp_to_ucp, status)
  end
end
