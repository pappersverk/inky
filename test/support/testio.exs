alias Inky.InkyIO

defmodule Inky.TestIO do
  @behaviour InkyIO

  def assert_expectations() do
    case Process.get(:read_busy, :not_set) do
      [] -> :ok
      b when is_integer(b) -> :ok
      :not_set -> raise ArgumentError, message: "busy-value never set"
      v -> raise ArgumentError, message: "Unexpected busy-value: #{inspect(v)}"
    end
  end

  @impl InkyIO
  def init(args) do
    if(args[:read_busy] != nil, do: Process.put(:read_busy, args[:read_busy]))
    send(self(), {:init, args})
    {:init, args}
  end

  @impl InkyIO
  def handle_sleep({:init, _}, duration_ms), do: send(self(), {:sleep, duration_ms})

  @impl InkyIO
  def handle_read_busy({:init, _}) do
    busy = do_handle_read_busy()
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

  # Internals

  defp do_handle_read_busy() do
    case Process.get(:read_busy, :not_set) do
      :not_set ->
        raise(ArgumentError, message: "Tried to read busy without any mock values left")

      [] ->
        raise(ArgumentError, message: "Tried to read busy with no mock values left")

      busy_list when is_list(busy_list) ->
        Process.put(:read_busy, tl(busy_list))
        hd(busy_list)

      busy_value ->
        busy_value
    end
  end
end
