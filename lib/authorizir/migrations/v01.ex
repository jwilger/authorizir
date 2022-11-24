defmodule Authorizir.Migrations.V01 do
  use Ecto.Migration

  require Dagex.Migrations
  import Dagex.Migrations, only: [setup_node_type: 2]

  def up(_opts) do
    Dagex.Migrations.up()

    create table("authorizir_subjects") do
      add(:ext_id, :binary, null: false)
      add(:description, :string, null: false)
      timestamps()
    end

    create(index("authorizir_subjects", :ext_id, unique: true))
    setup_node_type("authorizir_subjects", "1.0.0")

    create table("authorizir_objects") do
      add(:ext_id, :binary, null: false)
      add(:description, :string, null: false)
      timestamps()
    end

    create(index("authorizir_objects", :ext_id, unique: true))
    setup_node_type("authorizir_objects", "1.0.0")

    create table("authorizir_permissions") do
      add(:ext_id, :binary, null: false)
      add(:description, :string, null: false)
      timestamps()
    end

    create(index("authorizir_permissions", :ext_id, unique: true))
    setup_node_type("authorizir_permissions", "1.0.0")

    execute("CREATE TYPE grant_type AS ENUM ('+', '-')")

    create table("authorizir_rules", primary_key: false) do
      add(
        :subject_id,
        references("authorizir_subjects",
          on_delete: :restrict,
          on_update: :update_all,
          validate: true
        ),
        null: false,
        primary_key: true
      )

      add(
        :object_id,
        references("authorizir_objects",
          on_delete: :restrict,
          on_update: :update_all,
          validate: true
        ),
        null: false,
        primary_key: true
      )

      add(
        :permission_id,
        references("authorizir_permissions",
          on_delete: :delete_all,
          on_update: :update_all,
          validate: true
        ),
        null: false,
        primary_key: true
      )

      add(:rule_type, :grant_type, null: false)
      timestamps()
    end

    create(index("authorizir_rules", [:subject_id, :object_id, :permission_id, :rule_type]))
  end

  def down(_opts) do
    drop(index("authorizir_rules", [:subject_id, :object_id, :permission_id, :rule_type]))
    drop(table("authorizir_rules"))
    drop(table("authorizir_permissions"))
    drop(table("authorizir_objects"))
    drop(table("authorizir_subjects"))
    execute("DROP TYPE grant_type")
    Dagex.Migrations.down()
  end
end
