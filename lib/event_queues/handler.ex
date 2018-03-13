defmodule EventQueues.Handler do
  @moduledoc false

  @doc """
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
  defmacro __using__(opts) do
    library = Keyword.get opts, :library, :gen_stage
    subscribe = Keyword.get opts, :subscribe, "amq.topic"
    configuration = Keyword.get opts, :configuration, []
    filter = Keyword.get opts, :filter, "#"

    case library do
      :amqp -> amqp_handler(configuration, subscribe, filter)
      :gen_stage -> gen_stage_handler(subscribe)
    end
  end

  defp amqp_handler(configuration, subscribe, filter) do
    quote do
      use GenServer
      use AMQP

      require Logger

      def start_link do
        GenServer.start_link(__MODULE__, [], [])
      end

      @exchange    to_string(unquote(subscribe))
      @queue       to_string(__MODULE__)

      # Extract your connect logic into a private method amqp_connect
      def init(_opts) do
        amqp_connect()
      end

      defp amqp_connect do
        case AMQP.Connection.open(unquote(configuration)) do
          {:ok, conn} ->
            # Get notifications when the connection goes down
            Process.monitor(conn.pid)
            # Everything else remains the same
            {:ok, channel} = AMQP.Channel.open(conn)
            setup_queue(channel)

            # Limit unacknowledged messages to 10
            :ok = AMQP.Basic.qos(channel, prefetch_count: 10)
            # Register the GenServer process as a consumer
            {:ok, _consumer_tag} = AMQP.Basic.consume(channel, @queue)
            {:ok, channel}
          {:error, _} ->
            # Reconnection loop
            :timer.sleep(10000)
            amqp_connect()
        end
      end

      # Confirmation sent by the broker after registering this process as a consumer
      def handle_info({:basic_consume_ok, %{consumer_tag: consumer_tag}}, channel) do
        {:noreply, channel}
      end

      # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
      def handle_info({:basic_cancel, %{consumer_tag: consumer_tag}}, channel) do
        {:stop, :normal, channel}
      end

      # Confirmation sent by the broker to the consumer process after a Basic.cancel
      def handle_info({:basic_cancel_ok, %{consumer_tag: consumer_tag}}, channel) do
        {:noreply, channel}
      end

      def handle_info({:basic_deliver, payload, %{delivery_tag: tag, redelivered: redelivered}}, channel) do
        spawn fn -> consume(channel, tag, redelivered, payload) end
        {:noreply, channel}
      end

      # Implement a callback to handle DOWN notifications from the system
      # This callback should try to reconnect to the server
      def handle_info({:DOWN, _, :process, _pid, _reason}, _) do
        Logger.info("#{__MODULE__} is restablishing connection over AMQP.")
        {:ok, channel} = amqp_connect()
        {:noreply, channel}
      end

      defp setup_queue(channel) do
        # Messages that cannot be delivered to any consumer in the main queue will be routed to the error queue
        {:ok, _} = AMQP.Queue.declare(channel, @queue, durable: true)
        :ok = AMQP.Exchange.topic(channel, @exchange, durable: true)
        :ok = AMQP.Queue.bind(channel, @queue, @exchange, routing_key: unquote(filter))
      end

      defp consume(channel, tag, redelivered, payload) do
        handle EventQueues.Event.deserialize payload
        :ok = AMQP.Basic.ack channel, tag
      end

      def handle(%EventQueues.Event{} = event) do
        IO.puts "No handle defined in module #{__MODULE__}"
      end

      defoverridable [handle: 1]
    end
  end

  defp gen_stage_handler(subscribe) do
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
