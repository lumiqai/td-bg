defmodule TdBgWeb.BusinessConceptController do
  require Logger
  use TdBgWeb, :controller
  use TdBg.Hypermedia, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias TdBg.BusinessConcepts
  alias TdBg.BusinessConcepts.BusinessConcept
  alias TdBg.BusinessConcepts.BusinessConceptVersion
  alias TdBg.Taxonomies
  alias TdBg.Permissions
  alias TdBgWeb.ErrorView
  alias TdBgWeb.SwaggerDefinitions
  alias TdBg.Templates
  alias Guardian.Plug, as: GuardianPlug

  plug :load_resource, model: BusinessConcept, id_name: "business_concept_id", persisted: true, only: [:update_status]

  @search_service Application.get_env(:td_bg, :elasticsearch)[:search_service]

  action_fallback TdBgWeb.FallbackController

  def swagger_definitions do
    SwaggerDefinitions.business_concept_definitions()
  end

  swagger_path :index do
    get "/business_concepts"
    description "List Business Concepts"
    response 200, "OK", Schema.ref(:BusinessConceptsResponse)
  end

  def index(conn, _params) do
    business_concept_versions = BusinessConcepts.list_all_business_concept_versions()
    render(conn, "index.json", business_concepts: business_concept_versions, hypermedia: hypermedia("business_concept", conn, business_concept_versions))
  end

  swagger_path :index_children_business_concept do
    get "/business_concepts/domains/{id}"
    description "List Business Concepts children of Domain"
    produces "application/json"
    parameters do
      id :path, :integer, "Domain ID", required: true
    end
    response 200, "OK", Schema.ref(:BusinessConceptsResponse)
    response 400, "Client Error"
  end

  def index_children_business_concept(conn, %{"domain_id" => id}) do
    business_concept_versions = BusinessConcepts.get_domain_children_versions!(id)
    render(conn, "index.json", business_concepts: business_concept_versions, hypermedia: hypermedia("business_concept", conn, business_concept_versions))
  end

  def search(conn, %{} = search_params) do
    filter = Map.new
    |> add_to_filter_as_int_list(:id, Map.get(search_params, "id"))
    |> add_to_filter_as_list(:status, Map.get(search_params, "status"))

    business_concept_versions = if length(filter.id) > 0 do
      BusinessConcepts.find_business_concept_versions(filter)
    else
      []
    end

    render(conn, "search.json", business_concepts: business_concept_versions)
  end

  swagger_path :create do
    post "/business_concepts"
    description "Creates a Business Concept child of Data Domain"
    produces "application/json"
    parameters do
      business_concept :body, Schema.ref(:BusinessConceptCreate), "Business Concept create attrs"
    end
    response 201, "Created", Schema.ref(:BusinessConceptResponse)
    response 400, "Client Error"
  end

  def create(conn, %{"business_concept" => business_concept_params}) do
    #validate fields that if not present are throwing internal server errors in bc creation
    validate_required_bc_fields(business_concept_params)

    concept_type = Map.get(business_concept_params, "type")
    %{:content => content_schema} = Templates.get_template_by_name(concept_type)

    concept_name = Map.get(business_concept_params, "name")

    user = conn.assigns.current_user
    domain_id = Map.get(business_concept_params, "domain_id")
    domain = Taxonomies.get_domain!(domain_id)

    business_concept_attrs = %{}
    |> Map.put("domain_id", domain_id)
    |> Map.put("type", concept_type)
    |> Map.put("last_change_by", user.id)
    |> Map.put("last_change_at", DateTime.utc_now())

    creation_attrs = business_concept_params
    |> Map.put("business_concept", business_concept_attrs)
    |> Map.put("content_schema", content_schema)
    |> Map.update("content", %{},  &(&1))
    |> Map.update("related_to", [],  &(&1))
    |> Map.put("last_change_by", conn.assigns.current_user.id)
    |> Map.put("last_change_at", DateTime.utc_now())
    |> Map.put("status", BusinessConcept.status.draft)
    |> Map.put("version", 1)

    related_to = Map.get(creation_attrs, "related_to")

    with true <- can?(user, create_business_concept(domain)),
         {:name_available} <- BusinessConcepts.check_business_concept_name_availability(concept_type, concept_name),
         {:valid_related_to} <- check_valid_related_to(concept_type, related_to),
         {:ok, %BusinessConceptVersion{} = concept} <-
          BusinessConcepts.create_business_concept(creation_attrs) do
      conn = conn
      |> put_status(:created)
      |> put_resp_header("location", business_concept_path(conn, :show, concept.business_concept))
      |> render("show.json", business_concept: concept)
      @search_service.put_search(concept)
      conn
    else
      error ->
        handle_bc_errors(conn, error)
    end
  rescue
    validationError in ValidationError ->
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{"errors": %{"#{validationError.field}": [validationError.error]}})
  end

  defp handle_bc_errors(conn, error) do
    case error do
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, :"403.json")
      {:name_not_available} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{"errors": %{name: ["unique"]}})
      {:not_valid_related_to} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{"errors": %{related_to: ["invalid"]}})
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(TdBgWeb.ChangesetView, "error.json", changeset: changeset)
      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  defp validate_required_bc_fields(attrs) do
    if not Map.has_key?(attrs, "content") do
      raise ValidationError, field: "content", error: "blank"
    end
    if not Map.has_key?(attrs, "type") do
      raise ValidationError, field: "type", error: "blank"
    end
  end

  swagger_path :show do
    get "/business_concepts/{id}"
    description "Show Business Concepts"
    produces "application/json"
    parameters do
      id :path, :integer, "Business Concept ID", required: true
    end
    response 200, "OK", Schema.ref(:BusinessConceptResponse)
    response 400, "Client Error"
  end

  def show(conn, %{"id" => id}) do
    business_concept = BusinessConcepts.get_current_version_by_business_concept_id!(id)
    render(conn, "show.json", business_concept: business_concept, hypermedia: hypermedia("business_concept", conn, business_concept))
  end

  swagger_path :update do
    put "/business_concepts/{id}"
    description "Updates Business Concepts"
    produces "application/json"
    parameters do
      business_concept :body, Schema.ref(:BusinessConceptUpdate), "Business Concept update attrs"
      id :path, :integer, "Business Concept ID", required: true
    end
    response 200, "OK", Schema.ref(:BusinessConceptResponse)
    response 400, "Client Error"
  end

  def update(conn, %{"id" => id, "business_concept" => business_concept_params}) do
    business_concept_version = BusinessConcepts.get_current_version_by_business_concept_id!(id)

    concept_type = business_concept_version.business_concept.type
    concept_name = Map.get(business_concept_params, "name")
    %{:content => content_schema} = Templates.get_template_by_name(concept_type)

    user = conn.assigns.current_user

    business_concept_attrs = %{}
    |> Map.put("last_change_by", user.id)
    |> Map.put("last_change_at", DateTime.utc_now())

    update_params = business_concept_params
    |> Map.put("business_concept", business_concept_attrs)
    |> Map.put("content_schema", content_schema)
    |> Map.update("content", %{},  &(&1))
    |> Map.update("related_to", [],  &(&1))
    |> Map.put("last_change_by", user.id)
    |> Map.put("last_change_at", DateTime.utc_now())

    related_to = Map.get(update_params, "related_to")

    with true <- can?(user, update(business_concept_version)),
         {:name_available} <- BusinessConcepts.check_business_concept_name_availability(concept_type, concept_name, id),
         {:valid_related_to} <- check_valid_related_to(concept_type, related_to),
         {:ok, %BusinessConceptVersion{} = concept} <-
      BusinessConcepts.update_business_concept_version(business_concept_version,
                                                              update_params) do
      @search_service.put_search(business_concept_version)
      render(conn, "show.json", business_concept: concept)
    else
      error ->
        handle_bc_errors(conn, error)
    end
  end

  swagger_path :delete do
    delete "/business_concepts/{id}"
    description "Delete Business Concepts"
    produces "application/json"
    parameters do
      id :path, :integer, "Business Concept ID", required: true
    end
    response 204, "No Content"
    response 400, "Client Error"
  end

  def delete(conn, %{"id" => id}) do
    business_concept_version = BusinessConcepts.get_current_version_by_business_concept_id!(id)

    user = conn.assigns.current_user

    with true <- can?(user, delete(business_concept_version)),
         {:ok, %BusinessConceptVersion{}} <- BusinessConcepts.delete_business_concept_version(business_concept_version) do
      @search_service.delete_search(business_concept_version)
      send_resp(conn, :no_content, "")
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, :"403.json")
      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  swagger_path :update_status do
    patch "/business_concepts/{business_concept_id}/status"
    description "Updates Business Ccncept status"
    produces "application/json"
    parameters do
      business_concept :body, Schema.ref(:BusinessConceptUpdateStatus), "Business Concept status update attrs"
      business_concept_id :path, :integer, "Business Concept ID", required: true
    end
    response 200, "OK", Schema.ref(:BusinessConceptResponse)
    response 400, "Client Error"
  end

  def update_status(conn, %{"business_concept_id" => id, "business_concept" => %{"status" => new_status} = business_concept_params}) do

    business_concept_version = BusinessConcepts.get_current_version_by_business_concept_id!(id)
    status = business_concept_version.status
    user = conn.assigns.current_user

    draft = BusinessConcept.status.draft
    rejected = BusinessConcept.status.rejected
    pending_approval = BusinessConcept.status.pending_approval
    published = BusinessConcept.status.published
    deprecated = BusinessConcept.status.deprecated

    case {status, new_status} do
      {^draft, ^pending_approval} ->
        send_for_approval(conn, user, business_concept_version, business_concept_params)
      {^pending_approval, ^published} ->
        publish(conn, user,  business_concept_version, business_concept_params)
      {^pending_approval, ^rejected} ->
        reject(conn, user,  business_concept_version, business_concept_params)
      {^rejected, ^pending_approval} ->
        send_for_approval(conn, user, business_concept_version, business_concept_params)
      {^rejected, ^draft} ->
        undo_rejection(conn, user, business_concept_version, business_concept_params)
      {^published, ^deprecated} ->
        deprecate(conn, user, business_concept_version, business_concept_params)
      {^published, ^draft} ->
        do_version(conn, user, business_concept_version, business_concept_params)
      _ ->
        Logger.info "No status action for {#{status}, #{new_status}} combination"
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  def taxonomy_roles(conn, %{"business_concept_id" => id}) do
    # We should fetch the user in order to check its permissions over the
    # current version of the business concept
    user = get_current_user(conn)
    # First of all we should retrieve the business concept for a
    business_concept_version =
      BusinessConcepts.get_current_version_by_business_concept_id!(id)
    with true <- can?(user, view_versions(business_concept_version)) do
      business_concept = business_concept_version.business_concept
      business_concept_taxonomy =
        get_taxonomy_levels_from_business_concept(business_concept.domain_id)
        render(conn, "index_business_concept_taxonomy.json",
          business_concept_taxonomy: business_concept_taxonomy)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, :"403.json")
      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  defp get_taxonomy_levels_from_business_concept(domain_id, acc \\ [])
  defp get_taxonomy_levels_from_business_concept(nil, acc) do
    acc
  end
  defp get_taxonomy_levels_from_business_concept(domain_id, acc) do
    domain = Taxonomies.get_domain!(domain_id)
    acl_list = Permissions.get_list_acl_from_domain(domain)
    acc = case acl_list do
        [] -> acc
        acl_list -> acc ++ [%{domain_id: domain_id, domain_name: domain.name, roles: acl_list}]
      end
    get_taxonomy_levels_from_business_concept(domain.parent_id, acc)
  end

  defp send_for_approval(conn, user, business_concept_version, _business_concept_params) do
    attrs = %{status: BusinessConcept.status.pending_approval}
    with true <- can?(user, send_for_approval(business_concept_version)),
         {:ok, %BusinessConceptVersion{} = concept} <-
           BusinessConcepts.update_business_concept_version_status(business_concept_version, attrs) do
       @search_service.put_search(business_concept_version)
       render(conn, "show.json", business_concept: concept)
    else
      false ->
        conn
          |> put_status(:forbidden)
          |> render(ErrorView, :"403.json")
      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  defp reject(conn, user, business_concept_version, business_concept_params) do
    attrs = %{reject_reason: Map.get(business_concept_params, "reject_reason")}
    with true <- can?(user, reject(business_concept_version)),
         {:ok, %BusinessConceptVersion{} = concept} <-
           BusinessConcepts.reject_business_concept_version(business_concept_version, attrs) do
       @search_service.put_search(business_concept_version)
       render(conn, "show.json", business_concept: concept)
    else
      false ->
        conn
          |> put_status(:forbidden)
          |> render(ErrorView, :"403.json")
      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  defp undo_rejection(conn, user, business_concept_version, _business_concept_params) do
    attrs = %{status: BusinessConcept.status.draft}
    with true <- can?(user, undo_rejection(business_concept_version)),
         {:ok, %BusinessConceptVersion{} = concept} <-
           BusinessConcepts.update_business_concept_version_status(business_concept_version, attrs) do
       @search_service.put_search(business_concept_version)
       render(conn, "show.json", business_concept: concept)
    else
      false ->
        conn
          |> put_status(:forbidden)
          |> render(ErrorView, :"403.json")
      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  defp publish(conn, user, business_concept_version, _business_concept_params) do
    with true <- can?(user, publish(business_concept_version)),
         {:ok, %{published: %BusinessConceptVersion{} = concept}} <-
                    BusinessConcepts.publish_business_concept_version(business_concept_version) do
         render(conn, "show.json", business_concept: concept)
    else
      false ->
        conn
          |> put_status(:forbidden)
          |> render(ErrorView, :"403.json")
      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  defp deprecate(conn, user, business_concept_version, _business_concept_params) do
    attrs = %{status: BusinessConcept.status.deprecated}
    with true <- can?(user, deprecate(business_concept_version)),
          {:ok, %BusinessConceptVersion{} = concept} <-
            BusinessConcepts.update_business_concept_version_status(business_concept_version, attrs) do
         @search_service.put_search(business_concept_version)
         render(conn, "show.json", business_concept: concept)
    else
      false ->
        conn
          |> put_status(:forbidden)
          |> render(ErrorView, :"403.json")
      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  defp do_version(conn, user, business_concept_version, _business_concept_params) do
    business_concept = business_concept_version.business_concept
    concept_type = business_concept.type
    %{:content => content_schema} = Templates.get_template_by_name(concept_type)

    business_concept = business_concept
    |> Map.put("last_change_by", user.id)
    |> Map.put("last_change_at", DateTime.utc_now())

    draft_attrs = Map.from_struct(business_concept_version)
    draft_attrs = draft_attrs
    |> Map.put("business_concept", business_concept)
    |> Map.put("content_schema", content_schema)
    |> Map.put("last_change_by", user.id)
    |> Map.put("last_change_at", DateTime.utc_now())
    |> Map.put("status", BusinessConcept.status.draft)
    |> Map.put("version", business_concept_version.version + 1)

    with true <- can?(user, version(business_concept_version)),
         {:ok, %{current: %BusinessConceptVersion{} = new_version}}
            <- BusinessConcepts.version_business_concept(business_concept_version, draft_attrs) do
      conn
        |> put_status(:created)
        |> render("show.json", business_concept: new_version)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, :"403.json")
      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  swagger_path :index_status do
    get "/business_concepts/index/{status}"
    description "List Business Concept with certain status"
    produces "application/json"
    parameters do
      status :path, :string, "Business Concept Status", required: true
    end
    response 200, "OK", Schema.ref(:BusinessConceptResponse)
    response 400, "Client Error"
  end

  def index_status(conn, status) do
    user = conn.assigns.current_user
    business_concepts = build_list(user, status)
    render(conn, "index.json", business_concepts: business_concepts, hypermedia: hypermedia("business_concept", conn, business_concepts))
  end

  defp build_list(user, %{"status" => status}) do
    list_business_concept = BusinessConcepts.list_all_business_concept_with_status([status])
    case status do
      "draft" ->
        []
      "pending_approval" -> filter_list(user, list_business_concept)
      "rejected" ->
        []
      "published" ->
        []
      "versioned" ->
        []
      "deprecated" ->
        []
    end
  end

  swagger_path :search_by_name do
    get "/business_concepts/search_by_name/{name}"
    description "List Business Concepts by name"
    produces "application/json"
    parameters do
      status :path, :string, "Business Concept Name", required: true
    end
    response 200, "OK", Schema.ref(:BusinessConceptResponse)
    response 400, "Client Error"
  end
  def search_by_name(conn, %{"name" => name}) do
    business_concept_versions = BusinessConcepts.get_business_concept_by_name(name)
    render(conn, "index.json", business_concepts: business_concept_versions)
  end

  defp filter_list(user, list_business_concept) do
    Enum.reduce(list_business_concept, [], fn(business_concept, acc) ->
      if can?(user, publish(business_concept)) or can?(user, reject(business_concept)) do
        acc ++ [business_concept]
      else
        []
      end
    end
    )
  end

  defp check_valid_related_to(_type, []), do: {:valid_related_to}
  defp check_valid_related_to(type, ids) do
    input_count = length(ids)
    actual_count = BusinessConcepts.count_published_business_concepts(type, ids)
    if input_count == actual_count, do: {:valid_related_to}, else: {:not_valid_related_to}
  end

  defp add_to_filter_as_int_list(filter, name, nil), do: Map.put(filter, name, [])
  defp add_to_filter_as_int_list(filter, name, value) do
    list_value = value
    |> String.split(",")
    |> Enum.map(&String.to_integer(String.trim(&1)))
    Map.put(filter, name, list_value)
  end

  defp add_to_filter_as_list(filter, name, nil), do: Map.put(filter, name, [])
  defp add_to_filter_as_list(filter, name, value) do
    list_value = value
    |> String.split(",")
    |> Enum.map(&String.trim(&1))
    Map.put(filter, name, list_value)
  end

  defp get_current_user(conn) do
    GuardianPlug.current_resource(conn)
  end

end
