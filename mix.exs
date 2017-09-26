defmodule EventQueues.Mixfile do
  use Mix.Project

   @version "1.1.3"

  def project do
    [app: :event_queues,
     version: @version,
     elixir: "~> 1.4",
     elixirc_paths: elixirc_paths(Mix.env),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     description: "Provides helpers in Elixir to create GenStage based event queues and handlers",
     name: "Event Queues",
     package: %{
       licenses: ["Apache 2.0"],
       maintainers: ["Joseph Lindley"],
       links: %{"GitHub" => "https://github.com/cenurv/event_queues"},
       files: ~w(mix.exs README.md CHANGELOG.md lib)
     },
     docs: [source_ref: "v#{@version}", main: "readme",
            canonical: "http://hexdocs.pm/event_queues",
            source_url: "https://github.com/cenurv/event_queues",
            extras: ["CHANGELOG.md", "README.md"]]]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger]]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:gen_stage, "~> 0.12"},
     {:uuid, "~> 1.1"},
     {:ex_doc, "~> 0.16", only: [:docs, :dev]},]
  end
end
