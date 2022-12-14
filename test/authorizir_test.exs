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

  describe "subject_members/1" do
    test "returns an error if the subject does not exist" do
      assert Auth.subject_members("no_such_subject") == {:error, :not_found}
    end

    test "returns an empty list if the subject has no children" do
      :ok = Auth.register_subject("foo", "bar")
      assert Auth.subject_members("foo") == {:ok, []}
    end

    test "returns a list of all descendants of the subject" do
      :ok = Auth.register_subject("foo", "bar")
      :ok = Auth.register_subject("baz", "bam")
      :ok = Auth.register_subject("ham", "spam")
      :ok = Auth.add_child("foo", "baz", Subject)
      :ok = Auth.add_child("baz", "ham", Subject)
      assert Auth.subject_members("foo") == {:ok, ["baz", "ham"]}
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

  describe "object_members/1" do
    test "returns an error if the object does not exist" do
      assert Auth.object_members("no_such_object") == {:error, :not_found}
    end

    test "returns an empty list if the object has no children" do
      :ok = Auth.register_object("foo", "bar")
      assert Auth.object_members("foo") == {:ok, []}
    end

    test "returns a list of all descendants of the object" do
      :ok = Auth.register_object("foo", "bar")
      :ok = Auth.register_object("baz", "bam")
      :ok = Auth.register_object("ham", "spam")
      :ok = Auth.add_child("foo", "baz", Object)
      :ok = Auth.add_child("baz", "ham", Object)
      assert Auth.object_members("foo") == {:ok, ["baz", "ham"]}
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

  describe "permission_members/1" do
    test "returns an error if the permission does not exist" do
      assert Auth.permission_members("no_such_permission") == {:error, :not_found}
    end

    test "returns an empty list if the permission has no children" do
      :ok = Auth.register_permission("foo", "bar")
      assert Auth.permission_members("foo") == {:ok, []}
    end

    test "returns a list of all descendants of the permission" do
      :ok = Auth.register_permission("foo", "bar")
      :ok = Auth.register_permission("baz", "bam")
      :ok = Auth.register_permission("ham", "spam")
      :ok = Auth.add_child("foo", "baz", Permission)
      :ok = Auth.add_child("baz", "ham", Permission)
      assert Auth.permission_members("foo") == {:ok, ["baz", "ham"]}
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

    test "removes Dagex parent/child association" do
      subject_a = register(Subject, UUID.generate(), "Subject A")
      subject_b = register(Subject, UUID.generate(), "Subject B")

      :ok = Auth.add_child(subject_a, subject_b, Subject)
      :ok = Auth.remove_child(subject_a, subject_b, Subject)

      refute subject_a in (Subject.parents(subject_b) |> Repo.all())
    end
  end

  describe "permission_granted?/3" do
    test "returns {:error, :invalid_subject} if subject ID has not been registered" do
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      {:error, :invalid_subject} = Auth.permission_granted?(UUID.generate(), object, permission)
    end

    test "returns {:error, :invalid_object} if object ID has not been registered" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      {:error, :invalid_object} = Auth.permission_granted?(subject, UUID.generate(), permission)
    end

    test "returns {:error, :invalid_permission} if permission ID has not been registered" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()

      {:error, :invalid_permission} = Auth.permission_granted?(subject, object, UUID.generate())
    end

    test "returns :denied when no authorization rules exist that can affect the given sop" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :denied = Auth.permission_granted?(subject, object, permission)
    end

    test "returns :denied when negative grant rule is applied to the sop" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.deny_permission(subject, object, permission)

      :denied = Auth.permission_granted?(subject, object, permission)
    end

    test "returns :denied when negative grant rule is applied to the sop via subject ancestors" do
      {:ok, subject_a} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, subject_p} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      :ok = Auth.add_child(subject_a, subject_p, Subject)
      :ok = Auth.add_child(subject_p, subject, Subject)

      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.deny_permission(subject_a, object, permission)

      :denied = Auth.permission_granted?(subject, object, permission)
    end

    test "returns :denied when negative grant rule is applied to the sop via object ancestors" do
      {:ok, object_a} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, object_p} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      :ok = Auth.add_child(object_a, object_p, Object)
      :ok = Auth.add_child(object_p, object, Object)

      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.deny_permission(subject, object_a, permission)

      :denied = Auth.permission_granted?(subject, object, permission)
    end

    test "returns :denied when negative grant rule is applied to the sop via permission descendants" do
      {:ok, permission_a} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      {:ok, permission_p} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      {:ok, permission} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      :ok = Auth.add_child(permission_a, permission_p, Permission)
      :ok = Auth.add_child(permission_p, permission, Permission)

      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.deny_permission(subject, object, permission)

      :denied = Auth.permission_granted?(subject, object, permission_a)
    end

    test "returns :denied when negative grant rule is applied to the sop via permission supremum" do
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

      :denied = Auth.permission_granted?(subject, object, permission_a)
      :denied = Auth.permission_granted?(subject, object, permission_p)
      :denied = Auth.permission_granted?(subject, object, permission)
    end

    test "returns :denied when negative grant rule is applied to the sop via subject ancestors despite more specific positive grant" do
      {:ok, subject_a} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, subject_p} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      :ok = Auth.add_child(subject_a, subject_p, Subject)
      :ok = Auth.add_child(subject_p, subject, Subject)

      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.deny_permission(subject_a, object, permission)
      :ok = Auth.grant_permission(subject, object, permission)

      :denied = Auth.permission_granted?(subject, object, permission)
    end

    test "returns :denied when negative grant rule is applied to the sop via object ancestors despite more specific positive grant" do
      {:ok, object_a} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, object_p} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      :ok = Auth.add_child(object_a, object_p, Object)
      :ok = Auth.add_child(object_p, object, Object)

      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.deny_permission(subject, object_a, permission)
      :ok = Auth.grant_permission(subject, object, permission)

      :denied = Auth.permission_granted?(subject, object, permission)
    end

    test "returns :denied when negative grant rule is applied to the sop via permission descendants despite more specific positive grant" do
      {:ok, permission_a} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      {:ok, permission_p} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      {:ok, permission} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      :ok = Auth.add_child(permission_a, permission_p, Permission)
      :ok = Auth.add_child(permission_p, permission, Permission)

      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.deny_permission(subject, object, permission)
      :ok = Auth.grant_permission(subject, object, permission_a)

      :denied = Auth.permission_granted?(subject, object, permission_a)
    end

    test "returns :denied when negative grant rule is applied to the sop via permission supremum despite more specific positive grant" do
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

      :denied = Auth.permission_granted?(subject, object, permission_a)
    end

    ################
    ################

    test "returns :granted when positive grant rule is applied to the sop" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.grant_permission(subject, object, permission)

      :granted = Auth.permission_granted?(subject, object, permission)
    end

    test "returns :granted when positive grant rule is applied to the sop via subject ancestors" do
      {:ok, subject_a} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, subject_p} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      :ok = Auth.add_child(subject_a, subject_p, Subject)
      :ok = Auth.add_child(subject_p, subject, Subject)

      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.grant_permission(subject_a, object, permission)

      :granted = Auth.permission_granted?(subject, object, permission)
    end

    test "returns :granted when positive grant rule is applied to the sop via object ancestors" do
      {:ok, object_a} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, object_p} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      :ok = Auth.add_child(object_a, object_p, Object)
      :ok = Auth.add_child(object_p, object, Object)

      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.grant_permission(subject, object_a, permission)

      :granted = Auth.permission_granted?(subject, object, permission)
    end

    test "returns :granted when positive grant rule is applied to the sop via permission ancestors" do
      {:ok, permission_a} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      {:ok, permission_p} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      {:ok, permission} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      :ok = Auth.add_child(permission_a, permission_p, Permission)
      :ok = Auth.add_child(permission_p, permission, Permission)

      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.grant_permission(subject, object, permission_a)

      :granted = Auth.permission_granted?(subject, object, permission)
    end

    test "returns :granted when negative grant rule is applied to subject descendants" do
      {:ok, subject_a} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, subject_p} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      :ok = Auth.add_child(subject_a, subject_p, Subject)
      :ok = Auth.add_child(subject_p, subject, Subject)

      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.grant_permission(subject_a, object, permission)
      :ok = Auth.deny_permission(subject, object, permission)

      :granted = Auth.permission_granted?(subject_a, object, permission)
    end

    test "returns :granted when negative grant rule is applied to object descendants" do
      {:ok, object_a} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, object_p} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      :ok = Auth.add_child(object_a, object_p, Object)
      :ok = Auth.add_child(object_p, object, Object)

      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.grant_permission(subject, object_a, permission)
      :ok = Auth.deny_permission(subject, object, permission)

      :granted = Auth.permission_granted?(subject, object_a, permission)
    end

    test "returns :granted when negative grant rule is applied to permission ancestors" do
      {:ok, permission_a} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      {:ok, permission_p} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      {:ok, permission} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      :ok = Auth.add_child(permission_a, permission_p, Permission)
      :ok = Auth.add_child(permission_p, permission, Permission)

      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.deny_permission(subject, object, permission_a)
      :ok = Auth.grant_permission(subject, object, permission)

      :granted = Auth.permission_granted?(subject, object, permission)
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
end
