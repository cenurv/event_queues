defmodule SampleHandler do
  use EventStream, type: :handler, subscribe: SampleQueue

  def handle(%EventStream.Event{category: :ticket, name: :update} = event) do
    send event.data.pid, event
  end
  def handle(_event), do: nil
end
