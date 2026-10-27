defmodule Aesir.Repo.Migrations.AddSourceTypeToCharacterStatuses do
  use Ecto.Migration

  def change do
    alter table(:character_statuses) do
      add :source_type, :string
    end
  end
end
