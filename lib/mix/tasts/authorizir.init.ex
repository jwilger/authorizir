defmodule Mix.Tasks.Authorizir.Init do
  @moduledoc """
  Initializes the static authorization components defined in your application's authorization module.
  """
  @shortdoc "Initialize Authorizir rules"
  @requirements ["app.start"]
  @preferred_cli_env :dev

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Authorizir.application_module().init()
  end
end
