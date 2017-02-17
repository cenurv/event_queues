defmodule EventQueues.Handler do
  @moduledoc false

  defmacro __using__(opts) do
    subscribe = Keyword.get opts, :subscribe

    quote do
      use GenStage

      def start_link() do
        GenStage.start_link(__MODULE__, :ok)
      end

      def init(:ok) do
        # Starts a permanent subscription to the broadcaster
        # which will automatically start requesting items.

        if Code.ensure_compiled?(unquote(subscribe).Queue) do
          subscribe_queue unquote(subscribe).Queue
        else
          subscribe_queue unquote(subscribe)
        end
      end

      def subscribe_queue(queue) do
        :ok = apply queue, :is_queue?, []
        {:consumer, :ok, subscribe_to: [queue]}
      end

      def handle_events(events, _from, state) do
        for event <- events do
          spawn fn -> handle event end
        end

        {:noreply, [], state}
      end

      def handle(%EventQueues.Event{} = event) do
        IO.puts "No handle defined in module #{__MODULE__}"
      end

      defoverridable [handle: 1]
    end
  end
end
