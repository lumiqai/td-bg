defmodule TrueBGWeb.ApiServices.MockTdAuthService do
  @moduledoc false

  @users [
    %TrueBG.Accounts.User{id: Integer.mod(:binary.decode_unsigned("app-admin"), 100_000), is_admin: true, user_name: "app-admin"},
    %TrueBG.Accounts.User{id: 10, is_admin: false, user_name: "watcher"},
    %TrueBG.Accounts.User{id: 11, is_admin: false, user_name: "creator"},
    %TrueBG.Accounts.User{id: 12, is_admin: false, user_name: "publisher"},
    %TrueBG.Accounts.User{id: 13, is_admin: false, user_name: "admin"},
    %TrueBG.Accounts.User{id: 14, is_admin: false, user_name: "pietro.alpin"},
    %TrueBG.Accounts.User{id: 15, is_admin: false, user_name: "johndoe"},
    %TrueBG.Accounts.User{id: 16, is_admin: false, user_name: "Hari.seldon"},
    %TrueBG.Accounts.User{id: 17, is_admin: false, user_name: "tomclancy"},
    %TrueBG.Accounts.User{id: 18, is_admin: false, user_name: "Peter.sellers"},
    %TrueBG.Accounts.User{id: 19, is_admin: false, user_name: "tom.sawyer"}
  ]

  def create(%{"user" => user_params}) do
      Enum.find(@users, fn(user) -> user_params.user_name == user.user_name end)
  end

  def search(%{"data" => %{"ids" => ids}}) do
    Enum.filter(@users, fn(user) -> Enum.find(ids, &(&1 == user.id)) != nil end)
  end
end
