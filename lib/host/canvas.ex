defmodule Inky.Host.Canvas do
  @behaviour :wx_object

  @title "Inky"

  def start_link(config = %{size: _size, accent: _accent}) do
    :wx_object.start_link(__MODULE__, config, [])
  end

  def init(%{size: size, accent: accent}) do
    wx = :wx.new()
    frame = :wxFrame.new(wx, -1, @title, size: size)
    :wxWindow.setClientSize(frame, size)
    :wxFrame.connect(frame, :close_window)

    panel = :wxPanel.new(frame, size: size)
    :wxPanel.connect(panel, :paint, [:callback])
    :wxFrame.show(frame)

    state = %{
      panel: panel,
      size: size,
      frame: frame,
      accent: accent,
      pixels: %{}
    }

    Process.send_after(self(), :refresh, 200)
    {frame, state}
  end

  @spec handle_call({:draw_pixels, any}, any, %{pixels: any}) :: {:reply, nil, %{pixels: any}}
  def handle_call({:draw_pixels, pixels}, _from, state) do
    state = %{state | pixels: pixels}
    {:reply, nil, state}
  end

  def handle_info(:refresh, state) do
    :wxWindow.refresh(state.frame)
    Process.send_after(self(), :refresh, 200)
    {:noreply, state}
  end

  defp draw_pixel(_, _, _, _, nil) do
  end

  defp draw_pixel(dc, x, y, brushes, color) do
    brush = brushes[color]

    :wxDC.setBrush(dc, brush)
    :wxDC.setPen(dc, :wxPen.new({255, 255, 255, 0}))
    :wxDC.drawRectangle(dc, {x, y}, {x + 1, y + 1})
  end

  def handle_event({:wx, _, _, _, {:wxSize, :size, _size, _}}, state) do
    {:noreply, state}
  end

  def handle_event({:wx, _, _, _, {:wxClose, :close_window}}, state) do
    {:stop, :normal, state}
  end

  def handle_sync_event({:wx, _, _, _, {:wxPaint, :paint}}, _, state) do
    %{
      panel: panel,
      frame: frame,
      accent: accent,
      pixels: pixels
    } = state

    # Must be created, even if not used.
    dc = :wxPaintDC.new(panel)

    accent_brush_color =
      case accent do
        :red -> {255, 0, 0}
        :yellow -> {255, 255, 0}
        _ -> {0, 255, 0}
      end

    brushes = %{
      black: :wxBrush.new({0, 0, 0}),
      white: :wxBrush.new({255, 255, 255}),
      accent: :wxBrush.new(accent_brush_color)
    }

    {width, height} = state.size



    for y <- 0..(height - 1),
        x <- 0..(width - 1),
        do: draw_pixel(dc, x, y, brushes, pixels[{x, y}])

    :wxWindow.show(frame)

    :wxPaintDC.destroy(dc)

    :ok
  end
end
