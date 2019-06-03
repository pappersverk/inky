defmodule Inky.Commands do
  alias Inky.InkyIO

  # API
  def pixels_to_bitstring(pixels, display, p2b) do
    rotation = display.rotation / 90
    width = display.width
    height = display.height

    opts = bitstring_traversal_opts(rotation, width, height)
    do_pixels_to_bitstring(pixels, p2b, opts)
  end

  def update(pins, display, buffer_black, buffer_accent) do
    d_pd = display.packed_dimensions

    pins
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

  def soft_reset(pins) do
    send_command(pins, 0x12)
  end

  def await_device(pins) do
    should_wait = InkyIO.read_busy(pins) == 1

    if should_wait do
      :timer.sleep(10)
      await_device(pins)
    else
      :ok
    end
  end

  # Bitstringifying

  defp bitstring_traversal_opts(rotation, width, height) do
    case rotation do
      -1.0 -> %{order: :x_outer, i_1: width - 1, i_n: 0, j_1: 0, j_n: height - 1}
      1.0 -> %{order: :x_outer, i_1: 0, i_n: width - 1, j_1: height - 1, j_n: 0}
      -2.0 -> %{order: :y_outer, i_1: height - 1, i_n: 0, j_1: width - 1, j_n: 0}
      _ -> %{order: :y_outer, i_1: 0, i_n: height - 1, j_1: 0, j_n: width - 1}
    end
  end

  defp do_pixels_to_bitstring(pixels, p2b, opts) do
    for i <- opts.i_1..opts.i_n,
        j <- opts.j_1..opts.j_n,
        do: <<pixel_value(pixels, p2b, opts.order, i, j)::size(1)>>,
        into: <<>>
  end

  defp pixel_value(pixels, p2b, order, i, j) do
    key = pixel_key(order, i, j)
    p2b.(pixels[key])
  end

  defp pixel_key(:x_outer, i, j), do: {i, j}
  defp pixel_key(:y_outer, i, j), do: {j, i}

  # Update commands

  defp set_analog_block_control(pins) do
    send_command(pins, 0x74, 0x54)
  end

  defp set_digital_block_control(pins) do
    send_command(pins, 0x7E, 0x3B)
  end

  defp set_gate(pins, packed_height) do
    data = <<packed_height::unsigned-little-integer-16, 0>>
    send_command(pins, 0x01, data)
  end

  defp set_gate_driving_voltage(pins) do
    send_command(pins, 0x03, [0b10000, 0b0001])
  end

  defp dummy_line_period(pins) do
    send_command(pins, 0x3A, 0x07)
  end

  defp set_gate_line_width(pins) do
    send_command(pins, 0x3B, 0x04)
  end

  defp set_data_entry_mode(pins) do
    # Data entry mode setting 0x03 = X/Y increment
    send_command(pins, 0x11, 0x03)
  end

  defp power_on(pins) do
    send_command(pins, 0x04)
  end

  defp vcom_register(pins) do
    # VCOM Register, 0x3c = -1.5v?
    send_command(pins, 0x2C, 0x3C)
    send_command(pins, 0x3C, 0x00)
  end

  defp set_border_color(pins) do
    # Always black border
    send_command(pins, 0x3C, 0x00)
  end

  defp configure_if_yellow(pins, accent) do
    # Set voltage of VSH and VSL on Yellow device
    if accent == :yellow do
      send_command(pins, 0x04, 0x07)
    else
      pins
    end
  end

  defp set_luts(pins, luts) do
    send_command(pins, 0x32, luts)
  end

  defp set_dimensions(pins, width_data, packed_height) do
    height_data = <<0, 0, packed_height::unsigned-little-integer-16>>

    pins
    # Set RAM X Start/End
    |> send_command(0x44, width_data)
    # Set RAM Y Start/End
    |> send_command(0x45, height_data)
  end

  defp push_pixel_data(pins, buffer_black, buffer_accent) do
    # 0x24 == RAM B/W
    do_push_pixel_data(pins, 0x24, buffer_black)
    # 0x26 == RAM Red/Yellow/etc
    do_push_pixel_data(pins, 0x26, buffer_accent)
    pins
  end

  defp do_push_pixel_data(pins, pixel_cmd, pixel_buffer) do
    # Set RAM X Pointer start
    send_command(pins, 0x4E, 0x00)

    # Set RAM Y Pointer start
    send_command(pins, 0x4F, <<0x00, 0x00>>)
    send_command(pins, pixel_cmd, pixel_buffer)
  end

  defp display_update_sequence(pins) do
    send_command(pins, 0x22, 0xC7)
  end

  defp trigger_display_update(pins) do
    send_command(pins, 0x20)
  end

  defp deep_sleep(pins) do
    send_command(pins, 0x10, 0x01)
  end

  defp wait_before_sleep(pins) do
    :timer.sleep(50)
    await_device(pins)
    pins
  end

  # pipe-able wrappers

  defp send_command(pins, command) do
    InkyIO.send_command(pins, command)
    pins
  end

  defp send_command(pins, command, data) do
    InkyIO.send_command(pins, command, data)
    pins
  end
end
