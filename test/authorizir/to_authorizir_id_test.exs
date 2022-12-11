defmodule Authorizir.ToAuthorizirIdTest do
  use Authorizir.TestCase, async: true

  alias Authorizir.ToAuthorizirId

  test "implementation for Bitstring returns the string value" do
    str = Faker.String.base64()
    assert ToAuthorizirId.to_ext_id(str) == str
  end

  test "implementation for Integer returns the string value" do
    num = Faker.random_between(1, 100_000_000_000)
    assert ToAuthorizirId.to_ext_id(num) == to_string(num)
  end

  test "implementation for Atom returns the string value" do
    atom = Faker.String.base64() |> String.to_atom()
    assert ToAuthorizirId.to_ext_id(atom) == to_string(atom)
  end

  test "implementationfor Float returns the string value" do
    float = Faker.random_uniform()
    assert ToAuthorizirId.to_ext_id(float) == to_string(float)
  end

  test "implementation for URI returns the string value" do
    uri = URI.parse("https://example.test/foo?bar=baz&ham=spam")
    assert ToAuthorizirId.to_ext_id(uri) == to_string(uri)
  end
end
