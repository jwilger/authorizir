defmodule Authorizir.Permission do
  use Dagex
  use TypedEctoSchema

  import Ecto.Changeset

  typed_schema "authorizir_permissions" do
    field(:ext_id, :binary)
    field(:description, :string)
    timestamps()
  end

  def new(ext_id, description) do
    %__MODULE__{}
    |> cast(%{ext_id: ext_id, description: description}, [:ext_id, :description])
    |> validate_required([:ext_id, :description])
    |> unique_constraint(:ext_id)
  end

  def supremum, do: %__MODULE__{id: "*", ext_id: "*", description: "Permission Supremum"}
end
