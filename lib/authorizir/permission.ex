defmodule Authorizir.Permission do
  @moduledoc false

  use Dagex
  use TypedEctoSchema

  import Ecto.Changeset

  typed_schema "authorizir_permissions" do
    field(:ext_id, :binary)
    field(:description, :string)
    timestamps()
  end

  @spec new(String.t(), String.t()) :: Ecto.Changeset.t(t())
  def new(ext_id, description) do
    %__MODULE__{}
    |> cast(%{ext_id: ext_id, description: description}, [:ext_id, :description])
    |> validate_required([:ext_id, :description])
    |> unique_constraint(:ext_id)
  end

  @spec supremum :: t()
  def supremum, do: %__MODULE__{ext_id: "*", description: "Permission Supremum"}
end
