defmodule Inky.HAL.PhatSSD1608 do
  @default_io_mod Inky.IO.Phat

  @moduledoc """
  An `Inky.HAL` implementation responsible for sending commands to the Inky
  screen with SSD1608 display driver. It delegates to whatever IO module its
  user provides at init, but defaults to #{inspect(@default_io_mod)}
  """

  @behaviour Inky.HAL

  alias Inky.PixelUtil
  import Bitwise

  @color_map_black %{black: 0, miss: 1}
  @color_map_accent %{red: 1, yellow: 1, accent: 1, miss: 0}

  @cols 136
  @rows 250
  @rotation -90
  @lut_data <<0x02, 0x02, 0x01, 0x11, 0x12, 0x12, 0x22, 0x22, 0x66, 0x69, 0x69, 0x59, 0x58, 0x99,
              0x99, 0x88, 0x00, 0x00, 0x00, 0x00, 0xF8, 0xB4, 0x13, 0x51, 0x35, 0x51, 0x51, 0x19,
              0x01, 0x00>>

  @cmd_set_driver_output 0x01
  @cmd_set_data_entry_mode 0x11
  @cmd_soft_reset 0x12
  @cmd_activate_display_update_sequence 0x20
  @cmd_write_ram 0x24
  @cmd_write_alt_ram 0x26
  @cmd_write_vcom 0x2C
  @cmd_write_lut 0x32
  @cmd_set_dummy_line_period 0x3A
  @cmd_set_gate_line_width 0x3B
  @cmd_set_border_waveform 0x3C
  @cmd_set_ram_x_position 0x44
  @cmd_set_ram_y_position 0x45
  @cmd_set_ram_x_address 0x4E
  @cmd_set_ram_y_address 0x4F

  defmodule State do
    @moduledoc false

    @state_fields [:display, :io_mod, :io_state]

    @enforce_keys @state_fields
    defstruct @state_fields

    @type t :: %__MODULE__{}
  end

  #
  # API
  #

  @impl Inky.HAL
  def init(args) do
    display = args[:display] || raise(ArgumentError, message: ":display missing in args")
    io_mod = args[:io_mod] || @default_io_mod

    io_args = args[:io_args] || []
    io_args = if :gpio_mod in io_args, do: io_args, else: [gpio_mod: Circuits.GPIO] ++ io_args
    io_args = if :spi_mod in io_args, do: io_args, else: [spi_mod: Circuits.SPI] ++ io_args

    %State{
      display: display,
      io_mod: io_mod,
      io_state: io_mod.init(io_args)
    }
  end

  @impl Inky.HAL
  def handle_update(pixels, border, push_policy, state = %State{}) do
    black_bits = PixelUtil.pixels_to_bits(pixels, @rows, @cols, @rotation, @color_map_black)
    accent_bits = PixelUtil.pixels_to_bits(pixels, @rows, @cols, @rotation, @color_map_accent)

    state |> set_reset(0) |> sleep(500) |> set_reset(1) |> sleep(500)
    state |> write_command(@cmd_soft_reset) |> sleep(1000)

    case pre_update(state, push_policy) do
      :cont -> do_update(state, state.display, border, black_bits, accent_bits)
      :halt -> {:error, :device_busy}
    end
  end

  #
  # procedures
  #

  @spec pre_update(State.t(), :await | :once) :: :cont | :halt
  defp pre_update(state, :await) do
    await_device(state)
    :cont
  end

  defp pre_update(state, :once) do
    case read_busy(state) do
      0 -> :cont
      1 -> :halt
    end
  end

  @spec do_update(State.t(), Inky.Display.t(), atom(), binary(), binary()) :: :ok
  defp do_update(state, _display, border, black_bits, accent_bits) do
    state
    |> write_command(@cmd_set_driver_output, [@rows - 1, (@rows - 1) >>> 8, 0x00])
    |> write_command(@cmd_set_dummy_line_period, [0x1B])
    |> write_command(@cmd_set_gate_line_width, [0x0B])
    |> write_command(@cmd_set_data_entry_mode, [0x03])
    |> write_command(@cmd_set_ram_x_position, [0x00, div(@cols, 8) - 1])
    |> write_command(@cmd_set_ram_y_position, [0x00, 0x00, @rows - 1, (@rows - 1) >>> 8])
    |> write_command(@cmd_write_vcom, [0x70])
    |> write_command(@cmd_write_lut, @lut_data)
    |> set_border_color(border)
    |> write_command(@cmd_set_ram_x_address, [0x00])
    |> write_command(@cmd_set_ram_y_address, [0x00, 0x00])
    |> write_command(@cmd_write_ram, black_bits)
    |> write_command(@cmd_write_alt_ram, accent_bits)
    |> await_device()
    |> write_command(@cmd_activate_display_update_sequence)

    :ok
  end

  @spec set_border_color(State.t(), atom()) :: State.t()
  defp set_border_color(state, border) do
    accent = state.display.accent

    cond do
      # GS Transition + Waveform 00 + GSA 0 + GSB 0
      border == :black ->
        write_command(state, @cmd_set_border_waveform, 0b00000000)

      # GS Transition + Waveform 01 + GSA 1 + GSB 0
      border in [:red, :accent] and accent == :red ->
        write_command(state, @cmd_set_border_waveform, 0b00000110)

      # GS Transition + Waveform 11 + GSA 1 + GSB 1
      border in [:yellow, :accent] and accent == :yellow ->
        write_command(state, @cmd_set_border_waveform, 0b00001111)

      # GS Transition + Waveform 00 + GSA 0 + GSB 1
      border == :white ->
        write_command(state, @cmd_set_border_waveform, 0b00000001)

      true ->
        raise ArgumentError,
          message: "Invalid border #{inspect(border)} provided. Accent was #{inspect(accent)}"
    end
  end

  #
  # waiting
  #

  @spec await_device(State.t()) :: State.t()
  defp await_device(state) do
    case read_busy(state) do
      1 -> state |> sleep(10) |> await_device()
      0 -> state
    end
  end

  #
  # pipe-able wrappers
  #

  defp sleep(state, sleep_time) do
    io_call(state, :handle_sleep, [sleep_time])
    state
  end

  defp set_reset(state, value) do
    io_call(state, :handle_reset, [value])
    state
  end

  defp read_busy(state) do
    io_call(state, :handle_read_busy)
  end

  defp write_command(state, command) do
    io_call(state, :handle_command, [command])
    state
  end

  defp write_command(state, command, data) do
    io_call(state, :handle_command, [command, data])
    state
  end

  #
  # Behaviour dispatching
  #

  # Dispatch to the IO callback module that's held in state, using the previously obtained state
  defp io_call(state, op, args \\ []) do
    apply(state.io_mod, op, [state.io_state | args])
  end
end
