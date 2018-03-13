defmodule Sample.QLP.Queue do
  use EventQueues, type: :queue, library: :amqp
end
