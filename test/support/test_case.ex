defmodule Authorizir.TestCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      import Authorizir.TestCase
    end
  end
end
