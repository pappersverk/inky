defmodule InkySimple do
  @moduledoc """
  This is a simple API to Inky for the Simple Display Standard.
  """
  @behaviour SimpleDisplay

  @impl SimpleDisplay
  def info(pid) do
    {:ok, %{width: width, height: height}} = Inky.display_info(pid)
    {:ok, %{resolution: {width, height}}}
  end

  @impl SimpleDisplay
  def set_pixels(pid, pixels) do
    {:ok, %{width: width, height: _height}} = Inky.display_info(pid)

    pixel_map =
      Enum.reduce(
        pixels,
        {{0, 0}, %{}},
        fn pixel, {{x, y}, pixel_map} ->
          pixel_map = Map.put(pixel_map, {x, y}, pixel)

          {x, y} =
            if x >= width - 1 do
              {0, y + 1}
            else
              {x + 1, y}
            end

          {{x, y}, pixel_map}
        end
      )

    Inky.set_pixels(pid, pixel_map, %{push: :skip})
    :ok
  end

  @impl SimpleDisplay
  def render_to_display(pid) do
    Inky.show(pid)
    :ok
  end
end
