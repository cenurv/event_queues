defmodule EventStream.Queue do
  defmacro __using__(_opts) do
    quote do
      alias Experimental.GenStage

      use GenStage

      def start_link() do
        GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
      end

      def sync_notify(event, timeout \\ 5000)
      def sync_notify(%EventStream.Event{} = event, timeout) do
        GenStage.call(__MODULE__, {:notify, event}, timeout)
      end
      def sync_notify(fields, timeout) do
        sync_notify EventStream.Event.new(fields), timeout
      end

      def async_notify(%EventStream.Event{} = event) do
        spawn fn ->
          sync_notify event
        end
      end
      def async_notify(fields) do
        async_notify EventStream.Event.new(fields)
      end

      ## Callbacks

      def init(:ok) do
        {:producer, {:queue.new, 0}, dispatcher: GenStage.BroadcastDispatcher}
      end

      def handle_call({:notify, event}, from, {queue, pending_demand}) do
        queue = :queue.in({from, event}, queue)
        dispatch_events(queue, pending_demand, [])
      end

      def handle_demand(incoming_demand, {queue, pending_demand}) do
        dispatch_events(queue, incoming_demand + pending_demand, [])
      end

      defp dispatch_events(queue, 0, events) do
        {:noreply, Enum.reverse(events), {queue, 0}}
      end
      defp dispatch_events(queue, demand, events) do
        case :queue.out(queue) do
          {{:value, {from, event}}, queue} ->
            GenStage.reply(from, :ok)
            dispatch_events(queue, demand - 1, [event | events])
          {:empty, queue} ->
            {:noreply, Enum.reverse(events), {queue, demand}}
        end
      end
    end
  end
end
