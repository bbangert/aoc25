defmodule Day2 do
  @doc ~S"""

  ## Example

      iex> Day2.part1("11-22,95-115,998-1012,1188511880-1188511890,222220-222224,1698522-1698528,446443-446449,38593856-38593862,565653-565659,824824821-824824827,2121212118-2121212124")
      1227775554
      iex> Day2.part2("11-22,95-115,998-1012,1188511880-1188511890,222220-222224,1698522-1698528,446443-446449,38593856-38593862,565653-565659,824824821-824824827,2121212118-2121212124")
      4174379265
  """
  def part1(input) do
    input
    |> parse_input()
    |> Task.async_stream(&find_invalid_ids(&1, 2))
    |> Stream.map(&elem(&1, 1))
    |> Enum.sum()
  end

  def part2(input) do
    input
    |> parse_input()
    |> Task.async_stream(&find_invalid_ids_for_all_divisors/1)
    |> Stream.map(&elem(&1, 1))
    |> Enum.sum()
  end

  defp find_invalid_ids_for_all_divisors({first, last}) do
    first..last
    |> Stream.filter(&find_invalid_id_for_all_divisors/1)
    |> Enum.sum()
  end

  defp find_invalid_id_for_all_divisors(id) do
    digits = Integer.digits(id)
    digit_count = length(digits)
    digit_count > 1 and Enum.any?(2..digit_count, &is_invalid_id(id, &1))
  end

  defp find_invalid_ids({first, last}, divisor) do
    first..last
    |> Stream.filter(&is_invalid_id(&1, divisor))
    |> Enum.sum()
  end

  defp is_invalid_id(id, divisor) do
    digits = Integer.digits(id)
    digit_count = length(digits)

    if rem(digit_count, divisor) == 0 do
      chunk_size = div(digit_count, divisor)
      chunks = Enum.chunk_every(digits, chunk_size)
      chunk_values = Enum.map(chunks, &Integer.undigits/1)
      first_chunk = hd(chunk_values)
      Enum.all?(chunk_values, &(&1 == first_chunk))
    else
      false
    end
  end

  defp parse_range(range_input) do
    [first, last] = String.split(range_input, "-", parts: 2)
    {String.to_integer(first), String.to_integer(last)}
  end

  defp parse_input(input) do
    input
    |> String.trim()
    |> String.split(",")
    |> Enum.map(&parse_range/1)
  end
end
