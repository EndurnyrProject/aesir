defmodule Aesir.Repo.Migrations.AddNextTickMsToCharacterStatuses do
  use Ecto.Migration

  def change do
    alter table(:character_statuses) do
      add :next_tick_ms, :bigint
    end
  end
end
