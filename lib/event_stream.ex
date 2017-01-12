defmodule EventStream do
  @moduledoc """
  Documentation for EventStream.
  """

  def queue do
    quote do
      use EventStream.Queue
    end
  end

  def handler(subscribe) do
    quote do
      use EventStream.Handler, subscribe: unquote(subscribe)
    end
  end

  defmacro __using__(opts \\ []) do
    key = Keyword.get opts, :type, :queue
    subscribe = Keyword.get opts, :subscribe

    case key do
      :queue -> queue()
      :handler -> handler(subscribe)
    end
  end
end
