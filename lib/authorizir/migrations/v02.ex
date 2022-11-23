defmodule Authorizir.Migrations.V02 do
  use Ecto.Migration

  require Dagex.Migrations
  import Dagex.Migrations, only: [setup_node_type: 2]

  def up(_opts) do
    Dagex.Migrations.up(version: 2)
    setup_node_type("authorizir_subjects", "2.0.0")
    setup_node_type("authorizir_objects", "2.0.0")
    setup_node_type("authorizir_permissions", "2.0.0")
  end

  def down(_opts) do
    setup_node_type("authorizir_subjects", "1.0.0")
    setup_node_type("authorizir_objects", "1.0.0")
    setup_node_type("authorizir_permissions", "1.0.0")
    Dagex.Migrations.down(version: 1)
  end
end
