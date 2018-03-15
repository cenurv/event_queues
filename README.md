# Event Queues #

This library provides helpers in Elixir to create GenStage broadcast based event queues and handlers.

This library is built to work on Elixir 1.4 or later.

## Installation ##

The package can be installed by adding `event_queues` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:event_queues, "~> 1.1"}]
end
```

## Event Message ##

The event queues and handlers created by this library utilize a common struct to pass events around.

`EventQueues.Event`

 * `id`               - A unique id for the event. Default: UUID Version 4 value
 * `category`         - The category or major subject this event belongs.
 * `name`             - The name of the event.
 * `source`           - The source this event originated. Default: `self()`
 * `created`          - Date and time the event was created. Default: `NaiveDateTime.utc_now`
 * `data`             - An open value that can be any valid Elixir term of your choosing.

```elixir
EventQueues.Event.create category: :car,
                         name: :sold,
                         data: %{
                           id: 45,
                           purchaser: %{
                             name: "Bob Nobody"
                           },
                           purchased_on: Date.utc_today
                         }

%EventQueues.Event{category: :car, created: ~N[2017-01-14 22:50:30.989000],
 data: %{id: 45, purchased_on: ~D[2017-01-14],
   purchaser: %{name: "Bob Nobody"}},
 id: "b06fec0a-3cda-41f1-a089-7a6c30fbe7a4", name: :sold, source: #PID<0.151.0>}
```

## Queues ##

An event queue is a GenStage BroadcastDispatcher producer module that can be subscribed to either by using the provided
handler generated from this library or by using GenStage directly and subscribing a consumer to the module. Multiple queues can be
created and are encouraged for applications that may have large groups of handlers that listen to different groups of
events. Since events will only be dispatched once all handlers (GenStage Consumers) are listening, this will help minimize
the wait time be segregating handlers from one another that are part of different business flows.

```elixir
defmodule VehicleInventoryQueue do
  use EventQueues, type: :queue

end

defmodule BoatInventoryQueue do
  use EventQueues, type: :queue

end
```

## Announce Events ##

Queue Functions:

* `announce`              - Sends the event to the queue to be broadcast. Does not wait for the event to be accepted by the queue before returning.
* `announce_sync`         - Sends the event to the queue to be broadcast. Waits for the event to be accepted by the queue before returning.
This does not wait for events to be handled as that event dispatching and handeling are always asynchronous.

Both function take either a `EventQueues.Event` struct or a keyword list of the values for the event. See `EventQueues.Event.create/1`.

```elixir
VehicleInventoryQueue.announce category: :car, name: :sold, data: %{}
VehicleInventoryQueue.announce_sync category: :car, name: :sold, data: %{}
```

## Handlers ##

An event handler is a GenStage consumer that spawns an asynchronous handler process for each event broadcast from a queue.

```elixir
defmodule RegistrationVehicleHandler do
  use EventQueues, type: :handler, subscribe: VehicleInventoryQueue

  def handle(%EventQueues.Event{category: :car, name: :sold, data: data}) do
    # Custom logic here that would register the vehicle electronically with a government agenecy.
  end
  def handle(_event), do: nil
end

defmodule LoanVehicleHandler do
  use EventQueues, type: :handler, subscribe: VehicleInventoryQueue

  def handle(%EventQueues.Event{category: :car, name: :sold, data: data}) do
    # Custom logic to finalize a loan process when a car is sold.
  end
  def handle(_event), do: nil
end

defmodule RegistrationBoatHandler do
  use EventQueues, type: :handler, subscribe: BoatInventoryQueue

  def handle(%EventQueues.Event{category: :jet_ski, name: :sold, data: data}) do
    # Custom logic here that would register the vehicle electronically.
  end
  def handle(_event), do: nil
end
```

## Starting ##

Each module created is a ordinary GenServer that must be started with your application.

```elixir
VehicleInventoryQueue.start_link()
BoatInventoryQueue.start_link()
RegistrationVehicleHandler.start_link()
LoanVehicleHandler.start_link()
RegistrationBoatHandler.start_link()
```

Or the modules can be added to a supervisor:

```elixir
defmodule MyApp do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(VehicleInventoryQueue, [])
      worker(BoatInventoryQueue, [])
      worker(RegistrationVehicleHandler, [])
      worker(LoanVehicleHandler, [])
      worker(RegistrationBoatHandler, [])
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

## Announcers ##

A module can add a set of predefined events that can be called on a module that integrates Event Queues into other libraries.

```elixir
defmodule LibraryModule do

  defmacro __using__(_) do
    quote do
      use EventQueues, type: :announcer

      defevents [:after_action]

      def execute_action do
        # Perform some action

        if has_after_action? do
          on_after_action category: __MODULE__, name: :after_action
        end
      end
    end
  end
end

defmodule AppModule do
  use LibraryModule

  create_queue()

  announces  events: [:after_action]
end

def AppHandler do
  use EventQueues, type: :handler, subscribe: AppModule

  def handle(event) do
    # Handle the event.
  end
end

# Start the event queue and handler.
AppModule.start_link
AppHandler.start_link

# Call the function created by the library.
# The event will be executed as part of the function.
AppModule.execute_action
```

A module built with the announcer macros can be used with any Queue.

```elixir
defmodule AppQueue do
  use EventQueues, type: :queue
end

defmodule AppModule do
  use LibraryModule

  announces  events: [:after_action],
             queues: [AppQueue]
end

```

## Exq ##

As of 2.0.0, Support has been added to support the Exq worker queue for distibuting events.

See the `exq` project on Hex for more details on how to setup and configure.

```elixir
defmodule VehicleInventoryQueue do
  use EventQueues, type: :queue,
                   library: :exq,
                   # This configuration is default, the line is not required
                   configuration: [concurrency: :infinite]

end

defmodule RegistrationVehicleHandler do
  use EventQueues, type: :handler,
                   subscribe: VehicleInventoryQueue,

  def handle(%EventQueues.Event{category: :car, name: :sold, data: data}) do
    # Custom logic here that would register the vehicle electronically with a government agenecy.
  end
  def handle(_event), do: nil
end
```

Using Exq also allows filtering specific categories and event names for the handler.

```elixir
defmodule RegistrationVehicleHandler do
  use EventQueues, type: :handler,
                   subscribe: VehicleInventoryQueue,
                   category: :category,
                   name: :sold

  def handle(%EventQueues.Event{category: :car, name: :sold, data: data}) do
    # Custom logic here that would register the vehicle electronically with a government agenecy.
  end
  def handle(_event), do: nil
end

VehicleInventoryQueue.announce category: :car, name: :sold, data: %{}
```

Both the category and name options are optional and can match individually. For instance, only providing the name of "sold".
The handler can listen events from all categories that provide an event name of "sold".

## AMQP ##

As of 2.0.0, Support has been added to support the AMQP message protocol for distributing events.

```elixir
defmodule VehicleInventoryQueue do
  use EventQueues, type: :queue,
                   library: :amqp,
                   configuration: Application.get_env(:my_app, :amqp_connection_configuration)

end

defmodule RegistrationVehicleHandler do
  use EventQueues, type: :handler,
                   subscribe: VehicleInventoryQueue,
                   configuration: Application.get_env(:my_app, :amqp_connection_configuration)

  def handle(%EventQueues.Event{category: :car, name: :sold, data: data}) do
    # Custom logic here that would register the vehicle electronically with a government agenecy.
  end
  def handle(_event), do: nil
end
```

Using AMQP also allows filtering specific categories and event names for the handler.

```elixir
defmodule RegistrationVehicleHandler do
  use EventQueues, type: :handler,
                   subscribe: VehicleInventoryQueue,
                   category: :car,
                   name: :sold,
                   configuration: Application.get_env(:my_app, :amqp_connection_configuration)

  def handle(%EventQueues.Event{data: data}) do
    # Custom logic here that would register the vehicle electronically with a government agenecy.
  end
  def handle(_event), do: nil
end

VehicleInventoryQueue.announce category: :car, name: :sold, data: %{}
```

Both the category and name options are optional and can match individually. For instance, only providing the name of "sold".
The handler can listen events from all categories that provide an event name of "sold".
