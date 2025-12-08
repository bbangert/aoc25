defmodule Day7 do
  @doc ~S"""

  ## Example

      iex> Day7.part1(".......S.......\n...............\n.......^.......\n...............\n......^.^......\n...............\n.....^.^.^.....\n...............\n....^.^...^....\n...............\n...^.^...^.^...\n...............\n..^...^.....^..\n...............\n.^.^.^.^.^...^.\n...............")
      21
  """
  def part1(input) do
    grid = parse_grid(input)
    start = find_start(grid)

    simulate(grid, MapSet.new([start]), 0)
  end

  @doc ~S"""

  ## Example

      iex> Day7.part2(".......S.......\n...............\n.......^.......\n...............\n......^.^......\n...............\n.....^.^.^.....\n...............\n....^.^...^....\n...............\n...^.^...^.^...\n...............\n..^...^.....^..\n...............\n.^.^.^.^.^...^.\n...............")
      40
  """
  def part2(input) do
    grid = parse_grid(input)
    {start_row, start_col} = find_start(grid)

    # Track counts at each position instead of just unique positions
    beams = %{{start_row, start_col} => 1}
    simulate_quantum(grid, beams, 0)
  end

  defp simulate_quantum(_grid, beams, timeline_count) when beams == %{} do
    timeline_count
  end

  defp simulate_quantum(grid, beams, timeline_count) do
    {new_beams, exited} =
      beams
      |> move_beams_down()
      |> process_quantum_beams(grid)

    simulate_quantum(grid, new_beams, timeline_count + exited)
  end

  defp move_beams_down(beams) do
    Enum.reduce(beams, %{}, fn {{row, col}, count}, acc ->
      Map.update(acc, {row + 1, col}, count, &(&1 + count))
    end)
  end

  defp process_quantum_beams(beams, grid) do
    Enum.reduce(beams, {%{}, 0}, fn {pos, count}, {acc_beams, acc_exited} ->
      process_quantum_beam(pos, count, grid, acc_beams, acc_exited)
    end)
  end

  defp process_quantum_beam({row, col} = pos, count, grid, acc_beams, acc_exited) do
    case Map.get(grid, pos) do
      "^" ->
        # Splitter: each particle becomes two (left and right)
        {acc_beams, acc_exited}
        |> add_quantum_beam(grid, {row, col - 1}, count)
        |> add_quantum_beam(grid, {row, col + 1}, count)

      nil ->
        # Out of bounds: timelines exit
        {acc_beams, acc_exited + count}

      _ ->
        # Empty space: particles continue
        {Map.update(acc_beams, pos, count, &(&1 + count)), acc_exited}
    end
  end

  defp add_quantum_beam({beams, exited}, grid, pos, count) do
    if Map.has_key?(grid, pos) do
      {Map.update(beams, pos, count, &(&1 + count)), exited}
    else
      {beams, exited + count}
    end
  end

  defp parse_grid(input) do
    input
    |> String.trim()
    |> String.split("\n")
    |> Enum.reject(&(&1 == ""))
    |> Enum.with_index()
    |> Enum.flat_map(fn {line, row} ->
      line
      |> String.graphemes()
      |> Enum.with_index()
      |> Enum.map(fn {char, col} -> {{row, col}, char} end)
    end)
    |> Map.new()
  end

  defp find_start(grid) do
    grid
    |> Enum.find(fn {_, char} -> char == "S" end)
    |> elem(0)
  end

  defp simulate(_grid, beams, split_count) when beams == %MapSet{} do
    split_count
  end

  defp simulate(grid, beams, split_count) do
    {new_beams, new_splits} =
      beams
      |> move_all_down()
      |> process_beams(grid)

    simulate(grid, new_beams, split_count + new_splits)
  end

  defp move_all_down(beams) do
    Enum.map(beams, fn {row, col} -> {row + 1, col} end)
  end

  defp process_beams(positions, grid) do
    Enum.reduce(positions, {MapSet.new(), 0}, fn pos, acc ->
      process_beam(pos, grid, acc)
    end)
  end

  defp process_beam({row, col} = pos, grid, {beams, splits}) do
    case Map.get(grid, pos) do
      "^" ->
        new_beams =
          beams
          |> maybe_add_beam(grid, {row, col - 1})
          |> maybe_add_beam(grid, {row, col + 1})

        {new_beams, splits + 1}

      nil ->
        {beams, splits}

      _ ->
        {MapSet.put(beams, pos), splits}
    end
  end

  defp maybe_add_beam(beams, grid, pos) do
    if Map.has_key?(grid, pos), do: MapSet.put(beams, pos), else: beams
  end
end
