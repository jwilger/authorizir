defmodule AuthorizirTest do
  use ExUnit.Case, async: true

  import Ecto.Query, only: [from: 2]

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

  describe "list_rules/3" do
    test "list rules defined for the given subject/object" do
      subject_a = Subject.new(UUID.generate(), "Sub A") |> Repo.insert!()
      subject_b = Subject.new(UUID.generate(), "Sub B") |> Repo.insert!()
      :ok = Auth.add_child(subject_a.ext_id, subject_b.ext_id, Subject)

      object_a = Object.new(UUID.generate(), "Obj A") |> Repo.insert!()
      object_b = Object.new(UUID.generate(), "Obj B") |> Repo.insert!()
      :ok = Auth.add_child(object_a.ext_id, object_b.ext_id, Object)

      permission_a = Permission.new("foo", "Foo") |> Repo.insert!()
      permission_b = Permission.new("bar", "Bar") |> Repo.insert!()
      :ok = Auth.add_child(permission_a.ext_id, permission_b.ext_id, Permission)

      :ok = Auth.grant_permission(subject_a.ext_id, object_a.ext_id, "foo")
      :ok = Auth.grant_permission(subject_b.ext_id, object_b.ext_id, "foo")
      :ok = Auth.deny_permission(subject_a.ext_id, object_a.ext_id, "bar")
      :ok = Auth.deny_permission(subject_b.ext_id, object_b.ext_id, "bar")

      assert Auth.list_rules(subject_b.ext_id, Subject) == [
               {subject_b.ext_id, object_b.ext_id, "bar", :-},
               {subject_b.ext_id, object_b.ext_id, "foo", :+}
             ]

      assert Auth.list_rules(object_b.ext_id, Object) == [
               {subject_b.ext_id, object_b.ext_id, "bar", :-},
               {subject_b.ext_id, object_b.ext_id, "foo", :+}
             ]
    end
  end

  describe "macros" do
    defmodule MacroTest do
      @moduledoc false
      use Authorizir, repo: Repo

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
      documents = Repo.get_by!(Object, ext_id: "documents")
      faq = Repo.get_by!(Object, ext_id: "faq")
      articles = Repo.get_by!(Object, ext_id: "articles")

      assert Object.parents(faq) |> Repo.all() == [articles]
      assert Object.ancestors(faq) |> Repo.all() == [articles, documents]
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
      users = Repo.get_by!(Subject, ext_id: "users")
      editor = Repo.get_by!(Subject, ext_id: "editor")
      support = Repo.get_by!(Subject, ext_id: "support")
      scheduler = Repo.get_by!(Subject, ext_id: "scheduler")
      admin = Repo.get_by!(Subject, ext_id: "admin")

      assert Subject.parents(admin) |> Repo.all() == [scheduler, support, editor]
      assert Subject.ancestors(admin) |> Repo.all() == [scheduler, support, editor, users]
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

    test "makes role object a child/descendant of any implied objects" do
      users = Repo.get_by!(Object, ext_id: "users")
      editor = Repo.get_by!(Object, ext_id: "editor")
      support = Repo.get_by!(Object, ext_id: "support")
      scheduler = Repo.get_by!(Object, ext_id: "scheduler")
      admin = Repo.get_by!(Object, ext_id: "admin")

      assert Object.parents(admin) |> Repo.all() == [scheduler, support, editor]
      assert Object.ancestors(admin) |> Repo.all() == [scheduler, support, editor, users]
    end

    test "creates positive grant authorization rules" do
      assert {"users", "documents", "read", :+} in Auth.list_rules("users", Subject)
      assert {"admin", "*", "*", :+} in Auth.list_rules("admin", Subject)
    end

    test "creates negative grant authorization rules" do
      assert {"scheduler", "articles", "read", :-} in Auth.list_rules("scheduler", Subject)
      assert {"no_access", "*", "*", :-} in Auth.list_rules("no_access", Subject)
    end

    test "removes static authorization rules that are no longer defined" do
      Authorizir.grant_permission(AuthorizirTest.Repo, "users", "articles", "edit", true)
      Authorizir.deny_permission(AuthorizirTest.Repo, "scheduler", "articles", "edit", true)
      assert {"users", "articles", "edit", :+} in Auth.list_rules("users", Subject)
      assert {"scheduler", "articles", "edit", :-} in Auth.list_rules("scheduler", Subject)
      MacroTest.init()
      refute {"users", "articles", "edit", :+} in Auth.list_rules("users", Subject)
      refute {"scheduler", "articles", "edit", :-} in Auth.list_rules("scheduler", Subject)
    end

    test "does not remove non-static authorization rules" do
      Auth.grant_permission("users", "articles", "edit")
      Auth.deny_permission("scheduler", "articles", "edit")
      assert {"users", "articles", "edit", :+} in Auth.list_rules("users", Subject)
      assert {"scheduler", "articles", "edit", :-} in Auth.list_rules("scheduler", Subject)
      MacroTest.init()
      assert {"users", "articles", "edit", :+} in Auth.list_rules("users", Subject)
      assert {"scheduler", "articles", "edit", :-} in Auth.list_rules("scheduler", Subject)
    end

    test "init removes any static permissions, subjects, and objects that are no longer defined" do
      permission = %Permission{ext_id: "old", description: "Old", static: true} |> Repo.insert!()
      subject = %Subject{ext_id: "old", description: "Old", static: true} |> Repo.insert!()
      object = %Object{ext_id: "old", description: "Old", static: true} |> Repo.insert!()

      MacroTest.init()

      assert Repo.get_by(Permission, ext_id: permission.ext_id) == nil
      assert Repo.get_by(Subject, ext_id: subject.ext_id) == nil
      assert Repo.get_by(Object, ext_id: object.ext_id) == nil
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

    test "init removes static children that are no longer set as children" do
      permission_delete = Repo.get_by!(Permission, ext_id: "delete")
      permission_foo = Permission.new("foo", "foo", true) |> Repo.insert!()
      sub_editor = Repo.get_by!(Subject, ext_id: "editor")
      sub_foo = Subject.new("foo", "foo", true) |> Repo.insert!()
      obj_editor = Repo.get_by!(Object, ext_id: "editor")
      obj_foo = Object.new("foo", "foo", true) |> Repo.insert!()
      :ok = MacroTest.add_child(permission_foo.ext_id, permission_delete.ext_id, Permission)
      :ok = MacroTest.add_child(sub_foo.ext_id, sub_editor.ext_id, Subject)
      :ok = MacroTest.add_child(obj_foo.ext_id, obj_editor.ext_id, Object)
      assert permission_delete in (Permission.children(permission_foo) |> Repo.all())
      assert sub_editor in (Subject.children(sub_foo) |> Repo.all())
      assert obj_editor in (Object.children(obj_foo) |> Repo.all())
      MacroTest.init()
      refute permission_delete in (Permission.children(permission_foo) |> Repo.all())
      refute sub_editor in (Subject.children(sub_foo) |> Repo.all())
      refute obj_editor in (Object.children(obj_foo) |> Repo.all())
    end

    test "init does not remove non-static children" do
      permission_delete = Repo.get_by!(Permission, ext_id: "delete")
      permission_x = Permission.new("x", "x") |> Repo.insert!()
      sub_editor = Repo.get_by!(Subject, ext_id: "editor")
      sub_x = Subject.new("x", "x") |> Repo.insert!()
      obj_editor = Repo.get_by!(Object, ext_id: "editor")
      obj_x = Object.new("x", "x") |> Repo.insert!()
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
end
