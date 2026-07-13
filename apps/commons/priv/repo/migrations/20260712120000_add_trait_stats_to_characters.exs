defmodule Aesir.Repo.Migrations.AddTraitStatsToCharacters do
  @moduledoc """
  Adds the six SP-B trait base stats (pow/sta/wis/spl/con/crt), the trait-point
  pool, and AP/max_ap to characters.
  """

  use Ecto.Migration

  def change do
    alter table(:characters) do
      add :pow, :integer, default: 0, null: false
      add :sta, :integer, default: 0, null: false
      add :wis, :integer, default: 0, null: false
      add :spl, :integer, default: 0, null: false
      add :con, :integer, default: 0, null: false
      add :crt, :integer, default: 0, null: false
      add :trait_point, :integer, default: 0, null: false
      add :ap, :integer, default: 0, null: false
      add :max_ap, :integer, default: 0, null: false
    end
  end
end
