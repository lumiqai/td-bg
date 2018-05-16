defmodule TdBgWeb.DomainControllerTest do
  use TdBgWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  import TdBgWeb.Authentication, only: :functions

  alias TdBgWeb.ApiServices.MockTdAuthService
  alias TdBg.Taxonomies
  alias TdBg.Taxonomies.Domain
  alias TdBg.Permissions

  @create_attrs %{description: "some description", name: "some name"}
  @update_attrs %{description: "some updated description", name: "some updated name"}
  @invalid_attrs %{description: nil, name: nil}

  def fixture(:domain) do
    {:ok, domain} = Taxonomies.create_domain(@create_attrs)
    domain
  end

  setup_all do
    start_supervised MockTdAuthService
    :ok
  end

  setup %{conn: conn, jwt: _jwt} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    @tag :admin_authenticated
    test "lists all domain_groups", %{conn: conn} do
      conn = get conn, domain_path(conn, :index)
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create domain" do
    @tag :admin_authenticated
    test "renders domain when data is valid", %{conn: conn, swagger_schema: schema} do
      conn = post conn, domain_path(conn, :create), domain: @create_attrs
      assert %{"id" => id} = json_response(conn, 201)["data"]
      validate_resp_schema(conn, schema, "DomainResponse")

      conn = recycle_and_put_headers(conn)
      conn = get conn, domain_path(conn, :show, id)
      json_response_data = json_response(conn, 200)["data"]
      validate_resp_schema(conn, schema, "DomainResponse")
      assert json_response_data["id"] == id
      assert json_response_data["description"] == "some description"
      assert json_response_data["name"] == "some name"
      assert json_response_data["parent_id"] == nil
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn} do
      conn = post conn, domain_path(conn, :create), domain: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update domain" do
    setup [:create_domain]

    @tag :admin_authenticated
    test "renders domain when data is valid", %{conn: conn, swagger_schema: schema, domain: %Domain{id: id} = domain} do
      conn = put conn, domain_path(conn, :update, domain), domain: @update_attrs
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = recycle_and_put_headers(conn)
      conn = get conn, domain_path(conn, :show, id)
      validate_resp_schema(conn, schema, "DomainResponse")
      assert json_response(conn, 200)["data"]["id"] == id
      assert json_response(conn, 200)["data"]["description"] == "some updated description"
      assert json_response(conn, 200)["data"]["name"] == "some updated name"
      assert json_response(conn, 200)["data"]["parent_id"] == nil
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn, domain: domain} do
      conn = put conn, domain_path(conn, :update, domain), domain: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "index root" do
    setup [:create_domain]

    @tag :admin_authenticated
    test "lists root domain groups", %{conn: conn, swagger_schema: schema, domain: domain} do
      conn = get conn, domain_path(conn, :index_root)
      validate_resp_schema(conn, schema, "DomainsResponse")
      assert List.first(json_response(conn, 200)["data"])["data"]["id"] == domain.id
      assert List.first(json_response(conn, 200)["data"])["data"]["description"] == domain.description
      assert List.first(json_response(conn, 200)["data"])["data"]["name"] == domain.name
      assert List.first(json_response(conn, 200)["data"])["data"]["parent_id"] == domain.parent_id
    end
  end

  describe "index_children" do
    setup [:create_child_domain_group]

    @tag :admin_authenticated
    test "index domain children", %{conn: conn, swagger_schema: schema, child_domains: {:ok, child_domains}} do
      conn = get conn, domain_domain_path(conn,  :index_children, child_domains.parent_id)
      validate_resp_schema(conn, schema, "DomainsResponse")
      assert List.first(json_response(conn, 200)["data"])["data"]["id"] == child_domains.id
      assert List.first(json_response(conn, 200)["data"])["data"]["description"] == child_domains.description
      assert List.first(json_response(conn, 200)["data"])["data"]["name"] == child_domains.name
      assert List.first(json_response(conn, 200)["data"])["data"]["parent_id"] == child_domains.parent_id
    end
  end

  describe "delete domain" do
    setup [:create_domain]

    @tag :admin_authenticated
    test "deletes chosen domain", %{conn: conn, domain: domain} do
      conn = delete conn, domain_path(conn, :delete, domain)

      assert response(conn, 204)
      conn = recycle_and_put_headers(conn)
      assert_error_sent 404, fn ->
        get conn, domain_path(conn, :show, domain)
      end
    end
  end

  describe "create acl_entry from domain route" do
    @tag :admin_authenticated
    test "renders acl_entry when data is valid", %{conn: conn, swagger_schema: schema} do
      user = build(:user)
      domain = insert(:domain)
      role = Permissions.get_role_by_name("watch")
      acl_entry_attrs = %{
        principal_id: user.id,
        principal_type: "user",
        role_id: role.id
      }
      conn = post conn, domain_domain_path(conn, :create_acl_entry, domain.id), acl_entry: acl_entry_attrs
      assert %{"id" => id} = json_response(conn, 201)["data"]
      validate_resp_schema(conn, schema, "DomainAclEntryResponse")

      conn = recycle_and_put_headers(conn)
      conn = get conn, acl_entry_path(conn, :show, id)
      validate_resp_schema(conn, schema, "DomainAclEntryResponse")
      assert json_response(conn, 200)["data"] == %{
        "id" => id,
        "principal_id" => user.id,
        "principal_type" => "user",
        "resource_id" => domain.id,
        "resource_type" => "domain",
        "role_id" => role.id
      }
    end

    @tag :admin_authenticated
    test "renders error for duplicated acl_entry from domain route", %{conn: conn, swagger_schema: schema} do
      user = build(:user)
      domain = insert(:domain)
      role = Permissions.get_role_by_name("watch")
      acl_entry_attrs = %{
        principal_id: user.id,
        principal_type: "user",
        role_id: role.id
      }
      conn = post conn, domain_domain_path(conn, :create_acl_entry, domain.id), acl_entry: acl_entry_attrs
      assert %{"id" => _id} = json_response(conn, 201)["data"]
      validate_resp_schema(conn, schema, "DomainAclEntryResponse")

      conn = recycle_and_put_headers(conn)
      conn = post conn, acl_entry_path(conn, :create), acl_entry: acl_entry_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn} do
      conn = post conn, acl_entry_path(conn, :create), acl_entry: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  defp create_domain(_) do
    domain = fixture(:domain)
    {:ok, domain: domain}
  end

  defp create_child_domain_group(_) do
    {:ok, domain} =  Taxonomies.create_domain(@create_attrs)
    child_domains = Taxonomies.create_domain(%{parent_id: domain.id, description: "some child description", name: "some child name"})
    {:ok, child_domains: child_domains}
  end
end
