{:ok, _pid} = AuthorizirTest.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(AuthorizirTest.Repo, :manual)

ExUnit.start()
