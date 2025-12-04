defmodule Day4 do
  @doc ~S"""

  ## Example

      iex> Day4.part1("..@@.@@@@.\n@@@.@.@.@@\n@@@@@.@.@@\n@.@@@@..@.\n@@.@@@@.@@\n.@@@@@@@.@\n.@.@.@.@@@\n@.@@@.@@@@\n.@@@@@@@@.\n@.@.@@@.@.")
      13
  """
  def part1(input) do
    map = parse_input(input)

    map.rolls
    |> Task.async_stream(&check_position(map, &1))
    |> Stream.map(&elem(&1, 1))
    |> Enum.sum()
  end

  @doc ~S"""

  ## Example

      iex> Day4.part2("..@@.@@@@.\n@@@.@.@.@@\n@@@@@.@.@@\n@.@@@@..@.\n@@.@@@@.@@\n.@@@@@@@.@\n.@.@.@.@@@\n@.@@@.@@@@\n.@@@@@@@@.\n@.@.@@@.@.")
      43
  """
  def part2(input) do
    map = parse_input(input)
    remove_rolls(map, removable_rolls(map), 0)
  end

  defp remove_rolls(map, rolls_to_remove, rolls_removed) do
    if MapSet.size(rolls_to_remove) == 0 do
      rolls_removed
    else
      updated_map = put_in(map.rolls, MapSet.difference(map.rolls, rolls_to_remove))
      remove_rolls(updated_map, removable_rolls(updated_map), rolls_removed + MapSet.size(rolls_to_remove))
    end
  end

  defp removable_rolls(map) do
    map.rolls
    |> Task.async_stream(fn coord -> {check_position(map, coord), coord} end)
    |> Stream.filter(fn {:ok, {result, _coord}} -> result == 1 end)
    |> Stream.map(fn {:ok, {_result, coord}} -> coord end)
    |> Enum.into(MapSet.new())
  end

  defp check_position(map, {x, y}) do
    nearby_count = count_nearby_rolls(map, {x, y})
    if nearby_count < 4, do: 1, else: 0
  end

  defp count_nearby_rolls(map, {x, y}) do
    [{x - 1, y}, {x + 1, y}, {x - 1, y + 1}, {x, y + 1}, {x + 1, y + 1}, {x - 1, y - 1}, {x, y - 1}, {x + 1, y - 1}]
    |> Enum.count(fn coord -> not outside_bounds?(map, coord) and is_roll?(map, coord) end)
  end

  defp is_roll?(map, {x, y}), do: MapSet.member?(map.rolls, {x, y})

  defp outside_bounds?(map, {x, y}), do: x < 0 or x >= map.width or y < 0 or y >= map.height

  defp parse_input(input) do
    raw_map = input |> String.trim() |> String.split("\n")

    map = %{
      :width => Enum.at(raw_map, 0) |> String.length(),
      :height => Enum.count(raw_map),
      :rolls => MapSet.new(),
    }

    raw_map
    |> Enum.with_index()
    |> Enum.reduce(map, fn {row, y}, map ->
      row
      |> String.graphemes()
      |> Enum.with_index()
      |> Enum.reduce(map, fn {char, x}, map ->
        case char do
          "@" -> put_in(map.rolls, MapSet.put(map.rolls, {x, y}))
          _ -> map
        end
      end)
    end)
  end
end
