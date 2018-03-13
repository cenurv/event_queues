defmodule EventQueues.Queue do
  @moduledoc false

  defmacro __using__(opts \\ []) do
    library = Keyword.get opts, :library, :gen_stage
    configuration = Keyword.get opts, :configuration, []

    case library do
      :amqp -> amqp_queue(configuration)
      :gen_stage -> genstage_queue()
    end
  end

  defp amqp_queue(configuration) do
    quote do
      use GenServer
      require Logger

      def start_link() do
        GenServer.start_link(__MODULE__, [], name: __MODULE__)
      end

      def init(_opts) do
        amqp_connect()
      end

      defp amqp_connect do
        case AMQP.Connection.open(unquote(configuration)) do
          {:ok, conn} ->
            # Get notifications when the connection goes down
            Process.monitor(conn.pid)
            # Everything else remains the same
            AMQP.Channel.open(conn) # Return {:ok channel}
          {:error, _} ->
            # Reconnection loop
            :timer.sleep(10000)
            amqp_connect()
        end
      end

      # Implement a callback to handle DOWN notifications from the system
      # This callback should try to reconnect to the server
      def handle_info({:DOWN, _, :process, _pid, _reason}, _) do
        Logger.info("#{__MODULE__} is restablishing connection over AMQP.")
        {:ok, channel} = amqp_connect()
        {:noreply, channel}
      end

      def handle_cast({:notify, %EventQueues.Event{} = event}, channel) do
        AMQP.Basic.publish channel, to_string(__MODULE__), "#{event.category}.#{event.name}", EventQueues.Event.serialize(event)
        {:noreply, channel}
      end

      def is_queue? do
        :ok
      end

      def announce_sync(event, timeout \\ 5000)
      def announce_sync(%EventQueues.Event{} = event, _timeout) do
        GenServer.cast(__MODULE__, {:notify, event})
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
    end
  end

  defp genstage_queue do
    quote do
      use GenStage

      def is_queue? do
        :ok
      end

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
