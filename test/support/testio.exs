alias Inky.InkyIO

defmodule Inky.TestIO do
  @behaviour InkyIO

  @impl InkyIO
  def init(args) do
    args[:read_busy] && Process.put(:read_busy, args[:read_busy])
    send(self(), {:init, args})
    {:init, args}
  end

  @impl InkyIO
  def handle_sleep({:init, _}, duration_ms), do: send(self(), {:sleep, duration_ms})

  @impl InkyIO
  def handle_read_busy({:init, _}) do
    busy_sequence = Process.get(:read_busy, :value_missing)
    busy = hd(busy_sequence)

    Process.put(:read_busy, tl(busy_sequence))
    send(self(), {:read_busy, busy})

    busy
  end

  @impl InkyIO
  def handle_reset({:init, _}, bit), do: send(self(), {:write_reset, bit})

  @impl InkyIO
  def handle_command({:init, _}, command), do: {send(self(), {:send_command, command}), ""}

  @impl InkyIO
  def handle_command({:init, _}, command, data),
    do: {send(self(), {:send_command, {command, data}}), ""}
end
