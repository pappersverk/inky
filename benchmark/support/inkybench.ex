defmodule Inky.InkyBench do
  @moduledoc false

  use Bitwise

  def run(opts) do
    for _ <- 0..opts[:runs] do
      {:ok, state} = Inky.init([:phat, :red, [hal_mod: Inky.BenchHAL]])
      Inky.handle_call({:set_pixels, &painter/5, %{}}, nil, state)
    end
  end

  defp painter(x, y, w, h, _pixels_so_far) do
    {wh, hh} = painter_params(x, y, w, h)
    x_even = is_even(x)
    painter_color(wh, hh, x_even)
  end

  defp painter_params(x, y, w, h), do: {w / 2 < x, h / 2 < y}

  defp is_even(x), do: not (band(x, 1) == 1)

  defp painter_color(wh, hh, x_even) do
    case {wh, hh} do
      {true, true} -> :red
      {false, true} -> if(x_even, do: :black, else: :white)
      {true, false} -> :black
      {false, false} -> :white
    end
  end
end
