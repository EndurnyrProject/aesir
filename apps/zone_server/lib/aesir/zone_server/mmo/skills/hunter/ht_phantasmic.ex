defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtPhantasmic do
  @moduledoc """
  Phantasmic Arrow (HT_PHANTASMIC). Hunter quest skill: a single instant bow
  hit at 500% Wind weapon damage that knocks a surviving target back 3 cells.

  Grant-only: absent from the normal Hunter skill tree, learnable only through
  a permanent quest-skill grant (`Definition.quest_skill`/`quest_owner_job`,
  checked by the interpreter's quest-lineage gate). No arrow is required or
  consumed, only an equipped bow. Knockback fires only when the strike
  connects and the prepared damage is not predicted to be lethal - a miss or
  a killing blow leaves the target in place.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 1009,
    name: :ht_phantasmic,
    display_name: "Phantasmic Arrow",
    max_level: 1,
    target_type: :target_enemy,
    damage_type: :damage,
    range: -1,
    element: :wind,
    knockback: 3,
    sp_cost: [50],
    quest_skill: true,
    quest_owner_job: :hunter

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @behaviour Active

  @impl Active
  def validate(%PlayerState{stats: %{equipment: equipment}}, _target, _level, _definition) do
    if Stats.weapon_type(equipment) == :bow, do: :ok, else: {:error, :bow_not_equipped}
  end

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: 500,
      element: definition.element,
      hit_count: 1,
      skip_crit: true,
      base_distance: definition.knockback,
      origin: {caster.x, caster.y},
      native_target_types: [:mob],
      native_requires_survival: true
    ]

    case Combat.execute_skill_attack(caster, target_id, opts) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
