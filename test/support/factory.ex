defmodule TdBg.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: TdBg.Repo

  alias TdBg.BusinessConcepts.BusinessConcept
  alias TdBg.BusinessConcepts.BusinessConceptVersion

  def user_factory do
    %TdBg.Accounts.User{
      id: 0,
      user_name: "bufoncillo",
      is_admin: false,
      jti: 0
    }
  end

  def domain_factory do
    %TdBg.Taxonomies.Domain{
      name: "My domain",
      description: "My domain description"
    }
  end

  def child_domain_factory do
    %TdBg.Taxonomies.Domain{
      name: "My child domain",
      description: "My child domain description",
      parent: build(:domain)
    }
  end

  def business_concept_factory do
    %BusinessConcept{
      domain: build(:domain),
      type: "some_type",
      last_change_by: 1,
      last_change_at: DateTime.utc_now()
    }
  end

  def business_concept_version_factory do
    %BusinessConceptVersion{
      business_concept: build(:business_concept),
      content: %{},
      related_to: [],
      name: "My business term",
      description: %{"document" => "My business term description"},
      last_change_by: 1,
      last_change_at: DateTime.utc_now(),
      status: BusinessConcept.status().draft,
      version: 1,
      in_progress: false
    }
  end
end
