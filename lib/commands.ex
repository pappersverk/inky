# TODO: rename to HAL
defmodule Inky.Commands do
  @moduledoc """
  A behaviour for defining the command interface between Inky and an IO implementation
  """

  @type io_state :: any()

  @callback init(map()) :: io_state()
  @callback handle_update(
              map(),
              :await | :once,
              Inky.IOCommands.State.t()
            ) ::
              :ok | {:error, :device_busy}
end
