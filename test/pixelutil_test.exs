defmodule Inky.PixelUtilTest do
  @moduledoc false

  use ExUnit.Case

  import Inky.PixelUtil, only: [pixels_to_bits: 4]

  doctest Inky.PixelUtil

  setup_all do
    %{:sq3 => for(i <- 0..2, j <- 0..2, do: {i, j})}
  end

  defp seed_pixels(points, p2c) do
    for {i, j} <- points, do: {{i, j}, p2c.(i, j)}, into: %{}
  end

  defp to_bit_list(bitstring) do
    for <<b::1 <- bitstring>>, do: b, into: []
  end

  describe "the pixel conversion API" do
    test "black, 3x3 pixels", ctx do
      pixels = seed_pixels(ctx.sq3, fn _, _ -> :black end)
      {black_bits, accent_bits} = pixels_to_bits(pixels, 3, 3, 0)
      assert to_bit_list(black_bits) == [0, 0, 0, 0, 0, 0, 0, 0, 0]
      assert to_bit_list(accent_bits) == [0, 0, 0, 0, 0, 0, 0, 0, 0]
    end

    test "specific color, red", ctx do
      pixels =
        seed_pixels(ctx.sq3, fn
          0, _ -> :black
          1, _ -> :white
          2, _ -> :red
        end)

      {black_bits, accent_bits} = pixels_to_bits(pixels, 3, 3, 0)
      assert to_bit_list(black_bits) == [0, 1, 1, 0, 1, 1, 0, 1, 1]
      assert to_bit_list(accent_bits) == [0, 0, 1, 0, 0, 1, 0, 0, 1]
    end

    test "generic color, accent", ctx do
      pixels =
        seed_pixels(ctx.sq3, fn
          0, _ -> :black
          1, _ -> :accent
          2, _ -> :white
        end)

      {black_bits, accent_bits} = pixels_to_bits(pixels, 3, 3, 0)
      assert to_bit_list(black_bits) == [0, 1, 1, 0, 1, 1, 0, 1, 1]
      assert to_bit_list(accent_bits) == [0, 1, 0, 0, 1, 0, 0, 1, 0]
    end
  end
end
