defmodule Inky.TestGPIO do
  @moduledoc """
  A module that mocks Circuits.GPIO
  """

  def open(pin, mode) do
    report(:open, {pin, mode})
    {:ok, {:pid, pin}}
  end

  def write(pid, command_or_data) do
    report(:write, {pid, command_or_data})
    :ok
  end

  defp report(fun, args) do
    send({{:gpio, fun}, args})
  end

  defp send(msg), do: Process.send(self(), {__MODULE__, msg}, [])
end
