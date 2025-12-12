defmodule Day11 do
  @doc ~S"""

  ## Example

      iex> Day11.part1("aaa: you hhh\nyou: bbb ccc\nbbb: ddd eee\nccc: ddd eee fff\nddd: ggg\neee: out\nfff: out\nggg: out\nhhh: ccc fff iii\niii: out")
      5
  """
  def part1(input) do
    input
    |> parse()
    |> count_paths("you", "out")
  end

  @doc ~S"""

  ## Example

      iex> Day11.part2("svr: aaa bbb\naaa: fft\nfft: ccc\nbbb: tty\ntty: ccc\nccc: ddd eee\nddd: hub\nhub: fff\neee: dac\ndac: fff\nfff: ggg hhh\nggg: out\nhhh: out")
      2
  """
  def part2(input) do
    graph = parse(input)
    required = ["dac", "fft"]
    {count, _cache} = count_paths_visiting(graph, "svr", "out", required, [], %{})
    count
  end

  defp count_paths_visiting(_graph, target, target, required, visited, cache) do
    count = if length(required) == length(visited), do: 1, else: 0
    {count, cache}
  end

  defp count_paths_visiting(graph, current, target, required, visited, cache) do
    visited = maybe_mark_visited(current, required, visited)
    key = {current, Enum.sort(visited)}

    with :error <- Map.fetch(cache, key) do
      {count, cache} = compute_paths(graph, current, target, required, visited, cache)
      {count, Map.put(cache, key, count)}
    else
      {:ok, count} -> {count, cache}
    end
  end

  defp maybe_mark_visited(current, required, visited) do
    if current in required and current not in visited do
      [current | visited]
    else
      visited
    end
  end

  defp compute_paths(graph, current, target, required, visited, cache) do
    case Map.get(graph, current) do
      nil ->
        {0, cache}

      outputs ->
        Enum.reduce(outputs, {0, cache}, fn next, {acc, c} ->
          {count, c} = count_paths_visiting(graph, next, target, required, visited, c)
          {acc + count, c}
        end)
    end
  end

  defp parse(input) do
    input
    |> String.trim()
    |> String.split("\n")
    |> Map.new(&parse_line/1)
  end

  defp parse_line(line) do
    [device, outputs] = String.split(line, ": ")
    {device, String.split(outputs)}
  end

  defp count_paths(_graph, target, target), do: 1

  defp count_paths(graph, current, target) do
    case Map.get(graph, current) do
      nil -> 0
      outputs -> Enum.sum(Enum.map(outputs, &count_paths(graph, &1, target)))
    end
  end
end
