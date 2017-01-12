ExUnit.start()

# Start the producer
SampleQueue.start_link()

# Start multiple consumers
SampleHandler.start_link()
