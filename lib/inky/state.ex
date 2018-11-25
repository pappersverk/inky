defmodule Inky.State do
  defstruct(
    type: nil,
    dc_pid: nil,
    reset_pid: nil,
    busy_pid: nil,
    spi_pid: nil,
    width: nil,
    height: nil,
    columns: nil,
    rows: nil,
    rotation: nil,
    color: nil,
    white: nil,
    black: nil,
    red: nil,
    yellow: nil,
    resolution_data: nil,
    pixels: %{}
  )
end
