defmodule EventStreamTest do
  use ExUnit.Case

  test "Test Sync Notify" do
    SampleQueue.sync_notify(category: :ticket, name: :update, data: %{id: 15, pid: self()})

    receive do
      event ->
        assert event.category == :ticket 
        assert event.name == :update
        assert event.data.id == 15
    after
      500 -> assert "Did not receive response." == true
    end
  end

  test "Test Async Notify" do
    SampleQueue.async_notify(category: :ticket, name: :update, data: %{id: 123456, pid: self()})

    receive do
      event ->
        assert event.category == :ticket 
        assert event.name == :update
        assert event.data.id == 123456
    after
      500 -> assert "Did not receive response." == true
    end
  end

  test "Test Matching" do
    SampleQueue.sync_notify(category: :ticket, name: :insert, data: %{id: 15, pid: self()})

    receive do
      event ->
        assert "Event should not arrive." == true
    after
      100 -> nil
    end
  end

end
