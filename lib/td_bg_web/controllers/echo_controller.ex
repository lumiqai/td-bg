defmodule TdBgWeb.EchoController do
  use TdBgWeb, :controller

  alias Jason, as: JSON

  action_fallback TdBgWeb.FallbackController

  def echo(conn, params) do
    send_resp(conn, 200, params |> JSON.encode!())
  end
end
