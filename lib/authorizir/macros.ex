defmodule Authorizir.Macros do
  @moduledoc """
  Macros for defining base authorization system

  The macros contained in this module are available to your application's Auth
  module and are used to define your application's base authorization. See
  `Authorizir` for details.
  """
  defmacro permission(ext_id, description, opts \\ []) do
    ext_id = to_string(ext_id)
    description = to_string(description)

    children = Authorizir.string_list_from_option(opts, :implies)

    quote bind_quoted: [ext_id: ext_id, description: description, children: children] do
      @permissions {ext_id, description, children}

      defp permission_declarations, do: @permissions

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

      defp subject_declarations, do: @subjects
      defp object_declarations, do: @objects

      defoverridable subject_declarations: 0, object_declarations: 0
    end
  end

  defmacro collection(ext_id, description, opts \\ []) do
    ext_id = to_string(ext_id)
    description = to_string(description)

    parents = Authorizir.string_list_from_option(opts, :in)

    quote bind_quoted: [ext_id: ext_id, description: description, parents: parents] do
      @objects {ext_id, description, parents}

      defp object_declarations, do: @objects

      defoverridable object_declarations: 0
    end
  end

  defmacro grant(permission, [{:on, object}, {:to, subject}]) do
    permission = to_string(permission)
    object = to_string(object)
    subject = to_string(subject)

    quote bind_quoted: [permission: permission, object: object, subject: subject] do
      @rules {subject, object, permission, :+}

      defp rule_declarations, do: @rules

      defoverridable rule_declarations: 0
    end
  end

  defmacro deny(permission, [{:on, object}, {:to, subject}]) do
    permission = to_string(permission)
    object = to_string(object)
    subject = to_string(subject)

    quote bind_quoted: [permission: permission, object: object, subject: subject] do
      @rules {subject, object, permission, :-}

      defp rule_declarations, do: @rules

      defoverridable rule_declarations: 0
    end
  end
end
