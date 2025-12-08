defmodule Day8 do
  @doc ~S"""

  ## Example

      iex> Day8.part1(10, "162,817,812\n57,618,57\n906,360,560\n592,479,940\n352,342,300\n466,668,158\n542,29,236\n431,825,988\n739,650,466\n52,470,668\n216,146,977\n819,987,18\n117,168,530\n805,96,715\n346,949,466\n970,615,88\n941,993,340\n862,61,35\n984,92,344\n425,690,689\n")
      40
  """
  def part1(n, input) do
    boxes = parse_input(input)
    pairs = pairs_by_distance(boxes)
    circuits = init_union_find(boxes)

    circuits
    |> connect_pairs(pairs, n)
    |> circuit_sizes(boxes)
    |> Enum.take(3)
    |> Enum.product()
  end

  @doc ~S"""

  ## Example

      iex> Day8.part2("162,817,812\n57,618,57\n906,360,560\n592,479,940\n352,342,300\n466,668,158\n542,29,236\n431,825,988\n739,650,466\n52,470,668\n216,146,977\n819,987,18\n117,168,530\n805,96,715\n346,949,466\n970,615,88\n941,993,340\n862,61,35\n984,92,344\n425,690,689\n")
      25272
  """
  def part2(input) do
    boxes = parse_input(input)
    pairs = pairs_by_distance(boxes)
    circuits = init_union_find(boxes)
    num_boxes = length(boxes)

    {{x1, _, _}, {x2, _, _}} = find_final_connection(circuits, pairs, num_boxes, 0)
    x1 * x2
  end

  defp find_final_connection(circuits, [{p1, p2} | rest], num_boxes, connections) do
    root1 = find(circuits, p1)
    root2 = find(circuits, p2)

    cond do
      root1 == root2 ->
        # Already connected, skip
        find_final_connection(circuits, rest, num_boxes, connections)

      connections == num_boxes - 2 ->
        # This is the final connection
        {p1, p2}

      true ->
        # Connect them and continue
        new_circuits = Map.put(circuits, root1, root2)
        find_final_connection(new_circuits, rest, num_boxes, connections + 1)
    end
  end

  defp pairs_by_distance(boxes) do
    boxes
    |> all_pairs()
    |> Enum.sort_by(fn {p1, p2} -> distance_squared(p1, p2) end)
  end

  defp init_union_find(boxes) do
    Map.new(boxes, fn p -> {p, p} end)
  end

  defp connect_pairs(circuits, pairs, n) do
    pairs
    |> Enum.take(n)
    |> Enum.reduce(circuits, fn {p1, p2}, acc -> union(acc, p1, p2) end)
  end

  defp circuit_sizes(circuits, boxes) do
    boxes
    |> Enum.group_by(fn p -> find(circuits, p) end)
    |> Map.values()
    |> Enum.map(&length/1)
    |> Enum.sort(:desc)
  end

  defp parse_input(input) do
    input
    |> String.split("\n", trim: true)
    |> Enum.map(fn line ->
      [x, y, z] = line |> String.split(",") |> Enum.map(&String.to_integer/1)
      {x, y, z}
    end)
  end

  defp all_pairs(boxes) do
    for p1 <- boxes, p2 <- boxes, p1 < p2, do: {p1, p2}
  end

  defp distance_squared({x1, y1, z1}, {x2, y2, z2}) do
    (x2 - x1) ** 2 + (y2 - y1) ** 2 + (z2 - z1) ** 2
  end

  defp find(circuits, point) do
    parent = Map.get(circuits, point)
    if parent == point, do: point, else: find(circuits, parent)
  end

  defp union(circuits, p1, p2) do
    root1 = find(circuits, p1)
    root2 = find(circuits, p2)

    if root1 == root2 do
      circuits
    else
      Map.put(circuits, root1, root2)
    end
  end
end
