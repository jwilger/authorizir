defmodule Authorizir.Migrations.V02 do
  @moduledoc false

  use Ecto.Migration

  import Dagex.Migrations, only: [setup_node_type: 2]

  require Dagex.Migrations

  @spec up(keyword()) :: :ok
  def up(_opts) do
    alter table("authorizir_subjects") do
      add(:static, :boolean, default: false)
    end

    alter table("authorizir_objects") do
      add(:static, :boolean, default: false)
    end

    alter table("authorizir_permissions") do
      add(:static, :boolean, default: false)
    end

    alter table("authorizir_rules") do
      add(:static, :boolean, default: false)
    end

    Dagex.Migrations.up(version: 2)
    setup_node_type("authorizir_subjects", "2.0.0")
    setup_node_type("authorizir_objects", "2.0.0")
    setup_node_type("authorizir_permissions", "2.0.0")

    execute(
      "INSERT INTO authorizir_subjects (id, ext_id, description, inserted_at, updated_at) VALUES(0, '*', 'Subject Supremum', NOW(), NOW());"
    )

    execute(
      "INSERT INTO authorizir_objects (id, ext_id, description, inserted_at, updated_at) VALUES(0, '*', 'Object Supremum', NOW(), NOW());"
    )

    execute(
      "INSERT INTO authorizir_permissions (id, ext_id, description, inserted_at, updated_at) VALUES(0, '*', 'Permission Supremum', NOW(), NOW());"
    )

    :ok
  end

  @spec down(keyword()) :: :ok
  def down(_opts) do
    execute("DELETE FROM authorizir_subjects WHERE id = 0 AND ext_id = '*';")
    execute("DELETE FROM authorizir_objects WHERE id = 0 AND ext_id = '*';")
    execute("DELETE FROM authorizir_permissions WHERE id = 0 AND ext_id = '*';")
    setup_node_type("authorizir_subjects", "1.0.0")
    setup_node_type("authorizir_objects", "1.0.0")
    setup_node_type("authorizir_permissions", "1.0.0")
    Dagex.Migrations.down(version: 2)

    alter table("authorizir_subjects") do
      remove(:static)
    end

    alter table("authorizir_objects") do
      remove(:static)
    end

    alter table("authorizir_permissions") do
      remove(:static)
    end

    alter table("authorizir_rules") do
      remove(:static)
    end

    :ok
  end
end
