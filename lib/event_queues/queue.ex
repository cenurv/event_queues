defmodule EventQueues.Queue do
  @moduledoc false

  @doc """
  EXQ Configurationm
  * `:concurrency` - Defaults `:infinite`

  AMQP Configuration

  * `:username` - The name of a user registered with the broker (defaults to "guest");
  * `:password` - The password of user (defaults to "guest");
  * `:virtual_host` - The name of a virtual host in the broker (defaults to "/");
  * `:host` - The hostname of the broker (defaults to "localhost");
  * `:port` - The port the broker is listening on (defaults to 5672);
  * `:channel_max` - The channel_max handshake parameter (defaults to 0);
  * `:frame_max` - The frame_max handshake parameter (defaults to 0);
  * `:heartbeat` - The hearbeat interval in seconds (defaults to 10);
  * `:connection_timeout` - The connection timeout in milliseconds (defaults to 60000);
  * `:ssl_options` - Enable SSL by setting the location to cert files (defaults to none);
  * `:client_properties` - A list of extra client properties to be sent to the server, defaults to [];
  * `:socket_options` - Extra socket options. These are appended to the default options. See http://www.erlang.org/doc/man/inet.html#setopts-2 and http://www.erlang.org/doc/man/gen_tcp.html#connect-4 for descriptions of the available options.
  """
  defmacro __using__(opts \\ []) do
    library = Keyword.get opts, :library, :gen_stage
    configuration = Keyword.get opts, :configuration, []

    case library do
      :exq -> exq_queue(configuration)
      :amqp -> amqp_queue(configuration)
      :gen_stage -> genstage_queue()
    end
  end

  defp exq_queue(configuration) do
    concurrency = Keyword.get configuration, :concurrency, :infinite

    quote do
      use GenServer

      def library, do: :exq

      def perform(event) do
        event = EventQueues.Event.deserialize(event)
        registry = GenServer.call(__MODULE__, :get)
        category = event.category
        name = event.name

        # Construct a list of modules that should be called.
        # The keys are specified by the filter of the handler module.
        specific_event = "#{category}.#{name}"
        any_category = "*.#{name}"
        any_event = "#{category}.*"
        all_events = "*.*"

        modules = [registry[specific_event], registry[any_category], registry[any_event], registry[all_events]]
        modules = Enum.reject(modules, &(is_nil(&1)))
        modules = List.flatten(modules)

        # Pass the event to all valid handlers.
        Enum.each modules, fn(module) ->
          GenServer.cast(module, {:handle, event})
        end
      end

      def start_link() do
        Exq.subscribe(Exq, to_string(__MODULE__), unquote(concurrency))
        GenServer.start_link(__MODULE__, [], name: __MODULE__)
      end

      def init(_opts) do
        {:ok, %{}}
      end

      def handle_call(:get, _from, registry) do
        {:reply, registry, registry}
      end

      def handle_cast({:register, filter, module}, registry) do
        registry =
          if registry[filter] do
            Map.put(registry, filter, registry[filter] ++ [module])
          else
            Map.put(registry, filter, [module])
          end

        {:noreply, registry}
      end

      def is_queue? do
        :ok
      end

      def announce_sync(event, timeout \\ 5000)
      def announce_sync(%EventQueues.Event{} = event, _timeout) do
        Exq.enqueue(Exq, to_string(__MODULE__), __MODULE__, [EventQueues.Event.serialize(event)])
        :ok
      end
      def announce_sync(fields, timeout) do
        announce_sync EventQueues.Event.new(fields), timeout
      end

      def announce(%EventQueues.Event{} = event) do
        spawn fn ->
          announce_sync event
        end
        :ok
      end
      def announce(fields) do
        announce EventQueues.Event.new(fields)
      end
    end
  end

  defp amqp_queue(configuration) do
    quote do
      use GenServer
      require Logger

      def library, do: :amqp

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
        Logger.debug("#{__MODULE__} is restablishing connection over AMQP.")
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
        :ok
      end
      def announce_sync(fields, timeout) do
        announce_sync EventQueues.Event.new(fields), timeout
      end

      def announce(%EventQueues.Event{} = event) do
        spawn fn ->
          announce_sync event
        end
        :ok
      end
      def announce(fields) do
        announce EventQueues.Event.new(fields)
      end
    end
  end

  defp genstage_queue do
    quote do
      use GenStage

      def library, do: :gen_stage

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
