defmodule TdBg.Search do
  @moduledoc """
  Search Engine calls
  """

  alias TdBg.Search.Cluster

  require Logger

  @index "concepts"

  def search(query) do
    Logger.debug(fn -> "Query: #{inspect(query)}" end)
    response = Elasticsearch.post(Cluster, "/#{@index}/_search", query)

    case response do
      {:ok, %{"aggregations" => aggregations, "hits" => %{"hits" => results, "total" => total}}} ->
        %{results: results, total: total, aggregations: aggregations}

      {:ok, %{"hits" => %{"hits" => results, "total" => total}}} ->
        %{results: results, total: total, aggregations: %{}}

      {:error, %Elasticsearch.Exception{message: message} = error} ->
        Logger.warn("Error response from Elasticsearch: #{message}")
        error
    end
  end

  def get_filters(query) do
    response = Elasticsearch.post(Cluster, "/#{@index}/_search", query)

    case response do
      {:ok, %{"aggregations" => aggregations}} ->
        aggregations
        |> Map.to_list()
        |> Enum.into(%{}, &filter_values/1)

      {:error, %Elasticsearch.Exception{message: message} = error} ->
        Logger.warn("Error response from Elasticsearch: #{message}")
        error
    end
  end

  defp filter_values({name, %{"buckets" => buckets}}) do
    {name, buckets |> Enum.map(& &1["key"])}
  end

  defp filter_values({name, %{"distinct_search" => distinct_search}}) do
    filter_values({name, distinct_search})
  end
end
