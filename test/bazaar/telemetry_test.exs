defmodule Bazaar.TelemetryTest do
  use ExUnit.Case, async: true

  alias Bazaar.Telemetry

  # Module function to avoid telemetry warning about local functions
  def handle_event(event, measurements, metadata, pid) do
    send(pid, {event, measurements, metadata})
  end

  describe "span/3" do
    test "emits start and stop events" do
      ref = make_ref()

      :telemetry.attach_many(
        "test-#{inspect(ref)}",
        [
          [:bazaar, :test, :start],
          [:bazaar, :test, :stop]
        ],
        &__MODULE__.handle_event/4,
        self()
      )

      result = Telemetry.span([:bazaar, :test], %{foo: "bar"}, fn -> {:ok, "result"} end)

      assert result == {:ok, "result"}

      assert_receive {[:bazaar, :test, :start], %{system_time: _}, %{foo: "bar"}}
      assert_receive {[:bazaar, :test, :stop], %{duration: duration}, %{foo: "bar"}}
      assert is_integer(duration)

      :telemetry.detach("test-#{inspect(ref)}")
    end

    test "emits exception event on error" do
      ref = make_ref()

      :telemetry.attach_many(
        "test-#{inspect(ref)}",
        [
          [:bazaar, :test, :start],
          [:bazaar, :test, :exception]
        ],
        &__MODULE__.handle_event/4,
        self()
      )

      assert_raise RuntimeError, fn ->
        Telemetry.span([:bazaar, :test], %{}, fn -> raise "boom" end)
      end

      assert_receive {[:bazaar, :test, :start], _, _}

      assert_receive {[:bazaar, :test, :exception], %{duration: _},
                      %{kind: :error, reason: %RuntimeError{}}}

      :telemetry.detach("test-#{inspect(ref)}")
    end
  end

  describe "span_with_metadata/3" do
    test "includes stop metadata from function result" do
      ref = make_ref()

      :telemetry.attach_many(
        "test-#{inspect(ref)}",
        [
          [:bazaar, :test, :stop]
        ],
        &__MODULE__.handle_event/4,
        self()
      )

      result =
        Telemetry.span_with_metadata([:bazaar, :test], %{input: "x"}, fn ->
          {{:ok, "done"}, %{output: "y", count: 42}}
        end)

      assert result == {:ok, "done"}

      assert_receive {[:bazaar, :test, :stop], _, metadata}
      assert metadata[:input] == "x"
      assert metadata[:output] == "y"
      assert metadata[:count] == 42

      :telemetry.detach("test-#{inspect(ref)}")
    end
  end
end
