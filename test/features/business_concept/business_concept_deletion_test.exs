defmodule TdBg.BusinessConceptDeletionTest do
  use Cabbage.Feature, file: "business_concept/business_concept_deletion.feature"
  use TdBgWeb.FeatureCase
  import TdBgWeb.BusinessConcept

  import TdBgWeb.ResponseCode
  import TdBgWeb.User, only: :functions
  import TdBgWeb.Taxonomy, only: :functions
  import TdBgWeb.AclEntry, only: :functions
  import TdBgWeb.Authentication, only: :functions

  alias TdBg.BusinessConcepts.BusinessConcept
  alias TdBg.Utils.CollectionUtils
  alias TdBgWeb.ApiServices.MockTdAuditService
  alias TdBgWeb.ApiServices.MockTdAuthService

  import_steps TdBg.BusinessConceptSteps
  import_steps TdBg.DomainSteps
  import_steps TdBg.ResultSteps
  import_steps TdBg.UsersSteps

  import TdBg.BusinessConceptSteps
  import TdBg.ResultSteps

  setup_all do
    start_supervised MockTdAuthService
    start_supervised MockTdAuditService
    :ok
  end

  setup do
    on_exit fn ->
      rm_business_concept_schema()
    end
  end

end
