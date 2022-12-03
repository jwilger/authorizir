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
  import Ecto.Query, only: [from: 2]

  alias Authorizir.{AuthorizationRule, Object, Permission, Subject}

  @callback permission_declarations :: list({String.t(), String.t(), list(String.t())})
  @callback subject_declarations :: list({String.t(), String.t(), list(String.t())})
  @callback object_declarations :: list({String.t(), String.t(), list(String.t())})
  @callback rule_declarations :: list({String.t(), String.t(), String.t(), atom()})

  @callback init :: :ok

  @callback register_subject(id :: binary(), description :: String.t(), static :: boolean()) ::
              :ok | {:error, reason :: atom()}

  @spec register_subject(Ecto.Repo.t(), binary(), String.t(), static :: boolean()) ::
          :ok | {:error, :description_is_required | :id_is_required}
  def register_subject(repo, id, description, static \\ false) do
    case Subject.new(id, description, static)
         |> repo.insert(on_conflict: {:replace, [:description]}, conflict_target: :ext_id) do
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

  @callback register_object(id :: binary(), description :: String.t(), static :: boolean()) ::
              :ok | {:error, reason :: atom()}

  @spec register_object(Ecto.Repo.t(), binary(), String.t(), static :: boolean()) ::
          :ok | {:error, :description_is_required | :id_is_required}
  def register_object(repo, id, description, static \\ false) do
    case Object.new(id, description, static)
         |> repo.insert(on_conflict: {:replace, [:description]}, conflict_target: :ext_id) do
      {:ok, _object} ->
        :ok

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

  @callback register_permission(id :: binary(), description :: String.t(), static :: boolean()) ::
              :ok | {:error, reason :: atom()}

  @spec register_permission(Ecto.Repo.t(), binary(), String.t(), static :: boolean()) ::
          :ok | {:error, :description_is_required | :id_is_required}
  def register_permission(repo, id, description, static \\ false) do
    case Permission.new(id, description, static)
         |> repo.insert(on_conflict: {:replace, [:description]}, conflict_target: :ext_id) do
      {:ok, _permisson} ->
        :ok

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
              subject_id :: binary(),
              object_id :: binary(),
              permission_id :: binary()
            ) :: :ok | {:error, reason :: atom()}

  @spec grant_permission(Ecto.Repo.t(), binary(), binary(), binary(), boolean()) ::
          :ok | {:error, atom()}
  def grant_permission(repo, subject_id, object_id, permission_id, static \\ false) do
    create_rule(repo, subject_id, object_id, permission_id, :+, static)
  end

  @callback revoke_permission(
              subject_id :: binary(),
              object_id :: binary(),
              permission_id :: binary()
            ) :: :ok | {:error, reason :: atom()}

  @spec revoke_permission(Ecto.Repo.t(), binary(), binary(), binary()) :: :ok | {:error, atom()}
  def revoke_permission(repo, subject_id, object_id, permission_id) do
    delete_rule(repo, subject_id, object_id, permission_id, :+)
  end

  @callback deny_permission(
              subject_id :: binary(),
              object_id :: binary(),
              permission_id :: binary()
            ) :: :ok | {:error, reason :: atom()}

  @spec deny_permission(Ecto.Repo.t(), binary(), binary(), binary(), boolean()) ::
          :ok | {:error, atom()}
  def deny_permission(repo, subject_id, object_id, permission_id, static \\ false) do
    create_rule(repo, subject_id, object_id, permission_id, :-, static)
  end

  @callback allow_permission(
              subject_id :: binary(),
              object_id :: binary(),
              permission_id :: binary()
            ) :: :ok | {:error, reason :: atom()}

  @spec allow_permission(Ecto.Repo.t(), binary(), binary(), binary()) :: :ok | {:error, atom()}
  def allow_permission(repo, subject_id, object_id, permission_id) do
    delete_rule(repo, subject_id, object_id, permission_id, :-)
  end

  @callback add_child(parent_id :: binary(), child_id :: binary(), type :: module()) ::
              :ok | {:error, reason :: atom()}

  @spec add_child(Ecto.Repo.t(), binary(), binary(), module()) ::
          :ok | {:error, :invalid_parent | :invalid_child}
  def add_child(repo, parent_id, child_id, type) do
    with {:ok, parent} <- get_parent(repo, type, parent_id),
         {:ok, child} <- get_child(repo, type, child_id),
         {:edge_created, _edge} <- type.create_edge(parent, child) |> repo.dagex_update() do
      :ok
    end
  end

  defp get_parent(repo, type, parent_id) do
    case repo.get_by(type, ext_id: parent_id) do
      nil -> {:error, :invalid_parent}
      parent -> {:ok, parent}
    end
  end

  defp get_child(repo, type, child_id) do
    case repo.get_by(type, ext_id: child_id) do
      nil -> {:error, :invalid_child}
      child -> {:ok, child}
    end
  end

  @callback remove_child(parent_id :: binary(), child_id :: binary(), type :: module()) ::
              :ok | {:error, reason :: atom()}

  @spec remove_child(Ecto.Repo.t(), binary(), binary(), module()) ::
          :ok | {:error, :invalid_parent | :invalid_child}
  def remove_child(repo, parent_id, child_id, type) do
    with {:ok, parent} <- get_parent(repo, type, parent_id),
         {:ok, child} <- get_child(repo, type, child_id),
         {:edge_removed, _edge} <- type.remove_edge(parent, child) |> repo.dagex_update() do
      :ok
    end
  end

  @callback permission_granted?(
              subject_id :: binary(),
              object_id :: binary(),
              permission_id :: binary()
            ) :: :granted | :denied | {:error, reason :: atom()}

  @spec permission_granted?(Ecto.Repo.t(), binary(), binary(), binary()) ::
          :denied | :granted | {:error, :invalid_subject | :invalid_object | :invalid_permission}
  def permission_granted?(repo, subject_id, object_id, permission_id) do
    case sop_nodes(repo, subject_id, object_id, permission_id) do
      {:ok, subject, object, permission} ->
        cond do
          authorization_rule_applies?(repo, subject, object, permission, :-) -> :denied
          authorization_rule_applies?(repo, subject, object, permission, :+) -> :granted
          true -> :denied
        end

      {:error, _} = error ->
        error
    end
  end

  @callback list_rules(ext_id :: binary(), type :: Subject | Object | Permission) ::
              list(
                {subject :: binary(), object :: binary(), permission :: binary(), type :: :+ | :-}
              )
  @spec list_rules(Ecto.Repo.t(), binary(), module()) ::
          list({binary(), binary(), binary(), :+ | :-})
  def list_rules(repo, ext_id, Subject) do
    q = from([r, subject: s] in list_rules_query(), where: s.ext_id == ^ext_id)
    repo.all(q)
  end

  def list_rules(repo, ext_id, Object) do
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
    with %Subject{} = subject <- subject_node(repo, subject_ext_id),
         %Object{} = object <- object_node(repo, object_ext_id),
         %Permission{} = permission <- permission_node(repo, permission_ext_id) do
      {:ok, subject, object, permission}
    end
  end

  defp subject_node(_repo, "*"), do: Subject.supremum()

  defp subject_node(repo, ext_id),
    do: repo.get_by(Subject, ext_id: ext_id) || {:error, :invalid_subject}

  defp object_node(_repo, "*"), do: Object.supremum()

  defp object_node(repo, ext_id),
    do: repo.get_by(Object, ext_id: ext_id) || {:error, :invalid_object}

  defp permission_node(repo, ext_id),
    do: repo.get_by(Permission, ext_id: ext_id) || {:error, :invalid_permission}

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

    import Ecto.Query, only: [from: 2, exclude: 2]

    @spec remove_orphans(m :: module(), Ecto.Repo.t(), fun()) :: m :: module()
    def remove_orphans(AuthorizationRule, repo, _fn) do
      q = from(r in AuthorizationRule, where: r.static == true)
      repo.delete_all(q)
      AuthorizationRule
    end

    def remove_orphans(type, repo, declarations_fn) do
      keep_ids = Enum.map(declarations_fn.(), fn {ext_id, _desc, _children} -> ext_id end)
      q = from(r in type, where: r.static == true and r.ext_id not in ^keep_ids)
      repo.delete_all(q)
      type
    end

    @spec register_items(
            AuthorizationRule,
            Ecto.Repo.t(),
            fun(),
            (Ecto.Repo.t(), String.t(), String.t(), String.t(), :+ | :- -> any())
          ) :: AuthorizationRule
    def register_items(AuthorizationRule, repo, declarations_fn, register_fn) do
      for {subject, object, permission, type} <- declarations_fn.() do
        register_fn.(repo, subject, object, permission, type)
      end

      AuthorizationRule
    end

    @spec register_items(
            m :: module(),
            Ecto.Repo.t(),
            fun(),
            (String.t(), String.t(), boolean() -> any())
          ) :: m :: module()
    def register_items(type, _repo, declarations_fn, register_fn) do
      for {ext_id, description, _children} <- declarations_fn.() do
        register_fn.(ext_id, description, true)
      end

      type
    end

    @spec set_up(
            AuthorizationRule,
            Ecto.Repo.t(),
            fun(),
            (Ecto.Repo.t(), String.t(), String.t(), String.t(), :+ | :- -> any())
          ) :: :ok
    @spec set_up(module(), Ecto.Repo.t(), fun(), (String.t(), String.t(), boolean() -> any())) ::
            :ok
    def set_up(type, repo, declarations_fn, register_fn) do
      type
      |> remove_orphans(repo, declarations_fn)
      |> register_items(repo, declarations_fn, register_fn)
      |> build_tree(repo, declarations_fn)

      :ok
    end

    @spec create_rule(Ecto.Repo.t(), String.t(), String.t(), String.t(), :+ | :-) ::
            :ok | {:error, atom()}
    def create_rule(repo, subject, object, permission, :+) do
      Authorizir.grant_permission(repo, subject, object, permission, true)
    end

    def create_rule(repo, subject, object, permission, :-) do
      Authorizir.deny_permission(repo, subject, object, permission, true)
    end

    @spec build_tree(module(), Ecto.Repo.t(), fun()) :: :ok
    def build_tree(AuthorizationRule, _repo, _fn), do: :ok

    def build_tree(Permission = type, repo, declarations_fn) do
      for {ext_id, _description, children} <- declarations_fn.() do
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
        item = repo.get_by(type, ext_id: ext_id)

        from(c in type.parents(item), where: c.static == true)
        |> exclude(:distinct)
        |> repo.all()
        |> Enum.each(fn parent ->
          Authorizir.remove_child(repo, parent.ext_id, ext_id, type)
        end)

        for parent <- parents do
          Authorizir.add_child(repo, parent, ext_id, type)
        end
      end

      :ok
    end
  end

  defmacro __using__(opts) do
    repo = Keyword.fetch!(opts, :repo)
    module = __CALLER__.module

    quote bind_quoted: [repo: repo, module: module] do
      Module.register_attribute(module, :permissions, accumulate: true)
      Module.register_attribute(module, :subjects, accumulate: true)
      Module.register_attribute(module, :objects, accumulate: true)
      Module.register_attribute(module, :rules, accumulate: true)

      @authorizir_repo repo
      @behaviour Authorizir

      require Authorizir

      import Authorizir,
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
        set_up(Permission, @authorizir_repo, &permission_declarations/0, &register_permission/3)
        set_up(Subject, @authorizir_repo, &subject_declarations/0, &register_subject/3)
        set_up(Object, @authorizir_repo, &object_declarations/0, &register_object/3)
        set_up(AuthorizationRule, @authorizir_repo, &rule_declarations/0, &create_rule/5)
        :ok
      end

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
      def register_subject(id, description, static \\ false),
        do: Authorizir.register_subject(@authorizir_repo, id, description, static)

      @impl Authorizir
      def register_object(id, description, static \\ false),
        do: Authorizir.register_object(@authorizir_repo, id, description, static)

      @impl Authorizir
      def register_permission(id, description, static \\ false),
        do: Authorizir.register_permission(@authorizir_repo, id, description, static)

      @impl Authorizir
      def permission_declarations, do: @permissions

      @impl Authorizir
      def subject_declarations, do: @subjects

      @impl Authorizir
      def object_declarations, do: @objects

      @impl Authorizir
      def rule_declarations, do: @rules

      @impl Authorizir
      def list_rules(ext_id, type), do: Authorizir.list_rules(@authorizir_repo, ext_id, type)

      defoverridable permission_declarations: 0,
                     subject_declarations: 0,
                     object_declarations: 0,
                     rule_declarations: 0
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

  defmacro permission(ext_id, description, opts \\ []) do
    ext_id = to_string(ext_id)
    description = to_string(description)

    children = Authorizir.string_list_from_option(opts, :implies)

    quote bind_quoted: [ext_id: ext_id, description: description, children: children] do
      @permissions {ext_id, description, children}

      def permission_declarations, do: @permissions

      defoverridable permission_declarations: 0
    end
  end

  defmacro role(ext_id, description, opts \\ []) do
    ext_id = to_string(ext_id)
    description = to_string(description)

    parents = Authorizir.string_list_from_option(opts, :implies)

    quote bind_quoted: [ext_id: ext_id, description: description, parents: parents] do
      @subjects {ext_id, description, parents}
      @objects {ext_id, description, parents}

      def subject_declarations, do: @subjects
      def object_declarations, do: @objects

      defoverridable subject_declarations: 0, object_declarations: 0
    end
  end

  defmacro collection(ext_id, description, opts \\ []) do
    ext_id = to_string(ext_id)
    description = to_string(description)

    parents = Authorizir.string_list_from_option(opts, :in)

    quote bind_quoted: [ext_id: ext_id, description: description, parents: parents] do
      @objects {ext_id, description, parents}

      def object_declarations, do: @objects

      defoverridable object_declarations: 0
    end
  end

  defmacro grant(permission, [{:on, object}, {:to, subject}]) do
    permission = to_string(permission)
    object = to_string(object)
    subject = to_string(subject)

    quote bind_quoted: [permission: permission, object: object, subject: subject] do
      @rules {subject, object, permission, :+}

      def rule_declarations, do: @rules

      defoverridable rule_declarations: 0
    end
  end

  defmacro deny(permission, [{:on, object}, {:to, subject}]) do
    permission = to_string(permission)
    object = to_string(object)
    subject = to_string(subject)

    quote bind_quoted: [permission: permission, object: object, subject: subject] do
      @rules {subject, object, permission, :-}

      def rule_declarations, do: @rules

      defoverridable rule_declarations: 0
    end
  end
end
