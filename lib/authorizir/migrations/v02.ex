defmodule Authorizir.Migrations.V02 do
  @moduledoc false

  use Ecto.Migration

  import Dagex.Migrations, only: [setup_node_type: 2]

  require Dagex.Migrations

  @spec up(keyword()) :: :ok
  def up(_opts) do
    Dagex.Migrations.up(version: 2)
    setup_node_type("authorizir_subjects", "2.0.0")
    setup_node_type("authorizir_objects", "2.0.0")
    setup_node_type("authorizir_permissions", "2.0.0")
    :ok
  end

  @spec down(keyword()) :: :ok
  def down(_opts) do
    setup_node_type("authorizir_subjects", "1.0.0")
    setup_node_type("authorizir_objects", "1.0.0")
    setup_node_type("authorizir_permissions", "1.0.0")
    Dagex.Migrations.down(version: 2)
    :ok
  end
end