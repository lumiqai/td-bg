defmodule TdBg.Canary.BusinessConceptAbilities do
  @moduledoc false
  alias TdBg.Accounts.User
  alias TdBg.Taxonomies.Domain
  alias TdBg.BusinessConcepts.BusinessConcept
  alias TdBg.BusinessConcepts.BusinessConceptVersion
  alias TdBg.Permissions

  def can?(%User{id: user_id}, :create_business_concept, %Domain{id: domain_id})  do
    %{user_id: user_id,
      action: :create,
      domain_id: domain_id}
    |> can_execute_action?
  end

  def can?(%User{id: user_id}, :update, %BusinessConceptVersion{status: status, business_concept: %BusinessConcept{domain_id: domain_id}}) do
    %{user_id: user_id, action: :update,
      current_status: status,
      required_statuses: [BusinessConcept.status.draft, BusinessConcept.status.rejected],
      domain_id: domain_id}
    |> can_execute_action?
  end

  def can?(%User{id: user_id}, :send_for_approval, %BusinessConceptVersion{status: status, business_concept: %BusinessConcept{domain_id: domain_id}}) do
    %{user_id: user_id, action: :send_for_approval,
      current_status: status,
      required_statuses: [BusinessConcept.status.draft, BusinessConcept.status.rejected],
      domain_id: domain_id}
    |> can_execute_action?
  end

  def can?(%User{id: user_id}, :reject, %BusinessConceptVersion{status: status, business_concept: %BusinessConcept{domain_id: domain_id}}) do
    %{user_id: user_id, action: :reject,
      current_status: status,
      required_statuses: [BusinessConcept.status.pending_approval, BusinessConcept.status.rejected],
      domain_id: domain_id}
    |> can_execute_action?
  end

  def can?(%User{id: user_id}, :publish, %BusinessConceptVersion{status: status, business_concept: %BusinessConcept{domain_id: domain_id}}) do
    %{user_id: user_id, action: :publish,
      current_status: status,
      required_statuses: [BusinessConcept.status.pending_approval],
      domain_id: domain_id}
    |> can_execute_action?
  end

  def can?(%User{id: user_id}, :deprecate, %BusinessConceptVersion{status: status, business_concept: %BusinessConcept{domain_id: domain_id}}) do
    %{user_id: user_id, action: :deprecate,
      current_status: status,
      required_statuses: [BusinessConcept.status.published],
      domain_id: domain_id}
    |> can_execute_action?
  end

  def can?(%User{id: user_id}, :update_published, %BusinessConceptVersion{status: status, business_concept: %BusinessConcept{domain_id: domain_id}}) do
    %{user_id: user_id, action: :update,
      current_status: status,
      required_statuses: [BusinessConcept.status.published],
      domain_id: domain_id}
    |> can_execute_action?
  end

  def can?(%User{id: user_id}, :delete, %BusinessConceptVersion{status: status, business_concept: %BusinessConcept{domain_id: domain_id}}) do
    %{user_id: user_id, action: :delete,
      current_status: status,
      required_statuses: [BusinessConcept.status.draft, BusinessConcept.status.rejected],
      domain_id: domain_id}
    |> can_execute_action?
  end

  def can?(%User{id: user_id}, :view_versions, %BusinessConceptVersion{status: status, business_concept: %BusinessConcept{domain_id: domain_id}}) do
    %{user_id: user_id, action: :view_versions,
      current_status: status,
      required_statuses: [BusinessConcept.status.draft, BusinessConcept.status.pending_approval, BusinessConcept.status.rejected,
                          BusinessConcept.status.published, BusinessConcept.status.versioned, BusinessConcept.status.deprecated],
      domain_id: domain_id}
    |> can_execute_action?
  end

  def can?(%User{id: user_id}, :manage_alias, %BusinessConceptVersion{status: status, business_concept: %BusinessConcept{domain_id: domain_id}}) do
    %{user_id: user_id, action: :manage_alias,
      current_status: status,
      required_statuses: [BusinessConcept.status.draft, BusinessConcept.status.published],
      domain_id: domain_id}
    |> can_execute_action?
  end

  def can?(%User{}, _action, _domain),  do: false

  defp can_execute_action?(%{user_id: _user_id,
                             action: _action,
                             current_status: current_status,
                             required_statuses: required_statuses,
                             domain_id: _domain_id} = params) do
    (params |> allowed_action?) &&
    Enum.member?(required_statuses, current_status)
  end

  defp can_execute_action?(%{user_id: _user_id,
                             action: _action,
                             domain_id: _domain_id} = params) do
    params |> allowed_action?
  end

  defp allowed_action?(%{user_id: user_id, action: action, domain_id: domain_id}) do
    role_in_resource = Permissions.get_role_in_resource(%{user_id: user_id, domain_id: domain_id})
    if role_in_resource do
      role_name = role_in_resource |> Map.get(:name) |> String.to_atom
      BusinessConcept.get_permissions() |> Map.get(role_name) |> Enum.member?(action)
    else
      false
    end
  end

end
