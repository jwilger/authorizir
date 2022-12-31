defmodule Authorizir.Cache do
  @moduledoc """
  Implements caching for permission queries.

  You must call `Authorizir.Cache.start/0` somewhere in your application before
  you can use the Authorizir function.

  The cache ttl defaults to 60 seconds, and the cache will hold up to 100_000
  entries. These defaults can be changes in your application config:

  ```
  config :authorizir, cache_size: 200_000, cache_ttl: 120
  ```
  """
  require DCache

  DCache.define(Results, Application.compile_env(:authorizir, :cache_size, 100_000))

  @spec start() :: :ok
  def start do
    __MODULE__.Results.setup()
  end
end
