defmodule Aesir.Repo.Migrations.AddGuildPositionToCharacters do
  use Ecto.Migration

  def change do
    alter table(:characters) do
      add :guild_position, :smallint, null: false, default: 0
    end
  end
end
