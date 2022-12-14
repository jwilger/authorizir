import Config

case Mix.env() do
  :test ->
    config :authorizir, ecto_repos: [AuthorizirTest.Repo], app_module: AuthorizirTest.Auth

  _env ->
    nil
end
