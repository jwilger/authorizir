defmodule Authorizir.TestRepo.Migrations.AddAuthorizir do
  use Ecto.Migration

  def up do
    Authorizir.Migrations.up(version: 1)
  end

  def down do
    Authorizir.Migrations.down(version: 1)
  end
end
