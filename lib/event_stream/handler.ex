defmodule EventStream.Handler do
  defmacro __using__(opts) do
    subscribe = Keyword.get opts, :subscribe

    quote do
      alias Experimental.GenStage

      use GenStage

      def start_link() do
        GenStage.start_link(__MODULE__, :ok)
      end

      def init(:ok) do
        # Starts a permanent subscription to the broadcaster
        # which will automatically start requesting items.
        {:consumer, :ok, subscribe_to: [unquote(subscribe)]}
      end

      def handle_events(events, _from, state) do
        for event <- events do
          spawn fn -> handle event end
        end

        {:noreply, [], state}
      end

      def handle(%EventStream.Event{} = event) do
        IO.puts "No handle defined in module #{__MODULE__}"
      end

      defoverridable [handle: 1]
    end
  end
end
