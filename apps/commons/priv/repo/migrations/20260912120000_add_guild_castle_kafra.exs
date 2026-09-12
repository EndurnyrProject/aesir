defmodule Aesir.Repo.Migrations.AddGuildCastleKafra do
  use Ecto.Migration

  def change do
    alter table(:guild_castles) do
      add :kafra, :boolean, null: false, default: false
    end
  end
end
