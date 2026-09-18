defmodule Bazaar.Location do
  @moduledoc """
  The location capability's rules (`dev.ucp.common.location.search` and
  `.lookup`), as pure functions over location documents in the spec's shape:
  `id`, `name`, `address`, `geo` (`latitude`, `longitude`), `amenities` (a
  map keyed by reverse-DNS amenity id), `hours`, `exception_hours` and
  `timezone`.

      def search_locations(params, _conn) do
        with {:ok, locations} <-
               Bazaar.Location.filter(Shop.locations(), params, serves: &Shop.serves?/2, items: &Shop.stocks?/2) do
          {page, pagination} = Bazaar.Location.paginate(locations, params["pagination"])
          {:ok, %{"locations" => page, "pagination" => pagination}}
        end
      end

      def lookup_locations(%{"ids" => ids} = params, _conn) do
        {locations, messages} = Bazaar.Location.lookup(Shop.locations(), ids)
        with {:ok, locations} <- Bazaar.Location.filter(locations, params) do
          {:ok, %{"locations" => locations, "messages" => messages}}
        end
      end

  Distances are WGS 84 geodesics in meters (Vincenty's inverse formula),
  compared unrounded, as the spec asks. Evaluating `filters.hours.open_at`
  shifts the instant into the location's `timezone`, which needs a time zone
  database configured for `Calendar` (the `tz` or `tzdata` package); with
  the default UTC-only database only `Etc/UTC` locations can be evaluated.
  """

  @a 6_378_137.0
  @f 1 / 298.257223563
  @b (1 - @f) * @a

  @days ~w(monday tuesday wednesday thursday friday saturday sunday)

  @doc "The `ucp` metadata for a location response (`:search` or `:lookup`)."
  def envelope(%{"ucp" => _} = document, _operation), do: document

  def envelope(document, operation) when operation in [:search, :lookup] do
    version = Bazaar.DiscoveryProfile.version()

    Map.put(document, "ucp", %{
      "version" => version,
      "capabilities" => %{
        "dev.ucp.common.location.#{operation}" => [%{"version" => version}]
      }
    })
  end

  @doc "The spec's cursor pagination, same as `Bazaar.Catalog.paginate/2`."
  defdelegate paginate(locations, pagination), to: Bazaar.Catalog

  @doc """
  Applies a search or lookup request's predicates, which all combine with
  AND: `distance` (`center` and `max` meters against `geo`; a location
  without coordinates never matches), `filters.amenities` (every id an exact
  key of the location's map), `filters.hours.open_at` (see `open?/2`), and
  through the business's functions in `opts`, `serves` (`fn location, target
  -> boolean end`, `target` being `%{"point" => geo}` or `%{"address" =>
  locality}`) and `filters.items` (`fn location, item_ids -> boolean end`).

  A predicate the business gave no function for is unsupported, and the
  spec has the request rejected rather than the predicate ignored:
  `{:error, :unsupported_filter}`. A `distance` without a numeric center
  and max is `{:error, :invalid_distance}`.
  """
  def filter(locations, request, opts \\ []) do
    with :ok <- supported(request, opts) do
      {:ok, Enum.filter(locations, &matches?(&1, request, opts))}
    end
  end

  defp supported(request, opts) do
    cond do
      not is_nil(request["distance"]) and not distance?(request["distance"]) ->
        {:error, :invalid_distance}

      is_map(request["serves"]) and is_nil(opts[:serves]) ->
        {:error, :unsupported_filter}

      is_list(get_in(request, ["filters", "items"])) and is_nil(opts[:items]) ->
        {:error, :unsupported_filter}

      true ->
        :ok
    end
  end

  defp matches?(location, request, opts) do
    filters = request["filters"] || %{}

    within?(location, request["distance"]) and
      serves?(location, request["serves"], opts[:serves]) and
      amenities?(location, filters["amenities"]) and
      open_at?(location, get_in(filters, ["hours", "open_at"])) and
      stocks?(location, filters["items"], opts[:items])
  end

  defp distance?(%{"center" => %{"latitude" => lat, "longitude" => lon}, "max" => max}),
    do: is_number(lat) and is_number(lon) and is_number(max)

  defp distance?(_distance), do: false

  defp within?(_location, nil), do: true

  defp within?(location, %{"center" => center, "max" => max}) do
    case location["geo"] do
      %{"latitude" => _, "longitude" => _} = geo -> distance(geo, center) <= max
      _ -> false
    end
  end

  defp serves?(_location, nil, _fun), do: true
  defp serves?(location, target, fun), do: fun.(location, target)

  defp amenities?(_location, nil), do: true

  defp amenities?(location, ids) when is_list(ids) do
    amenities = location["amenities"] || %{}
    Enum.all?(ids, &Map.has_key?(amenities, &1))
  end

  defp open_at?(_location, nil), do: true

  defp open_at?(location, instant) when is_binary(instant) do
    case DateTime.from_iso8601(instant) do
      {:ok, datetime, _offset} -> open?(location, datetime)
      _ -> false
    end
  end

  defp stocks?(_location, nil, _fun), do: true
  defp stocks?(location, ids, fun), do: fun.(location, ids)

  @doc """
  Whether a location is open at an instant, evaluated in its own `timezone`
  against `hours` for that weekday, with any `exception_hours` covering the
  local date taking precedence (an exception without `opens` and `closes`
  is a closure). A location without a timezone or schedule is never
  confirmed open. Intervals may run past midnight.
  """
  def open?(%{"timezone" => zone} = location, %DateTime{} = instant) when is_binary(zone) do
    case DateTime.shift_zone(instant, zone) do
      {:ok, local} ->
        open_locally?(location, DateTime.to_date(local), DateTime.to_time(local))

      {:error, :utc_only_time_zone_database} ->
        raise ArgumentError,
              "evaluating hours in #{zone} needs a time zone database: add the tz or tzdata " <>
                "package and configure :elixir, :time_zone_database"

      {:error, _unknown_zone} ->
        false
    end
  end

  def open?(_location, _instant), do: false

  defp open_locally?(location, date, time) do
    exceptions = Enum.filter(location["exception_hours"] || [], &covers?(&1, date))

    intervals =
      if exceptions == [],
        do:
          Enum.filter(
            location["hours"] || [],
            &(&1["day"] == Enum.at(@days, Date.day_of_week(date) - 1))
          ),
        else: exceptions

    Enum.any?(intervals, &open_in?(&1, time))
  end

  defp covers?(%{"valid_from" => from, "valid_through" => through}, date) do
    with {:ok, from} <- Date.from_iso8601(from),
         {:ok, through} <- Date.from_iso8601(through) do
      Date.compare(date, from) != :lt and Date.compare(date, through) != :gt
    else
      _ -> false
    end
  end

  defp covers?(_exception, _date), do: false

  defp open_in?(%{"opens" => opens, "closes" => closes}, time) do
    with {:ok, opens} <- local_time(opens), {:ok, closes} <- local_time(closes) do
      if Time.compare(closes, opens) == :gt,
        do: Time.compare(time, opens) != :lt and Time.compare(time, closes) == :lt,
        else: Time.compare(time, opens) != :lt or Time.compare(time, closes) == :lt
    else
      _ -> false
    end
  end

  defp open_in?(_closure, _time), do: false

  defp local_time(<<_h::binary-size(2), ":", _m::binary-size(2)>> = hhmm),
    do: Time.from_iso8601(hhmm <> ":00")

  defp local_time(value) when is_binary(value), do: Time.from_iso8601(value)
  defp local_time(_value), do: :error

  @doc """
  Resolves lookup ids for a lookup response. Ids are deduplicated and only
  the first `:max` (default 10) are processed, with a `batch_limit_applied`
  info message naming what was left out. Every returned location carries
  `inputs`, the request ids that resolved to it; an id nothing matched gets
  a `not_found` info. Returns `{locations, messages}`.
  """
  def lookup(locations, ids, opts \\ []) when is_list(ids) do
    max = Keyword.get(opts, :max, 10)
    {wanted, dropped} = ids |> Enum.uniq() |> Enum.split(max)

    resolved =
      Enum.reduce(wanted, [], fn id, acc ->
        case Enum.find(locations, &(&1["id"] == id)) do
          nil -> acc
          location -> add_input(acc, location, id)
        end
      end)
      |> Enum.reverse()

    found = for location <- resolved, input <- location["inputs"], do: input["id"]

    not_found =
      for id <- wanted, id not in found do
        %{
          "type" => "info",
          "code" => "not_found",
          "content" => "Unable to find the location #{id}."
        }
      end

    limit =
      if dropped == [],
        do: [],
        else: [
          %{
            "type" => "info",
            "code" => "batch_limit_applied",
            "content" =>
              "Only the first #{max} identifiers were processed; #{length(dropped)} were not."
          }
        ]

    {resolved, not_found ++ limit}
  end

  defp add_input(acc, location, id) do
    case Enum.split_with(acc, &(&1["id"] == location["id"])) do
      {[], _} -> [Map.put(location, "inputs", [%{"id" => id}]) | acc]
      {[seen], rest} -> [Map.update!(seen, "inputs", &(&1 ++ [%{"id" => id}])) | rest]
    end
  end

  @doc """
  The geodesic distance in meters between two `%{"latitude", "longitude"}`
  points on the WGS 84 ellipsoid (Vincenty's inverse formula; the
  great-circle distance when it does not converge, near antipodes).
  """
  def distance(%{"latitude" => lat1, "longitude" => lon1}, %{
        "latitude" => lat2,
        "longitude" => lon2
      }) do
    u1 = :math.atan((1 - @f) * :math.tan(rad(lat1)))
    u2 = :math.atan((1 - @f) * :math.tan(rad(lat2)))
    l = rad(lon2 - lon1)
    vincenty(l, l, {:math.sin(u1), :math.cos(u1)}, {:math.sin(u2), :math.cos(u2)}, 0)
  end

  defp vincenty(l, lambda, {sin_u1, cos_u1} = u1, {sin_u2, cos_u2} = u2, iteration) do
    sin_lambda = :math.sin(lambda)
    cos_lambda = :math.cos(lambda)

    sin_sigma =
      :math.sqrt(
        :math.pow(cos_u2 * sin_lambda, 2) +
          :math.pow(cos_u1 * sin_u2 - sin_u1 * cos_u2 * cos_lambda, 2)
      )

    cond do
      sin_sigma == 0.0 ->
        0.0

      iteration > 200 ->
        great_circle(l, u1, u2)

      true ->
        cos_sigma = sin_u1 * sin_u2 + cos_u1 * cos_u2 * cos_lambda
        sigma = :math.atan2(sin_sigma, cos_sigma)
        sin_alpha = cos_u1 * cos_u2 * sin_lambda / sin_sigma
        cos2_alpha = 1 - sin_alpha * sin_alpha

        cos_2sm =
          if cos2_alpha == 0.0, do: 0.0, else: cos_sigma - 2 * sin_u1 * sin_u2 / cos2_alpha

        c = @f / 16 * cos2_alpha * (4 + @f * (4 - 3 * cos2_alpha))

        next =
          l +
            (1 - c) * @f * sin_alpha *
              (sigma + c * sin_sigma * (cos_2sm + c * cos_sigma * (-1 + 2 * cos_2sm * cos_2sm)))

        if abs(next - lambda) < 1.0e-12 do
          u_sq = cos2_alpha * (@a * @a - @b * @b) / (@b * @b)
          big_a = 1 + u_sq / 16_384 * (4096 + u_sq * (-768 + u_sq * (320 - 175 * u_sq)))
          big_b = u_sq / 1024 * (256 + u_sq * (-128 + u_sq * (74 - 47 * u_sq)))

          delta =
            big_b * sin_sigma *
              (cos_2sm +
                 big_b / 4 *
                   (cos_sigma * (-1 + 2 * cos_2sm * cos_2sm) -
                      big_b / 6 * cos_2sm * (-3 + 4 * sin_sigma * sin_sigma) *
                        (-3 + 4 * cos_2sm * cos_2sm)))

          @b * big_a * (sigma - delta)
        else
          vincenty(l, next, u1, u2, iteration + 1)
        end
    end
  end

  defp great_circle(l, {sin_u1, cos_u1}, {sin_u2, cos_u2}) do
    @a * :math.acos(sin_u1 * sin_u2 + cos_u1 * cos_u2 * :math.cos(l))
  end

  defp rad(degrees), do: degrees * :math.pi() / 180
end
