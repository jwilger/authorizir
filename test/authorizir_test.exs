defmodule AuthorizirTest do
  use AuthorizirTest.DataCase

  alias AuthorizirTest.Repo

  alias Authorizir.{Object, Permission, Subject}
  alias Ecto.UUID

  defmodule Auth do
    @moduledoc false
    use Authorizir, repo: AuthorizirTest.Repo, application: :authorizir
  end

  setup do
    Auth.init()
  end

  defp register(Permission, id, desc) do
    :ok = Auth.register_permission(id, desc)
    Repo.get_by!(Permission, ext_id: id)
  end

  defp register(Subject, id, desc) do
    :ok = Auth.register_subject(id, desc)
    Repo.get_by!(Subject, ext_id: id)
  end

  defp register(Object, id, desc) do
    :ok = Auth.register_object(id, desc)
    Repo.get_by!(Object, ext_id: id)
  end

  describe "register_subject/2" do
    test "returns :ok if subject was successfully registered" do
      :ok = Auth.register_subject(UUID.generate(), "some description")
    end

    test "returns an error if id is nil or blank" do
      for id <- [nil, "", " "] do
        {:error, :id_is_required} = Auth.register_subject(id, "some description")
      end
    end

    test "returns an error if description is nil or blank" do
      for desc <- [nil, "", " "] do
        {:error, :description_is_required} = Auth.register_subject(UUID.generate(), desc)
      end
    end

    test "updates description if ext_id is the same and description is not" do
      ext_id = UUID.generate()
      :ok = Auth.register_subject(ext_id, "some description")
      :ok = Auth.register_subject(ext_id, "new description")
      %Subject{description: description} = Repo.get_by!(Subject, ext_id: ext_id)
      assert description == "new description"
    end

    test "new subject is a direct child of the subject supremum" do
      :ok = Auth.register_subject("foo", "bar")
      supremum = Repo.get_by!(Subject, ext_id: "*")
      foo = Repo.get_by!(Subject, ext_id: "foo")
      parents = Subject.parents(foo) |> Repo.all()
      assert parents == [supremum]
    end
  end

  describe "subjects_matching/1" do
    setup do
      :ok = Auth.register_subject(:grand_ancestor, "Grand Ancestor")
      :ok = Auth.register_subject(:ancestor, "Ancestor")
      :ok = Auth.register_subject(:ancestor2, "Ancestor 2")
      :ok = Auth.register_subject(:parent1, "Parent 1")
      :ok = Auth.register_subject(:parent2, "Parent 2")
      :ok = Auth.register_subject(:child1, "Child 1")
      :ok = Auth.register_subject(:child2, "Child 2")
      :ok = Auth.register_subject(:child3, "Child 2")
      :ok = Auth.add_child(:grand_ancestor, :ancestor, Subject)
      :ok = Auth.add_child(:grand_ancestor, :ancestor2, Subject)
      :ok = Auth.add_child(:ancestor, :parent1, Subject)
      :ok = Auth.add_child(:ancestor, :parent2, Subject)
      :ok = Auth.add_child(:parent1, :child1, Subject)
      :ok = Auth.add_child(:parent2, :child2, Subject)
      :ok = Auth.add_child(:grand_ancestor, :child3, Subject)
    end

    test "returns an empty list if no query terms are supplied" do
      assert Auth.subjects_matching([]) == []
    end

    test "returns a list of subject IDs for all subjects that are descendants of the specified subject" do
      assert Auth.subjects_matching(ancestor: :ancestor) == ~w(parent1 parent2 child1 child2)
    end

    test "returns a list of subject IDs for all subjects where the id matches the provided pattern" do
      assert Auth.subjects_matching(id: ".*ancestor$") == ~w(grand_ancestor ancestor)
    end

    test "returns a list of subject IDs that are descendants of the specified subject and where the id matches the provided pattern" do
      assert Auth.subjects_matching(ancestor: :ancestor, id: "^child") == ~w(child1 child2)
    end
  end

  describe "register_object/2" do
    test "returns :ok if object was successfully registered" do
      :ok = Auth.register_object(UUID.generate(), "some description")
    end

    test "returns an error if id is nil or blank" do
      for id <- [nil, "", " "] do
        {:error, :id_is_required} = Auth.register_object(id, "some description")
      end
    end

    test "returns an error if description is nil or blank" do
      for desc <- [nil, "", " "] do
        {:error, :description_is_required} = Auth.register_object(UUID.generate(), desc)
      end
    end

    test "updates description if ext_id is the same and description is not" do
      ext_id = UUID.generate()
      :ok = Auth.register_object(ext_id, "some description")
      :ok = Auth.register_object(ext_id, "new description")
      %Object{description: description} = Repo.get_by!(Object, ext_id: ext_id)
      assert description == "new description"
    end

    test "new object is a direct child of the object supremum" do
      :ok = Auth.register_object("foo", "bar")
      supremum = Repo.get_by!(Object, ext_id: "*")
      foo = Repo.get_by!(Object, ext_id: "foo")
      parents = Object.parents(foo) |> Repo.all()
      assert parents == [supremum]
    end
  end

  describe "register_permission/2" do
    test "returns :ok if permission was successfully registered" do
      :ok = Auth.register_permission(UUID.generate(), "some description")
    end

    test "returns an error if id is nil or blank" do
      for id <- [nil, "", " "] do
        {:error, :id_is_required} = Auth.register_permission(id, "some description")
      end
    end

    test "returns an error if description is nil or blank" do
      for desc <- [nil, "", " "] do
        {:error, :description_is_required} = Auth.register_permission(UUID.generate(), desc)
      end
    end

    test "updates description if ext_id is the same and description is not" do
      ext_id = UUID.generate()
      :ok = Auth.register_permission(ext_id, "some description")
      :ok = Auth.register_permission(ext_id, "new description")

      %Permission{description: description} = Repo.get_by!(Permission, ext_id: ext_id)

      assert description == "new description"
    end

    test "new permission is a direct child of the permission supremum" do
      :ok = Auth.register_permission("foo", "bar")
      supremum = Repo.get_by!(Permission, ext_id: "*")
      foo = Repo.get_by!(Permission, ext_id: "foo")
      parents = Permission.parents(foo) |> Repo.all()
      assert parents == [supremum]
    end
  end

  describe "grant_permission/3" do
    test "returns :ok if permission grant is successful" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.grant_permission(subject, object, permission)
    end

    test "operation is idempotent" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.grant_permission(subject, object, permission)
      :ok = Auth.grant_permission(subject, object, permission)
    end

    test "returns {:error, :invalid_subject} if subject ID has not been registered" do
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      {:error, :invalid_subject} = Auth.grant_permission(UUID.generate(), object, permission)
    end

    test "returns {:error, :invalid_object} if object ID has not been registered" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      {:error, :invalid_object} = Auth.grant_permission(subject, UUID.generate(), permission)
    end

    test "returns {:error, :invalid_permission} if permission ID has not been registered" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()

      {:error, :invalid_permission} = Auth.grant_permission(subject, object, UUID.generate())
    end

    test "returns {:error, :conflicting_rule_type} if the permission has already been explicitly denied for the given subject and object" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.deny_permission(subject, object, permission)

      {:error, :conflicting_rule_type} = Auth.grant_permission(subject, object, permission)
    end
  end

  describe "deny_permission/3" do
    test "returns :ok if permission denial is successful" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.deny_permission(subject, object, permission)
    end

    test "operation is idempotent" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.deny_permission(subject, object, permission)
      :ok = Auth.deny_permission(subject, object, permission)
    end

    test "returns {:error, :invalid_subject} if subject ID has not been registered" do
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      {:error, :invalid_subject} = Auth.deny_permission(UUID.generate(), object, permission)
    end

    test "returns {:error, :invalid_object} if object ID has not been registered" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      {:error, :invalid_object} = Auth.deny_permission(subject, UUID.generate(), permission)
    end

    test "returns {:error, :invalid_permission} if permission ID has not been registered" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()

      {:error, :invalid_permission} = Auth.deny_permission(subject, object, UUID.generate())
    end

    test "returns {:error, :conflicting_rule_type} if the permission has already been explicitly denied for the given subject and object" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new(UUID.generate(), "edit stuff") |> Repo.insert()

      :ok = Auth.grant_permission(subject, object, permission)

      {:error, :conflicting_rule_type} = Auth.deny_permission(subject, object, permission)
    end
  end

  describe "revoke_permission/3" do
    test "returns :ok if permission revoke is successful" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.grant_permission(subject, object, permission)
      :ok = Auth.revoke_permission(subject, object, permission)
    end

    test "operation is idempotent" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.grant_permission(subject, object, permission)
      :ok = Auth.revoke_permission(subject, object, permission)
      :ok = Auth.revoke_permission(subject, object, permission)
    end

    test "returns {:error, :invalid_subject} if subject ID has not been registered" do
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      {:error, :invalid_subject} = Auth.revoke_permission(UUID.generate(), object, permission)
    end

    test "returns {:error, :invalid_object} if object ID has not been registered" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      {:error, :invalid_object} = Auth.revoke_permission(subject, UUID.generate(), permission)
    end

    test "returns {:error, :invalid_permission} if permission ID has not been registered" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()

      {:error, :invalid_permission} = Auth.revoke_permission(subject, object, UUID.generate())
    end
  end

  describe "allow_permission/3" do
    test "returns :ok if permission allow is successful" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.deny_permission(subject, object, permission)
      :ok = Auth.allow_permission(subject, object, permission)
    end

    test "operation is idempotent" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.deny_permission(subject, object, permission)
      :ok = Auth.allow_permission(subject, object, permission)
      :ok = Auth.allow_permission(subject, object, permission)
    end

    test "returns {:error, :invalid_subject} if subject ID has not been registered" do
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      {:error, :invalid_subject} = Auth.allow_permission(UUID.generate(), object, permission)
    end

    test "returns {:error, :invalid_object} if object ID has not been registered" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      {:error, :invalid_object} = Auth.allow_permission(subject, UUID.generate(), permission)
    end

    test "returns {:error, :invalid_permission} if permission ID has not been registered" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()

      {:error, :invalid_permission} = Auth.allow_permission(subject, object, UUID.generate())
    end
  end

  describe "add_child/3" do
    test "returns {:error, :invalid_parent} when parent id not registered as specified type" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()

      {:error, :invalid_parent} = Auth.add_child(UUID.generate(), subject, Subject)
    end

    test "returns {:error, :invalid_child} when child id not registered as specified type" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()

      {:error, :invalid_child} = Auth.add_child(subject, UUID.generate(), Subject)
    end

    test "returns :ok when relationship is created" do
      {:ok, subject_a} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, subject_b} = Subject.new(UUID.generate(), "Subject B") |> Repo.insert()

      :ok = Auth.add_child(subject_a, subject_b, Subject)
    end

    test "creates Dagex parent/child association" do
      {:ok, subject_a} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, subject_b} = Subject.new(UUID.generate(), "Subject B") |> Repo.insert()

      :ok = Auth.add_child(subject_a, subject_b, Subject)

      assert subject_a in (Subject.parents(subject_b) |> Repo.all())
    end

    test "returns Dagex error if edge cannot be created" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()

      {:error, :cyclic_edge} = Auth.add_child(subject, subject, Subject)
    end

    test "can add child subjects with the :subject key" do
      {:ok, subject_a} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, subject_b} = Subject.new(UUID.generate(), "Subject B") |> Repo.insert()

      :ok = Auth.add_child(subject_a, subject_b, :subject)

      assert subject_a in (Subject.parents(subject_b) |> Repo.all())
    end

    test "can add child objects with the :object key" do
      {:ok, object_a} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, object_b} = Object.new(UUID.generate(), "Object B") |> Repo.insert()

      :ok = Auth.add_child(object_a, object_b, :object)

      assert object_a in (Object.parents(object_b) |> Repo.all())
    end

    test "can add child permissions with the :permission key" do
      {:ok, permission_a} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      {:ok, permission_b} = Permission.new(UUID.generate(), "Permission B") |> Repo.insert()

      :ok = Auth.add_child(permission_a, permission_b, :permission)

      assert permission_a in (Permission.parents(permission_b) |> Repo.all())
    end
  end

  describe "remove_child/3" do
    test "returns {:error, :invalid_parent} when parent id not registered as specified type" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()

      {:error, :invalid_parent} = Auth.remove_child(UUID.generate(), subject, Subject)
    end

    test "returns {:error, :invalid_child} when child id not registered as specified type" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()

      {:error, :invalid_child} = Auth.remove_child(subject, UUID.generate(), Subject)
    end

    test "returns :ok when relationship is removed" do
      subject_a = register(Subject, UUID.generate(), "Subject A")
      subject_b = register(Subject, UUID.generate(), "Subject B")

      :ok = Auth.add_child(subject_a, subject_b, Subject)
      :ok = Auth.remove_child(subject_a, subject_b, Subject)
    end

    test "can remove child using :subject key" do
      subject_a = register(Subject, UUID.generate(), "Subject A")
      subject_b = register(Subject, UUID.generate(), "Subject B")

      :ok = Auth.add_child(subject_a, subject_b, Subject)
      :ok = Auth.remove_child(subject_a, subject_b, :subject)
    end

    test "can remove child using :object key" do
      object_a = register(Object, UUID.generate(), "Object A")
      object_b = register(Object, UUID.generate(), "Object B")

      :ok = Auth.add_child(object_a, object_b, Object)
      :ok = Auth.remove_child(object_a, object_b, :object)
    end

    test "can remove child using :permission key" do
      permission_a = register(Permission, UUID.generate(), "Permission A")
      permission_b = register(Permission, UUID.generate(), "Permission B")

      :ok = Auth.add_child(permission_a, permission_b, Permission)
      :ok = Auth.remove_child(permission_a, permission_b, :permission)
    end

    test "removes Dagex parent/child association" do
      subject_a = register(Subject, UUID.generate(), "Subject A")
      subject_b = register(Subject, UUID.generate(), "Subject B")

      :ok = Auth.add_child(subject_a, subject_b, Subject)
      :ok = Auth.remove_child(subject_a, subject_b, Subject)

      refute subject_a in (Subject.parents(subject_b) |> Repo.all())
    end
  end

  describe "permission_granted?/3" do
    test "raises if subject ID has not been registered" do
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()
      id = UUID.generate()

      assert_raise Authorizir.AuthorizationError, "invalid subject: #{id}", fn ->
        Auth.permission_granted?(id, object, permission)
      end
    end

    test "raises if object ID has not been registered" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()
      id = UUID.generate()

      assert_raise Authorizir.AuthorizationError, "invalid object: #{id}", fn ->
        Auth.permission_granted?(subject, id, permission)
      end
    end

    test "raises if permission ID has not been registered" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      id = UUID.generate()

      assert_raise Authorizir.AuthorizationError, "invalid permission: #{id}", fn ->
        Auth.permission_granted?(subject, object, id)
      end
    end

    test "returns false when no authorization rules exist that can affect the given sop" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      refute Auth.permission_granted?(subject, object, permission)
    end

    test "returns false when negative grant rule is applied to the sop" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()
      :ok = Auth.deny_permission(subject, object, permission)

      refute Auth.permission_granted?(subject, object, permission)
    end

    test "returns false when negative grant rule is applied to the sop via subject ancestors" do
      {:ok, subject_a} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, subject_p} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      :ok = Auth.add_child(subject_a, subject_p, Subject)
      :ok = Auth.add_child(subject_p, subject, Subject)
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()
      :ok = Auth.deny_permission(subject_a, object, permission)

      refute Auth.permission_granted?(subject, object, permission)
    end

    test "returns false when negative grant rule is applied to the sop via object ancestors" do
      {:ok, object_a} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, object_p} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      :ok = Auth.add_child(object_a, object_p, Object)
      :ok = Auth.add_child(object_p, object, Object)
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()
      :ok = Auth.deny_permission(subject, object_a, permission)

      refute Auth.permission_granted?(subject, object, permission)
    end

    test "returns false when negative grant rule is applied to the sop via permission descendants" do
      {:ok, permission_a} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      {:ok, permission_p} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      {:ok, permission} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      :ok = Auth.add_child(permission_a, permission_p, Permission)
      :ok = Auth.add_child(permission_p, permission, Permission)
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new("edit", "edit stuff") |> Repo.insert()
      :ok = Auth.deny_permission(subject, object, permission)

      refute Auth.permission_granted?(subject, object, permission_a)
    end

    test "returns false when negative grant rule is applied to the sop via permission supremum" do
      supremum = Repo.get_by!(Permission, ext_id: "*")
      {:ok, permission_a} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      {:ok, permission_p} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      {:ok, permission} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      :ok = Auth.add_child(supremum, permission_a, Permission)
      :ok = Auth.add_child(permission_a, permission_p, Permission)
      :ok = Auth.add_child(permission_p, permission, Permission)
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new("edit", "edit stuff") |> Repo.insert()
      :ok = Auth.deny_permission(subject, object, "*")

      refute Auth.permission_granted?(subject, object, permission_a)
      refute Auth.permission_granted?(subject, object, permission_p)
      refute Auth.permission_granted?(subject, object, permission)
    end

    test "returns false when negative grant rule is applied to the sop via subject ancestors despite more specific positive grant" do
      {:ok, subject_a} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, subject_p} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      :ok = Auth.add_child(subject_a, subject_p, Subject)
      :ok = Auth.add_child(subject_p, subject, Subject)
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()
      :ok = Auth.deny_permission(subject_a, object, permission)
      :ok = Auth.grant_permission(subject, object, permission)

      refute Auth.permission_granted?(subject, object, permission)
    end

    test "returns false when negative grant rule is applied to the sop via object ancestors despite more specific positive grant" do
      {:ok, object_a} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, object_p} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      :ok = Auth.add_child(object_a, object_p, Object)
      :ok = Auth.add_child(object_p, object, Object)
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()
      :ok = Auth.deny_permission(subject, object_a, permission)
      :ok = Auth.grant_permission(subject, object, permission)

      refute Auth.permission_granted?(subject, object, permission)
    end

    test "returns false when negative grant rule is applied to the sop via permission descendants despite more specific positive grant" do
      {:ok, permission_a} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      {:ok, permission_p} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      {:ok, permission} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      :ok = Auth.add_child(permission_a, permission_p, Permission)
      :ok = Auth.add_child(permission_p, permission, Permission)
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new("edit", "edit stuff") |> Repo.insert()
      :ok = Auth.deny_permission(subject, object, permission)
      :ok = Auth.grant_permission(subject, object, permission_a)

      refute Auth.permission_granted?(subject, object, permission_a)
    end

    test "returns false when negative grant rule is applied to the sop via permission supremum despite more specific positive grant" do
      supremum = Repo.get_by!(Permission, ext_id: "*")
      {:ok, permission_a} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      {:ok, permission_p} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      {:ok, permission} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      :ok = Auth.add_child(supremum, permission_a, Permission)
      :ok = Auth.add_child(permission_a, permission_p, Permission)
      :ok = Auth.add_child(permission_p, permission, Permission)
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new("edit", "edit stuff") |> Repo.insert()
      :ok = Auth.deny_permission(subject, object, "*")
      :ok = Auth.grant_permission(subject, object, permission_a)

      refute Auth.permission_granted?(subject, object, permission_a)
    end

    test "returns true when positive grant rule is applied to the sop" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()
      :ok = Auth.grant_permission(subject, object, permission)

      assert Auth.permission_granted?(subject, object, permission)
    end

    test "returns true when positive grant rule is applied to the sop via subject ancestors" do
      {:ok, subject_a} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, subject_p} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      :ok = Auth.add_child(subject_a, subject_p, Subject)
      :ok = Auth.add_child(subject_p, subject, Subject)
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()
      :ok = Auth.grant_permission(subject_a, object, permission)

      assert Auth.permission_granted?(subject, object, permission)
    end

    test "returns true when positive grant rule is applied to the sop via object ancestors" do
      {:ok, object_a} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, object_p} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      :ok = Auth.add_child(object_a, object_p, Object)
      :ok = Auth.add_child(object_p, object, Object)
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()
      :ok = Auth.grant_permission(subject, object_a, permission)

      assert Auth.permission_granted?(subject, object, permission)
    end

    test "returns true when positive grant rule is applied to the sop via permission ancestors" do
      {:ok, permission_a} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      {:ok, permission_p} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      {:ok, permission} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      :ok = Auth.add_child(permission_a, permission_p, Permission)
      :ok = Auth.add_child(permission_p, permission, Permission)
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new("edit", "edit stuff") |> Repo.insert()
      :ok = Auth.grant_permission(subject, object, permission_a)

      assert Auth.permission_granted?(subject, object, permission)
    end

    test "returns true when negative grant rule is applied to subject descendants" do
      {:ok, subject_a} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, subject_p} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      :ok = Auth.add_child(subject_a, subject_p, Subject)
      :ok = Auth.add_child(subject_p, subject, Subject)
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()
      :ok = Auth.grant_permission(subject_a, object, permission)
      :ok = Auth.deny_permission(subject, object, permission)

      assert Auth.permission_granted?(subject_a, object, permission)
    end

    test "returns true when negative grant rule is applied to object descendants" do
      {:ok, object_a} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, object_p} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      :ok = Auth.add_child(object_a, object_p, Object)
      :ok = Auth.add_child(object_p, object, Object)
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()
      :ok = Auth.grant_permission(subject, object_a, permission)
      :ok = Auth.deny_permission(subject, object, permission)

      assert Auth.permission_granted?(subject, object_a, permission)
    end

    test "returns true when negative grant rule is applied to permission ancestors" do
      {:ok, permission_a} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      {:ok, permission_p} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      {:ok, permission} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      :ok = Auth.add_child(permission_a, permission_p, Permission)
      :ok = Auth.add_child(permission_p, permission, Permission)
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new("edit", "edit stuff") |> Repo.insert()
      :ok = Auth.deny_permission(subject, object, permission_a)
      :ok = Auth.grant_permission(subject, object, permission)

      assert Auth.permission_granted?(subject, object, permission)
    end
  end

  describe "list_rules/3" do
    test "list rules defined for the given subject/object" do
      subject_a = Subject.new(UUID.generate(), "Sub A") |> Repo.insert!()
      subject_b = Subject.new(UUID.generate(), "Sub B") |> Repo.insert!()
      :ok = Auth.add_child(subject_a, subject_b, Subject)

      object_a = Object.new(UUID.generate(), "Obj A") |> Repo.insert!()
      object_b = Object.new(UUID.generate(), "Obj B") |> Repo.insert!()
      :ok = Auth.add_child(object_a, object_b, Object)

      permission_a = Permission.new("foo", "Foo") |> Repo.insert!()
      permission_b = Permission.new("bar", "Bar") |> Repo.insert!()
      :ok = Auth.add_child(permission_a, permission_b, Permission)

      :ok = Auth.grant_permission(subject_a, object_a, "foo")
      :ok = Auth.grant_permission(subject_b, object_b, "foo")
      :ok = Auth.deny_permission(subject_a, object_a, "bar")
      :ok = Auth.deny_permission(subject_b, object_b, "bar")

      assert Auth.list_rules(subject_b, Subject) == [
               {subject_b.ext_id, object_b.ext_id, "bar", :-},
               {subject_b.ext_id, object_b.ext_id, "foo", :+}
             ]

      assert Auth.list_rules(object_b, Object) == [
               {subject_b.ext_id, object_b.ext_id, "bar", :-},
               {subject_b.ext_id, object_b.ext_id, "foo", :+}
             ]
    end
  end

  describe "to_ext_id/1" do
    test "attempts to conver the value to an ext_id using Authorizir.ToAuthorizirId protocol" do
      assert Auth.to_ext_id(%Subject{ext_id: "foo"}) == "foo"
    end
  end
end
