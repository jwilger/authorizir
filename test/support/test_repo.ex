defmodule AuthorizirTest.Repo do
  use Ecto.Repo, otp_app: :authorizir, adapter: Ecto.Adapters.Postgres
  use Dagex.Repo
end
