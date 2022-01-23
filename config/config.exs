import Config

case Mix.env() do
  :test ->
    config :authorizir, ecto_repos: [AuthorizirTest.Repo]

  _env ->
    nil
end
