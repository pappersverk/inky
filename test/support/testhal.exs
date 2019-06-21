alias Inky.HAL

defmodule Inky.TestHAL do
  @moduledoc """
  A module that implements the HAL behaviour for testing purposes.
  """

  @behaviour HAL

  def on_update(result) when result in [:ok, :busy], do: Process.put(:update, result)

  def assert_expectations() do
    case Process.get(:update, :not_set) do
      [] -> :ok
      val when val == :ok or val == :busy -> :ok
      :not_set -> raise ArgumentError, message: "Update value never set!"
      v -> raise ArgumentError, message: "Unexpected update-value: #{inspect(v)}"
    end
  end

  @impl HAL
  def init(_args) do
    send(:init)
    %{}
  end

  @impl HAL
  def handle_update(_pixels, _push_policy, _state) do
    response = do_handle_update()
    do_report_response(response)
  end

  #
  # Internals
  #

  defp do_handle_update() do
    case Process.get(:update, :not_set) do
      :not_set ->
        arg_err("Update called unexpectedly!")

      [] ->
        arg_err("Update called after all values were consumed!")

      result_list when is_list(result_list) ->
        Process.put(:update, tl(result_list))
        hd(result_list)

      update_result ->
        update_result
    end
  end

  defp do_report_response(response) do
    result =
      case response do
        :busy -> {:error, :device_busy}
        :ok -> :ok
      end

    send({:update, result})

    result
  end

  defp send(msg), do: Process.send(self(), {__MODULE__, msg}, [])

  defp arg_err(msg), do: raise(ArgumentError, message: msg)
end
