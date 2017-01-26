defmodule EventQueuesTest do
  use ExUnit.Case

  test "Test Sync Notify" do
    SampleQueue.announce_sync(category: :ticket, name: :update, data: %{id: 15, pid: self()})

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
    SampleQueue.announce(category: :ticket, name: :update, data: %{id: 123456, pid: self()})

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
    SampleQueue.announce_sync(category: :ticket, name: :insert, data: %{id: 15, pid: self()})

    receive do
      _ ->
        assert "Event should not arrive." == true
    after
      100 -> nil
    end
  end

  test "Announcer and handler" do
    SampleAnnouncer.execute_event

    assert true == SampleAnnouncer.has_after_insert?
    assert false == SampleAnnouncer.has_after_update?

    receive do
      event ->
        assert event.category == :test 
        assert event.name == :after_insert
    after
      500 -> assert "Did not receive response." == true
    end
  end

end
