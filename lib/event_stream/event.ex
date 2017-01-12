defmodule EventStream.Event do
  defstruct id: UUID.uuid4(),
            event: nil,
            category: nil,
            description: nil,
            data: %{}
end
