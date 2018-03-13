defmodule EventQueues.Event do
  @moduledoc """
  The event queues and handlers created by this library utilize a common struct to pass events around.
  """

  defstruct id: nil,
            name: nil,
            category: nil,
            created: nil,
            source: nil,
            data: nil

  @doc """
  Creates an event struct based upon the fields passed in.

  * `id`               - A unique id for the event. Default: UUID Version 4 value
  * `category`         - The category or major subject this event belongs.
  * `name`             - The name of the event.
  * `source`           - The source this event originated. Default: `self()`
  * `created`          - Date and time the event was created. Default: `NaiveDateTime.utc_now`
  * `data`             - An open value that can be any valid Elixir term of your choosing.
  """
  def new(fields \\ []) do
    id = Keyword.get fields, :id, UUID.uuid4()
    category = Keyword.get fields, :category, nil
    name = Keyword.get fields, :name, nil
    data = Keyword.get fields, :data, nil
    source = Keyword.get fields, :source, self()
    created = Keyword.get fields, :created, NaiveDateTime.utc_now

    %EventQueues.Event{id: id,
                       name: name,
                       category: category,
                       source: source,
                       created: created,
                       data: data}
  end

  def serialize(%__MODULE__{} = event) do
    event
    |> :erlang.term_to_binary
    |> Base.encode64
  end

  def deserialize(content) when is_binary content do
    content
    |> Base.decode64!
    |> :erlang.binary_to_term
  end
end
