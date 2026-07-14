defmodule Aesir.Repo.Migrations.CreateGuildsTable do
  use Ecto.Migration

  def change do
    create table(:guilds) do
      add :name, :string, null: false
      add :master_char_id, :bigint, null: false
      add :emblem_id, :integer, null: false, default: 0
      add :emblem_data, :binary
      add :notice_subject, :string
      add :notice_body, :text

      timestamps()
    end

    create unique_index(:guilds, [:name])
  end
end
