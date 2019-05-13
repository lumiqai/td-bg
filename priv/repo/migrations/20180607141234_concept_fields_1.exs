defmodule TdBg.Repo.Migrations.ConceptFields1 do
  use Ecto.Migration

  def change do
    create table(:concept_fields) do
      add(:concept, :string)
      add(:field, :map)

      timestamps(type: :utc_datetime_usec)
    end
  end
end
