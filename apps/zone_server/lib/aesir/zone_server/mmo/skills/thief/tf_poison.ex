defmodule Aesir.ZoneServer.Mmo.Skills.Thief.TfPoison do
  @moduledoc """
  Envenom (TF_POISON). Weapon strike that adds flat mastery ATK and can poison.

  rAthena renewal: 100% weapon damage + `15 * level` flat ATK, poison element,
  no crit, weapon range. On a connecting hit it rolls `4 * level + 10`% to apply
  `sc_poison` for 18000 ms.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 52,
    name: :tf_poison,
    requires: [],
    display_name: "Envenom",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    element: :poison,
    range: -1,
    sp_cost: List.duplicate(12, 10)

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Shared.Envenom

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target}, level, _definition),
    do: Envenom.execute(caster, target, level)
end
