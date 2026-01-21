defmodule Bazaar.ProtocolTest do
  use ExUnit.Case, async: true

  alias Bazaar.Protocol

  describe "protocol types" do
    test "type/0 returns valid protocol types" do
      assert Protocol.types() == [:ucp, :acp]
    end

    test "valid?/1 returns true for valid protocols" do
      assert Protocol.valid?(:ucp)
      assert Protocol.valid?(:acp)
    end

    test "valid?/1 returns false for invalid protocols" do
      refute Protocol.valid?(:invalid)
      refute Protocol.valid?(nil)
      refute Protocol.valid?("ucp")
    end
  end

  describe "UCP statuses" do
    test "ucp_statuses/0 returns all UCP checkout statuses" do
      statuses = Protocol.ucp_statuses()

      assert :incomplete in statuses
      assert :requires_escalation in statuses
      assert :ready_for_complete in statuses
      assert :complete_in_progress in statuses
      assert :completed in statuses
      assert :canceled in statuses
    end
  end

  describe "ACP statuses" do
    test "acp_statuses/0 returns all ACP checkout statuses" do
      statuses = Protocol.acp_statuses()

      assert :not_ready_for_payment in statuses
      assert :authentication_required in statuses
      assert :ready_for_payment in statuses
      assert :in_progress in statuses
      assert :completed in statuses
      assert :canceled in statuses
    end
  end

  describe "status mapping: UCP to ACP" do
    test "maps incomplete to not_ready_for_payment" do
      assert Protocol.to_acp_status(:incomplete) == :not_ready_for_payment
    end

    test "maps requires_escalation to authentication_required" do
      assert Protocol.to_acp_status(:requires_escalation) == :authentication_required
    end

    test "maps ready_for_complete to ready_for_payment" do
      assert Protocol.to_acp_status(:ready_for_complete) == :ready_for_payment
    end

    test "maps complete_in_progress to in_progress" do
      assert Protocol.to_acp_status(:complete_in_progress) == :in_progress
    end

    test "keeps completed as completed" do
      assert Protocol.to_acp_status(:completed) == :completed
    end

    test "keeps canceled as canceled" do
      assert Protocol.to_acp_status(:canceled) == :canceled
    end

    test "handles string input" do
      assert Protocol.to_acp_status("incomplete") == :not_ready_for_payment
      assert Protocol.to_acp_status("ready_for_complete") == :ready_for_payment
    end
  end

  describe "status mapping: ACP to UCP" do
    test "maps not_ready_for_payment to incomplete" do
      assert Protocol.to_ucp_status(:not_ready_for_payment) == :incomplete
    end

    test "maps authentication_required to requires_escalation" do
      assert Protocol.to_ucp_status(:authentication_required) == :requires_escalation
    end

    test "maps ready_for_payment to ready_for_complete" do
      assert Protocol.to_ucp_status(:ready_for_payment) == :ready_for_complete
    end

    test "maps in_progress to complete_in_progress" do
      assert Protocol.to_ucp_status(:in_progress) == :complete_in_progress
    end

    test "keeps completed as completed" do
      assert Protocol.to_ucp_status(:completed) == :completed
    end

    test "keeps canceled as canceled" do
      assert Protocol.to_ucp_status(:canceled) == :canceled
    end

    test "handles string input" do
      assert Protocol.to_ucp_status("not_ready_for_payment") == :incomplete
      assert Protocol.to_ucp_status("ready_for_payment") == :ready_for_complete
    end
  end
end
