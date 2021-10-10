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
      :spi_pid
    ]

    @enforce_keys @state_fields
    defstruct @state_fields
  end

  @colors %{
    :black => 0,
    :white => 1,
    :green => 2,
    :blue => 3,
    :red => 4,
    :yellow => 5,
    :orange => 6,
    :clean => 7
  }

  @default_palette = [
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

  @psr 0x00
  @pwr 0x01
  @pof 0x02
  @pfs 0x03
  @pon 0x04
  @btst 0x06
  @dslp 0x07
  @dtm1 0x10
  @dsp 0x11
  @drf 0x12
  @ipc 0x13
  @pll 0x30
  @tsc 0x40
  @tse 0x41
  @tws 0x42
  @tsr 0x43
  @cdi 0x50
  @lpd 0x51
  @tcon 0x60
  @tres 0x61
  @dam 0x65
  @rev 0x70
  @flg 0x71
  @amv 0x80
  @vv 0x81
  @vdcs 0x82
  @pws 0xE3
  @tsset 0xE5

  @default_pin_mappings %{
    busy_pin: @busy_pin,
    cs0_pin: @cs0_pin,
    dc_pin: @dc_pin,
    reset_pin: @reset_pin
  }

  @spi_speed_hz 488_000
  @spi_command 0
  @spi_data 1
  @spi_chunk_size 4096

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

    spi_address = "spidev0." <> to_string(pin_mappings[:cs0_pin])

    # TODO: Resume straight porting here, up to https://github.com/pimoroni/inky/blob/master/library/inky/inky_uc8159.py#L130

    {:ok, dc_pid} = gpio.open(pin_mappings[:dc_pin], :output)
    {:ok, reset_pid} = gpio.open(pin_mappings[:reset_pin], :output)
    {:ok, busy_pid} = gpio.open(pin_mappings[:busy_pin], :input)
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
    :ok = gpio_call(state, :write, [state.dc_pid, data_or_command])

    case spi_call(state, :transfer, [state.spi_pid, value]) do
      {:ok, response} -> {:ok, response}
      {:error, :transfer_failed} -> spi_call_chunked(state, value)
    end
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
