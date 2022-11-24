defmodule Authorizir.TestRepo.Migrations.UpdateAuthorizir do
  use Ecto.Migration

  def up do
    Authorizir.Migrations.up(version: 2)
  end

  def down do
   Authorizir.Migrations.down(version: 2)
  end
end
