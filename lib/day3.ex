defmodule Day3 do
  @doc ~S"""

  ## Example

      iex> Day3.part1("987654321111111\n811111111111119\n234234234234278\n818181911112111")
      357
  """
  def part1(input) do
    input
    |> parse_input()
    |> Enum.map(&retain_larger_digits(&1, 2))
    |> Enum.sum()
  end

  @doc ~S"""

  ## Example

      iex> Day3.part2("987654321111111\n811111111111119\n234234234234278\n818181911112111")
      3121910778619
  """
  def part2(input) do
    input
    |> parse_input()
    |> Enum.map(&retain_larger_digits(&1, 12))
    |> Enum.sum()
  end

  defp retain_larger_digits(input, n), do: retain_larger_digits(input, n, 0, [])
  defp retain_larger_digits(_i, 0, _s, acc), do: Integer.undigits(Enum.reverse(acc))

  defp retain_larger_digits(input, n, start_pos, acc) do
    # Find the largest digit that is at least n positions from the end
    end_pos = length(input) - n
    search_range = Enum.slice(input, start_pos..end_pos)

    {max_digit, relative_pos} =
      search_range
      |> Enum.with_index()
      |> Enum.max_by(fn {digit, _idx} -> digit end)

    absolute_pos = start_pos + relative_pos
    retain_larger_digits(input, n - 1, absolute_pos + 1, [max_digit | acc])
  end

  defp parse_input(input) do
    input
    |> String.trim()
    |> String.split("\n")
    |> Enum.map(&parse_into_digits/1)
  end

  defp parse_into_digits(input) do
    input
    |> String.to_integer()
    |> Integer.digits()
  end
end
