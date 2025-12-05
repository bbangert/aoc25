defmodule Day5 do
  @doc ~S"""

  ## Example

      iex> Day5.part1("3-5\n10-14\n16-20\n12-18\n\n1\n5\n8\n11\n17\n32\n")
      3
  """
  def part1(input) do
    {fresh_ranges, items_to_check} = parse_input(input)

    items_to_check
    |> Task.async_stream(fn number -> in_any_range?(number, fresh_ranges) end)
    |> Stream.map(&elem(&1, 1))
    |> Enum.count(& &1)
  end

  @doc ~S"""

  ## Example

      iex> Day5.part2("3-5\n10-14\n16-20\n12-18\n\n1\n5\n8\n11\n17\n32\n")
      14
  """
  def part2(input) do
    {fresh_ranges, _items_to_check} = parse_input(input)

    fresh_ranges
    |> merge_ranges()
    |> Enum.map(fn {start, finish} -> finish - start + 1 end)
    |> Enum.sum()
  end

  defp merge_ranges(ranges) do
    ranges
    |> Enum.sort()
    |> Enum.reduce([], fn {start, finish} = range, acc ->
      case acc do
        [] -> [range]
        [{prev_start, prev_finish} | rest] when start <= prev_finish + 1 ->
          [{prev_start, max(prev_finish, finish)} | rest]
        _ ->
          [range | acc]
      end
    end)
    |> Enum.reverse()
  end

  defp in_any_range?(number, ranges) do
    Enum.any?(ranges, fn {start, finish} -> number >= start and number <= finish end)
  end

  defp parse_input(input) do
    [raw_fresh, raw_items_to_check] = input
    |> String.trim()
    |> String.split("\n\n")

    fresh = raw_fresh
    |> String.split("\n")
    |> Enum.map(fn raw_range ->
      [start, finish] = String.split(raw_range, "-")
      {String.to_integer(start), String.to_integer(finish)}
    end)

    items_to_check = raw_items_to_check
    |> String.split("\n")
    |> Enum.map(&String.to_integer/1)

    {fresh, items_to_check}
  end
end
