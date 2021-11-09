defmodule Inky.Impression.RpiIO do
  @moduledoc """
  An `Inky.InkyIO` implementation intended for use with raspberry pis and relies on
  Circuits.GPIO and Cirtuits.SPI.
  """

  @behaviour Inky.InkyIO

  alias Inky.InkyIO

  defmodule State do
    @moduledoc false

    @state_fields [
      :gpio_mod,
      :spi_mod,
      :busy_pid,
      :dc_pid,
      :reset_pid,
      :spi_pid,
      # The python library uses a CS pin but we haven't been able to use pin 8 as a CS pin
      # :cs_pid
    ]

    @enforce_keys @state_fields
    defstruct @state_fields
  end


  @default_palette [
    [57, 48, 57],
    [255, 255, 255],
    [58, 91, 70],
    [61, 59, 94],
    [156, 72, 75],
    [208, 190, 71],
    [177, 106, 73],
    [255, 255, 255]
  ]

  @reset_pin 27
  @busy_pin 17
  @dc_pin 22
  @cs0_pin 8

  @default_pin_mappings %{
    busy_pin: @busy_pin,
    cs0_pin: @cs0_pin,
    spi: 0,
    dc_pin: @dc_pin,
    reset_pin: @reset_pin
  }

  @spi_speed_hz 3000000
  @spi_command 0
  @spi_data 1
  @spi_chunk_bytes 4096

  @resolution %{
    {600, 448} => {600, 448, 0, 0, 0}
  }

  @border :white

  # API

  @impl InkyIO
  def init(opts \\ []) do
    gpio = opts[:gpio_mod] || Inky.TestGPIO
    spi = opts[:spi_mod] || Inky.TestSPI
    pin_mappings = opts[:pin_mappings] || @default_pin_mappings

    spi_address = "spidev0." <> to_string(pin_mappings[:spi])

    IO.inspect(pin_mappings)
    # MAYBE_DO: Open CS pin
    IO.puts("opening DC pin")
    {:ok, dc_pid} = gpio.open(pin_mappings[:dc_pin], :output, initial_value: 0)
    IO.puts("opening reset pin")
    {:ok, reset_pid} = gpio.open(pin_mappings[:reset_pin], :output, initial_value: 1)
    IO.puts("opening busy pin")
    {:ok, busy_pid} = gpio.open(pin_mappings[:busy_pin], :input)
    IO.puts("opening SPI device")
    {:ok, spi_pid} = spi.open(spi_address, speed_hz: @spi_speed_hz)

    # Use binary pattern matching to pull out the ADC counts (low 10 bits)
    # <<_::size(6), counts::size(10)>> = SPI.transfer(spi_pid, <<0x78, 0x00>>)
    %State{
      gpio_mod: gpio,
      spi_mod: spi,
      busy_pid: busy_pid,
      dc_pid: dc_pid,
      reset_pid: reset_pid,
      spi_pid: spi_pid
    }
    |> IO.inspect(label: "init complete")
  end

  @impl InkyIO
  def handle_sleep(_state, duration_ms) do
    :timer.sleep(duration_ms)
  end

  @impl InkyIO
  def handle_read_busy(state), do: gpio_call(state, :read, [state.busy_pid])

  @impl InkyIO
  def handle_reset(state, value), do: :ok = gpio_call(state, :write, [state.reset_pid, value])

  @impl InkyIO
  def handle_command(state, command, data) do
    write_command(state, command)
    write_data(state, data)
  end

  @impl InkyIO
  def handle_command(state, command) do
    write_command(state, command)
  end

  # IO primitives

  defp write_command(state, command) do
    value = maybe_wrap_integer(command)
    spi_write(state, @spi_command, value)
  end

  require Logger

  defp write_data(state, data) do
    value = maybe_wrap_integer(data)
    spi_write(state, @spi_data, value)
  end

  defp spi_write(state, data_or_command, values) when is_list(values),
    do: spi_write(state, data_or_command, :erlang.list_to_binary(values))

  defp spi_write(state, data_or_command, value) when is_binary(value) do
    # MAYBE_DO: Write a 0 to CS pin
    :ok = gpio_call(state, :write, [state.dc_pid, data_or_command])

    result = case spi_call(state, :transfer, [state.spi_pid, value]) do
      {:ok, response} -> {:ok, response}
      {:error, :transfer_failed} -> spi_call_chunked(state, value)
    end
    # MAYBE_DO: Write a 1 to CS pin
  end

  defp spi_call_chunked(state, value) do
    size = byte_size(value)
    parts = div(size - 1, @spi_chunk_bytes)

    for x <- 0..parts do
      offset = x * @spi_chunk_bytes
      # NOTE: grab the smallest of a chunk or the remainder
      length = min(@spi_chunk_bytes, size - offset)

      {:ok, <<_::binary>>} =
        spi_call(state, :transfer, [state.spi_pid, :binary.part(value, offset, length)])
    end
  end

  # internals

  defp maybe_wrap_integer(value), do: if(is_integer(value), do: <<value>>, else: value)

  defp gpio_call(state, op, args), do: apply(state.gpio_mod, op, args)
  defp spi_call(state, op, args), do: apply(state.spi_mod, op, args)
end
