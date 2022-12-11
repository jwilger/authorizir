defprotocol Authorizir.ToAuthorizirId do
  @spec to_ext_id(t()) :: String.t()
  def to_ext_id(term)
end

defimpl Authorizir.ToAuthorizirId, for: BitString do
  def to_ext_id(term), do: to_string(term)
end

defimpl Authorizir.ToAuthorizirId, for: Integer do
  def to_ext_id(term), do: to_string(term)
end

defimpl Authorizir.ToAuthorizirId, for: Atom do
  def to_ext_id(term), do: to_string(term)
end

defimpl Authorizir.ToAuthorizirId, for: Float do
  def to_ext_id(term), do: to_string(term)
end

defimpl Authorizir.ToAuthorizirId, for: URI do
  def to_ext_id(term), do: to_string(term)
end
