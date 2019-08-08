defmodule Inky.TestSPI do
  def open(pin, mode) do
    report(:open, {pin, mode})
    {:ok, {:pid, pin}}
  end

  def transfer(pid, value) do
    report(:transfer, {pid, value})
    {:ok, value}
  end

  defp report(fun, args), do: send({{:spi, fun}, args})
  defp send(msg), do: Process.send(self(), {__MODULE__, msg}, [])
end
