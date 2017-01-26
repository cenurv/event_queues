ExUnit.start()

# Start the producer
SampleQueue.start_link
SampleAnnouncer.start_link

# Start multiple consumers
SampleHandler.start_link
SampleAnnouncer.SampleAnnouncerHandler.start_link
