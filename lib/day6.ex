defmodule Day6 do
  @doc ~S"""

  ## Example

      iex> Day6.part1("123 328  51 64 \n45 64  387 23 \n 6 98  215 314\n*   +   *   +  \n")
      4277556
  """
  def part1(input) do
    {number_lines, operator_line} = parse_lines(input)

    numbers_by_row = Enum.map(number_lines, &parse_numbers/1)
    operators = parse_operators(operator_line)

    numbers_by_row
    |> transpose()
    |> Enum.zip(operators)
    |> Enum.map(fn {numbers, operator} -> apply_operator(numbers, operator) end)
    |> Enum.sum()
  end

  @doc ~S"""

  ## Example

      iex> Day6.part2("123 328  51 64 \n 45 64  387 23 \n  6 98  215 314\n*   +   *   +  \n")
      3263827
  """
  def part2(input) do
    {number_lines, operator_line} = parse_lines(input)

    number_lines
    |> pad_to_match(operator_line)
    |> to_char_columns()
    |> attach_operators(operator_line)
    |> group_into_problems()
    |> Enum.map(&solve_problem/1)
    |> Enum.sum()
  end

  defp parse_lines(input) do
    lines = input |> String.split("\n") |> Enum.filter(&(&1 != ""))
    {number_lines, [operator_line]} = Enum.split(lines, -1)
    {number_lines, operator_line}
  end

  defp parse_numbers(line), do: line |> String.split() |> Enum.map(&String.to_integer/1)

  defp parse_operators(line), do: String.split(line)

  defp pad_to_match(number_lines, operator_line) do
    max_len = [operator_line | number_lines] |> Enum.map(&String.length/1) |> Enum.max()
    Enum.map(number_lines, &String.pad_trailing(&1, max_len))
  end

  defp to_char_columns(lines) do
    lines
    |> Enum.map(&String.graphemes/1)
    |> Enum.zip_with(&Function.identity/1)
  end

  defp attach_operators(columns, operator_line) do
    op_chars = String.graphemes(String.pad_trailing(operator_line, length(columns)))
    Enum.zip(columns, op_chars)
  end

  defp group_into_problems(cols_with_ops) do
    cols_with_ops
    |> Enum.chunk_by(&separator_column?/1)
    |> Enum.reject(fn [first | _] -> separator_column?(first) end)
  end

  defp separator_column?({digits, op}), do: op == " " and Enum.all?(digits, &(&1 == " "))

  defp solve_problem(cols_with_ops) do
    operator = find_operator(cols_with_ops)
    numbers = extract_numbers(cols_with_ops)
    apply_operator(numbers, operator)
  end

  defp find_operator(cols_with_ops) do
    Enum.find_value(cols_with_ops, fn {_, op} -> if op != " ", do: op end)
  end

  defp extract_numbers(cols_with_ops) do
    cols_with_ops
    |> Enum.map(fn {digits, _} -> column_to_number(digits) end)
    |> Enum.reject(&is_nil/1)
  end

  defp column_to_number(digits) do
    case digits |> Enum.join() |> String.trim() do
      "" -> nil
      s -> String.to_integer(s)
    end
  end

  defp transpose(rows) do
    rows
    |> Enum.zip()
    |> Enum.map(&Tuple.to_list/1)
  end

  defp apply_operator(numbers, operator) do
    case operator do
      "+" -> Enum.sum(numbers)
      "*" -> Enum.product(numbers)
      _ -> raise "Unknown operator: #{operator}"
    end
  end
end
