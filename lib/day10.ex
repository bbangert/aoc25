defmodule Day10 do
  import Bitwise

  @doc ~S"""

  ## Example

      iex> Day10.part1("[.##.] (3) (1,3) (2) (2,3) (0,2) (0,1) {3,5,4,7}\n[...#.] (0,2,3,4) (2,3) (0,4) (0,1,2) (1,2,3,4) {7,5,12,7,2}\n[.###.#] (0,1,2,3,4) (0,3,4) (0,1,2,4,5) (1,2) {10,11,11,5,10,5}\n")
      7
  """
  def part1(input) do
    input
    |> parse()
    |> Enum.map(&min_presses/1)
    |> Enum.sum()
  end

  @doc ~S"""

  ## Example

      iex> Day10.part2("[.##.] (3) (1,3) (2) (2,3) (0,2) (0,1) {3,5,4,7}\n[...#.] (0,2,3,4) (2,3) (0,4) (0,1,2) (1,2,3,4) {7,5,12,7,2}\n[.###.#] (0,1,2,3,4) (0,3,4) (0,1,2,4,5) (1,2) {10,11,11,5,10,5}\n")
      33
  """
  def part2(input) do
    input
    |> parse2()
    |> Task.async_stream(&min_presses_additive/1,
      max_concurrency: System.schedulers_online(),
      timeout: :infinity
    )
    |> Enum.map(fn {:ok, result} -> result end)
    |> sum_or_infinity()
  end

  defp sum_or_infinity(results) do
    if Enum.any?(results, &(&1 == :infinity)), do: :infinity, else: Enum.sum(results)
  end

  # ============================================================================
  # Part 1: XOR Toggle Problem
  # ============================================================================

  defp parse(input) do
    input
    |> String.trim()
    |> String.split("\n")
    |> Enum.map(&parse_line/1)
  end

  defp parse_line(line) do
    [lights_str] = Regex.run(~r/\[([.#]+)\]/, line, capture: :all_but_first)
    target = parse_lights(lights_str)
    buttons = parse_buttons(line)
    {target, buttons}
  end

  defp parse_lights(str) do
    str
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.filter(fn {c, _} -> c == "#" end)
    |> Enum.map(fn {_, i} -> i end)
    |> MapSet.new()
  end

  defp parse_buttons(line) do
    Regex.scan(~r/\(([0-9,]+)\)/, line, capture: :all_but_first)
    |> Enum.map(fn [s] -> s |> String.split(",") |> Enum.map(&String.to_integer/1) end)
  end

  defp min_presses({target, buttons}) do
    num_buttons = length(buttons)
    button_masks = buttons |> Enum.map(&lights_to_bitmask/1)
    target_mask = lights_to_bitmask(target)

    if num_buttons <= 20 do
      brute_force_min(button_masks, target_mask, num_buttons)
    else
      gaussian_min(button_masks, target_mask, num_buttons)
    end
  end

  defp lights_to_bitmask(lights) do
    Enum.reduce(lights, 0, fn light, acc -> acc ||| (1 <<< light) end)
  end

  defp brute_force_min(button_masks, target_mask, num_buttons) do
    0..((1 <<< num_buttons) - 1)
    |> Enum.reduce(:infinity, fn mask, best ->
      result = compute_xor_result(button_masks, mask, num_buttons)

      if result == target_mask do
        min(popcount(mask), best)
      else
        best
      end
    end)
  end

  defp compute_xor_result(button_masks, mask, num_buttons) do
    Enum.reduce(0..(num_buttons - 1), 0, fn i, acc ->
      if (mask &&& (1 <<< i)) != 0 do
        bxor(acc, Enum.at(button_masks, i))
      else
        acc
      end
    end)
  end

  defp gaussian_min(button_masks, target_mask, num_buttons) do
    cols = button_masks ++ [target_mask]
    {reduced_cols, pivot_cols} = gaussian_eliminate(cols, 64, num_buttons)
    find_min_weight_solution(reduced_cols, num_buttons, pivot_cols)
  end

  defp gaussian_eliminate(cols, num_rows, num_buttons) do
    Enum.reduce(0..(num_rows - 1), {cols, []}, fn row, {cols, pivots} ->
      case find_unused_pivot_col(cols, pivots, num_buttons, row) do
        nil -> {cols, pivots}
        pivot_col -> {eliminate_column(cols, pivot_col, row), [pivot_col | pivots]}
      end
    end)
  end

  defp find_unused_pivot_col(cols, pivots, num_buttons, row) do
    used_cols = MapSet.new(pivots)

    Enum.find(0..(num_buttons - 1), fn col ->
      not MapSet.member?(used_cols, col) and (Enum.at(cols, col) &&& (1 <<< row)) != 0
    end)
  end

  defp eliminate_column(cols, pivot_col, row) do
    pivot_val = Enum.at(cols, pivot_col)

    cols
    |> Enum.with_index()
    |> Enum.map(fn {col, idx} ->
      if idx != pivot_col and (col &&& (1 <<< row)) != 0 do
        bxor(col, pivot_val)
      else
        col
      end
    end)
  end

  defp find_min_weight_solution(cols, num_buttons, pivot_cols) do
    button_cols = Enum.take(cols, num_buttons)
    target_col = List.last(cols)
    pivot_set = MapSet.new(pivot_cols)
    free_indices = Enum.reject(0..(num_buttons - 1), &MapSet.member?(pivot_set, &1))
    pivot_info = build_pivot_info(button_cols, pivot_cols)

    case compute_particular(button_cols, target_col, pivot_info) do
      nil -> :infinity
      particular ->
        null_basis = compute_null_basis(button_cols, pivot_info, free_indices)
        min_weight_with_null_space(particular, null_basis)
    end
  end

  defp build_pivot_info(button_cols, pivot_cols) do
    pivot_cols
    |> Enum.map(fn col ->
      col_val = Enum.at(button_cols, col)
      if col_val != 0, do: {col, lowest_set_bit_position(col_val)}
    end)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
  end

  defp lowest_set_bit_position(n) when n > 0, do: trunc(:math.log2(n &&& -n))

  defp compute_particular(button_cols, target_col, pivot_info) do
    result =
      Enum.reduce_while(0..63, {0, target_col}, fn row, {sol, remaining} ->
        if (remaining &&& (1 <<< row)) != 0 do
          handle_set_bit(sol, remaining, row, button_cols, pivot_info)
        else
          {:cont, {sol, remaining}}
        end
      end)

    case result do
      nil -> nil
      {sol, 0} -> sol
      _ -> nil
    end
  end

  defp handle_set_bit(sol, remaining, row, button_cols, pivot_info) do
    case Enum.find(pivot_info, fn {_col, r} -> r == row end) do
      {col, _} ->
        new_sol = sol ||| (1 <<< col)
        new_remaining = bxor(remaining, Enum.at(button_cols, col))
        {:cont, {new_sol, new_remaining}}

      nil ->
        {:halt, nil}
    end
  end

  defp compute_null_basis(button_cols, pivot_info, free_indices) do
    Enum.map(free_indices, fn free_idx ->
      base = 1 <<< free_idx
      free_col = Enum.at(button_cols, free_idx)

      Enum.reduce(pivot_info, base, fn {pivot_col, pivot_row}, vec ->
        if (free_col &&& (1 <<< pivot_row)) != 0 do
          vec ||| (1 <<< pivot_col)
        else
          vec
        end
      end)
    end)
  end

  defp min_weight_with_null_space(particular, null_basis) do
    num_null = length(null_basis)

    if num_null > 20 do
      popcount(particular)
    else
      0..((1 <<< num_null) - 1)
      |> Enum.map(&(popcount(apply_null_vectors(particular, null_basis, &1))))
      |> Enum.min()
    end
  end

  defp apply_null_vectors(particular, null_basis, mask) do
    null_basis
    |> Enum.with_index()
    |> Enum.reduce(particular, fn {null_vec, idx}, sol ->
      if (mask &&& (1 <<< idx)) != 0, do: bxor(sol, null_vec), else: sol
    end)
  end

  defp popcount(0), do: 0
  defp popcount(n) when n > 0, do: (n &&& 1) + popcount(n >>> 1)

  # ============================================================================
  # Part 2: Additive Counter Problem
  # ============================================================================

  defp parse2(input) do
    input
    |> String.trim()
    |> String.split("\n")
    |> Enum.map(&parse_line2/1)
  end

  defp parse_line2(line) do
    buttons = parse_buttons(line)
    [joltage_str] = Regex.run(~r/\{([0-9,]+)\}/, line, capture: :all_but_first)
    targets = joltage_str |> String.split(",") |> Enum.map(&String.to_integer/1)
    {targets, buttons}
  end

  defp min_presses_additive({targets, buttons}) do
    a_matrix = build_coefficient_matrix(targets, buttons)
    solve_integer_ilp(a_matrix, targets, length(buttons))
  end

  defp build_coefficient_matrix(targets, buttons) do
    num_counters = length(targets)
    num_buttons = length(buttons)

    for i <- 0..(num_counters - 1) do
      for j <- 0..(num_buttons - 1) do
        if i in Enum.at(buttons, j), do: 1, else: 0
      end
    end
  end

  defp solve_integer_ilp(a_matrix, targets, num_buttons) do
    aug = build_augmented_matrix(a_matrix, targets)
    {reduced, pivots} = integer_gauss(aug, num_buttons)
    free_cols = Enum.to_list(0..(num_buttons - 1)) -- pivots

    cond do
      inconsistent?(reduced, pivots, num_buttons) -> :infinity
      free_cols == [] -> solve_unique(reduced, pivots, num_buttons)
      true -> search_with_free_vars(reduced, pivots, free_cols, num_buttons, targets)
    end
  end

  defp build_augmented_matrix(a_matrix, targets) do
    Enum.zip(a_matrix, targets)
    |> Enum.map(fn {row, t} -> row ++ [t] end)
  end

  defp solve_unique(reduced, pivots, num_buttons) do
    solution = back_substitute(reduced, pivots, num_buttons)

    if Enum.all?(solution, &(&1 >= 0)) do
      Enum.sum(solution)
    else
      :infinity
    end
  end

  # Integer Gaussian elimination
  defp integer_gauss(matrix, num_cols) do
    num_rows = length(matrix)

    {final, pivots, _} =
      Enum.reduce(0..(num_rows - 1), {matrix, [], 0}, &gauss_step(&1, &2, num_cols))

    {final, Enum.reverse(pivots)}
  end

  defp gauss_step(_row_idx, {mat, pivots, col_idx}, num_cols) when col_idx >= num_cols do
    {mat, pivots, col_idx}
  end

  defp gauss_step(row_idx, {mat, pivots, col_idx}, num_cols) do
    case find_pivot(mat, row_idx, col_idx, num_cols) do
      nil ->
        {mat, pivots, col_idx}

      {prow, pcol} ->
        mat = mat |> swap_row(row_idx, prow) |> eliminate_below_and_above(row_idx, pcol)
        {mat, [pcol | pivots], pcol + 1}
    end
  end

  defp find_pivot(mat, start_row, start_col, num_cols) do
    Enum.find_value(start_col..(num_cols - 1), fn col ->
      row = Enum.find(start_row..(length(mat) - 1), &(get_element(mat, &1, col) != 0))
      if row, do: {row, col}
    end)
  end

  defp get_element(mat, row, col), do: Enum.at(Enum.at(mat, row), col)

  defp swap_row(mat, i, i), do: mat

  defp swap_row(mat, i, j) do
    ri = Enum.at(mat, i)
    rj = Enum.at(mat, j)
    mat |> List.replace_at(i, rj) |> List.replace_at(j, ri)
  end

  defp eliminate_below_and_above(mat, pivot_row, col) do
    pivot_val = get_element(mat, pivot_row, col)
    pivot_data = Enum.at(mat, pivot_row)

    mat
    |> Enum.with_index()
    |> Enum.map(fn {row, idx} ->
      if idx == pivot_row do
        row
      else
        eliminate_row(row, pivot_data, pivot_val, col)
      end
    end)
  end

  defp eliminate_row(row, _pivot_data, _pivot_val, col) when elem(row, col) == 0, do: row

  defp eliminate_row(row, pivot_data, pivot_val, col) do
    row_val = Enum.at(row, col)

    if row_val == 0 do
      row
    else
      row |> compute_eliminated_row(pivot_data, pivot_val, row_val) |> reduce_by_gcd()
    end
  end

  defp compute_eliminated_row(row, pivot_data, pivot_val, row_val) do
    g = Integer.gcd(abs(pivot_val), abs(row_val))
    mult_row = div(pivot_val, g)
    mult_pivot = div(row_val, g)

    Enum.zip(row, pivot_data)
    |> Enum.map(fn {r, p} -> r * mult_row - p * mult_pivot end)
  end

  defp reduce_by_gcd(row) do
    row_gcd = Enum.reduce(row, 0, fn x, acc -> Integer.gcd(abs(x), acc) end)
    if row_gcd > 1, do: Enum.map(row, &div(&1, row_gcd)), else: row
  end

  defp inconsistent?(reduced, pivots, num_cols) do
    reduced
    |> Enum.drop(length(pivots))
    |> Enum.any?(&inconsistent_row?(&1, num_cols))
  end

  defp inconsistent_row?(row, num_cols) do
    coeffs_zero? = row |> Enum.take(num_cols) |> Enum.all?(&(&1 == 0))
    rhs_nonzero? = List.last(row) != 0
    coeffs_zero? and rhs_nonzero?
  end

  defp back_substitute(reduced, pivots, num_cols) do
    pivot_to_row = pivots |> Enum.with_index() |> Map.new()

    Enum.map(0..(num_cols - 1), fn col ->
      case Map.get(pivot_to_row, col) do
        nil -> 0
        row_idx -> compute_pivot_value(reduced, row_idx, col)
      end
    end)
  end

  defp compute_pivot_value(reduced, row_idx, col) do
    row = Enum.at(reduced, row_idx)
    pivot_val = Enum.at(row, col)
    rhs = List.last(row)

    if rem(rhs, pivot_val) == 0, do: div(rhs, pivot_val), else: rhs / pivot_val
  end

  # Free variable search
  defp search_with_free_vars(reduced, pivots, free_cols, num_buttons, targets) do
    pivot_to_row = pivots |> Enum.with_index() |> Map.new()
    num_free = length(free_cols)
    bound = Enum.max(targets) + 50
    ctx = %{reduced: reduced, pivot_to_row: pivot_to_row, free_cols: free_cols, num_buttons: num_buttons}

    case num_free do
      1 -> exhaustive_search(ctx, [-bound..bound])
      2 -> exhaustive_search(ctx, List.duplicate(-bound..bound, 2))
      3 -> search_three_free_vars(ctx, bound)
      _ -> grid_search_free(ctx, bound)
    end
  end

  defp search_three_free_vars(ctx, bound) do
    small_bound = min(bound, 50)
    ranges = List.duplicate(-small_bound..small_bound, 3)

    case exhaustive_search(ctx, ranges) do
      :infinity -> grid_search_free(ctx, bound)
      result -> result
    end
  end

  defp exhaustive_search(ctx, ranges) do
    cartesian(ranges)
    |> Enum.reduce(:infinity, fn free_vals, best ->
      case evaluate_solution(ctx, free_vals) do
        :invalid -> best
        total -> min(total, best)
      end
    end)
  end

  defp grid_search_free(ctx, bound) do
    num_free = length(ctx.free_cols)
    step = max(1, div(bound, 20))

    base_results = generate_grid_points(num_free, bound, step)
    |> Enum.map(&evaluate_with_vals(ctx, &1))
    |> Enum.reject(&(&1 == :infinity))

    case base_results do
      [] -> :infinity
      results ->
        {best_sum, best_vals} = Enum.min_by(results, fn {sum, _} -> sum end)
        refine_search(ctx, best_vals, step, best_sum)
    end
  end

  defp generate_grid_points(num_free, bound, step) do
    for t1 <- -bound..bound//step,
        t2 <- -bound..bound//step,
        t3 <- if(num_free >= 3, do: -bound..bound//step, else: [0]) do
      build_free_vals(num_free, t1, t2, t3)
    end
  end

  defp build_free_vals(num_free, t1, t2, t3) do
    base = [t1, t2] ++ if(num_free >= 3, do: [t3], else: [])
    rest = if(num_free > 3, do: List.duplicate(0, num_free - 3), else: [])
    Enum.take(base ++ rest, num_free)
  end

  defp evaluate_with_vals(ctx, free_vals) do
    case evaluate_solution(ctx, free_vals) do
      :invalid -> :infinity
      total -> {total, free_vals}
    end
  end

  defp refine_search(_ctx, _center, step, best) when step <= 1, do: best

  defp refine_search(ctx, center, step, best) do
    num_free = length(ctx.free_cols)
    new_step = max(1, div(step, 2))
    offsets = -step..step//new_step

    results =
      for d1 <- offsets,
          d2 <- if(num_free >= 2, do: offsets, else: [0]),
          d3 <- if(num_free >= 3, do: offsets, else: [0]) do
        deltas = [d1, d2, d3] |> Enum.take(num_free)
        free_vals = Enum.zip(center, deltas) |> Enum.map(fn {c, d} -> c + d end)

        case evaluate_solution(ctx, free_vals) do
          :invalid -> :infinity
          total -> total
        end
      end

    min(best, Enum.min(results))
  end

  defp evaluate_solution(ctx, free_vals) do
    case compute_solution(ctx, free_vals) do
      :invalid -> :invalid
      solution when is_list(solution) ->
        if valid_solution?(solution), do: Enum.sum(solution), else: :invalid
    end
  end

  defp valid_solution?(solution) do
    Enum.all?(solution, &(is_integer(&1) and &1 >= 0))
  end

  defp compute_solution(ctx, free_vals) do
    free_map = Enum.zip(ctx.free_cols, free_vals) |> Map.new()

    results =
      Enum.map(0..(ctx.num_buttons - 1), fn col ->
        case Map.get(free_map, col) do
          nil -> compute_pivot_col_value(ctx, col, free_map)
          val -> val
        end
      end)

    if :invalid in results, do: :invalid, else: results
  end

  defp compute_pivot_col_value(ctx, col, free_map) do
    case Map.get(ctx.pivot_to_row, col) do
      nil -> 0
      row_idx -> compute_from_row(ctx, row_idx, col, free_map)
    end
  end

  defp compute_from_row(ctx, row_idx, col, free_map) do
    row = Enum.at(ctx.reduced, row_idx)
    pivot_val = Enum.at(row, col)
    rhs = List.last(row)
    contrib = compute_free_contribution(row, ctx.free_cols, free_map)
    adjusted_rhs = rhs - contrib

    if rem(adjusted_rhs, pivot_val) == 0 do
      div(adjusted_rhs, pivot_val)
    else
      :invalid
    end
  end

  defp compute_free_contribution(row, free_cols, free_map) do
    Enum.reduce(free_cols, 0, fn fc, acc ->
      coeff = Enum.at(row, fc)
      fv = Map.get(free_map, fc)
      acc + coeff * fv
    end)
  end

  defp cartesian([]), do: [[]]
  defp cartesian([range | rest]) do
    for x <- range, tail <- cartesian(rest), do: [x | tail]
  end
end
