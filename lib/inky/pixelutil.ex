defmodule Inky.PixelUtil do
  def pixels_to_bitstring(pixels, display, color) do
    rotation = display.rotation / 90
    width = display.width
    height = display.height

    p2b =
      case color do
        :black -> &pixel_to_black/1
        _ -> &pixel_to_accent/1
      end

    opts = bitstring_traversal_opts(rotation, width, height)
    do_pixels_to_bitstring(pixels, p2b, opts)
  end

  defp pixel_to_black(:black), do: 0
  defp pixel_to_black(_), do: 1

  defp pixel_to_accent(c) when c in [:red, :yellow, :accent], do: 1
  defp pixel_to_accent(_), do: 0

  defp bitstring_traversal_opts(rotation, width, height) do
    case rotation do
      -1.0 -> %{order: :x_outer, i_1: width - 1, i_n: 0, j_1: 0, j_n: height - 1}
      1.0 -> %{order: :x_outer, i_1: 0, i_n: width - 1, j_1: height - 1, j_n: 0}
      -2.0 -> %{order: :y_outer, i_1: height - 1, i_n: 0, j_1: width - 1, j_n: 0}
      _ -> %{order: :y_outer, i_1: 0, i_n: height - 1, j_1: 0, j_n: width - 1}
    end
  end

  defp do_pixels_to_bitstring(pixels, p2b, opts) do
    for i <- opts.i_1..opts.i_n,
        j <- opts.j_1..opts.j_n,
        do: <<pixel_value(pixels, p2b, opts.order, i, j)::size(1)>>,
        into: <<>>
  end

  defp pixel_value(pixels, p2b, order, i, j) do
    key = pixel_key(order, i, j)
    p2b.(pixels[key])
  end

  defp pixel_key(:x_outer, i, j), do: {i, j}
  defp pixel_key(:y_outer, i, j), do: {j, i}
end
