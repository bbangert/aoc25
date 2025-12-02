defmodule Day1 do
  @doc ~S"""

  ## Example

      iex> Day1.part1("L68\nL30\nR48\nL5\nR60\nL55\nL1\nL99\nR14\nL82")
      3
  """
  def part1(input) do
    input
    |> parse_input()
    |> execute_commands(50, 0)
  end

  @doc ~S"""

  ## Example

      iex> Day1.part2("L68\nL30\nR48\nL5\nR60\nL55\nL1\nL99\nR14\nL82")
      6
  """
  def part2(input) do
    input
    |> parse_input()
    |> execute_commands(50, 0, true)
  end

  defp execute_commands(commands, starting_position, count, include_spins \\ false)

  defp execute_commands([command | rest], starting_position, count, include_spins) do
    {new_position, spins} = execute_command(starting_position, command)
    new_count = case new_position do
      0 when include_spins and spins > 0 -> count + spins
      0 when include_spins -> count + 1
      0 -> count + 1
      _ when include_spins -> count + spins
      _ -> count
    end
    execute_commands(rest, new_position, new_count, include_spins)
  end

  defp execute_commands([], _starting_position, count, _include_spins), do: count

  def execute_command(starting_position, {:left, amount}) do
    remainder = rem(amount, 100)
    new_pos = rem(starting_position - remainder + 100, 100)
    wraps_past_zero = starting_position > 0 and starting_position <= remainder
    spins = div(amount, 100) + if wraps_past_zero, do: 1, else: 0
    {new_pos, spins}
  end

  def execute_command(starting_position, {:right, amount}) do
    total = starting_position + amount
    {rem(total, 100), div(total, 100)}
  end

  defp parse_line("L" <> amount), do: {:left, String.to_integer(amount)}
  defp parse_line("R" <> amount), do: {:right, String.to_integer(amount)}
  defp parse_line(_), do: raise("Invalid command")

  defp parse_input(input) do
    input
    |> String.trim()
    |> String.split("\n")
    |> Enum.map(&parse_line/1)
  end
end
