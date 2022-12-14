defmodule Mix.Tasks.Authorizir.Init do
  @shortdoc "Initialize Authorizir rules"
  @moduledoc """
  Initializes the static authorization components defined in your application's authorization module.
  """

  use Mix.Task
  @requirements ["app.start"]
  @preferred_cli_env :dev

  @impl Mix.Task
  def run(_args) do
    Authorizir.application_module().init()
  end
end
