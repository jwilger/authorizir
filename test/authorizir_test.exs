defmodule AuthorizirTest do
  use ExUnit.Case, async: true

  alias Authorizir.{Object, Permission, Subject}
  alias AuthorizirTest.Repo
  alias Ecto.Adapters.SQL.Sandbox
  alias Ecto.UUID

  defmodule Auth do
    @moduledoc false
    use Authorizir, repo: AuthorizirTest.Repo
  end

  setup do
    :ok = Sandbox.checkout(Repo)
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
  end

  describe "grant_permission/3" do
    test "returns :ok if permission grant is successful" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.grant_permission(subject.ext_id, object.ext_id, permission.ext_id)
    end

    test "operation is idempotent" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.grant_permission(subject.ext_id, object.ext_id, permission.ext_id)
      :ok = Auth.grant_permission(subject.ext_id, object.ext_id, permission.ext_id)
    end

    test "returns {:error, :invalid_subject} if subject ID has not been registered" do
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      {:error, :invalid_subject} =
        Auth.grant_permission(UUID.generate(), object.ext_id, permission.ext_id)
    end

    test "returns {:error, :invalid_object} if object ID has not been registered" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      {:error, :invalid_object} =
        Auth.grant_permission(subject.ext_id, UUID.generate(), permission.ext_id)
    end

    test "returns {:error, :invalid_permission} if permission ID has not been registered" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()

      {:error, :invalid_permission} =
        Auth.grant_permission(subject.ext_id, object.ext_id, UUID.generate())
    end

    test "returns {:error, :conflicting_rule_type} if the permission has already been explicitly denied for the given subject and object" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.deny_permission(subject.ext_id, object.ext_id, permission.ext_id)

      {:error, :conflicting_rule_type} =
        Auth.grant_permission(subject.ext_id, object.ext_id, permission.ext_id)
    end
  end

  describe "deny_permission/3" do
    test "returns :ok if permission denial is successful" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.deny_permission(subject.ext_id, object.ext_id, permission.ext_id)
    end

    test "operation is idempotent" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.deny_permission(subject.ext_id, object.ext_id, permission.ext_id)
      :ok = Auth.deny_permission(subject.ext_id, object.ext_id, permission.ext_id)
    end

    test "returns {:error, :invalid_subject} if subject ID has not been registered" do
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      {:error, :invalid_subject} =
        Auth.deny_permission(UUID.generate(), object.ext_id, permission.ext_id)
    end

    test "returns {:error, :invalid_object} if object ID has not been registered" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      {:error, :invalid_object} =
        Auth.deny_permission(subject.ext_id, UUID.generate(), permission.ext_id)
    end

    test "returns {:error, :invalid_permission} if permission ID has not been registered" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()

      {:error, :invalid_permission} =
        Auth.deny_permission(subject.ext_id, object.ext_id, UUID.generate())
    end

    test "returns {:error, :conflicting_rule_type} if the permission has already been explicitly denied for the given subject and object" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.grant_permission(subject.ext_id, object.ext_id, permission.ext_id)

      {:error, :conflicting_rule_type} =
        Auth.deny_permission(subject.ext_id, object.ext_id, permission.ext_id)
    end
  end

  describe "revoke_permission/3" do
    test "returns :ok if permission revoke is successful" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.grant_permission(subject.ext_id, object.ext_id, permission.ext_id)
      :ok = Auth.revoke_permission(subject.ext_id, object.ext_id, permission.ext_id)
    end

    test "operation is idempotent" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.grant_permission(subject.ext_id, object.ext_id, permission.ext_id)
      :ok = Auth.revoke_permission(subject.ext_id, object.ext_id, permission.ext_id)
      :ok = Auth.revoke_permission(subject.ext_id, object.ext_id, permission.ext_id)
    end

    test "returns {:error, :invalid_subject} if subject ID has not been registered" do
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      {:error, :invalid_subject} =
        Auth.revoke_permission(UUID.generate(), object.ext_id, permission.ext_id)
    end

    test "returns {:error, :invalid_object} if object ID has not been registered" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      {:error, :invalid_object} =
        Auth.revoke_permission(subject.ext_id, UUID.generate(), permission.ext_id)
    end

    test "returns {:error, :invalid_permission} if permission ID has not been registered" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()

      {:error, :invalid_permission} =
        Auth.revoke_permission(subject.ext_id, object.ext_id, UUID.generate())
    end
  end

  describe "allow_permission/3" do
    test "returns :ok if permission allow is successful" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.deny_permission(subject.ext_id, object.ext_id, permission.ext_id)
      :ok = Auth.allow_permission(subject.ext_id, object.ext_id, permission.ext_id)
    end

    test "operation is idempotent" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.deny_permission(subject.ext_id, object.ext_id, permission.ext_id)
      :ok = Auth.allow_permission(subject.ext_id, object.ext_id, permission.ext_id)
      :ok = Auth.allow_permission(subject.ext_id, object.ext_id, permission.ext_id)
    end

    test "returns {:error, :invalid_subject} if subject ID has not been registered" do
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      {:error, :invalid_subject} =
        Auth.allow_permission(UUID.generate(), object.ext_id, permission.ext_id)
    end

    test "returns {:error, :invalid_object} if object ID has not been registered" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      {:error, :invalid_object} =
        Auth.allow_permission(subject.ext_id, UUID.generate(), permission.ext_id)
    end

    test "returns {:error, :invalid_permission} if permission ID has not been registered" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()

      {:error, :invalid_permission} =
        Auth.allow_permission(subject.ext_id, object.ext_id, UUID.generate())
    end
  end

  describe "add_child/3" do
    test "returns {:error, :invalid_parent} when parent id not registered as specified type" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()

      {:error, :invalid_parent} = Auth.add_child(UUID.generate(), subject.ext_id, Subject)
    end

    test "returns {:error, :invalid_child} when child id not registered as specified type" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()

      {:error, :invalid_child} = Auth.add_child(subject.ext_id, UUID.generate(), Subject)
    end

    test "returns :ok when relationship is created" do
      {:ok, subject_a} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, subject_b} = Subject.new(UUID.generate(), "Subject B") |> Repo.insert()

      :ok = Auth.add_child(subject_a.ext_id, subject_b.ext_id, Subject)
    end

    test "creates Dagex parent/child association" do
      {:ok, subject_a} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, subject_b} = Subject.new(UUID.generate(), "Subject B") |> Repo.insert()

      :ok = Auth.add_child(subject_a.ext_id, subject_b.ext_id, Subject)

      assert subject_a in (Subject.parents(subject_b) |> Repo.all())
    end

    test "returns Dagex error if edge cannot be created" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()

      {:error, :cyclic_edge} = Auth.add_child(subject.ext_id, subject.ext_id, Subject)
    end
  end

  describe "remove_child/3" do
    test "returns {:error, :invalid_parent} when parent id not registered as specified type" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()

      {:error, :invalid_parent} = Auth.remove_child(UUID.generate(), subject.ext_id, Subject)
    end

    test "returns {:error, :invalid_child} when child id not registered as specified type" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()

      {:error, :invalid_child} = Auth.remove_child(subject.ext_id, UUID.generate(), Subject)
    end

    test "returns :ok when relationship is removed" do
      {:ok, subject_a} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, subject_b} = Subject.new(UUID.generate(), "Subject B") |> Repo.insert()

      :ok = Auth.add_child(subject_a.ext_id, subject_b.ext_id, Subject)
      :ok = Auth.remove_child(subject_a.ext_id, subject_b.ext_id, Subject)
    end

    test "removes Dagex parent/child association" do
      {:ok, subject_a} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, subject_b} = Subject.new(UUID.generate(), "Subject B") |> Repo.insert()

      :ok = Auth.add_child(subject_a.ext_id, subject_b.ext_id, Subject)
      :ok = Auth.remove_child(subject_a.ext_id, subject_b.ext_id, Subject)

      refute subject_a in (Subject.parents(subject_b) |> Repo.all())
    end
  end

  describe "permission_granted?/3" do
    test "returns {:error, :invalid_subject} if subject ID has not been registered" do
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      {:error, :invalid_subject} =
        Auth.permission_granted?(UUID.generate(), object.ext_id, permission.ext_id)
    end

    test "returns {:error, :invalid_object} if object ID has not been registered" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      {:error, :invalid_object} =
        Auth.permission_granted?(subject.ext_id, UUID.generate(), permission.ext_id)
    end

    test "returns {:error, :invalid_permission} if permission ID has not been registered" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()

      {:error, :invalid_permission} =
        Auth.permission_granted?(subject.ext_id, object.ext_id, UUID.generate())
    end

    test "returns :denied when no authorization rules exist that can affect the given sop" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :denied = Auth.permission_granted?(subject.ext_id, object.ext_id, permission.ext_id)
    end

    test "returns :denied when negative grant rule is applied to the sop" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.deny_permission(subject.ext_id, object.ext_id, permission.ext_id)

      :denied = Auth.permission_granted?(subject.ext_id, object.ext_id, permission.ext_id)
    end

    test "returns :denied when negative grant rule is applied to the sop via subject ancestors" do
      {:ok, subject_a} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, subject_p} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      :ok = Auth.add_child(subject_a.ext_id, subject_p.ext_id, Subject)
      :ok = Auth.add_child(subject_p.ext_id, subject.ext_id, Subject)

      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.deny_permission(subject_a.ext_id, object.ext_id, permission.ext_id)

      :denied = Auth.permission_granted?(subject.ext_id, object.ext_id, permission.ext_id)
    end

    test "returns :denied when negative grant rule is applied to the sop via object ancestors" do
      {:ok, object_a} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, object_p} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      :ok = Auth.add_child(object_a.ext_id, object_p.ext_id, Object)
      :ok = Auth.add_child(object_p.ext_id, object.ext_id, Object)

      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.deny_permission(subject.ext_id, object_a.ext_id, permission.ext_id)

      :denied = Auth.permission_granted?(subject.ext_id, object.ext_id, permission.ext_id)
    end

    test "returns :denied when negative grant rule is applied to the sop via permission descendants" do
      {:ok, permission_a} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      {:ok, permission_p} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      {:ok, permission} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      :ok = Auth.add_child(permission_a.ext_id, permission_p.ext_id, Permission)
      :ok = Auth.add_child(permission_p.ext_id, permission.ext_id, Permission)

      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.deny_permission(subject.ext_id, object.ext_id, permission.ext_id)

      :denied = Auth.permission_granted?(subject.ext_id, object.ext_id, permission_a.ext_id)
    end

    test "returns :denied when negative grant rule is applied to the sop via subject ancestors despite more specific positive grant" do
      {:ok, subject_a} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, subject_p} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      :ok = Auth.add_child(subject_a.ext_id, subject_p.ext_id, Subject)
      :ok = Auth.add_child(subject_p.ext_id, subject.ext_id, Subject)

      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.deny_permission(subject_a.ext_id, object.ext_id, permission.ext_id)
      :ok = Auth.grant_permission(subject.ext_id, object.ext_id, permission.ext_id)

      :denied = Auth.permission_granted?(subject.ext_id, object.ext_id, permission.ext_id)
    end

    test "returns :denied when negative grant rule is applied to the sop via object ancestors despite more specific positive grant" do
      {:ok, object_a} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, object_p} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      :ok = Auth.add_child(object_a.ext_id, object_p.ext_id, Object)
      :ok = Auth.add_child(object_p.ext_id, object.ext_id, Object)

      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.deny_permission(subject.ext_id, object_a.ext_id, permission.ext_id)
      :ok = Auth.grant_permission(subject.ext_id, object.ext_id, permission.ext_id)

      :denied = Auth.permission_granted?(subject.ext_id, object.ext_id, permission.ext_id)
    end

    test "returns :denied when negative grant rule is applied to the sop via permission descendants despite more specific positive grant" do
      {:ok, permission_a} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      {:ok, permission_p} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      {:ok, permission} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      :ok = Auth.add_child(permission_a.ext_id, permission_p.ext_id, Permission)
      :ok = Auth.add_child(permission_p.ext_id, permission.ext_id, Permission)

      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.deny_permission(subject.ext_id, object.ext_id, permission.ext_id)
      :ok = Auth.grant_permission(subject.ext_id, object.ext_id, permission_a.ext_id)

      :denied = Auth.permission_granted?(subject.ext_id, object.ext_id, permission_a.ext_id)
    end

    ################
    ################

    test "returns :granted when positive grant rule is applied to the sop" do
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.grant_permission(subject.ext_id, object.ext_id, permission.ext_id)

      :granted = Auth.permission_granted?(subject.ext_id, object.ext_id, permission.ext_id)
    end

    test "returns :granted when positive grant rule is applied to the sop via subject ancestors" do
      {:ok, subject_a} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, subject_p} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      :ok = Auth.add_child(subject_a.ext_id, subject_p.ext_id, Subject)
      :ok = Auth.add_child(subject_p.ext_id, subject.ext_id, Subject)

      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.grant_permission(subject_a.ext_id, object.ext_id, permission.ext_id)

      :granted = Auth.permission_granted?(subject.ext_id, object.ext_id, permission.ext_id)
    end

    test "returns :granted when positive grant rule is applied to the sop via object ancestors" do
      {:ok, object_a} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, object_p} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      :ok = Auth.add_child(object_a.ext_id, object_p.ext_id, Object)
      :ok = Auth.add_child(object_p.ext_id, object.ext_id, Object)

      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.grant_permission(subject.ext_id, object_a.ext_id, permission.ext_id)

      :granted = Auth.permission_granted?(subject.ext_id, object.ext_id, permission.ext_id)
    end

    test "returns :granted when positive grant rule is applied to the sop via permission ancestors" do
      {:ok, permission_a} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      {:ok, permission_p} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      {:ok, permission} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      :ok = Auth.add_child(permission_a.ext_id, permission_p.ext_id, Permission)
      :ok = Auth.add_child(permission_p.ext_id, permission.ext_id, Permission)

      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.grant_permission(subject.ext_id, object.ext_id, permission_a.ext_id)

      :granted = Auth.permission_granted?(subject.ext_id, object.ext_id, permission.ext_id)
    end

    test "returns :granted when negative grant rule is applied to subject descendants" do
      {:ok, subject_a} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, subject_p} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      :ok = Auth.add_child(subject_a.ext_id, subject_p.ext_id, Subject)
      :ok = Auth.add_child(subject_p.ext_id, subject.ext_id, Subject)

      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.grant_permission(subject_a.ext_id, object.ext_id, permission.ext_id)
      :ok = Auth.deny_permission(subject.ext_id, object.ext_id, permission.ext_id)

      :granted = Auth.permission_granted?(subject_a.ext_id, object.ext_id, permission.ext_id)
    end

    test "returns :granted when negative grant rule is applied to object descendants" do
      {:ok, object_a} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, object_p} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      {:ok, object} = Object.new(UUID.generate(), "Object A") |> Repo.insert()
      :ok = Auth.add_child(object_a.ext_id, object_p.ext_id, Object)
      :ok = Auth.add_child(object_p.ext_id, object.ext_id, Object)

      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, permission} = Permission.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.grant_permission(subject.ext_id, object_a.ext_id, permission.ext_id)
      :ok = Auth.deny_permission(subject.ext_id, object.ext_id, permission.ext_id)

      :granted = Auth.permission_granted?(subject.ext_id, object_a.ext_id, permission.ext_id)
    end

    test "returns :granted when negative grant rule is applied to permission ancestors" do
      {:ok, permission_a} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      {:ok, permission_p} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      {:ok, permission} = Permission.new(UUID.generate(), "Permission A") |> Repo.insert()
      :ok = Auth.add_child(permission_a.ext_id, permission_p.ext_id, Permission)
      :ok = Auth.add_child(permission_p.ext_id, permission.ext_id, Permission)

      {:ok, subject} = Subject.new(UUID.generate(), "Subject A") |> Repo.insert()
      {:ok, object} = Object.new("edit", "edit stuff") |> Repo.insert()

      :ok = Auth.deny_permission(subject.ext_id, object.ext_id, permission_a.ext_id)
      :ok = Auth.grant_permission(subject.ext_id, object.ext_id, permission.ext_id)

      :granted = Auth.permission_granted?(subject.ext_id, object.ext_id, permission.ext_id)
    end
  end

  describe "permission/3 macro" do
    defmodule PermissionMacroTest do
      @moduledoc false
      use Authorizir, repo: Repo

      permission(:read, "view a document")
      permission(:edit, "edit a document", implies: :read)
      permission(:delete, "delete a document", implies: :edit)
      permission(:foo, "Foo")
      permission(:bar, "Bar", implies: [:foo, :delete])
    end

    test "registers a permission leaf node with the specified description" do
      PermissionMacroTest.init()

      read = Repo.get_by!(Permission, ext_id: "read")
      assert read.description == "view a document"

      edit = Repo.get_by!(Permission, ext_id: "edit")
      assert edit.description == "edit a document"

      delete = Repo.get_by!(Permission, ext_id: "delete")
      assert delete.description == "delete a document"
    end

    test "makes permission a parent/ancestor of any implied permissions" do
      PermissionMacroTest.init()

      read = Repo.get_by!(Permission, ext_id: "read")
      edit = Repo.get_by!(Permission, ext_id: "edit")
      delete = Repo.get_by!(Permission, ext_id: "delete")
      foo = Repo.get_by!(Permission, ext_id: "foo")
      bar = Repo.get_by!(Permission, ext_id: "bar")

      assert Permission.children(bar) |> Repo.all() == [foo, delete]
      assert Permission.descendants(bar) |> Repo.all() == [foo, delete, edit, read]
    end
  end
end
