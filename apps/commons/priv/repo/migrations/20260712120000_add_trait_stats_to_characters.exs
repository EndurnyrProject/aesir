defmodule Aesir.Repo.Migrations.AddTraitStatsToCharacters do
  @moduledoc """
  Adds the six SP-B trait base stats (pow/sta/wis/spl/con/crt), the trait-point
  pool, and AP/max_ap to characters, then backfills `trait_point` for existing
  4th-job (trait-job) characters.

  Backfill formula (architecture Section 5.1, formula rows 25-26):
  `trait_point = trait_table[least(base_level, 275)] + 7` for trait-job
  characters at base level 201+; a flat `+7` for trait-job characters below
  201. The trait-point table (cumulative TraitPoints, levels 201-275) and the
  25 trait-job ids are embedded as SQL literals since commons cannot depend on
  zone_server data (`db/re/statpoint.yml`).
  """

  use Ecto.Migration

  @trait_job_ids [
    4252,
    4253,
    4254,
    4255,
    4256,
    4257,
    4258,
    4259,
    4260,
    4261,
    4262,
    4263,
    4264,
    4278,
    4279,
    4280,
    4281,
    4302,
    4303,
    4304,
    4305,
    4306,
    4307,
    4308,
    4316
  ]

  @trait_point_table [
    {201, 3},
    {202, 6},
    {203, 9},
    {204, 12},
    {205, 19},
    {206, 22},
    {207, 25},
    {208, 28},
    {209, 31},
    {210, 38},
    {211, 41},
    {212, 44},
    {213, 47},
    {214, 50},
    {215, 57},
    {216, 60},
    {217, 63},
    {218, 66},
    {219, 69},
    {220, 76},
    {221, 79},
    {222, 82},
    {223, 85},
    {224, 88},
    {225, 95},
    {226, 98},
    {227, 101},
    {228, 104},
    {229, 107},
    {230, 114},
    {231, 117},
    {232, 120},
    {233, 123},
    {234, 126},
    {235, 133},
    {236, 136},
    {237, 139},
    {238, 142},
    {239, 145},
    {240, 152},
    {241, 155},
    {242, 158},
    {243, 161},
    {244, 164},
    {245, 171},
    {246, 174},
    {247, 177},
    {248, 180},
    {249, 183},
    {250, 190},
    {251, 193},
    {252, 196},
    {253, 199},
    {254, 202},
    {255, 209},
    {256, 212},
    {257, 215},
    {258, 218},
    {259, 221},
    {260, 228},
    {261, 231},
    {262, 234},
    {263, 237},
    {264, 240},
    {265, 247},
    {266, 250},
    {267, 253},
    {268, 256},
    {269, 259},
    {270, 266},
    {271, 269},
    {272, 272},
    {273, 275},
    {274, 278},
    {275, 285}
  ]

  def up do
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

    execute(table_backfill_sql())
    execute(flat_backfill_sql())
  end

  def down do
    alter table(:characters) do
      remove :pow
      remove :sta
      remove :wis
      remove :spl
      remove :con
      remove :crt
      remove :trait_point
      remove :ap
      remove :max_ap
    end
  end

  @doc false
  def table_backfill_sql do
    values =
      Enum.map_join(@trait_point_table, ", ", fn {level, points} -> "(#{level}, #{points})" end)

    """
    UPDATE characters
    SET trait_point = t.points + 7
    FROM (VALUES #{values}) AS t(level, points)
    WHERE characters.class IN (#{trait_job_ids_sql()})
      AND LEAST(characters.base_level, 275) = t.level
    """
  end

  @doc false
  def flat_backfill_sql do
    """
    UPDATE characters
    SET trait_point = 7
    WHERE characters.class IN (#{trait_job_ids_sql()})
      AND characters.base_level < 201
    """
  end

  defp trait_job_ids_sql, do: Enum.join(@trait_job_ids, ", ")
end
