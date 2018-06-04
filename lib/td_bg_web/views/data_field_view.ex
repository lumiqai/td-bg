defmodule TdBgWeb.DataFieldView do
  use TdBgWeb, :view
  use TdBg.Hypermedia, :view

  alias TdBgWeb.DataFieldView

  def render("data_fields.json", %{data_fields: data_fields}) do
    %{data: render_many(data_fields, DataFieldView, "data_field.json")}
  end

  def render("data_field.json", %{data_field: data_field}) do
    %{
      system: data_field.system,
      group: data_field.group,
      structure: data_field.structure,
      name: data_field.name
    }
  end
end
