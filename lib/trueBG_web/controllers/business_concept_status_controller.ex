defmodule TrueBGWeb.BusinessConceptStatusController do
  use TrueBGWeb, :controller

  import Canada, only: [can?: 2]

  alias TrueBG.BusinessConcepts
  alias TrueBG.BusinessConcepts.BusinessConcept
  alias TrueBG.BusinessConcepts.BusinessConceptVersion
  alias TrueBGWeb.BusinessConceptView
  alias TrueBGWeb.ErrorView

  action_fallback TrueBGWeb.FallbackController

  plug :load_resource, model: BusinessConcept, id_name: "business_concept_id", persisted: true, only: [:update]

  def update(conn, %{"business_concept_id" => id, "status" => new_status} = params) do

    business_concept_version = BusinessConcepts.get_business_concept!(id)
    status = business_concept_version.status
    user = conn.assigns.current_user

    draft = BusinessConcept.status.draft
    rejected = BusinessConcept.status.rejected
    pending_approval = BusinessConcept.status.pending_approval
    published = BusinessConcept.status.published

    case {status, new_status} do
      {^draft, ^pending_approval} ->
        send_for_approval(conn, user, business_concept_version, params)
      {^pending_approval, ^published} ->
        publish(conn, user,  business_concept_version, params)
      {^pending_approval, ^rejected} ->
        reject(conn, user,  business_concept_version, params)
      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  defp send_for_approval(conn, user, business_concept_version, _params) do
    attrs = %{status: BusinessConcept.status.pending_approval}
    with true <- can?(user, send_for_approval(business_concept_version)),
         {:ok, %BusinessConceptVersion{} = concept} <-
           BusinessConcepts.update_business_concept_status(business_concept_version, attrs) do
       render(conn, BusinessConceptView, "show.json", business_concept: concept)
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

  defp reject(conn, user, business_concept_version, params) do
    attrs = %{reject_reason: Map.get(params, "reject_reason")}
    with true <- can?(user, reject(business_concept_version)),
         {:ok, %BusinessConceptVersion{} = concept} <-
           BusinessConcepts.reject_business_concept(business_concept_version, attrs) do
       render(conn, BusinessConceptView, "show.json", business_concept: concept)
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

  defp publish(conn, user, business_concept_version, _parmas) do
    with true <- can?(user, publish(business_concept_version)),
         {:ok, %{published: %BusinessConceptVersion{} = concept}} <-
                    BusinessConcepts.publish_business_concept(business_concept_version) do
         render(conn, BusinessConceptView, "show.json", business_concept: concept)
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
end
