defmodule EventStream.Event do
  defstruct id: nil,
            name: nil,
            category: nil,
            data: nil

  def new(fields \\ []) do
    category = Keyword.get fields, :category, nil
    name = Keyword.get fields, :name, nil
    data = Keyword.get fields, :data, nil


    %EventStream.Event{id: UUID.uuid4(),
                       name: name,
                       category: category,
                       data: data}
  end
end
