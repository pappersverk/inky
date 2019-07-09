defmodule Inky.BenchIO do
  @moduledoc false

  @behaviour Inky.InkyIO

  @impl Inky.InkyIO
  def init(_args), do: :ok

  @impl Inky.InkyIO
  def handle_sleep(_, _), do: :ok

  @impl Inky.InkyIO
  def handle_read_busy(_), do: 0

  @impl Inky.InkyIO
  def handle_reset(_, _), do: :ok

  @impl Inky.InkyIO
  def handle_command(_, _), do: :ok

  @impl Inky.InkyIO
  def handle_command(_, _, _), do: :ok
end
