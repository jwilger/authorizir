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

    create table("users") do
      add :name, :string, null: false
      timestamps()
    end
    apply_subject_hierarchy("users", id_field: :id)
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

    schema "users" do
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

  import Authorizir.ErrorHelpers, only: [errors_on: 2]
  import Authorizir.ToAuthorizirId, only: [to_ext_id: 1]
  import Ecto.Query, only: [from: 2]

  alias Authorizir.{AuthorizationRule, Object, Permission, Subject, ToAuthorizirId}

  require Logger

  defmodule AuthorizationError do
    defexception [:message]
  end

  @type to_ext_id() :: ToAuthorizirId.t()

  @optional_callbacks [init: 0]

  @application_module :authorizir
                      |> Application.compile_env(:app_module)
                      |> tap(
                        &(!is_nil(&1) or
                            raise(CompileError,
                              file: __ENV__.file,
                              line: __ENV__.line,
                              description:
                                "Application Auth module not configured, e.g. `config :authorizir, app_module: MyApp.Auth`"
                            ))
                      )

  @spec application_module :: module()
  def application_module, do: @application_module

  @callback init :: :ok

  @callback register_subject(id :: to_ext_id(), description :: String.t(), static :: boolean()) ::
              :ok | {:error, reason :: atom()}

  @spec register_subject(Ecto.Repo.t(), to_ext_id(), String.t(), static :: boolean()) ::
          :ok | {:error, :description_is_required | :id_is_required}
  def register_subject(repo, id, description, static \\ false) do
    id = to_ext_id(id)
    log(:info, "Registering subject #{id} - #{description}")

    case Subject.new(id, description, static)
         |> repo.insert(
           on_conflict: {:replace, [:description, :static]},
           conflict_target: :ext_id
         ) do
      {:ok, _subject} ->
        :ok = add_child(repo, "*", id, Subject)

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

  @callback register_object(id :: to_ext_id(), description :: String.t(), static :: boolean()) ::
              :ok | {:error, reason :: atom()}

  @spec register_object(Ecto.Repo.t(), to_ext_id(), String.t(), static :: boolean()) ::
          :ok | {:error, :description_is_required | :id_is_required}
  def register_object(repo, id, description, static \\ false) do
    id = to_ext_id(id)

    case Object.new(id, description, static)
         |> repo.insert(
           on_conflict: {:replace, [:description, :static]},
           conflict_target: :ext_id
         ) do
      {:ok, _object} ->
        :ok = add_child(repo, "*", id, Object)

      {:error, changeset} ->
        cond do
          "can't be blank" in errors_on(changeset, :ext_id) ->
            {:error, :id_is_required}

          "can't be blank" in errors_on(changeset, :description) ->
            {:error, :description_is_required}

          true ->
            raise "Unanticipated error while adding object: #{inspect(changeset)}"
        end
    end
  end

  @callback register_permission(id :: to_ext_id(), description :: String.t(), static :: boolean()) ::
              :ok | {:error, reason :: atom()}

  @spec register_permission(Ecto.Repo.t(), to_ext_id(), String.t(), static :: boolean()) ::
          :ok | {:error, :description_is_required | :id_is_required}
  def register_permission(repo, id, description, static \\ false) do
    id = to_ext_id(id)

    case Permission.new(id, description, static)
         |> repo.insert(
           on_conflict: {:replace, [:description, :static]},
           conflict_target: :ext_id
         ) do
      {:ok, _permisson} ->
        :ok = add_child(repo, "*", id, Permission)

      {:error, changeset} ->
        cond do
          "can't be blank" in errors_on(changeset, :ext_id) ->
            {:error, :id_is_required}

          "can't be blank" in errors_on(changeset, :description) ->
            {:error, :description_is_required}

          true ->
            raise "Unanticipated error while adding permisson: #{inspect(changeset)}"
        end
    end
  end

  @callback grant_permission(
              subject_id :: to_ext_id(),
              object_id :: to_ext_id(),
              permission_id :: to_ext_id()
            ) :: :ok | {:error, reason :: atom()}

  @spec grant_permission(Ecto.Repo.t(), to_ext_id(), to_ext_id(), to_ext_id(), boolean()) ::
          :ok | {:error, atom()}
  def grant_permission(repo, subject_id, object_id, permission_id, static \\ false) do
    create_rule(repo, subject_id, object_id, permission_id, :+, static)
  end

  @callback revoke_permission(
              subject_id :: to_ext_id(),
              object_id :: to_ext_id(),
              permission_id :: to_ext_id()
            ) :: :ok | {:error, reason :: atom()}

  @spec revoke_permission(Ecto.Repo.t(), to_ext_id(), to_ext_id(), to_ext_id()) ::
          :ok | {:error, atom()}
  def revoke_permission(repo, subject_id, object_id, permission_id) do
    delete_rule(repo, subject_id, object_id, permission_id, :+)
  end

  @callback deny_permission(
              subject_id :: to_ext_id(),
              object_id :: to_ext_id(),
              permission_id :: to_ext_id()
            ) :: :ok | {:error, reason :: atom()}

  @spec deny_permission(Ecto.Repo.t(), to_ext_id(), to_ext_id(), to_ext_id(), boolean()) ::
          :ok | {:error, atom()}
  def deny_permission(repo, subject_id, object_id, permission_id, static \\ false) do
    create_rule(repo, subject_id, object_id, permission_id, :-, static)
  end

  @callback allow_permission(
              subject_id :: to_ext_id(),
              object_id :: to_ext_id(),
              permission_id :: to_ext_id()
            ) :: :ok | {:error, reason :: atom()}

  @spec allow_permission(Ecto.Repo.t(), to_ext_id(), to_ext_id(), to_ext_id()) ::
          :ok | {:error, atom()}
  def allow_permission(repo, subject_id, object_id, permission_id) do
    delete_rule(repo, subject_id, object_id, permission_id, :-)
  end

  @callback add_child(parent_id :: to_ext_id(), child_id :: to_ext_id(), type :: module()) ::
              :ok | {:error, reason :: atom()}

  @spec add_child(Ecto.Repo.t(), to_ext_id(), to_ext_id(), module()) ::
          :ok | {:error, :invalid_parent | :invalid_child}
  def add_child(repo, parent_id, child_id, type) do
    with {:ok, parent} <- get_parent(repo, type, parent_id),
         {:ok, child} <- get_child(repo, type, child_id),
         {:edge_created, _edge} <- type.create_edge(parent, child) |> repo.dagex_update() do
      :ok
    end
  end

  defp get_parent(repo, type, parent_id) do
    case get_node(repo, type, parent_id) do
      {:ok, node} -> {:ok, node}
      {:error, :not_found} -> {:error, :invalid_parent}
    end
  end

  defp get_child(repo, type, child_id) do
    case get_node(repo, type, child_id) do
      {:ok, node} -> {:ok, node}
      {:error, :not_found} -> {:error, :invalid_child}
    end
  end

  defp get_node(repo, type, id) do
    id = to_ext_id(id)
    get = fn -> repo.get_by(type, ext_id: id) end

    case get.() do
      nil ->
        :timer.sleep(100)

        case get.() do
          nil -> {:error, :not_found}
          node -> {:ok, node}
        end

      node ->
        {:ok, node}
    end
  end

  @callback remove_child(parent_id :: to_ext_id(), child_id :: to_ext_id(), type :: module()) ::
              :ok | {:error, reason :: atom()}

  @spec remove_child(Ecto.Repo.t(), to_ext_id(), to_ext_id(), module()) ::
          :ok | {:error, :invalid_parent | :invalid_child}
  def remove_child(repo, parent_id, child_id, type) do
    with {:ok, parent} <- get_parent(repo, type, parent_id),
         {:ok, child} <- get_child(repo, type, child_id),
         {:edge_removed, _edge} <- type.remove_edge(parent, child) |> repo.dagex_update() do
      :ok
    end
  end

  @callback permission_granted?(
              subject_id :: to_ext_id(),
              object_id :: to_ext_id(),
              permission_id :: to_ext_id()
            ) :: boolean()

  @spec permission_granted?(Ecto.Repo.t(), to_ext_id(), to_ext_id(), to_ext_id()) :: boolean()
  def permission_granted?(repo, subject_id, object_id, permission_id) do
    case sop_nodes(repo, subject_id, object_id, permission_id) do
      {:ok, subject, object, permission} ->
        cond do
          authorization_rule_applies?(repo, subject, object, permission, :-) -> false
          authorization_rule_applies?(repo, subject, object, permission, :+) -> true
          true -> false
        end

      {:error, :invalid_subject} ->
        raise(AuthorizationError, message: "invalid subject: #{subject_id}")

      {:error, :invalid_object} ->
        raise(AuthorizationError, message: "invalid object: #{object_id}")

      {:error, :invalid_permission} ->
        raise(AuthorizationError, message: "invalid permission: #{permission_id}")
    end
  end

  @callback list_rules(ext_id :: to_ext_id(), type :: Subject | Object | Permission) ::
              list(
                {subject :: binary(), object :: binary(), permission :: binary(), type :: :+ | :-}
              )
  @spec list_rules(Ecto.Repo.t(), to_ext_id(), module()) ::
          list({binary(), binary(), binary(), :+ | :-})
  def list_rules(repo, ext_id, Subject) do
    ext_id = to_ext_id(ext_id)
    q = from([r, subject: s] in list_rules_query(), where: s.ext_id == ^ext_id)
    repo.all(q)
  end

  def list_rules(repo, ext_id, Object) do
    ext_id = to_ext_id(ext_id)
    q = from([r, object: o] in list_rules_query(), where: o.ext_id == ^ext_id)
    repo.all(q)
  end

  defp list_rules_query do
    from(r in AuthorizationRule,
      join: s in Subject,
      as: :subject,
      on: s.id == r.subject_id,
      join: o in Object,
      as: :object,
      on: o.id == r.object_id,
      join: p in Permission,
      as: :permisson,
      on: p.id == r.permission_id,
      select: {s.ext_id, o.ext_id, p.ext_id, r.rule_type},
      order_by: [s.ext_id, o.ext_id, p.ext_id, r.rule_type]
    )
  end

  defp authorization_rule_applies?(repo, subject, object, permission, :-) do
    supremum = repo.get_by!(Permission, ext_id: "*")

    from([r, s, o] in authorization_rules_for(subject, object),
      join: p in subquery(Permission.with_descendants(permission)),
      on: p.id == r.permission_id,
      where: r.rule_type == :-
    )
    |> repo.exists?() ||
      if permission != supremum,
        do: authorization_rule_applies?(repo, subject, object, supremum, :-)
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
    with %Subject{} = subject <- subject_node(repo, subject_ext_id),
         %Object{} = object <- object_node(repo, object_ext_id),
         %Permission{} = permission <- permission_node(repo, permission_ext_id) do
      {:ok, subject, object, permission}
    end
  end

  defp subject_node(repo, ext_id),
    do: repo.get_by(Subject, ext_id: to_ext_id(ext_id)) || {:error, :invalid_subject}

  defp object_node(repo, ext_id),
    do: repo.get_by(Object, ext_id: to_ext_id(ext_id)) || {:error, :invalid_object}

  defp permission_node(repo, ext_id),
    do: repo.get_by(Permission, ext_id: to_ext_id(ext_id)) || {:error, :invalid_permission}

  defp create_rule(repo, subject_id, object_id, permission_id, rule_type, static) do
    with {:ok, subject_id, object_id, permission_id} <-
           sop_ids(repo, subject_id, object_id, permission_id),
         :ok <- check_existing_rule(repo, subject_id, object_id, permission_id) do
      case AuthorizationRule.new(subject_id, object_id, permission_id, rule_type, static)
           |> repo.insert() do
        {:ok, _rule} ->
          :ok

        {:error, changeset} ->
          raise "Unanticipated error occured while creating Authorization Rule. #{inspect(changeset)}"
      end
    else
      {:existing_rule, %{rule_type: ^rule_type}} -> :ok
      {:existing_rule, _rule} -> {:error, :conflicting_rule_type}
      {:error, _} = error -> error
    end
  end

  defp check_existing_rule(repo, subject_id, object_id, permission_id) do
    case repo.get_by(AuthorizationRule,
           subject_id: subject_id,
           object_id: object_id,
           permission_id: permission_id
         ) do
      nil -> :ok
      %AuthorizationRule{} = rule -> {:existing_rule, rule}
    end
  end

  defp delete_rule(repo, subject_id, object_id, permission_id, rule_type) do
    case sop_ids(repo, subject_id, object_id, permission_id) do
      {:ok, subject_id, object_id, permission_id} ->
        from(r in AuthorizationRule,
          where:
            r.subject_id == ^subject_id and r.object_id == ^object_id and
              r.permission_id == ^permission_id and r.rule_type == ^rule_type
        )
        |> repo.delete_all()

        :ok

      {:error, _} = error ->
        error
    end
  end

  defmodule ImplHelper do
    @moduledoc false

    import Ecto.Query, only: [from: 2, exclude: 2, where: 2]

    @spec create_rule(Ecto.Repo.t(), String.t(), String.t(), String.t(), :+ | :-) ::
            :ok | {:error, atom()}
    def create_rule(repo, subject, object, permission, :+) do
      Authorizir.grant_permission(repo, subject, object, permission, true)
    end

    def create_rule(repo, subject, object, permission, :-) do
      Authorizir.deny_permission(repo, subject, object, permission, true)
    end

    @spec remove_orphans(m, Ecto.Repo.t(), function()) :: m when m: module()

    def remove_orphans(AuthorizationRule, repo, _fn) do
      from(r in AuthorizationRule, where: r.static == true)
      |> repo.delete_all()

      AuthorizationRule
    end

    def remove_orphans(type, repo, declarations_fn) do
      keep_ids =
        Enum.map(declarations_fn.(), fn {ext_id, _desc, _children} -> to_ext_id(ext_id) end)

      q =
        case type do
          Subject ->
            from(r in AuthorizationRule,
              join: s in Subject,
              on: s.id == r.subject_id,
              where: s.static == true and s.ext_id not in ^keep_ids
            )

          Object ->
            from(r in AuthorizationRule,
              join: o in Object,
              on: o.id == r.object_id,
              where: o.static == true and o.ext_id not in ^keep_ids
            )

          Permission ->
            from(r in AuthorizationRule,
              join: p in Permission,
              on: p.id == r.permission_id,
              where: p.static == true and p.ext_id not in ^keep_ids
            )
        end

      repo.delete_all(q)

      from(r in type, where: r.static == true and r.ext_id not in ^keep_ids)
      |> repo.all()
      |> Enum.each(fn r -> repo.delete(r) end)

      type
    end

    @spec register_items(m, Ecto.Repo.t(), function(), function()) :: m when m: module()
    def register_items(AuthorizationRule, repo, declarations_fn, register_fn) do
      for {subject, object, permission, type} <- declarations_fn.() do
        register_fn.(repo, subject, object, permission, type)
      end

      AuthorizationRule
    end

    def register_items(type, _repo, declarations_fn, register_fn) do
      for {ext_id, description, _children} <- declarations_fn.() do
        register_fn.(ext_id, description, true)
      end

      type
    end

    @spec upsert_supremum(m, Ecto.Repo.t()) :: m when m: module()
    def upsert_supremum(type, repo) do
      %{ext_id: "*", description: "Supremum"}
      |> then(&struct!(type, &1))
      |> repo.insert!(on_conflict: :nothing, conflict_target: :ext_id)

      type
    end

    @spec build_tree(m, Ecto.Repo.t(), function()) :: m when m: module()
    def build_tree(Permission = type, repo, declarations_fn) do
      for {ext_id, _description, children} <- declarations_fn.() do
        ext_id = to_ext_id(ext_id)
        item = repo.get_by(type, ext_id: ext_id)

        from(c in type.children(item), where: c.static == true)
        |> exclude(:distinct)
        |> repo.all()
        |> Enum.each(fn child ->
          Authorizir.remove_child(repo, ext_id, child.ext_id, type)
        end)

        for child <- children do
          Authorizir.add_child(repo, ext_id, child, type)
        end
      end

      :ok
    end

    def build_tree(type, repo, declarations_fn) do
      for {ext_id, _description, parents} <- declarations_fn.() do
        ext_id = to_ext_id(ext_id)
        item = repo.get_by(type, ext_id: ext_id)

        from(c in type.parents(item), where: c.static == true and c.ext_id not in ^parents)
        |> exclude(:distinct)
        |> repo.all()
        |> Enum.each(fn parent ->
          Authorizir.remove_child(repo, parent.ext_id, ext_id, type)
        end)

        existing =
          type.parents(item)
          |> where(static: true)
          |> repo.all()
          |> Enum.map(fn x -> x.ext_id end)

        Enum.filter(parents, fn parent -> parent not in existing end)
        |> Enum.each(fn parent ->
          Authorizir.add_child(repo, parent, ext_id, type)
        end)
      end

      :ok
    end
  end

  defmacro __using__(opts) do
    repo = Keyword.fetch!(opts, :repo)
    application = Keyword.fetch!(opts, :application)
    module = __CALLER__.module

    # credo:disable-for-next-line Credo.Check.Refactor.LongQuoteBlocks
    quote location: :keep, bind_quoted: [repo: repo, module: module, application: application] do
      require Authorizir.Macros
      Module.register_attribute(module, :permissions, accumulate: true)
      Module.register_attribute(module, :subjects, accumulate: true)
      Module.register_attribute(module, :objects, accumulate: true)
      Module.register_attribute(module, :rules, accumulate: true)

      @authorizir_repo repo
      @authorizir_application application
      @behaviour Authorizir

      import Authorizir.Macros,
        only: [
          permission: 2,
          permission: 3,
          role: 2,
          role: 3,
          collection: 2,
          collection: 3,
          grant: 2,
          deny: 2
        ]

      import ImplHelper

      @impl Authorizir
      # credo:disable-for-next-line Credo.Check.Refactor.ABCSize
      def init do
        upsert_supremum(Permission, @authorizir_repo)
        upsert_supremum(Subject, @authorizir_repo)
        upsert_supremum(Object, @authorizir_repo)

        remove_orphans(AuthorizationRule, @authorizir_repo, &rule_declarations/0)
        remove_orphans(Permission, @authorizir_repo, &permission_declarations/0)
        remove_orphans(Subject, @authorizir_repo, &subject_declarations/0)
        remove_orphans(Object, @authorizir_repo, &object_declarations/0)

        register_items(
          Permission,
          @authorizir_repo,
          &permission_declarations/0,
          &register_permission/3
        )

        register_items(Subject, @authorizir_repo, &subject_declarations/0, &register_subject/3)
        register_items(Object, @authorizir_repo, &object_declarations/0, &register_object/3)

        register_items(
          AuthorizationRule,
          @authorizir_repo,
          &rule_declarations/0,
          &create_rule/5
        )

        build_tree(Permission, @authorizir_repo, &permission_declarations/0)
        build_tree(Subject, @authorizir_repo, &subject_declarations/0)
        build_tree(Object, @authorizir_repo, &object_declarations/0)

        :ok
      end

      @impl Authorizir
      def register_permission(id, description, static \\ false) do
        impl().register_permission(id, description, static)
      end

      @impl Authorizir
      def register_subject(id, description, static \\ false) do
        impl().register_subject(id, description, static)
      end

      @impl Authorizir
      def register_object(id, description, static \\ false) do
        impl().register_object(id, description, static)
      end

      @impl Authorizir
      def add_child(parent_id, child_id, type) do
        impl().add_child(parent_id, child_id, type)
      end

      @impl Authorizir
      def list_rules(ext_id, type) do
        impl().list_rules(ext_id, type)
      end

      @impl Authorizir
      def grant_permission(subject_id, object_id, permission_id) do
        impl().grant_permission(subject_id, object_id, permission_id)
      end

      @impl Authorizir
      def deny_permission(subject_id, object_id, permission_id) do
        impl().deny_permission(subject_id, object_id, permission_id)
      end

      @impl Authorizir
      def permission_granted?(subject_id, object_id, permission_id) do
        impl().permission_granted?(subject_id, object_id, permission_id)
      end

      @impl Authorizir
      def revoke_permission(subject_id, object_id, permission_id) do
        impl().revoke_permission(subject_id, object_id, permission_id)
      end

      @impl Authorizir
      def allow_permission(subject_id, object_id, permission_id) do
        impl().allow_permission(subject_id, object_id, permission_id)
      end

      @impl Authorizir
      def remove_child(parent_id, child_id, type) do
        impl().remove_child(parent_id, child_id, type)
      end

      defp permission_declarations, do: @permissions

      defp subject_declarations, do: @subjects

      defp object_declarations, do: @objects

      defp rule_declarations, do: @rules

      defoverridable permission_declarations: 0,
                     subject_declarations: 0,
                     object_declarations: 0,
                     rule_declarations: 0

      @spec impl() :: Authorizir.t()
      defp impl,
        do: Application.get_env(@authorizir_application, __MODULE__.Impl, __MODULE__.Impl)

      defmodule Impl do
        @moduledoc false
        @behaviour Authorizir
        @authorizir_repo repo

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
          do:
            Authorizir.permission_granted?(@authorizir_repo, subject_id, object_id, permission_id)

        @impl Authorizir
        def add_child(parent_id, child_id, type),
          do: Authorizir.add_child(@authorizir_repo, parent_id, child_id, type)

        @impl Authorizir
        def remove_child(parent_id, child_id, type),
          do: Authorizir.remove_child(@authorizir_repo, parent_id, child_id, type)

        @impl Authorizir
        def register_subject(id, description, static \\ false),
          do: Authorizir.register_subject(@authorizir_repo, id, description, static)

        @impl Authorizir
        def register_object(id, description, static \\ false),
          do: Authorizir.register_object(@authorizir_repo, id, description, static)

        @impl Authorizir
        def register_permission(id, description, static \\ false),
          do: Authorizir.register_permission(@authorizir_repo, id, description, static)

        @impl Authorizir
        def list_rules(ext_id, type), do: Authorizir.list_rules(@authorizir_repo, ext_id, type)
      end
    end
  end

  defp to_string_list(value) when is_atom(value), do: [to_string(value)]
  defp to_string_list(value) when is_list(value), do: Enum.map(value, fn v -> to_string(v) end)

  @doc false
  @spec string_list_from_option(keyword(), atom()) :: list(String.t())
  def string_list_from_option(opts, key) do
    case Keyword.fetch(opts, key) do
      {:ok, value} -> to_string_list(value)
      :error -> []
    end
  end

  defp log(level, message) do
    Logger.log(level, message, label: "[Authorizir]")
  end
end
