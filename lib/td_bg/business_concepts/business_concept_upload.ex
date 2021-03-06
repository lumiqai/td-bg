defmodule TdBg.BusinessConcept.Upload do
  @moduledoc """
  Helper module to upload business concepts in csv format.
  """

  @required_header ["template", "domain", "name", "description"]

  alias Codepagex
  alias NimbleCSV
  alias TdBg.BusinessConcepts
  alias TdBg.BusinessConcepts.BusinessConcept
  alias TdBg.BusinessConcepts.Events
  alias TdBg.Cache.ConceptLoader
  alias TdBg.Repo
  alias TdBg.Taxonomies
  alias TdCache.TemplateCache

  require Logger

  NimbleCSV.define(ParserCSVUpload, separator: ";")

  def from_csv(nil, _user), do: {:error, %{message: :no_csv_uploaded}}

  def from_csv(business_concept_upload, user) do
    path = business_concept_upload.path

    case create_concepts(path, user) do
      {:ok, concept_ids} ->
        Events.business_concepts_created(concept_ids)
        ConceptLoader.refresh(concept_ids)
        {:ok, concept_ids}

      error ->
        error
    end
  end

  defp create_concepts(path, user) do
    Logger.info("Inserting business concepts...")
    start_time = DateTime.utc_now()

    transaction_result =
      Repo.transaction(fn ->
        upload_in_transaction(path, user)
      end)

    end_time = DateTime.utc_now()

    Logger.info(
      "Business concepts inserted. Elapsed seconds: #{DateTime.diff(end_time, start_time)}"
    )

    transaction_result
  end

  defp upload_in_transaction(path, user) do
    file =
      path
      |> Path.expand()
      |> File.stream!()

    with {:ok, parsed_file} <- parse_file(file),
         {:ok, parsed_list} <- parse_data_list(parsed_file),
         {:ok, uploaded_ids} <- upload_data(parsed_list, user, [], 2) do
      uploaded_ids
    else
      {:error, err} -> Repo.rollback(err)
    end
  end

  defp parse_file(file) do
    parsed_file =
      file
      |> ParserCSVUpload.parse_stream(headers: false)
      |> Enum.to_list()

    {:ok, parsed_file}
  rescue
    _ -> {:error, %{error: :invalid_file_format}}
  end

  defp parse_data_list([headers | tail]) do
    case Enum.reduce(@required_header, true, fn head, acc ->
           Enum.member?(headers, head) and acc
         end) do
      true ->
        parsed_list =
          tail
          |> Enum.map(&parse_uncoded_rows(&1))
          |> Enum.map(&row_list_to_map(headers, &1))

        {:ok, parsed_list}

      false ->
        {:error, %{error: :missing_required_columns, expected: @required_header, found: headers}}
    end
  end

  defp parse_uncoded_rows(fiel_row_list) do
    fiel_row_list
    |> Enum.map(fn row ->
      case String.valid?(row) do
        true ->
          row

        false ->
          Codepagex.to_string!(
            row,
            "VENDORS/MICSFT/WINDOWS/CP1252",
            Codepagex.use_utf_replacement()
          )
      end
    end)
  end

  defp row_list_to_map(headers, row) do
    headers
    |> Enum.zip(row)
    |> Enum.into(%{})
  end

  defp upload_data([head | tail], user, acc, row_count) do
    case insert_business_concept(head, user) do
      {:ok, %{business_concept_id: concept_id}} ->
        upload_data(tail, user, [concept_id | acc], row_count + 1)

      {:error, error} ->
        {:error, Map.put(error, :row, row_count)}
    end
  end

  defp upload_data(_, _, acc, _), do: {:ok, acc}

  defp insert_business_concept(data, user) do
    with {:ok, %{name: concept_type, content: content_schema}} <- validate_template(data),
         {:ok} <- validate_name(data),
         {:ok, %{id: domain_id}} <- validate_domain(data),
         {:ok} <- validate_description(data) do

      empty_fields =
        Enum.filter(Map.keys(data), fn field_name ->
          Map.get(data, field_name) == nil or Map.get(data, field_name) == ""
        end)

      table_fields =
        content_schema
        |> Enum.filter(fn field ->
          Map.get(field, "type") == "table"
        end)
        |> Enum.map(&Map.get(&1, "name"))

      content =
        data
        |> Map.drop([
          "name",
          "domain",
          "description",
          "template"
        ])
        |> Map.drop(empty_fields)
        |> Map.drop(table_fields)

      business_concept_attrs =
        %{}
        |> Map.put("domain_id", domain_id)
        |> Map.put("type", concept_type)
        |> Map.put("last_change_by", user.id)
        |> Map.put("last_change_at", DateTime.utc_now())

      creation_attrs =
        data
        |> Map.take(["name"])
        |> Map.put("description", convert_description(Map.get(data, "description")))
        |> Map.put("content", content)
        |> Map.put("business_concept", business_concept_attrs)
        |> Map.put("content_schema", content_schema)
        |> Map.update("related_to", [], & &1)
        |> Map.put("last_change_by", user.id)
        |> Map.put("last_change_at", DateTime.utc_now())
        |> Map.put("status", BusinessConcept.status().draft)
        |> Map.put("version", 1)

      BusinessConcepts.create_business_concept(creation_attrs)
    else
      error -> error
    end
  end

  defp validate_template(%{"template" => ""}),
    do: {:error, %{error: :missing_value, field: "template"}}

  defp validate_template(%{"template" => template}) do
    case TemplateCache.get_by_name!(template) do
      nil ->
        {:error, %{error: :invalid_template, template: template}}

      template ->
        {:ok, template}
    end
  end

  defp validate_template(_), do: {:error, %{error: :missing_value, field: "template"}}

  defp validate_name(%{"name" => ""}), do: {:error, %{error: :missing_value, field: "name"}}

  defp validate_name(%{"name" => name, "template" => template}) do
    case BusinessConcepts.check_business_concept_name_availability(template, name) do
      {:name_available} -> {:ok}
      _ -> {:error, %{error: :name_not_available, name: name}}
    end
  end

  defp validate_name(_), do: {:error, %{error: :missing_value, field: "name"}}

  defp validate_domain(%{"domain" => ""}), do: {:error, %{error: :missing_value, field: "domain"}}

  defp validate_domain(%{"domain" => domain}) do
    case Taxonomies.get_domain_by_name(domain) do
      nil -> {:error, %{error: :invalid_domain, domain: domain}}
      domain -> {:ok, domain}
    end
  end

  defp validate_domain(_), do: {:error, %{error: :missing_value, field: "domain"}}

  defp validate_description(%{"description" => ""}),
    do: {:error, %{error: :missing_value, field: "description"}}

  defp validate_description(%{"description" => _}), do: {:ok}
  defp validate_description(_), do: {:error, %{error: :missing_value, field: "description"}}

  defp convert_description(description) do
    %{
      document: %{
        nodes: [
          %{
            object: "block",
            type: "paragraph",
            nodes: [%{object: "text", leaves: [%{text: description}]}]
          }
        ]
      }
    }
  end
end
