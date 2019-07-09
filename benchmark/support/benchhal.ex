defmodule Inky.BenchHAL do
  @moduledoc false

  @behaviour Inky.HAL

  @impl Inky.HAL
  def init(args), do: Inky.RpiHAL.init(display: args[:display], io_mod: Inky.BenchIO)

  @impl Inky.HAL
  def handle_update(pixels, border, push_policy, state),
    do: Inky.RpiHAL.handle_update(pixels, border, push_policy, state)
end
