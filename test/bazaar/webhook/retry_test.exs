defmodule Bazaar.Webhook.RetryTest do
  use ExUnit.Case, async: true

  alias Bazaar.Webhook.Retry

  describe "calculate_delay/2" do
    test "returns base delay for attempt 1" do
      assert Retry.calculate_delay(1, base_delay: 1000) == 1000
    end

    test "applies exponential backoff" do
      assert Retry.calculate_delay(2, base_delay: 1000) == 2000
      assert Retry.calculate_delay(3, base_delay: 1000) == 4000
      assert Retry.calculate_delay(4, base_delay: 1000) == 8000
    end

    test "respects max_delay" do
      assert Retry.calculate_delay(10, base_delay: 1000, max_delay: 5000) == 5000
    end

    test "uses default options" do
      # Default base_delay is 1000ms (1 second)
      assert Retry.calculate_delay(1) == 1000
    end
  end

  describe "calculate_delay_with_jitter/2" do
    test "returns delay within jitter range" do
      delay = Retry.calculate_delay_with_jitter(1, base_delay: 1000, jitter: 0.1)

      # 10% jitter means delay should be between 900 and 1100
      assert delay >= 900
      assert delay <= 1100
    end

    test "returns base delay when jitter is 0" do
      delay = Retry.calculate_delay_with_jitter(1, base_delay: 1000, jitter: 0)
      assert delay == 1000
    end
  end

  describe "should_retry?/3" do
    test "returns true when attempts below max" do
      assert Retry.should_retry?(1, max_attempts: 3, error: :timeout)
      assert Retry.should_retry?(2, max_attempts: 3, error: :timeout)
    end

    test "returns false when attempts reach max" do
      refute Retry.should_retry?(3, max_attempts: 3, error: :timeout)
      refute Retry.should_retry?(4, max_attempts: 3, error: :timeout)
    end

    test "returns false for non-retryable errors" do
      refute Retry.should_retry?(1, max_attempts: 3, error: {:http_error, 400, "Bad Request"})
      refute Retry.should_retry?(1, max_attempts: 3, error: {:http_error, 404, "Not Found"})
    end

    test "returns true for retryable HTTP errors" do
      assert Retry.should_retry?(1, max_attempts: 3, error: {:http_error, 500, "Server Error"})
      assert Retry.should_retry?(1, max_attempts: 3, error: {:http_error, 502, "Bad Gateway"})
      assert Retry.should_retry?(1, max_attempts: 3, error: {:http_error, 503, "Unavailable"})
      assert Retry.should_retry?(1, max_attempts: 3, error: {:http_error, 429, "Rate Limited"})
    end

    test "returns true for network errors" do
      assert Retry.should_retry?(1, max_attempts: 3, error: :timeout)
      assert Retry.should_retry?(1, max_attempts: 3, error: :econnrefused)
      assert Retry.should_retry?(1, max_attempts: 3, error: {:error, :nxdomain})
    end
  end

  describe "retryable_error?/1" do
    test "HTTP 5xx errors are retryable" do
      assert Retry.retryable_error?({:http_error, 500, ""})
      assert Retry.retryable_error?({:http_error, 502, ""})
      assert Retry.retryable_error?({:http_error, 503, ""})
      assert Retry.retryable_error?({:http_error, 504, ""})
    end

    test "HTTP 429 is retryable" do
      assert Retry.retryable_error?({:http_error, 429, ""})
    end

    test "HTTP 4xx (except 429) are not retryable" do
      refute Retry.retryable_error?({:http_error, 400, ""})
      refute Retry.retryable_error?({:http_error, 401, ""})
      refute Retry.retryable_error?({:http_error, 403, ""})
      refute Retry.retryable_error?({:http_error, 404, ""})
      refute Retry.retryable_error?({:http_error, 422, ""})
    end

    test "network errors are retryable" do
      assert Retry.retryable_error?(:timeout)
      assert Retry.retryable_error?(:econnrefused)
      assert Retry.retryable_error?(:closed)
      assert Retry.retryable_error?({:error, :nxdomain})
    end
  end

  describe "build_schedule/1" do
    test "generates a schedule of attempts" do
      schedule = Retry.build_schedule(max_attempts: 3, base_delay: 1000)

      assert length(schedule) == 3
      assert Enum.at(schedule, 0) == {1, 0}
      assert Enum.at(schedule, 1) == {2, 1000}
      assert Enum.at(schedule, 2) == {3, 2000}
    end

    test "respects max_delay" do
      schedule = Retry.build_schedule(max_attempts: 5, base_delay: 1000, max_delay: 2000)

      delays = Enum.map(schedule, fn {_, delay} -> delay end)
      assert delays == [0, 1000, 2000, 2000, 2000]
    end
  end
end
