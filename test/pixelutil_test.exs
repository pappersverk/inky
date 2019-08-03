defmodule Inky.PixelUtilTest do
  @moduledoc false

  use ExUnit.Case

  require Logger

  doctest Inky.PixelUtil

  setup_all do
    %{
      :rect3x2 => for(i <- 0..2, j <- 0..1, do: {i, j}),
      :rect6x4 => for(i <- 0..5, j <- 0..3, do: {i, j})
    }
  end

  defp seed_pixels(points, p2c) do
    for {i, j} <- points, do: {{i, j}, p2c.(i, j)}, into: %{}
  end

  defp to_bit_list(bitstring), do: for(<<b::1 <- bitstring>>, do: b, into: [])

  describe "the pixel conversion API" do
    test "all black", ctx do
      {black_bits, accent_bits} =
        Inky.PixelData.new(-90)
        |> Inky.PixelData.update(seed_pixels(ctx.rect3x2, fn _, _ -> :black end))
        |> Inky.PixelUtil.pixels_to_bits(3, 2)

      assert to_bit_list(black_bits) == [0, 0, 0, 0, 0, 0]
      assert to_bit_list(accent_bits) == [0, 0, 0, 0, 0, 0]
    end

    test "a non-rotated display" do
      display = Inky.Display.spec_for(:test_big, :red)
      display_points = for(i <- 0..(display.width - 1), j <- 0..(display.height - 1), do: {i, j})

      {black_bits, accent_bits} =
        Inky.PixelData.new(display.rotation)
        |> Inky.PixelData.update(
          seed_pixels(display_points, fn x, _y -> if(rem(x, 2) == 0, do: :black, else: :red) end)
        )
        |> Inky.PixelUtil.pixels_to_bits(display.width, display.height)

      assert black_bits |> to_bit_list() == [0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0]
      assert accent_bits |> to_bit_list() == [0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0]
    end

    test "column major coloring, red", ctx do
      {black_bits, accent_bits} =
        Inky.PixelData.new(-90)
        |> Inky.PixelData.update(
          seed_pixels(ctx.rect3x2, fn
            0, _ -> :black
            1, _ -> :white
            2, _ -> :red
          end)
        )
        |> Inky.PixelUtil.pixels_to_bits(3, 2)

      assert to_bit_list(black_bits) == [1, 1, 1, 1, 0, 0]
      assert to_bit_list(accent_bits) == [1, 1, 0, 0, 0, 0]
    end

    test "column major coloring, accent", ctx do
      {black_bits, accent_bits} =
        Inky.PixelData.new(-90)
        |> Inky.PixelData.update(
          seed_pixels(ctx.rect3x2, fn
            0, _ -> :black
            1, _ -> :accent
            2, _ -> :white
          end)
        )
        |> Inky.PixelUtil.pixels_to_bits(3, 2)

      assert to_bit_list(black_bits) == [1, 1, 1, 1, 0, 0]
      assert to_bit_list(accent_bits) == [0, 0, 1, 1, 0, 0]
    end

    test "row major coloring, red", ctx do
      {black_bits, accent_bits} =
        Inky.PixelData.new(-90)
        |> Inky.PixelData.update(
          seed_pixels(ctx.rect3x2, fn
            _, 0 -> :black
            _, 1 -> :white
            _, 2 -> :red
          end)
        )
        |> Inky.PixelUtil.pixels_to_bits(3, 2)

      assert to_bit_list(black_bits) == [0, 1, 0, 1, 0, 1]
      assert to_bit_list(accent_bits) == [0, 0, 0, 0, 0, 0]
    end

    test "row major coloring, accent", ctx do
      {black_bits, accent_bits} =
        Inky.PixelData.new(-90)
        |> Inky.PixelData.update(
          seed_pixels(ctx.rect3x2, fn
            _, 0 -> :black
            _, 1 -> :accent
            _, 2 -> :white
          end)
        )
        |> Inky.PixelUtil.pixels_to_bits(3, 2)

      assert to_bit_list(black_bits) == [0, 1, 0, 1, 0, 1]
      assert to_bit_list(accent_bits) == [0, 1, 0, 1, 0, 1]
    end
  end
end
