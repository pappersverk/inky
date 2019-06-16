defmodule Inky.PixelUtilTest do
  @moduledoc false

  use ExUnit.Case

  import Inky.PixelUtil, only: [pixels_to_bits: 5]

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

  describe "the new pixel conversion API" do
    test "black, 3x3 pixels", ctx do
      pixels = seed_pixels(ctx.sq3, fn _, _ -> :black end)
      bitstring = pixels_to_bits(pixels, 3, 3, 0, %{black: 0, miss: 1})
      assert to_bit_list(bitstring) == [0, 0, 0, 0, 0, 0, 0, 0, 0]
    end

    test "specific color, red", ctx do
      pixels =
        seed_pixels(ctx.sq3, fn
          0, _ -> :black
          1, _ -> :white
          2, _ -> :red
        end)

      color_map = %{red: 1, yellow: 1, accent: 1, miss: 0}
      bits = pixels |> pixels_to_bits(3, 3, 0, color_map)
      assert to_bit_list(bits) == [0, 0, 1, 0, 0, 1, 0, 0, 1]
    end

    test "generic color, accent", ctx do
      pixels =
        seed_pixels(ctx.sq3, fn
          0, _ -> :black
          1, _ -> :accent
          2, _ -> :white
        end)

      color_map = %{red: 1, yellow: 1, accent: 1, miss: 0}
      bits = pixels |> pixels_to_bits(3, 3, 0, color_map)
      assert to_bit_list(bits) == [0, 1, 0, 0, 1, 0, 0, 1, 0]
    end
  end
end
