defmodule Day9 do
  @doc ~S"""
  Find the largest box area from any two points used as opposite corners.

  ## Example

      iex> Day9.part1("7,1\n11,1\n11,7\n9,7\n9,5\n2,5\n2,3\n7,3\n")
      50
  """
  def part1(input) do
    input
    |> parse_input()
    |> all_pairs()
    |> Enum.map(&box_area/1)
    |> Enum.max()
  end

  @doc ~S"""
  Find the largest rectangle with red corners where all tiles are red or green.
  Red tiles = input points (forming a polygon in order)
  Green tiles = edges between consecutive red points + interior of polygon

  ## Example

    iex> Day9.part2("7,1\n11,1\n11,7\n9,7\n9,5\n2,5\n2,3\n7,3\n")
    24

  """
  def part2(input) do
    points = parse_input(input)
    {valid_ranges, sorted_ys} = build_valid_ranges(points)

    points
    |> all_pairs()
    |> Enum.filter(fn {p1, p2} -> rectangle_valid?(p1, p2, valid_ranges, sorted_ys) end)
    |> Enum.map(&box_area/1)
    |> Enum.max(fn -> 0 end)
  end

  # Only compute valid ranges at "critical" y values (input point y-coordinates)
  # Between critical y values, the valid range is constant (determined by vertical edges)
  defp build_valid_ranges(points) do
    vertical_edges = get_vertical_edges(points)
    horizontal_bounds = build_horizontal_bounds(points)
    critical_ys = get_critical_ys(points)

    valid_ranges =
      critical_ys
      |> Map.new(&{&1, compute_valid_range(&1, vertical_edges, horizontal_bounds)})

    {valid_ranges, List.to_tuple(critical_ys)}
  end

  defp get_critical_ys(points) do
    points
    |> Enum.map(fn {_, y} -> y end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp build_horizontal_bounds(points) do
    points
    |> get_horizontal_edges()
    |> Enum.group_by(fn {y, _, _} -> y end)
    |> Map.new(fn {y, edges} ->
      edges
      |> Enum.flat_map(fn {_, x_min, x_max} -> [x_min, x_max] end)
      |> xs_to_range()
      |> then(&{y, &1})
    end)
  end

  defp compute_valid_range(y, vertical_edges, horizontal_bounds) do
    crossing_xs = get_crossing_xs(y, vertical_edges)
    horiz_range = Map.get(horizontal_bounds, y)

    crossing_xs
    |> maybe_add_horiz_bounds(horiz_range)
    |> xs_to_range()
  end

  defp get_crossing_xs(y, vertical_edges) do
    vertical_edges
    |> Enum.filter(fn {_x, edge_y_min, edge_y_max} -> y >= edge_y_min and y < edge_y_max end)
    |> Enum.map(fn {edge_x, _, _} -> edge_x end)
  end

  defp maybe_add_horiz_bounds(xs, nil), do: xs
  defp maybe_add_horiz_bounds(xs, {horiz_x_min, horiz_x_max}), do: [horiz_x_min, horiz_x_max | xs]

  defp xs_to_range([]), do: nil
  defp xs_to_range(xs), do: {Enum.min(xs), Enum.max(xs)}

  defp get_vertical_edges(points) do
    points
    |> get_polygon_edges()
    |> Enum.filter(fn [{x1, _}, {x2, _}] -> x1 == x2 end)
    |> Enum.map(fn [{x, y1}, {_, y2}] -> {x, min(y1, y2), max(y1, y2)} end)
  end

  defp get_horizontal_edges(points) do
    points
    |> get_polygon_edges()
    |> Enum.filter(fn [{_, y1}, {_, y2}] -> y1 == y2 end)
    |> Enum.map(fn [{x1, y}, {x2, _}] -> {y, min(x1, x2), max(x1, x2)} end)
  end

  defp get_polygon_edges(points) do
    Enum.chunk_every(points, 2, 1, [hd(points)])
  end

  # Only check critical y values within range - valid range is constant between them
  defp rectangle_valid?({x1, y1}, {x2, y2}, valid_ranges, sorted_ys_tuple) do
    {min_x, max_x} = {min(x1, x2), max(x1, x2)}
    {min_y, max_y} = {min(y1, y2), max(y1, y2)}
    size = tuple_size(sorted_ys_tuple)

    # Binary search to find first index >= min_y
    start_idx = binary_search_left(sorted_ys_tuple, min_y, 0, size)

    # Check critical y values in range
    check_range(sorted_ys_tuple, size, start_idx, min_x, max_x, max_y, valid_ranges)
  end

  defp binary_search_left(tuple, target, lo, hi) when lo < hi do
    mid = div(lo + hi, 2)
    if elem(tuple, mid) < target do
      binary_search_left(tuple, target, mid + 1, hi)
    else
      binary_search_left(tuple, target, lo, mid)
    end
  end
  defp binary_search_left(_tuple, _target, lo, _hi), do: lo

  defp check_range(sorted_ys_tuple, size, idx, min_x, max_x, max_y, valid_ranges) do
    if idx >= size do
      true
    else
      y = elem(sorted_ys_tuple, idx)
      cond do
        y > max_y -> true
        true ->
          case Map.get(valid_ranges, y) do
            nil -> false
            {range_min, range_max} ->
              if min_x >= range_min and max_x <= range_max do
                check_range(sorted_ys_tuple, size, idx + 1, min_x, max_x, max_y, valid_ranges)
              else
                false
              end
          end
      end
    end
  end

  defp all_pairs(points) do
    for p1 <- points, p2 <- points, p1 < p2, do: {p1, p2}
  end

  defp box_area({{x1, y1}, {x2, y2}}) do
    # Include all tiles from corner to corner (inclusive)
    (abs(x2 - x1) + 1) * (abs(y2 - y1) + 1)
  end

  defp parse_input(input) do
    input
    |> String.split("\n", trim: true)
    |> Enum.map(fn line ->
      [x, y] = line |> String.split(",") |> Enum.map(&String.to_integer/1)
      {x, y}
    end)
  end

end
