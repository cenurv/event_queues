defmodule EventStream.Queue do
  defmacro __using__(_opts) do
    quote do
      alias Experimental.GenStage

      use GenStage

      def start_link(state \\ []) do
        GenStage.start_link(__MODULE__, state, name: __MODULE__)
      end

      def init(state), do: {:producer, dispacher: GenStage.BroadcastDispatcher}

      def handle_call({:notify, event}, _from, state) do
        {:reply, :ok, [event], state} # Dispatch immediately
      end

      def handle_demand(demand, state) do
        events =
          for index < 1..demand do
            Enum.get state, index
          end

        state = Enum.drop state, demand

        {:noreply, events, state}
      end
    end
  end
end
