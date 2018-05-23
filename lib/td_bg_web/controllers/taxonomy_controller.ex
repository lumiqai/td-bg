defmodule TdBgWeb.TaxonomyController do
  use TdBgWeb, :controller
  use PhoenixSwagger

  alias TdBg.Permissions
  alias TdBgWeb.SwaggerDefinitions

  action_fallback TdBgWeb.FallbackController

  def swagger_definitions do
    SwaggerDefinitions.taxonomy_swagger_definitions()
  end

  swagger_path :roles do
    get "/taxonomy/roles?principal_id={principal_id}"
    description "Returns tree of Domains"
    produces "application/json"
    parameters do
      principal_id :path, :integer, "user id", required: true
    end
    response 200, "Ok" , Schema.ref(:TaxonomyRolesResponse)
    response 400, "Client error"
  end
  def roles(conn, %{"principal_id" => principal_id}) do
    taxonomy_roles = Permissions.assemble_roles(%{user_id: principal_id})
    all_roles = Permissions.list_roles()
    taxonomy_roles = Enum.map(taxonomy_roles, &(%{id: &1.id, role: &1.role, role_id: get_role_id(all_roles, &1.role), acl_entry_id: &1.acl_entry_id, inherited: &1.inherited}))

    roles_domain = case taxonomy_roles do
      nil -> %{}
      tr -> tr |> Enum.reduce(%{}, fn(x, acc) -> Map.put(acc, x.id, %{role: x.role, role_id: x.role_id, acl_entry_id: x.acl_entry_id, inherited: x.inherited}) end)
    end

    taxonomy_roles = %{"domains": roles_domain}
    json conn, %{"data": taxonomy_roles}
  end
  def roles(conn, _params), do: json conn, %{"data": []}

  defp get_role_id(roles, role_name) do
    case role_name do
      nil -> nil
      name -> Enum.find(roles, fn(role) -> role.name == name end).id
    end
  end
end
