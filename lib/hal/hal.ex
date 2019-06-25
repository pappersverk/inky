defmodule Inky.HAL do
  @moduledoc """
  A behaviour for defining the command interface between Inky and an IO implementation
  """

  @type io_state :: any()

  @callback init(opts :: map()) :: io_state()
  @callback handle_update(
              opts :: map(),
              policy :: :await | :once,
              state :: Inky.IOCommands.State.t()
            ) ::
              :ok | {:error, :device_busy}
end
