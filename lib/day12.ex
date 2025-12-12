defmodule Day12 do
  @moduledoc false

  defmodule State do
    @moduledoc false
    defstruct [:grid, :width, :height, :slack, :blocked]

    @type t :: %__MODULE__{
            grid: MapSet.t({integer(), integer()}),
            width: non_neg_integer(),
            height: non_neg_integer(),
            slack: integer(),
            blocked: non_neg_integer()
          }
  end

  @type coord :: {integer(), integer()}
  @type shape :: MapSet.t(coord())
  @type orientations :: %{non_neg_integer() => [shape()]}

  @doc ~S"""
  ## Example

      iex> Day12.part1("0:\n###\n##.\n##.\n\n1:\n###\n##.\n.##\n\n2:\n.##\n###\n##.\n\n3:\n##.\n###\n##.\n\n4:\n###\n#..\n###\n\n5:\n###\n.#.\n###\n\n4x4: 0 0 0 0 2 0\n12x5: 1 0 1 0 2 2\n12x5: 1 0 1 0 3 2")
      2
  """
  @spec part1(String.t()) :: non_neg_integer()
  def part1(input) do
    {shapes, regions} = parse(input)
    orientations = build_orientations(shapes)

    regions
    |> Task.async_stream(&can_fit?(orientations, &1), timeout: :infinity, ordered: false)
    |> Enum.count(&match?({:ok, true}, &1))
  end

  # Parsing

  defp parse(input) do
    parts = String.split(input, "\n\n", trim: true)
    {shape_parts, [regions_part]} = Enum.split(parts, -1)

    shapes = Map.new(shape_parts, &parse_shape/1)
    regions = parse_regions(regions_part)

    {shapes, regions}
  end

  defp parse_shape(shape_str) do
    [header | lines] = String.split(shape_str, "\n", trim: true)
    index = header |> String.trim_trailing(":") |> String.to_integer()
    coords = parse_coords(lines)
    {index, coords}
  end

  defp parse_coords(lines) do
    for {line, row} <- Enum.with_index(lines),
        {char, col} <- Enum.with_index(String.graphemes(line)),
        char == "#",
        into: MapSet.new(),
        do: {row, col}
  end

  defp parse_regions(section) do
    section
    |> String.split("\n", trim: true)
    |> Enum.map(&parse_region/1)
  end

  defp parse_region(line) do
    [dims_str | counts] = String.split(line)
    {width, height} = parse_dimensions(dims_str)
    presents = expand_counts(counts)
    {width, height, presents}
  end

  defp parse_dimensions(dims_str) do
    [width, height] =
      dims_str
      |> String.trim_trailing(":")
      |> String.split("x")
      |> Enum.map(&String.to_integer/1)

    {width, height}
  end

  defp expand_counts(counts) do
    counts
    |> Enum.map(&String.to_integer/1)
    |> Enum.with_index()
    |> Enum.flat_map(fn {count, idx} -> List.duplicate(idx, count) end)
  end

  # Orientation generation

  defp build_orientations(shapes) do
    Map.new(shapes, fn {idx, coords} -> {idx, all_orientations(coords)} end)
  end

  defp all_orientations(coords) do
    rotations = coords |> Stream.iterate(&rotate/1) |> Enum.take(4)
    all = rotations ++ Enum.map(rotations, &flip/1)
    all |> Enum.map(&normalize/1) |> Enum.uniq()
  end

  defp rotate(coords), do: MapSet.new(coords, fn {r, c} -> {c, -r} end)
  defp flip(coords), do: MapSet.new(coords, fn {r, c} -> {r, -c} end)

  defp normalize(coords) do
    {min_r, min_c} = bounding_min(coords)
    MapSet.new(coords, fn {r, c} -> {r - min_r, c - min_c} end)
  end

  defp bounding_min(coords) do
    min_r = coords |> Enum.map(&elem(&1, 0)) |> Enum.min()
    min_c = coords |> Enum.map(&elem(&1, 1)) |> Enum.min()
    {min_r, min_c}
  end

  # Placement solver

  @spec can_fit?(orientations(), {pos_integer(), pos_integer(), [non_neg_integer()]}) :: boolean()
  @dialyzer {:no_opaque, can_fit?: 2}
  defp can_fit?(orientations, {width, height, presents}) do
    sizes = Enum.map(presents, &shape_size(orientations, &1))
    total_cells = Enum.sum(sizes)
    slack = width * height - total_cells

    if slack < 0 do
      false
    else
      sorted = sort_by_size_desc(presents, sizes)

      state = %State{
        grid: MapSet.new(),
        width: width,
        height: height,
        slack: slack,
        blocked: 0
      }

      place_all(sorted, orientations, state)
    end
  end

  defp shape_size(orientations, idx), do: orientations[idx] |> hd() |> MapSet.size()

  defp sort_by_size_desc(presents, sizes) do
    Enum.zip(presents, sizes) |> Enum.sort_by(&elem(&1, 1), :desc)
  end

  @spec place_all([{non_neg_integer(), pos_integer()}], orientations(), State.t()) :: boolean()
  @dialyzer {:no_opaque, place_all: 3}
  defp place_all([], _orientations, _state), do: true

  defp place_all(presents, orientations, state) do
    case first_empty(state) do
      nil -> false
      target -> try_place_or_block(presents, orientations, state, target)
    end
  end

  @spec try_place_or_block([{non_neg_integer(), pos_integer()}], orientations(), State.t(), coord()) :: boolean()
  defp try_place_or_block([{present, size} | rest], orientations, state, target) do
    try_cover(present, rest, orientations, state, target) ||
      try_block(present, size, rest, orientations, state, target)
  end

  @spec try_cover(non_neg_integer(), [{non_neg_integer(), pos_integer()}], orientations(), State.t(), coord()) ::
          boolean()
  defp try_cover(present, rest, orientations, %State{grid: grid} = state, {target_r, target_c}) do
    orientations[present]
    |> Enum.any?(fn shape ->
      shape
      |> placements_covering(target_r, target_c, state)
      |> Enum.any?(fn new_cells ->
        new_state = %State{state | grid: MapSet.union(grid, new_cells)}
        place_all(rest, orientations, new_state)
      end)
    end)
  end

  @spec try_block(non_neg_integer(), pos_integer(), [{non_neg_integer(), pos_integer()}], orientations(), State.t(), coord()) ::
          boolean()
  defp try_block(_present, _size, _rest, _orientations, %State{blocked: blocked, slack: slack}, _target)
       when blocked >= slack,
       do: false

  defp try_block(present, size, rest, orientations, %State{grid: grid, blocked: blocked} = state, {target_r, target_c}) do
    new_state = %State{state | grid: MapSet.put(grid, {target_r, target_c}), blocked: blocked + 1}
    place_all([{present, size} | rest], orientations, new_state)
  end

  @spec first_empty(State.t()) :: coord() | nil
  @dialyzer {:no_opaque, first_empty: 1}
  defp first_empty(%State{grid: grid, width: width, height: height}) do
    Enum.find_value(0..(height - 1), fn r ->
      Enum.find_value(0..(width - 1), fn c ->
        unless MapSet.member?(grid, {r, c}), do: {r, c}
      end)
    end)
  end

  @spec placements_covering(shape(), integer(), integer(), State.t()) :: [shape()]
  defp placements_covering(shape, target_r, target_c, %State{grid: grid, width: width, height: height}) do
    for {sr, sc} <- MapSet.to_list(shape),
        translated = translate(shape, target_r - sr, target_c - sc),
        in_bounds?(translated, width, height),
        MapSet.disjoint?(translated, grid),
        do: translated
  end

  defp translate(shape, dr, dc), do: MapSet.new(shape, fn {r, c} -> {r + dr, c + dc} end)

  defp in_bounds?(coords, width, height) do
    Enum.all?(coords, fn {r, c} -> r >= 0 and r < height and c >= 0 and c < width end)
  end
end
