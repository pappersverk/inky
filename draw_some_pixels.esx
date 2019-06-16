defmodule Script do
  def main(_args) do
    width = 212
    height = 104
    size = {width, height}
    accent = :red

    config = %{
      size: size,
      accent: accent
    }

    {:wx_ref, _, _, pid} = Inky.Host.Canvas.start_link(config)
    ref = Process.monitor(pid)

    :timer.sleep(1000)

    pixels =
      Enum.reduce(0..(height - 1), %{}, fn y, pixels ->
        Enum.reduce(0..(width - 1), pixels, fn x, pixels ->
          # color = cond do
          #   rem(x, 2) == 0 -> :black
          #   true -> :white
          # end
          color =
            cond do
              x > width / 2 ->
                cond do
                  y > height / 2 ->
                    :accent

                  true ->
                    cond do
                      rem(x, 2) == 0 -> :white
                      true -> :black
                    end
                end

              true ->
                cond do
                  y > height / 2 ->
                    :black

                  true ->
                    :white
                end
            end

          put_in(pixels, [{x, y}], color)
        end)
      end)

    GenServer.call(pid, {:draw_pixels, pixels})

    :timer.sleep(3000)

    pixels =
      Enum.reduce(0..(height - 1), %{}, fn y, pixels ->
        Enum.reduce(0..(width - 1), pixels, fn x, pixels ->
          color = cond do
            rem(x, 2) == 0 -> :black
            true -> :white
          end
          put_in(pixels, [{x, y}], color)
        end)
      end)

    GenServer.call(pid, {:draw_pixels, pixels})

    receive do
      {:DOWN, ^ref, _, _, _} ->
        :ok
    end
  end
end

Script.main(System.argv())
