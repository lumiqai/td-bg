defmodule TdBg.PingTest do
  use Cabbage.Feature, async: false, file: "ping/ping.feature"
  alias TdBgWeb.Router.Helpers, as: Routes
  @endpoint TdBgWeb.Endpoint

  defwhen ~r/^you send me a ping$/, _params, state do
    %HTTPoison.Response{status_code: status_code, body: body} =
      HTTPoison.get!(Routes.ping_url(@endpoint, :ping))

    assert status_code == 200
    {:ok, Map.merge(state, %{body: body})}
  end

  defthen ~r/^I send you a pong$/, _params, state do
    assert state[:body] == "pong"
    {:ok, state}
  end
end
