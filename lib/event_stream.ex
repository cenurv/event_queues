defmodule EventStream do
  @moduledoc """
  Documentation for EventStream.
  """

  defmacro queue do
    quote do
      use EventStream.Queue
    end
  end

  defmacro __using__(key) do
    case key do
      :queue -> queue
    end
  end
end
