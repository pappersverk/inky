alias Inky.Commands

defmodule Inky.TestCommands do
  @moduledoc """
  A module that implements the Commands behaviour for testing purposes.
  """
  @behaviour Commands

  def assert_expectations() do
    case Process.get(:update, :not_set) do
      [] -> :ok
      val when val == :ok or is_tuple(val) -> :ok
      :not_set -> raise ArgumentError, message: "update-value never set"
      v -> raise ArgumentError, message: "Unexpected update-value: #{inspect(v)}"
    end
  end

  @impl Commands
  def init(_args) do
    send(:init)
    %{}
  end

  @impl Commands
  def handle_update(_display, _buf_black, _buf_accent, _push_policy, _state) do
    response = do_handle_update()
    do_report_response(response)

    response
  end

  #
  # Internals
  #

  defp do_handle_update() do
    case Process.get(:update, :not_set) do
      :not_set ->
        arg_err("Called update without setting expectation")

      [] ->
        arg_err("Called update with no mock values left")

      result_list when is_list(result_list) ->
        Process.put(:update, tl(result_list))
        hd(result_list)

      update_result ->
        update_result
    end
  end

  defp do_report_response(response) do
    msg =
      case response do
        :busy -> {:error, :device_busy}
        :ok -> :ok
      end

    send({:update, msg})
  end

  defp send(msg), do: Process.send(self(), msg, [])

  defp arg_err(msg), do: raise(ArgumentError, message: msg)
end
