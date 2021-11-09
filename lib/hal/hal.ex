defmodule Inky.HAL do
  @moduledoc """
  A behaviour for defining the command interface between Inky and an IO implementation
  """

  @type io_state :: any()

  @callback init(opts :: map()) :: io_state()
  @callback handle_update(
              pixels :: map(),
              border :: :white | :black | :red | :yellow | :accent,
              policy :: :await | :once,
              state :: Inky.IOCommands.State.t()
            ) ::
              io_state() | :ok | {:error, :device_busy}
end
