defmodule TrueBG.Repo.Migrations.AddRejectReason do
  use Ecto.Migration

  def change do
    alter table(:business_concepts) do
      add :reject_reason, :string, null: true
    end
  end
end