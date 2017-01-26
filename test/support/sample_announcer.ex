defmodule SampleAnnouncer do
  use EventQueues, type: :announcer

  defevents [:after_insert, :after_update, :after_delete]

  create_queue()

  announces events: [:after_insert]

  def execute_event do
    on_after_insert category: :test, name: :after_insert
  end

  defmodule SampleAnnouncerHandler do
    use EventQueues, type: :handler, subscribe: SampleAnnouncer.Queue

    def handle(event) do
      send event.source, event
    end
  end
end
