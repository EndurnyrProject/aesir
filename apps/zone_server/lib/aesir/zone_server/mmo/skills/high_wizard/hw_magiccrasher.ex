defmodule Aesir.ZoneServer.Mmo.Skills.HighWizard.HwMagiccrasher do
  @moduledoc """
  Stave Crasher (HW_MAGICCRASHER). A single weapon strike at up to 9 cells,
  resolved as a long-range physical hit empowered by one roll of the caster's
  MATK band. It never crits.

  The strike takes the weapon element, then a forced neutral attribute step
  after defense.

  Renewal: a player's rolled MATK joins the weapon ATK component after the
  equipment ATK-rate share and before the weapon cards, so it skips the
  weapon's size and attribute steps. A monster's ordinary hit gains nothing
  from it. The equipment non-critical rate does not apply. 0.24 s cast plus
  0.06 s fixed.

  Pre-renewal: the rolled MATK replaces the weapon roll. Base ATK, overrefine,
  and status weapon ATK and ATK rate drop out, while size, refine, mastery,
  defense and cards remain. A positive non-critical rate applies. 0.3 s cast.

  Both modes: 8 SP and a 0.3 s after-cast delay. Monsters cast it through
  `mob_cast/5`.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 365,
    name: :hw_magiccrasher,
    requires: [],
    display_name: "Stave Crasher",
    max_level: 1,
    ignore_noncrit_atk_bonus: [renewal: true, pre_renewal: false],
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :weapon,
    range: 9,
    sp_cost: [8],
    cast_time: [renewal: [240], pre_renewal: [300]],
    fixed_cast_time: [renewal: [60], pre_renewal: []],
    after_cast_delay: [300]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @behaviour Active

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, {:unit, target_id}, level, definition) do
    with :ok <- strike(caster, target_id, level, definition), do: {:ok, caster}
  end

  @impl Active
  @spec mob_cast(MobState.t(), term(), pos_integer(), Definition.t(), map()) ::
          :ok | {:error, atom()}
  def mob_cast(%MobState{} = caster, {:unit, type, id}, level, definition, _row) do
    strike(caster, {type, id}, level, definition)
  end

  defp strike(caster, target, level, definition) do
    attack_opts = [
      skill_id: definition.id,
      skill_level: level,
      skip_crit: true,
      ranged: true,
      skip_range: true
    ]

    case Combat.execute_stave_crasher_attack(caster, target, attack_opts) do
      {:error, _reason} = error -> error
      _result -> :ok
    end
  end
end
