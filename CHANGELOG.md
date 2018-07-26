# Change Log #

## 3.0.0 ##

* Moved :uuid to :elixir_uuid to avoid incomptibilities moving forward with other libraries.
* Changed minimum Elixir version to 1.6.

## 2.0.0 ##

* Added support for using AMQP (Rabbit MQ) instead of GenStage.
* Added support for using Exq instead of GenStage.

## 1.1.0 ##

* Added macros to create announcer modules that create predefined events that can be called within another library.
