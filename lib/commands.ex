defmodule Inky.Commands do
  @moduledoc """
  `Commands` is responsible for sending commands to the Inky screen. It delegates
  to whatever IO module its user provides at init
  """

  defmodule State do
    @moduledoc false

    @state_fields [:io_mod, :io_state]

    @enforce_keys @state_fields
    defstruct @state_fields
  end

  @default_io_mod Inky.RpiIO

  # API
  def init_io(io_mod \\ @default_io_mod, io_args \\ []) do
    %State{io_mod: io_mod, io_state: io_mod.init(io_args)}
  end

  def update(state = %State{}, display, buffer_black, buffer_accent) do
    d_pd = display.packed_dimensions

    state
    |> reset()
    |> soft_reset()
    |> await_device()
    |> set_analog_block_control()
    |> set_digital_block_control()
    |> set_gate(d_pd.height)
    |> set_gate_driving_voltage()
    |> dummy_line_period()
    |> set_gate_line_width()
    |> set_data_entry_mode()
    |> power_on()
    |> vcom_register()
    |> set_border_color()
    |> configure_if_yellow(display.accent)
    |> set_luts(display.luts)
    |> set_dimensions(d_pd.width, d_pd.height)
    |> push_pixel_data(buffer_black, buffer_accent)
    |> display_update_sequence()
    |> trigger_display_update()
    |> wait_before_sleep()
    |> deep_sleep()

    :ok
  end

  defp reset(state) do
    io_call(state, :handle_reset, [0])
    io_call(state, :handle_sleep, [100])
    io_call(state, :handle_reset, [1])
    io_call(state, :handle_sleep, [100])
    state
  end

  # SPI commands

  defp wait_before_sleep(state) do
    io_call(state, :handle_sleep, [50])
    await_device(state)
  end

  defp await_device(state) do
    should_wait = io_call(state, :handle_read_busy) == 1

    if should_wait do
      io_call(state, :handle_sleep, [10])
      await_device(state)
    else
      state
    end
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
    write_command(state, 0x3C, 0x00)
  end

  defp set_border_color(state), do: write_command(state, 0x3C, 0x00)

  defp configure_if_yellow(state, accent) do
    # Set voltage of VSH and VSL on Yellow device
    if accent == :yellow do
      write_command(state, 0x04, 0x07)
    else
      state
    end
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

  defp push_pixel_data(state, buffer_black, buffer_accent) do
    # 0x24 == RAM B/W
    do_push_pixel_data(state, 0x24, buffer_black)
    # 0x26 == RAM Red/Yellow/etc
    do_push_pixel_data(state, 0x26, buffer_accent)
    state
  end

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

  # pipe-able wrappers

  defp write_command(state, command) do
    io_call(state, :handle_command, [command])
    state
  end

  defp write_command(state, command, data) do
    io_call(state, :handle_command, [command, data])
    state
  end

  # Dispatch to the IO callback module that's held in state, using the previously obtained state
  defp io_call(state, op, args \\ []) do
    apply(state.io_mod, op, [state.io_state | args])
  end
end
