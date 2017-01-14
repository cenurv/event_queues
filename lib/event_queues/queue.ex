defmodule EventQueues.Queue do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      alias Experimental.GenStage

      use GenStage

      def start_link() do
        GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
      end

      def announce_sync(event, timeout \\ 5000)
      def announce_sync(%EventQueues.Event{} = event, timeout) do
        GenStage.call(__MODULE__, {:notify, event}, timeout)
      end
      def announce_sync(fields, timeout) do
        announce_sync EventQueues.Event.new(fields), timeout
      end

      def announce(%EventQueues.Event{} = event) do
        spawn fn ->
          announce_sync event
        end
      end
      def announce(fields) do
        announce EventQueues.Event.new(fields)
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
