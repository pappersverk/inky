defmodule Inky.State do
  @enforce_keys [:display, :pins]
  defstruct type: nil,
            pins: nil,
            display: nil,
            packed_height: nil,
            pixels: %{},
            requires_reset: nil
end
