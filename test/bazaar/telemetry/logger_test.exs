defmodule Bazaar.Telemetry.LoggerTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Bazaar.Telemetry.Logger

  describe "attach/1" do
    test "attaches telemetry handlers" do
      Logger.attach(handler_id: "test-attach")

      # Verify handler is attached by checking it can be detached
      assert :ok = :telemetry.detach("test-attach")
    end

    test "uses custom handler_id" do
      Logger.attach(handler_id: "my-custom-handler")
      assert :ok = :telemetry.detach("my-custom-handler")
    end
  end

  describe "detach/1" do
    test "detaches the handler" do
      Logger.attach(handler_id: "test-detach")
      assert :ok = Logger.detach(handler_id: "test-detach")

      # Trying to detach again should fail
      assert {:error, :not_found} = :telemetry.detach("test-detach")
    end
  end

  describe "handle_event/4" do
    setup do
      Logger.attach(handler_id: "test-logging", level: :info)
      on_exit(fn -> Logger.detach(handler_id: "test-logging") end)
      :ok
    end

    test "logs checkout create events" do
      log =
        capture_log(fn ->
          :telemetry.execute(
            [:bazaar, :checkout, :create, :stop],
            %{duration: 42_000_000},
            %{checkout_id: "chk_123", status: :incomplete}
          )
        end)

      assert log =~ "[Bazaar]"
      assert log =~ "checkout.create"
      assert log =~ "42ms"
      assert log =~ "chk_123"
    end

    test "logs order get events" do
      log =
        capture_log(fn ->
          :telemetry.execute(
            [:bazaar, :order, :get, :stop],
            %{duration: 15_000_000},
            %{order_id: "ord_456", status: :completed}
          )
        end)

      assert log =~ "order.get"
      assert log =~ "15ms"
      assert log =~ "ord_456"
    end

    test "logs webhook events" do
      log =
        capture_log(fn ->
          :telemetry.execute(
            [:bazaar, :webhook, :handle, :stop],
            %{duration: 100_000_000},
            %{event_type: "order.shipped"}
          )
        end)

      assert log =~ "webhook.handle"
      assert log =~ "100ms"
      assert log =~ "order.shipped"
    end

    test "formats duration in seconds for long operations" do
      log =
        capture_log(fn ->
          :telemetry.execute(
            [:bazaar, :checkout, :create, :stop],
            %{duration: 2_500_000_000},
            %{}
          )
        end)

      assert log =~ "2.5s"
    end

    test "formats duration as <1ms for very fast operations" do
      log =
        capture_log(fn ->
          :telemetry.execute(
            [:bazaar, :checkout, :get, :stop],
            %{duration: 500_000},
            %{}
          )
        end)

      assert log =~ "<1ms"
    end
  end
end
