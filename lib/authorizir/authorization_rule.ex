defmodule Authorizir.AuthorizationRule do
  @moduledoc false

  use TypedEctoSchema

  import Ecto.Changeset

  alias Authorizir.{Object, Permission, Subject}

  @primary_key false
  typed_schema "authorizir_rules" do
    belongs_to(:subject, Subject, primary_key: true)
    belongs_to(:object, Object, primary_key: true)
    belongs_to(:permission, Permission, primary_key: true)
    field(:rule_type, Ecto.Enum, values: [:+, :-])
    field(:static, :boolean)
    timestamps()
  end

  @spec new(non_neg_integer(), non_neg_integer(), non_neg_integer(), :+ | :-, boolean()) ::
          Ecto.Changeset.t(t())
  def new(subject_id, object_id, permission_id, rule_type, static \\ false) do
    %__MODULE__{}
    |> cast(
      %{
        subject_id: subject_id,
        object_id: object_id,
        permission_id: permission_id,
        rule_type: rule_type,
        static: static
      },
      [:subject_id, :object_id, :permission_id, :rule_type, :static]
    )
  end
end
