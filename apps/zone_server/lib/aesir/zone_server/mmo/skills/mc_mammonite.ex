defmodule Aesir.ZoneServer.Mmo.Skills.McMammonite do
  @moduledoc """
  Mammonite (MC_MAMMONITE). Single-target physical strike on an enemy, paid for
  in zeny as well as SP.

  rAthena: base 100% + 50% per level weapon damage, no crit
  (`mammonite.cpp:9`: `base_skillratio += 50 * skill_lv`).
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 42,
    name: :mc_mammonite,
    display_name: "Mammonite",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    range: -1,
    sp_cost: [5, 5, 5, 5, 5, 5, 5, 5, 5, 5],
    zeny_cost: [100, 200, 300, 400, 500, 600, 700, 800, 900, 1000]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: 100 + 50 * level,
      skip_crit: true
    ]

    case Combat.execute_skill_attack(caster, target_id, opts) do
      :ok ->
        {:ok, caster}

      {:error, _reason} = error ->
        error
    end
  end
end
