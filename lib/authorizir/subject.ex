defmodule Authorizir.Subject do
  @moduledoc false

  use Dagex
  use TypedEctoSchema

  import Ecto.Changeset

  typed_schema "authorizir_subjects" do
    field(:ext_id, :binary)
    field(:description, :string)
    field(:static, :boolean)
    timestamps()
  end

  @spec new(String.t(), String.t(), boolean()) :: Ecto.Changeset.t(t())
  def new(ext_id, description, static \\ false) do
    %__MODULE__{}
    |> cast(%{ext_id: ext_id, description: description, static: static}, [
      :ext_id,
      :description,
      :static
    ])
    |> validate_required([:ext_id, :description])
    |> unique_constraint(:ext_id)
  end

  @spec supremum :: t()
  def supremum, do: %__MODULE__{id: 0, ext_id: "*", description: "Subject Supremum"}
end
