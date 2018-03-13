defmodule EventQueues.Announcer do
  @moduledoc false

  defmacro defevents(events) when is_list events do
    for event <- events do
      name = String.to_atom "on_#{event}"
      has_name = String.to_atom "has_#{event}?"

      override =
        []
        |> Keyword.put(name, 1)
        |> Keyword.put(has_name, 0)

      quote do
        def unquote(has_name)(), do: false
        def unquote(name)(_), do: nil

        defoverridable unquote(override)
      end
    end
  end

  defmacro create_queue(opts \\ []) do
    library = Keyword.get opts, :library, :gen_stage

    quote do
      defmodule Queue do
        use EventQueues, type: :queue, library: unquote(library)
      end

      def start_link, do: __MODULE__.Queue.start_link
    end
  end

  defmacro announces(events: events) do
    quote do
      announces events: unquote(events), queues: [__MODULE__.Queue]
    end
  end

  defmacro announces(events: events, queues: queues) when not is_list(events) do
    quote do
      announces events: [unquote(events)], queues: unquote(queues)
    end
  end
  defmacro announces(events: events, queues: queues) when not is_list(queues) do
    quote do
      announces events: unquote(events), queues: [unquote(queues)]
    end
  end
  defmacro announces(events: events, queues: queues) do
    for event <- events do
      name = String.to_atom "on_#{event}"
      has_name = String.to_atom "has_#{event}?"

      quote do
        def unquote(has_name)(), do: true
        def unquote(name)(event) do
          for queue <- unquote(queues) do
            queue.announce event
          end
        end
      end
    end
  end

  defmacro __using__(_opts) do
    quote do
      import EventQueues.Announcer
    end
  end

end
