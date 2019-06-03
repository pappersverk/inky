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
    w_n = width - 1
    h_n = height - 1

    case rotation do
      -1.0 -> {:x_outer, w_n, 0, 0, h_n}
      1.0 -> {:x_outer, 0, w_n, h_n, 0}
      -2.0 -> {:y_outer, h_n, 0, w_n, 0}
      _ -> {:y_outer, 0, h_n, 0, w_n}
    end
  end

  defp do_pixels_to_bitstring(pixels, p2b, {order, i_1, i_n, j_1, j_n}) do
    for i <- i_1..i_n,
        j <- j_1..j_n,
        do: <<pixel_value(pixels, p2b, order, i, j)::size(1)>>,
        into: <<>>
  end

  defp pixel_value(pixels, p2b, order, i, j) do
    key = pixel_key(order, i, j)
    p2b.(pixels[key])
  end

  defp pixel_key(:x_outer, i, j), do: {i, j}
  defp pixel_key(:y_outer, i, j), do: {j, i}
end
