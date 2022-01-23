defmodule AuthorizirTest do
  use ExUnit.Case, async: true

  alias Authorizir.{Object, Permission, Subject}
  alias AuthorizirTest.Repo
  alias Ecto.UUID

  defmodule Auth do
    use Authorizir, repo: AuthorizirTest.Repo
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(AuthorizirTest.Repo)
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
end
