defmodule TdBgWeb.FeatureCase do
  @moduledoc """
  This module defines the test case to be used by
  feature tests.

  """

  use ExUnit.CaseTemplate
  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      import TdBgWeb.Router.Helpers
      @endpoint TdBgWeb.Endpoint
    end
  end

  setup tags do
    :ok = Sandbox.checkout(TdBg.Repo)
    unless tags[:async] do
      Sandbox.mode(TdBg.Repo, {:shared, self()})
    end
    :ok
  end
end
