defmodule Authorizir.Permission do
  @moduledoc false

  use Dagex
  use TypedEctoSchema

  import Ecto.Changeset

  typed_schema "authorizir_permissions" do
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

  defimpl Authorizir.ToAuthorizirId do
    @spec to_ext_id(@for.t()) :: String.t()
    def to_ext_id(term), do: term.ext_id
  end
end
