defmodule Authorizir do
  @moduledoc ~S"""
  Ecto-backed Authorization Library for Elixir Applications

  See [README](README.md) for a description of the mathematical model used as
  the basis of this system.

  ## Usage

  Imagine you are creating an app that handles online ordering.

  First, create your app's authorization module, configuring it with your
  application repository:

  ```elixir
  defmodule Auth do
    use Authorizir, repo: Repo
  end
  ```

  Users of the application might be organized into a hierarchy as follows (note
  that an employee can also be a customer):

  ```mermaid
  graph TD
    *[Users *] --> E[Employees]
    * --> C[Customers]

    E --> A[Admins]
    E --> M[Marketing]
    E --> F[Finance]
    E --> S[Shipping and Fulfillment]

    A --> Bob

    M --> Bob
    M --> Jane

    F --> Amanda

    S --> George
    S --> Beth

    C --> Amanda
    C --> George
    C --> John
  ```

  We have two types of Subject entities represented here; "Organizational Units"
  represent groups of users such as internal departments and customers, while
  "Users" represent the individual system accounts. Each of these are
  represented with Ecto schemas in our app, and we include the
  `Authorizir.Subject` behavior in the modules, so that they can participate in
  the Subject hierarcy.

  First we add the necessary migrations by running `mix ecto.gen.migraion
  add_org_units_and_users` and editing the resulting migration file:

  ```elixir
  defmodule AddOrgUnitsAndUsers do
    use Ecto.Migration
    import Authorizir.Migrations, only: [apply_subject_hierarchy: 2]

    create table("org_units") do
      add :name, :string, null: false
      timestamps()
    end
    apply_subject_hierarchy("org_units", id_field: :id)

    create table("org_units") do
      add :name, :string, null: false
      timestamps()
    end
    apply_subject_hierarchy("org_units", id_field: :id)
  end
  ```

  ```elixir
  defmodule OrgUnit do
    use Ecto.Schema
    use Authorizir.Subject

    schema "org_units" do
      field :name, :string
    end
  end

  defmodule User do
    use Ecto.Schema
    use Authorizir.Subject

    schema "org_units" do
      field :name, :string
    end
  end
  ```

  You can create the hierarchy as:

  ```elixir
  {:ok, employees} = %OrgUnit{name: "Employees"} |> Repo.insert()

  {:ok, customers} = %OrgUnit{name: "Customers"} |> Repo.insert()

  {:ok, admins} = %OrgUnit{name: "Admins"} |> Repo.insert()
  :ok = Auth.add_child(employees.id, admins.id, Subject)

  {:ok, marketing} = %OrgUnit{name: "Marketing"} |> Repo.insert()
  :ok = Auth.add_child(employees.id, marketing.id, Subject)

  {:ok, finance} = %OrgUnit{name: "Finance"} |> Repo.insert()
  :ok = Auth.add_child(employees.id, finance.id, Subject)

  {:ok, shipping} = %OrgUnit{name: "Shipping and Fulfillment"} |> Repo.insert()
  :ok = Auth.add_child(employees.id, shipping.id, Subject)

  {:ok, bob} = %User{name: "Bob"} |> Repo.insert()
  :ok = Auth.add_child(admins.id, bob.id, Subject)
  :ok = Auth.add_child(marketing.id, bob.id, Subject)

  {:ok, jane} = %User{name: "Jane"} |> Repo.insert()
  :ok = Auth.add_child(marketing.id, jane.id, Subject)

  {:ok, amanda} = %User{name: "Amanda"} |> Repo.insert()
  :ok = Auth.add_child(finance.id, amanda.id, Subject)
  :ok = Auth.add_child(customers.id, amanda.id, Subject)

  {:ok, george} = %User{name: "George"} |> Repo.insert()
  :ok = Auth.add_child(shipping.id, george.id, Subject)
  :ok = Auth.add_child(customers.id, george.id, Subject)

  {:ok, beth} = %User{name: "Beth"} |> Repo.insert()
  :ok = Auth.add_child(shipping.id, beth.id, Subject)

  {:ok, john} = %User{name: "John"} |> Repo.insert()
  :ok = Auth.add_child(customers.id, john.id, Subject)
  ```

  """

  alias Authorizir.{AuthorizationRule, Object, Permission, Subject}

  import Authorizir.ErrorHelpers, only: [errors_on: 2]
  import Ecto.Query, only: [from: 2]

  @callback register_subject(id :: binary(), description :: String.t()) ::
              :ok | {:error, reason :: atom()}

  def register_subject(repo, id, description) do
    case Subject.new(id, description) |> repo.insert() do
      {:ok, _subject} ->
        :ok

      {:error, changeset} ->
        cond do
          "can't be blank" in errors_on(changeset, :ext_id) ->
            {:error, :id_is_required}

          "can't be blank" in errors_on(changeset, :description) ->
            {:error, :description_is_required}

          true ->
            raise "Unanticipated error while adding Subject: #{inspect(changeset)}"
        end
    end
  end

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

  @callback add_child(parent_id :: binary(), child_id :: binary(), type :: module()) ::
              :ok | {:error, reason :: atom()}

  def add_child(repo, parent_id, child_id, type) do
    with {:parent, parent} when not is_nil(parent) <-
           {:parent, repo.get_by(type, ext_id: parent_id)},
         {:child, child} when not is_nil(child) <- {:child, repo.get_by(type, ext_id: child_id)},
         {:edge_created, _edge} <- type.create_edge(parent, child) |> repo.dagex_update() do
      :ok
    else
      {:parent, nil} -> {:error, :invalid_parent}
      {:child, nil} -> {:error, :invalid_parent}
      {:error, _reason} = error -> error
    end
  end

  @callback remove_child(parent_id :: binary(), child_id :: binary(), type :: module()) ::
              :ok | {:error, reason :: atom()}

  def remove_child(repo, parent_id, child_id, type) do
    with {:parent, parent} when not is_nil(parent) <-
           {:parent, repo.get_by(type, ext_id: parent_id)},
         {:child, child} when not is_nil(child) <- {:child, repo.get_by(type, ext_id: child_id)},
         {:edge_removed, _edge} <- type.remove_edge(parent, child) |> repo.dagex_update() do
      :ok
    else
      {:parent, nil} -> {:error, :invalid_parent}
      {:child, nil} -> {:error, :invalid_parent}
      {:error, _reason} = error -> error
    end
  end

  @callback permission_granted?(
              subject_id :: binary(),
              object_id :: binary(),
              permission_id :: binary()
            ) :: :granted | :denied | {:error, reason :: atom()}

  def permission_granted?(repo, subject_id, object_id, permission_id) do
    with {:sop, {:ok, subject, object, permission}} <-
           {:sop, sop_nodes(repo, subject_id, object_id, permission_id)} do
      cond do
        authorization_rule_applies?(repo, subject, object, permission, :-) -> :denied
        authorization_rule_applies?(repo, subject, object, permission, :+) -> :granted
        true -> :denied
      end
    else
      {:sop, error} -> error
    end
  end

  defp authorization_rule_applies?(repo, subject, object, permission, :-) do
    from([r, s, o] in authorization_rules_for(subject, object),
      join: p in subquery(Permission.with_descendants(permission)),
      on: p.id == r.permission_id,
      where: r.rule_type == :-
    )
    |> repo.exists?()
  end

  defp authorization_rule_applies?(repo, subject, object, permission, :+) do
    from([r, s, o] in authorization_rules_for(subject, object),
      join: p in subquery(Permission.with_ancestors(permission)),
      on: p.id == r.permission_id,
      where: r.rule_type == :+
    )
    |> repo.exists?()
  end

  defp authorization_rules_for(subject, object) do
    from(r in AuthorizationRule,
      join: s in subquery(Subject.with_ancestors(subject)),
      on: s.id == r.subject_id,
      join: o in subquery(Object.with_ancestors(object)),
      on: o.id == r.object_id
    )
  end

  defp sop_ids(repo, subject_ext_id, object_ext_id, permission_ext_id) do
    case sop_nodes(repo, subject_ext_id, object_ext_id, permission_ext_id) do
      {:ok, subject, object, permission} -> {:ok, subject.id, object.id, permission.id}
      result -> result
    end
  end

  defp sop_nodes(repo, subject_ext_id, object_ext_id, permission_ext_id) do
    with {:subject, %{} = subject} <-
           {:subject, repo.get_by(Subject, ext_id: subject_ext_id)},
         {:object, %{} = object} <-
           {:object, repo.get_by(Object, ext_id: object_ext_id)},
         {:permission, %{} = permission} <-
           {:permission, repo.get_by(Permission, ext_id: permission_ext_id)} do
      {:ok, subject, object, permission}
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

      @impl Authorizir
      def permission_granted?(subject_id, object_id, permission_id),
        do: Authorizir.permission_granted?(@authorizir_repo, subject_id, object_id, permission_id)

      @impl Authorizir
      def add_child(parent_id, child_id, type),
        do: Authorizir.add_child(@authorizir_repo, parent_id, child_id, type)

      @impl Authorizir
      def remove_child(parent_id, child_id, type),
        do: Authorizir.remove_child(@authorizir_repo, parent_id, child_id, type)

      @impl Authorizir
      def register_subject(id, description),
        do: Authorizir.register_subject(@authorizir_repo, id, description)
    end
  end
end
