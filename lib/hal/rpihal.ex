defmodule Inky.RpiHAL do
  @default_io_mod Inky.RpiIO

  @moduledoc """
  An `Inky.HAL` implementation responsible for sending commands to the Inky
  screen. It delegates to whatever IO module its user provides at init, but
  defaults to #{inspect(@default_io_mod)}
  """

  @behaviour Inky.HAL

  @color_map_black %{black: 0, miss: 1}
  @color_map_accent %{red: 1, yellow: 1, accent: 1, miss: 0}

  alias Inky.Display
  alias Inky.HAL
  alias Inky.PixelUtil

  defmodule State do
    @moduledoc false

    @state_fields [:display, :io_mod, :io_state]

    @enforce_keys @state_fields
    defstruct @state_fields
  end

  #
  # API
  #

  @impl HAL
  def init(args) do
    display = args[:display] || raise(ArgumentError, message: ":display missing in args")
    io_mod = args[:io_mod] || @default_io_mod
    io_args = args[:io_args] || []

    %State{
      display: display,
      io_mod: io_mod,
      io_state: io_mod.init(io_args)
    }
  end

  @impl HAL
  def handle_update(pixels, border, push_policy, state = %State{}) do
    display = %Display{width: w, height: h, rotation: r} = state.display
    black_bits = PixelUtil.pixels_to_bits(pixels, w, h, r, @color_map_black)
    accent_bits = PixelUtil.pixels_to_bits(pixels, w, h, r, @color_map_accent)

    reset(state)
    soft_reset(state)

    case pre_update(state, push_policy) do
      :cont -> do_update(state, display, border, black_bits, accent_bits)
      :halt -> {:error, :device_busy}
    end
  end

  #
  # procedures
  #

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

  defp do_update(state, display, border, buf_black, buf_accent) do
    d_pd = display.packed_dimensions

    state
    |> set_analog_block_control()
    |> set_digital_block_control()
    |> set_gate(d_pd.height)
    |> set_gate_driving_voltage()
    |> dummy_line_period()
    |> set_gate_line_width()
    |> set_data_entry_mode()
    |> power_on()
    |> vcom_register()
    |> set_border_color(border)
    |> configure_if_yellow(display.accent)
    |> configure_if_red_what(display.accent, display.type)
    |> set_luts(display.luts)
    |> set_dimensions(d_pd.width, d_pd.height)
    |> push_pixel_data_bw(buf_black)
    |> push_pixel_data_ry(buf_accent)
    |> display_update_sequence()
    |> trigger_display_update()
    |> sleep(50)
    |> await_device()
    |> deep_sleep()

    :ok
  end

  #
  # "routines" and serial commands
  #

  defp reset(state) do
    state
    |> set_reset(0)
    |> sleep(100)
    |> set_reset(1)
    |> sleep(100)
  end

  defp soft_reset(state), do: write_command(state, 0x12)
  defp set_analog_block_control(state), do: write_command(state, 0x74, 0x54)
  defp set_digital_block_control(state), do: write_command(state, 0x7E, 0x3B)
  defp set_gate(state, packed_height), do: write_command(state, 0x01, packed_height <> <<0x00>>)
  defp set_gate_driving_voltage(state), do: write_command(state, 0x03, [0b10000, 0b0001])
  defp dummy_line_period(state), do: write_command(state, 0x3A, 0x07)
  defp set_gate_line_width(state), do: write_command(state, 0x3B, 0x04)
  # Data entry mode setting 0x03 = X/Y increment
  defp set_data_entry_mode(state), do: write_command(state, 0x11, 0x03)
  defp power_on(state), do: write_command(state, 0x04)

  defp vcom_register(state) do
    # VCOM Register, 0x3c = -1.5v?
    write_command(state, 0x2C, 0x3C)
  end

  defp set_border_color(state, border) do
    accent = state.display.accent

    border_data =
      case border do
        # GS Transition Define A + VSS + LUT0
        :black ->
          0b00000000

        # Fix Level Define A + VSH2 + LUT3
        c when c in [:red, :accent] and accent == :red ->
          0b01110011

        # GS Transition Define A + VSH2 + LUT3
        c when c in [:yellow, :accent] and accent == :yellow ->
          0b00110011

        # GS Transition Define A + VSH2 + LUT1
        :white ->
          0b00110001

        _ ->
          raise ArgumentError,
            message: "Invalid border #{inspect(border)} provided. Accent was #{inspect(accent)}"
      end

    write_command(state, 0x3C, border_data)
  end

  defp configure_if_yellow(state, :yellow) do
    # Set voltage of VSH and VSL on Yellow device
    write_command(state, 0x04, 0x07)
  end

  defp configure_if_yellow(state, _) do
    state
  end

  defp configure_if_red_what(state, :red, :what) do
    write_command(state, 0x04, <<0x30, 0xAC, 0x22>>)
  end

  defp configure_if_red_what(state, _, _) do
    state
  end

  defp set_luts(state, luts), do: write_command(state, 0x32, luts)

  defp set_dimensions(state, width_data, packed_height) do
    height_data = <<0, 0>> <> packed_height
    width_data = <<0>> <> width_data

    state
    # Set RAM X Start/End
    |> write_command(0x44, width_data)
    # Set RAM Y Start/End
    |> write_command(0x45, height_data)
  end

  # 0x24 == RAM B/W
  defp push_pixel_data_bw(state, buffer_black),
    do: do_push_pixel_data(state, 0x24, buffer_black)

  # 0x26 == RAM Red/Yellow/etc
  defp push_pixel_data_ry(state, buffer_accent),
    do: do_push_pixel_data(state, 0x26, buffer_accent)

  defp do_push_pixel_data(state, pixel_cmd, pixel_buffer) do
    # Set RAM X Pointer start
    write_command(state, 0x4E, 0x00)

    # Set RAM Y Pointer start
    write_command(state, 0x4F, <<0x00, 0x00>>)
    write_command(state, pixel_cmd, pixel_buffer)
  end

  defp display_update_sequence(state), do: write_command(state, 0x22, 0xC7)
  defp trigger_display_update(state), do: write_command(state, 0x20)
  defp deep_sleep(state), do: write_command(state, 0x10, 0x01)

  #
  # waiting
  #

  defp await_device(state) do
    case read_busy(state) do
      1 ->
        sleep(state, 10)
        await_device(state)

      0 ->
        state
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
