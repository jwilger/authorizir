defmodule Authorizir.TestRepo.Migrations.AddAuthorizir do
  use Ecto.Migration

  def up do
    Authorizir.Migrations.up()
  end

  def down do
    Authorizir.Migrations.down()
  end
end
