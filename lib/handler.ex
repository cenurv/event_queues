defmodule Handler do
  use EventQueues, type: :handler, library: :amqp, subscribe: Sample.QLP.Queue, filter: "*.say"

  def handle(%EventQueues.Event{} = event) do
    IO.inspect event
  end
  def handle(_event), do: nil
end