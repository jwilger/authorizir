defmodule Authorizir.MacrosTest do
  use AuthorizirTest.DataCase

  alias Authorizir.{
    Object,
    Permission,
    Subject
  }

  defmodule MacroTest do
    @moduledoc false
    use Authorizir, repo: Repo, application: :authorizir

    collection(:documents, "Documents")
    collection(:articles, "Articles", in: :documents)
    collection(:faq, "FAQ", in: :articles)
    collection(:events, "Events")

    permission(:read, "Read")
    permission(:edit, "Edit", implies: :read)
    permission(:create, "Create", implies: :edit)
    permission(:delete, "Delete", implies: :edit)
    permission(:manage, "All CRUD permissions", implies: [:create, :delete, :edit, :read])

    role(:users, "Users")
    role(:editor, "Document editors", implies: :users)
    role(:support, "Customer Support", implies: :users)
    role(:scheduler, "Event Scheduler", implies: :users)
    role(:admin, "Admin users", implies: [:editor, :support, :scheduler])
    role(:no_access, "No Access")

    grant(:*, on: :*, to: :admin)
    grant(:read, on: :documents, to: :users)
    deny(:read, on: :articles, to: :scheduler)
    deny(:*, on: :*, to: :no_access)
  end

  setup do
    MacroTest.init()
    :ok
  end

  defp register(Permission, id, desc, static) do
    :ok = MacroTest.register_permission(id, desc, static)
    Repo.get_by!(Permission, ext_id: id)
  end

  defp register(Subject, id, desc, static) do
    :ok = MacroTest.register_subject(id, desc, static)
    Repo.get_by!(Subject, ext_id: id)
  end

  defp register(Object, id, desc, static) do
    :ok = MacroTest.register_object(id, desc, static)
    Repo.get_by!(Object, ext_id: id)
  end

  test "registers a collection leaf node with the specified description" do
    documents = Repo.get_by!(Object, ext_id: "documents")
    assert documents.description == "Documents"
    faq = Repo.get_by!(Object, ext_id: "faq")
    assert faq.description == "FAQ"
    articles = Repo.get_by!(Object, ext_id: "articles")
    assert articles.description == "Articles"
    events = Repo.get_by!(Object, ext_id: "events")
    assert events.description == "Events"
  end

  test "makes collection object a child/descendant of any implied objects" do
    supremum = Repo.get_by!(Object, ext_id: "*")
    documents = Repo.get_by!(Object, ext_id: "documents")
    faq = Repo.get_by!(Object, ext_id: "faq")
    articles = Repo.get_by!(Object, ext_id: "articles")

    assert Object.parents(faq) |> Repo.all() == [articles]
    assert Object.ancestors(faq) |> Repo.all() == [supremum, articles, documents]
  end

  test "registers a permission leaf node with the specified description" do
    read = Repo.get_by!(Permission, ext_id: "read")
    assert read.description == "Read"

    edit = Repo.get_by!(Permission, ext_id: "edit")
    assert edit.description == "Edit"

    create = Repo.get_by!(Permission, ext_id: "create")
    assert create.description == "Create"

    delete = Repo.get_by!(Permission, ext_id: "delete")
    assert delete.description == "Delete"

    manage = Repo.get_by!(Permission, ext_id: "manage")
    assert manage.description == "All CRUD permissions"
  end

  test "makes permission a parent/ancestor of any implied permissions" do
    read = Repo.get_by!(Permission, ext_id: "read")
    edit = Repo.get_by!(Permission, ext_id: "edit")
    delete = Repo.get_by!(Permission, ext_id: "delete")

    assert Permission.children(delete) |> Repo.all() == [edit]
    assert Permission.descendants(delete) |> Repo.all() == [edit, read]
  end

  test "registers a role as a subject leaf node with the specified description" do
    users = Repo.get_by!(Subject, ext_id: "users")
    assert users.description == "Users"
    editor = Repo.get_by!(Subject, ext_id: "editor")
    assert editor.description == "Document editors"
    support = Repo.get_by!(Subject, ext_id: "support")
    assert support.description == "Customer Support"
    scheduler = Repo.get_by!(Subject, ext_id: "scheduler")
    assert scheduler.description == "Event Scheduler"
    admin = Repo.get_by!(Subject, ext_id: "admin")
    assert admin.description == "Admin users"
  end

  test "makes role subject a child/descendant of any implied subjects" do
    supremum = Repo.get_by!(Subject, ext_id: "*")
    users = Repo.get_by!(Subject, ext_id: "users")
    editor = Repo.get_by!(Subject, ext_id: "editor")
    support = Repo.get_by!(Subject, ext_id: "support")
    scheduler = Repo.get_by!(Subject, ext_id: "scheduler")
    admin = Repo.get_by!(Subject, ext_id: "admin")

    assert Subject.parents(admin) |> Repo.all() == [scheduler, support, editor]

    assert Subject.ancestors(admin) |> Repo.all() == [
             supremum,
             scheduler,
             support,
             editor,
             users
           ]
  end

  test "registers a role as a object leaf node with the specified description" do
    users = Repo.get_by!(Object, ext_id: "users")
    assert users.description == "Users"
    editor = Repo.get_by!(Object, ext_id: "editor")
    assert editor.description == "Document editors"
    support = Repo.get_by!(Object, ext_id: "support")
    assert support.description == "Customer Support"
    scheduler = Repo.get_by!(Object, ext_id: "scheduler")
    assert scheduler.description == "Event Scheduler"
    admin = Repo.get_by!(Object, ext_id: "admin")
    assert admin.description == "Admin users"
  end

  # This test is known to be flakey, but I haven't been able to figure out how
  # to fix it.
  @tag :flakey
  test "KNOWN FLAKEY: init removes any static permissions, subjects, and objects that are no longer defined" do
    permission = register(Permission, "old", "Old", true)
    subject = register(Subject, "old", "Old", true)
    object = register(Object, "old", "Old", true)

    MacroTest.init()
    assert Repo.get_by(Permission, ext_id: permission.ext_id) == nil
    assert Repo.get_by(Subject, ext_id: subject.ext_id) == nil
    assert Repo.get_by(Object, ext_id: object.ext_id) == nil
  end

  test "makes role object a child/descendant of any implied objects" do
    supremum = Repo.get_by!(Object, ext_id: "*")
    users = Repo.get_by!(Object, ext_id: "users")
    editor = Repo.get_by!(Object, ext_id: "editor")
    support = Repo.get_by!(Object, ext_id: "support")
    scheduler = Repo.get_by!(Object, ext_id: "scheduler")
    admin = Repo.get_by!(Object, ext_id: "admin")

    assert Object.parents(admin) |> Repo.all() == [scheduler, support, editor]

    assert Object.ancestors(admin) |> Repo.all() == [
             supremum,
             scheduler,
             support,
             editor,
             users
           ]
  end

  test "creates positive grant authorization rules" do
    assert {"users", "documents", "read", :+} in MacroTest.list_rules("users", Subject)
    assert {"admin", "*", "*", :+} in MacroTest.list_rules("admin", Subject)
  end

  test "creates negative grant authorization rules" do
    assert {"scheduler", "articles", "read", :-} in MacroTest.list_rules("scheduler", Subject)
    assert {"no_access", "*", "*", :-} in MacroTest.list_rules("no_access", Subject)
  end

  test "removes static authorization rules that are no longer defined" do
    Authorizir.grant_permission(AuthorizirTest.Repo, "users", "articles", "edit", true)
    Authorizir.deny_permission(AuthorizirTest.Repo, "scheduler", "articles", "edit", true)
    assert {"users", "articles", "edit", :+} in MacroTest.list_rules("users", Subject)
    assert {"scheduler", "articles", "edit", :-} in MacroTest.list_rules("scheduler", Subject)
    MacroTest.init()
    refute {"users", "articles", "edit", :+} in MacroTest.list_rules("users", Subject)
    refute {"scheduler", "articles", "edit", :-} in MacroTest.list_rules("scheduler", Subject)
  end

  test "does not remove non-static authorization rules" do
    MacroTest.grant_permission("users", "articles", "edit")
    MacroTest.deny_permission("scheduler", "articles", "edit")
    assert {"users", "articles", "edit", :+} in MacroTest.list_rules("users", Subject)
    assert {"scheduler", "articles", "edit", :-} in MacroTest.list_rules("scheduler", Subject)
    MacroTest.init()
    assert {"users", "articles", "edit", :+} in MacroTest.list_rules("users", Subject)
    assert {"scheduler", "articles", "edit", :-} in MacroTest.list_rules("scheduler", Subject)
  end

  test "init does not remove static permissions, subjects, or objects that are still defined" do
    all =
      [Permission, Subject, Object]
      |> Enum.flat_map(fn type -> Repo.all(from(t in type, order_by: t.id)) end)

    MacroTest.init()

    assert Enum.flat_map([Permission, Subject, Object], fn type ->
             Repo.all(from(t in type, order_by: t.id))
           end) == all
  end

  # This test is known to be flakey, but I haven't been able to figure out how
  # to fix it.
  @tag :flakey
  test "KNOWN FLAKEY: init removes static children that are no longer set as children" do
    permission_delete = Repo.get_by!(Permission, ext_id: "delete")
    permission_foo = register(Permission, "foo", "foo", true)
    sub_editor = Repo.get_by!(Subject, ext_id: "editor")
    sub_foo = register(Subject, "foo", "foo", true)
    obj_editor = Repo.get_by!(Object, ext_id: "editor")
    obj_foo = register(Object, "foo", "foo", true)
    :ok = MacroTest.add_child(permission_foo.ext_id, permission_delete.ext_id, Permission)
    :ok = MacroTest.add_child(sub_foo.ext_id, sub_editor.ext_id, Subject)
    :ok = MacroTest.add_child(obj_foo.ext_id, obj_editor.ext_id, Object)
    assert permission_delete in (Permission.children(permission_foo) |> Repo.all())
    assert sub_editor in (Subject.children(sub_foo) |> Repo.all())
    assert obj_editor in (Object.children(obj_foo) |> Repo.all())
    MacroTest.init()

    assert Repo.get_by!(Subject, ext_id: "*") in Repo.all(
             Subject.parents(Repo.get_by!(Subject, ext_id: "users"))
           )

    refute permission_delete in (Permission.children(permission_foo) |> Repo.all())
    refute sub_editor in (Subject.children(sub_foo) |> Repo.all())
    refute obj_editor in (Object.children(obj_foo) |> Repo.all())
  end

  test "init does not remove non-static children" do
    permission_delete = Repo.get_by!(Permission, ext_id: "delete")
    permission_x = register(Permission, "x", "x", false)
    sub_editor = Repo.get_by!(Subject, ext_id: "editor")
    sub_x = register(Subject, "x", "x", false)
    obj_editor = Repo.get_by!(Object, ext_id: "editor")
    obj_x = register(Object, "x", "x", false)
    :ok = MacroTest.add_child(permission_delete.ext_id, permission_x.ext_id, Permission)
    :ok = MacroTest.add_child(sub_editor.ext_id, sub_x.ext_id, Subject)
    :ok = MacroTest.add_child(obj_editor.ext_id, obj_x.ext_id, Object)
    assert permission_x in (Permission.children(permission_delete) |> Repo.all())
    assert sub_x in (Subject.children(sub_editor) |> Repo.all())
    assert obj_x in (Object.children(obj_editor) |> Repo.all())
    MacroTest.init()
    assert permission_x in (Permission.children(permission_delete) |> Repo.all())
    assert sub_x in (Subject.children(sub_editor) |> Repo.all())
    assert obj_x in (Object.children(obj_editor) |> Repo.all())
  end
end
