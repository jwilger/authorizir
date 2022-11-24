defmodule Authorizir.AuthorizationRule do
  @moduledoc false

  use TypedEctoSchema

  alias Authorizir.{Object, Permission, Subject}

  import Ecto.Changeset

  @primary_key false
  typed_schema "authorizir_rules" do
    belongs_to(:subject, Subject, primary_key: true)
    belongs_to(:object, Object, primary_key: true)
    belongs_to(:permission, Permission, primary_key: true)
    field(:rule_type, Ecto.Enum, values: [:+, :-])
    timestamps()
  end

  def new(subject_id, object_id, permission_id, rule_type) do
    %__MODULE__{}
    |> cast(
      %{
        subject_id: subject_id,
        object_id: object_id,
        permission_id: permission_id,
        rule_type: rule_type
      },
      [:subject_id, :object_id, :permission_id, :rule_type]
    )
  end
end
