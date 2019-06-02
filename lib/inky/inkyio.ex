defmodule Inky.InkyIO do
  alias Circuits.SPI
  alias Circuits.GPIO

  # SPI bus options include:
  # * `mode`: This specifies the clock polarity and phase to use. (0)
  # * `bits_per_word`: bits per word on the bus (8)
  # * `speed_hz`: bus speed (1000000)
  # * `delay_us`: delay between transaction (10)

  @reset_pin 27
  @busy_pin 17
  @dc_pin 22
  @cs0_pin 0
  # Note: unused
  @mosi_pin 10
  # Note: unused
  @sclk_pin 11

  @default_pin_mappings %{
    dc_pin: @dc_pin,
    reset_pin: @reset_pin,
    busy_pin: @busy_pin,
    cs0_pin: @cs0_pin
  }

  @spi_chunk_size 4096
  @spi_speed_hz 488_000
  @spi_command 0
  @spi_data 1

  # API

  def init_pins(pin_mappings \\ @default_pin_mappings) do
    spi_address = "spidev0." <> to_string(pin_mappings[:cs0_pin])

    {:ok, dc_pid} = GPIO.open(pin_mappings[:dc_pin], :output)
    {:ok, reset_pid} = GPIO.open(pin_mappings[:reset_pin], :output)
    {:ok, busy_pid} = GPIO.open(pin_mappings[:busy_pin], :input)
    {:ok, spi_pid} = SPI.open(spi_address, speed_hz: @spi_speed_hz)

    # Use binary pattern matching to pull out the ADC counts (low 10 bits)
    # <<_::size(6), counts::size(10)>> = SPI.transfer(spi_pid, <<0x78, 0x00>>)
    %{dc_pid: dc_pid, reset_pid: reset_pid, busy_pid: busy_pid, spi_pid: spi_pid}
  end

  def reset(pins) do
    :ok = GPIO.write(pins.reset_pid, 0)
    :ok = :timer.sleep(100)
    :ok = GPIO.write(pins.reset_pid, 1)
    :ok = :timer.sleep(100)
  end

  def read_busy(pins) do
    GPIO.read(pins.busy_pid)
  end

  def send_command(pins, command, data) do
    send_command(pins, <<command>>)
    send_data(pins, data)
  end

  def send_command(pins, command) when is_binary(command) do
    spi_write(pins, @spi_command, command)
  end

  def send_command(pins, command) do
    spi_write(pins, @spi_command, <<command>>)
  end

  # SPI data

  defp send_data(pins, data) when is_integer(data) do
    spi_write(pins, @spi_data, <<data::unsigned-little-integer-16>>)
  end

  defp send_data(pins, data) do
    spi_write(pins, @spi_data, data)
  end

  # SPI writes

  defp spi_write(pins, data_or_command, values) when is_list(values) do
    GPIO.write(pins.dc_pid, data_or_command)
    {:ok, <<_::binary>>} = SPI.transfer(pins.spi_pid, :erlang.list_to_binary(values))
  end

  defp spi_write(pins, data_or_command, values) when is_binary(values) do
    GPIO.write(pins.dc_pid, data_or_command)
    {:ok, <<_::binary>>} = SPI.transfer(pins.spi_pid, values)
  end
end
