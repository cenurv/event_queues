defmodule EventQueues do
  @moduledoc false

  def queue do
    quote do
      use EventQueues.Queue
    end
  end

  def handler(subscribe) do
    quote do
      use EventQueues.Handler, subscribe: unquote(subscribe)
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
