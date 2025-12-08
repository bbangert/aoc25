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
    {number_lines, operator_line} = normalize_width(number_lines, operator_line)
    width = String.length(operator_line)

    {total, answer, _op} =
      Enum.reduce(0..(width - 1), {0, 0, nil}, fn col, acc ->
        process_column(col, number_lines, operator_line, acc)
      end)

    total + answer
  end

  defp normalize_width(number_lines, operator_line) do
    max_len = [operator_line | number_lines] |> Enum.map(&String.length/1) |> Enum.max()
    {
      Enum.map(number_lines, &String.pad_trailing(&1, max_len)),
      String.pad_trailing(operator_line, max_len)
    }
  end

  defp process_column(col, number_lines, operator_line, {total, answer, op}) do
    {answer, op} = maybe_start_new_problem(String.at(operator_line, col), answer, op)

    case read_column_number(number_lines, col) do
      :space -> {total + answer, answer, op}
      number -> {total, accumulate(op, answer, number), op}
    end
  end

  defp maybe_start_new_problem("*", _answer, _op), do: {1, "*"}
  defp maybe_start_new_problem("+", _answer, _op), do: {0, "+"}
  defp maybe_start_new_problem(_char, answer, op), do: {answer, op}

  defp read_column_number(lines, col) do
    Enum.reduce(lines, {0, true}, fn line, {num, is_space} ->
      case String.at(line, col) do
        char when char >= "0" and char <= "9" ->
          {num * 10 + String.to_integer(char), false}
        _ ->
          {num, is_space}
      end
    end)
    |> then(fn
      {_num, true} -> :space
      {num, false} -> num
    end)
  end

  defp accumulate("*", answer, number), do: answer * number
  defp accumulate("+", answer, number), do: answer + number

  defp parse_lines(input) do
    lines = input |> String.split("\n") |> Enum.filter(&(&1 != ""))
    {number_lines, [operator_line]} = Enum.split(lines, -1)
    {number_lines, operator_line}
  end

  defp parse_numbers(line), do: line |> String.split() |> Enum.map(&String.to_integer/1)

  defp parse_operators(line), do: String.split(line)

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
