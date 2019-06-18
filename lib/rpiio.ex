defmodule Inky.RpiIO do
  @moduledoc """
  An InkyIO implementation intended for use with raspberry pis and relies on
  Circuits.GPIO and Cirtuits.SPI.
  """

  @behaviour Inky.InkyIO

  alias Circuits.GPIO
  alias Circuits.SPI
  alias Inky.InkyIO

  defmodule State do
    @moduledoc false

    @state_fields [:dc_pid, :reset_pid, :busy_pid, :spi_pid]

    @enforce_keys @state_fields
    defstruct @state_fields
  end

  @reset_pin 27
  @busy_pin 17
  @dc_pin 22
  @cs0_pin 0

  @default_pin_mappings %{
    dc_pin: @dc_pin,
    reset_pin: @reset_pin,
    busy_pin: @busy_pin,
    cs0_pin: @cs0_pin
  }

  @spi_speed_hz 488_000
  @spi_command 0
  @spi_data 1

  # API

  @impl InkyIO
  def init(opts \\ []) do
    pin_mappings = opts[:pin_mappings] || @default_pin_mappings

    spi_address = "spidev0." <> to_string(pin_mappings[:cs0_pin])

    {:ok, dc_pid} = GPIO.open(pin_mappings[:dc_pin], :output)
    {:ok, reset_pid} = GPIO.open(pin_mappings[:reset_pin], :output)
    {:ok, busy_pid} = GPIO.open(pin_mappings[:busy_pin], :input)
    {:ok, spi_pid} = SPI.open(spi_address, speed_hz: @spi_speed_hz)

    # Use binary pattern matching to pull out the ADC counts (low 10 bits)
    # <<_::size(6), counts::size(10)>> = SPI.transfer(spi_pid, <<0x78, 0x00>>)
    %State{dc_pid: dc_pid, reset_pid: reset_pid, busy_pid: busy_pid, spi_pid: spi_pid}
  end

  @impl InkyIO
  def handle_sleep(_state, duration_ms) do
    :timer.sleep(duration_ms)
  end

  @impl InkyIO
  def handle_read_busy(pins) do
    GPIO.read(pins.busy_pid)
  end

  @impl InkyIO
  def handle_reset(pins, value) do
    :ok = GPIO.write(pins.reset_pid, value)
  end

  @impl InkyIO
  def handle_command(pins, command, data) do
    write_command(pins, command)
    write_data(pins, data)
  end

  @impl InkyIO
  def handle_command(pins, command) do
    write_command(pins, command)
  end

  # IO primitives

  defp write_command(pins, command) do
    value = maybe_wrap_integer(command)
    spi_write(pins, @spi_command, value)
  end

  defp write_data(pins, data) do
    value = maybe_wrap_integer(data)
    spi_write(pins, @spi_data, value)
  end

  defp spi_write(pins, data_or_command, values) when is_list(values) do
    :ok = GPIO.write(pins.dc_pid, data_or_command)
    {:ok, <<_::binary>>} = SPI.transfer(pins.spi_pid, :erlang.list_to_binary(values))
  end

  defp spi_write(pins, data_or_command, value) when is_binary(value) do
    :ok = GPIO.write(pins.dc_pid, data_or_command)
    {:ok, <<_::binary>>} = SPI.transfer(pins.spi_pid, value)
  end

  # internals

  defp maybe_wrap_integer(value), do: if(is_integer(value), do: <<value>>, else: value)
end
