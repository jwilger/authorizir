defmodule Authorizir do
  @moduledoc """
  Ecto-backed Authorization Library for Elixir Applications

  See [README](README.md) for a description of the mathematical model used as
  the basis of this system.
  """

  alias Authorizir.{AuthorizationRule, Object, Permission, Subject}

  import Ecto.Query, only: [from: 2]

  @callback grant_permission(
              subject_id :: binary(),
              object_id :: binary(),
              permission_id :: binary()
            ) :: :ok | {:error, reason :: atom()}

  def grant_permission(repo, subject_id, object_id, permission_id) do
    create_rule(repo, subject_id, object_id, permission_id, :+)
  end

  @callback revoke_permission(
              subject_id :: binary(),
              object_id :: binary(),
              permission_id :: binary()
            ) :: :ok | {:error, reason :: atom()}

  def revoke_permission(repo, subject_id, object_id, permission_id) do
    delete_rule(repo, subject_id, object_id, permission_id, :+)
  end

  @callback deny_permission(
              subject_id :: binary(),
              object_id :: binary(),
              permission_id :: binary()
            ) :: :ok | {:error, reason :: atom()}

  def deny_permission(repo, subject_id, object_id, permission_id) do
    create_rule(repo, subject_id, object_id, permission_id, :-)
  end

  @callback allow_permission(
              subject_id :: binary(),
              object_id :: binary(),
              permission_id :: binary()
            ) :: :ok | {:error, reason :: atom()}

  def allow_permission(repo, subject_id, object_id, permission_id) do
    delete_rule(repo, subject_id, object_id, permission_id, :-)
  end

  defp sop_ids(repo, subject_ext_id, object_ext_id, permission_ext_id) do
    with {:subject, %{id: subject_id}} <-
           {:subject, repo.get_by(Subject, ext_id: subject_ext_id)},
         {:object, %{id: object_id}} <-
           {:object, repo.get_by(Object, ext_id: object_ext_id)},
         {:permission, %{id: permission_id}} <-
           {:permission, repo.get_by(Permission, ext_id: permission_ext_id)} do
      {:ok, subject_id, object_id, permission_id}
    else
      {participant, nil} -> {:error, "invalid_#{participant}" |> String.to_atom()}
    end
  end

  defp create_rule(repo, subject_id, object_id, permission_id, rule_type) do
    with {:sop, {:ok, subject_id, object_id, permission_id}} <-
           {:sop, sop_ids(repo, subject_id, object_id, permission_id)},
         {:existing_rule, nil} <-
           {:existing_rule,
            repo.get_by(AuthorizationRule,
              subject_id: subject_id,
              object_id: object_id,
              permission_id: permission_id
            )} do
      case AuthorizationRule.new(subject_id, object_id, permission_id, rule_type)
           |> repo.insert() do
        {:ok, _rule} ->
          :ok

        {:error, changeset} ->
          cond do
            true ->
              raise "Unanticipated error occured while creating Authorization Rule. #{inspect(changeset)}"
          end
      end
    else
      {:sop, error} -> error
      {:existing_rule, %{rule_type: ^rule_type}} -> :ok
      {:existing_rule, _rule} -> {:error, :conflicting_rule_type}
    end
  end

  defp delete_rule(repo, subject_id, object_id, permission_id, rule_type) do
    with {:sop, {:ok, subject_id, object_id, permission_id}} <-
           {:sop, sop_ids(repo, subject_id, object_id, permission_id)} do
      from(r in AuthorizationRule,
        where:
          r.subject_id == ^subject_id and r.object_id == ^object_id and
            r.permission_id == ^permission_id and r.rule_type == ^rule_type
      )
      |> repo.delete_all()

      :ok
    else
      {:sop, error} -> error
    end
  end

  defmacro __using__(opts) do
    repo = Keyword.fetch!(opts, :repo)

    quote bind_quoted: [repo: repo] do
      @authorizir_repo repo
      @behaviour Authorizir

      @impl Authorizir
      def grant_permission(subject_id, object_id, permission_id),
        do: Authorizir.grant_permission(@authorizir_repo, subject_id, object_id, permission_id)

      @impl Authorizir
      def revoke_permission(subject_id, object_id, permission_id),
        do: Authorizir.revoke_permission(@authorizir_repo, subject_id, object_id, permission_id)

      @impl Authorizir
      def deny_permission(subject_id, object_id, permission_id),
        do: Authorizir.deny_permission(@authorizir_repo, subject_id, object_id, permission_id)

      @impl Authorizir
      def allow_permission(subject_id, object_id, permission_id),
        do: Authorizir.allow_permission(@authorizir_repo, subject_id, object_id, permission_id)
    end
  end
end
