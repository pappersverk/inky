defmodule Inky.PixelUtil do
  @moduledoc """
  PixelUtil maps pixels to bitstrings to be sent to an Inky screen
  """

  require Logger

  def pixels_to_bits(pixel_data, width, height) do
    {flip_axes, dimension_vectors} = rotation_opts(pixel_data.rotation)
    {x_range, y_range} = rotated_axes(dimension_vectors, width, height)
    {x_range, y_range} = if flip_axes, do: {y_range, x_range}, else: {x_range, y_range}

    Inky.PixelStream.stream_points(x_range, y_range)
    |> Stream.map(fn {x, y} ->
      color =
        if flip_axes,
          do: compute_pixel_color(pixel_data, {y, x}, width, height),
          else: compute_pixel_color(pixel_data, {x, y}, width, height)

      # Logger.debug("#{inspect({x, y})} : #{inspect(flip_axes)} => #{inspect(color)}")
      color
    end)
    |> Stream.map(&{black_bit(&1), accent_bit(&1)})
    |> Enum.reduce({<<>>, <<>>}, &pixel_bit_reducer/2)
  end

  @doc """
  Only exposed for testing purposes. Do not use.

      iex> Enum.map([3, 1, 2, 0], &Inky.PixelUtil.rotation_opts/1)
      [{true, {{:x, :dec}, {:y, :inc}}},
       {true, {{:x, :inc}, {:y, :dec}}},
       {false, {{:x, :dec}, {:y, :dec}}},
       {false, {{:x, :inc}, {:y, :inc}}}]
  """
  def rotation_opts(3), do: {true, {{:x, :dec}, {:y, :inc}}}
  def rotation_opts(1), do: {true, {{:x, :inc}, {:y, :dec}}}
  def rotation_opts(2), do: {false, {{:x, :dec}, {:y, :dec}}}
  def rotation_opts(0), do: {false, {{:x, :inc}, {:y, :inc}}}

  defp rotated_axes({x_spec, y_spec}, width, height),
    do: {
      rotated_dimension(width, height, x_spec),
      rotated_dimension(width, height, y_spec)
    }

  defp rotated_dimension(width, _height, {:x, :inc}), do: 0..(width - 1)
  defp rotated_dimension(width, _height, {:x, :dec}), do: (width - 1)..0
  defp rotated_dimension(_width, height, {:y, :inc}), do: 0..(height - 1)
  defp rotated_dimension(_width, height, {:y, :dec}), do: (height - 1)..0

  defp compute_pixel_color(pixel_data, key = {x, y}, w, h),
    do:
      (pixel_data.overlay || %{})[key] ||
        (pixel_data.painter && pixel_data.painter.(x, y, w, h)) ||
        :black

  defp black_bit(:black), do: <<0::1>>
  defp black_bit(_), do: <<1::1>>

  defp accent_bit(accent) when accent in [:accent, :red, :yellow], do: <<1::1>>
  defp accent_bit(_), do: <<0::1>>

  defp pixel_bit_reducer({bw_bit, accent_bit}, {bw_bits, accent_bits}),
    do: {
      <<bw_bits::bitstring, bw_bit::bits-1>>,
      <<accent_bits::bitstring, accent_bit::bits-1>>
    }
end
