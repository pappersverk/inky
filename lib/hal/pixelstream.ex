defmodule Inky.PixelStream do
  @moduledoc """
  Converting pixel data to bitstrings suitable for consumption by Inky over SPI
  """

  def stream_points(x_range, y_range),
    do:
      Stream.resource(
        fn -> stream_init(x_range, y_range) end,
        &stream_step/1,
        fn _ -> :ok end
      )

  defp stream_init(x_range, y_range) do
    x_direction = stream_dimension_direction(x_range)
    y_direction = stream_dimension_direction(y_range)

    {x_start, x_limit} = stream_dimension_spec(x_direction, x_range)
    {y_start, y_limit} = stream_dimension_spec(y_direction, y_range)

    {{x_start, y_start}, {{x_direction, x_limit}, {y_direction, y_limit}}}
  end

  defp stream_dimension_direction(range),
    do: if(range.first < range.last, do: :inc, else: :dec)

  defp stream_dimension_spec(direction, range),
    do: if(direction == :inc, do: {0, range.last}, else: {range.first, range.first})

  # stopping
  defp stream_step(:ok), do: {:halt, :ok}
  # halting conditions
  defp stream_step({val = {x_lim, y_lim}, {{:inc, x_lim}, {:inc, y_lim}}}), do: {[val], :ok}
  defp stream_step({val = {x_lim, 0}, {{:inc, x_lim}, {:dec, _}}}), do: {[val], :ok}
  defp stream_step({val = {0, y_lim}, {{:dec, _}, {:inc, y_lim}}}), do: {[val], :ok}
  defp stream_step({val = {0, 0}, {{:dec, _}, {:dec, _}}}), do: {[val], :ok}
  # reset and step dimension counts at "end of line"
  defp stream_step({val = {xl, y}, {xs = {:inc, xl}, ys = {y_dir, _yl}}}),
    do: {[val], {{reset(xs), y + if(y_dir == :inc, do: 1, else: -1)}, {xs, ys}}}

  defp stream_step({val = {0, y}, {xs = {:dec, _}, ys = {y_dir, _}}}),
    do: {[val], {{reset(xs), y + if(y_dir == :inc, do: 1, else: -1)}, {xs, ys}}}

  # step dimension count for x
  defp stream_step({val = {x, y}, {xs = {x_dir, _}, ys}}),
    do: {[val], {{x + if(x_dir == :inc, do: 1, else: -1), y}, {xs, ys}}}

  defp reset({:inc, _}), do: 0
  defp reset({:dec, limit}), do: limit
end
