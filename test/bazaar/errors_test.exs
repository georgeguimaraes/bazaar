defmodule Bazaar.ErrorsTest do
  use ExUnit.Case, async: true

  alias Bazaar.Errors

  describe "response/2 for UCP" do
    test "renders a reason as an error document that validates against the spec" do
      doc = Errors.response(:not_found)

      assert doc["ucp"]["status"] == "error"
      assert doc["ucp"]["version"] == Bazaar.DiscoveryProfile.version()

      assert [%{"type" => "error", "code" => "not_found", "severity" => "unrecoverable"}] =
               doc["messages"]

      assert {:ok, _} = Bazaar.Validator.validate(doc, :error_response)
    end

    test "renders a changeset as one message per field with a JSONPath" do
      doc = Bazaar.Schemas.Shopping.CheckoutResp.new(%{}) |> Errors.response()

      assert Enum.all?(doc["messages"], &(&1["code"] == "invalid_request"))
      paths = Enum.map(doc["messages"], & &1["path"])
      assert "$.currency" in paths
      assert {:ok, _} = Bazaar.Validator.validate(doc, :error_response)
    end

    test "interpolates changeset message variables" do
      changeset =
        {%{}, %{name: :string}}
        |> Ecto.Changeset.cast(%{name: "ab"}, [:name])
        |> Ecto.Changeset.validate_length(:name, min: 3)

      [message] = Errors.response(changeset)["messages"]
      assert message["content"] == "name should be at least 3 character(s)"
    end

    test "explains a version mismatch" do
      [message] = Errors.response({:unsupported_version, "2099-01-01", "2026-08-25"})["messages"]

      assert message["code"] == "unsupported_version"
      assert message["content"] =~ "2099-01-01"
    end

    test "humanizes unknown atoms and passes strings through" do
      assert [%{"code" => "invalid_token", "content" => "Invalid token"}] =
               Errors.response(:invalid_token)["messages"]

      assert [%{"code" => "error", "content" => "Card declined"}] =
               Errors.response("Card declined")["messages"]
    end
  end

  describe "response/2 for ACP" do
    test "maps reasons to the ACP error types" do
      assert %{"type" => "invalid_request", "code" => "not_found"} =
               Errors.response(:not_found, protocol: :acp)

      assert %{"type" => "request_not_idempotent"} =
               Errors.response(:idempotency_conflict, protocol: :acp)

      assert %{"type" => "processing_error", "code" => "boom"} =
               Errors.response(:boom, protocol: :acp)
    end

    test "collapses a changeset into one error with the first path as param" do
      error = Bazaar.Schemas.Shopping.CheckoutResp.new(%{}) |> Errors.response(protocol: :acp)

      assert error["type"] == "invalid_request"
      assert error["param"] =~ ~r/^\$\./
      assert error["message"] =~ "can't be blank"
    end
  end

  describe "changeset_details/1" do
    test "returns field and message entries" do
      changeset =
        {%{}, %{buyer: :map}}
        |> Ecto.Changeset.cast(%{}, [:buyer])
        |> Ecto.Changeset.validate_required([:buyer])

      assert [%{"field" => "buyer", "message" => "can't be blank"}] =
               Errors.changeset_details(changeset)
    end
  end
end
