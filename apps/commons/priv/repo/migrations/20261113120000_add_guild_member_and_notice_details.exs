defmodule Aesir.Repo.Migrations.AddGuildMemberAndNoticeDetails do
  use Ecto.Migration

  def change do
    alter table(:characters) do
      add :guild_exp, :bigint, null: false, default: 0
    end

    alter table(:guilds) do
      add :notice_author, :string
      add :notice_posted_at, :utc_datetime
    end

    alter table(:guild_positions) do
      add :can_notice, :boolean, null: false, default: false
      add :can_relations, :boolean, null: false, default: false
    end
  end
end
