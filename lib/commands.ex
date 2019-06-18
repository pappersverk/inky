defmodule Inky.Commands do
  @moduledoc """
  A behaviour for defining the command interface between Inky and an IO implementation
  """

  @type io_state :: any()

  @callback init(module(), any()) :: io_state()
  @callback handle_update(
              Inky.Displays.Display.t(),
              binary(),
              binary(),
              :await | :once,
              Inky.IOCommands.State.t()
            ) ::
              :ok | {:error, :device_busy}
end
