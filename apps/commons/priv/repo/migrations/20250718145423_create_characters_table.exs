defmodule Aesir.Repo.Migrations.CreateCharactersTable do
  use Ecto.Migration

  def change do
    create table(:characters) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :char_num, :integer, null: false
      add :name, :string, null: false
      add :class, :integer, null: false
      add :base_level, :integer, default: 1
      add :job_level, :integer, default: 1
      add :base_exp, :bigint, default: 0
      add :job_exp, :bigint, default: 0
      add :zeny, :integer, default: 0
      add :str, :integer, default: 1
      add :agi, :integer, default: 1
      add :vit, :integer, default: 1
      add :int, :integer, default: 1
      add :dex, :integer, default: 1
      add :luk, :integer, default: 1
      add :max_hp, :integer, default: 40
      add :hp, :integer, default: 40
      add :max_sp, :integer, default: 11
      add :sp, :integer, default: 11
      add :status_point, :integer, default: 0
      add :skill_point, :integer, default: 0
      add :option, :integer, default: 0
      add :karma, :integer, default: 0
      add :manner, :integer, default: 0
      add :party_id, :integer, default: 0
      add :guild_id, :integer, default: 0
      add :pet_id, :integer, default: 0
      add :homun_id, :integer, default: 0
      add :elemental_id, :integer, default: 0
      add :hair, :integer, default: 0
      add :hair_color, :integer, default: 0
      add :clothes_color, :integer, default: 0
      add :weapon, :integer, default: 0
      add :shield, :integer, default: 0
      add :head_top, :integer, default: 0
      add :head_mid, :integer, default: 0
      add :head_bottom, :integer, default: 0
      add :robe, :integer, default: 0
      add :last_map, :string, default: "new_1-1"
      add :last_x, :integer, default: 53
      add :last_y, :integer, default: 111
      add :save_map, :string, default: "new_1-1"
      add :save_x, :integer, default: 53
      add :save_y, :integer, default: 111
      add :partner_id, :integer, default: 0
      add :online, :integer, default: 0
      add :father, :integer, default: 0
      add :mother, :integer, default: 0
      add :child, :integer, default: 0
      add :fame, :integer, default: 0
      add :rename, :integer, default: 0
      add :delete_date, :naive_datetime
      add :moves, :integer, default: 0
      add :unban_time, :naive_datetime
      add :font, :integer, default: 0
      add :uniqueitem_counter, :integer, default: 0
      add :sex, :string, size: 1, default: "U"
      add :hotkey_rowshift, :integer, default: 0
      add :clan_id, :integer, default: 0
      add :last_login, :naive_datetime
      add :title_id, :integer, default: 0
      add :show_equip, :integer, default: 0
      
      timestamps()
    end

    create unique_index(:characters, [:account_id, :char_num])
    create unique_index(:characters, [:name])
    create index(:characters, [:account_id])
    create index(:characters, [:class])
    create index(:characters, [:guild_id])
    create index(:characters, [:party_id])
    create index(:characters, [:online])
  end
end
