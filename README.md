# Event Queues #

This library provides helpers in Elixir to create GenStage broadcast based event queues and handlers. 

## Installation ##

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `event_queues` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:event_queues, "~> 1.0"}]
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
EventQueues.Event.new category: :car,
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
