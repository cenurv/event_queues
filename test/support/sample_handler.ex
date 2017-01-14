defmodule SampleHandler do
  use EventQueues, type: :handler, subscribe: SampleQueue

  def handle(%EventQueues.Event{category: :ticket, name: :update} = event) do
    send event.data.pid, event
  end
  def handle(_event), do: nil
end
