defmodule Inky.PixelUtil do
  @moduledoc """
  `PixelUtil` maps pixels to bitstrings to be sent to an Inky screen
  """

  def pixels_to_bits(pixels, width, height, rotation_degrees, color_map) do
    opts = bitstring_traversal_opts(rotation_degrees, width, height)
    do_pixels_to_bits(pixels, color_map, opts)
  end

  @doc """
  Only exposed for testing purposes. Do not use.

  ## Doctests

      iex> Inky.PixelUtil.bitstring_traversal_opts(0, 212, 104)
      {:y_outer, 0, 103, 0, 211}

      iex> Inky.PixelUtil.bitstring_traversal_opts(180, 212, 104)
      {:y_outer, 103, 0, 211, 0}

      iex> Inky.PixelUtil.bitstring_traversal_opts(-90, 212, 104)
      {:x_outer, 211, 0, 0, 103}

      iex> Inky.PixelUtil.bitstring_traversal_opts(90, 212, 104)
      {:x_outer, 0, 211, 103, 0}

  """
  def bitstring_traversal_opts(rotation_degrees, width, height) do
    # Simplify and wrap around rotations
    rotation =
      rotation_degrees
      |> div(90)
      |> rem(4)
      |> (fn r -> if(r < 0, do: r + 4, else: r) end).()

    w_n = width - 1
    h_n = height - 1

    case rotation do
      3 -> {:x_outer, w_n, 0, 0, h_n}
      1 -> {:x_outer, 0, w_n, h_n, 0}
      2 -> {:y_outer, h_n, 0, w_n, 0}
      0 -> {:y_outer, 0, h_n, 0, w_n}
    end
  end

  defp do_pixels_to_bits(pixels, color_map, {order, i_1, i_n, j_1, j_n}) do
    cmap = &(color_map[&1] || color_map.miss)

    for i <- i_1..i_n,
        j <- j_1..j_n,
        do: <<cmap.(pixels[pixel_key(order, i, j)])::size(1)>>,
        into: <<>>
  end

  defp pixel_key(:x_outer, i, j), do: {i, j}
  defp pixel_key(:y_outer, i, j), do: {j, i}
end
