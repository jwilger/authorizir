defmodule Authorizir.Macros do
  @moduledoc """
  Macros for defining base authorization system

  The macros contained in this module are available to your application's Auth
  module and are used to define your application's base authorization. See
  `Authorizir` for details.
  """
  defmacro permission(ext_id, description, opts \\ []) do
    children = Authorizir.string_list_from_option(opts, :implies)

    quote bind_quoted: [ext_id: ext_id, description: description, children: children] do
      @permissions {ext_id, description, children}

      defp permission_declarations, do: @permissions

      defoverridable permission_declarations: 0
    end
  end

  defmacro role(ext_id, description, opts \\ []) do
    parents = Authorizir.string_list_from_option(opts, :implies)

    quote bind_quoted: [ext_id: ext_id, description: description, parents: parents] do
      @subjects {ext_id, description, parents}
      @objects {ext_id, description, parents}

      defp subject_declarations, do: @subjects
      defp object_declarations, do: @objects

      defoverridable subject_declarations: 0, object_declarations: 0
    end
  end

  defmacro collection(ext_id, description, opts \\ []) do
    parents = Authorizir.string_list_from_option(opts, :in)

    quote bind_quoted: [ext_id: ext_id, description: description, parents: parents] do
      @objects {ext_id, description, parents}

      defp object_declarations, do: @objects

      defoverridable object_declarations: 0
    end
  end

  defmacro grant(permission, opts \\ []) do
    object = opts |> Keyword.fetch!(:on)
    subject = opts |> Keyword.fetch!(:to)

    quote bind_quoted: [permission: permission, object: object, subject: subject] do
      @rules {subject, object, permission, :+}

      defp rule_declarations, do: @rules

      defoverridable rule_declarations: 0
    end
  end

  defmacro deny(permission, opts \\ []) do
    object = opts |> Keyword.fetch!(:on)
    subject = opts |> Keyword.fetch!(:to)

    quote bind_quoted: [permission: permission, object: object, subject: subject] do
      @rules {subject, object, permission, :-}

      defp rule_declarations, do: @rules

      defoverridable rule_declarations: 0
    end
  end
end
