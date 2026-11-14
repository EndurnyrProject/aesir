defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsGatlingfever do
  @moduledoc """
  Gatling Fever (GS_GATLINGFEVER) toggles a Gatling-only self buff.
  Renewal has a one-second cast and delay; pre-renewal has neither.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 517,
    name: :gs_gatlingfever,
    display_name: "Gatling Fever",
    max_level: 10,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :weapon,
    status: :sc_gatlingfever,
    toggleable: true,
    require_weapon: [:gatling],
    sp_cost: [30, 32, 34, 36, 38, 40, 42, 44, 46, 48],
    cast_time: [renewal: [800], pre_renewal: []],
    fixed_cast_time: [renewal: [200], pre_renewal: []],
    after_cast_delay: [renewal: [1000], pre_renewal: []],
    duration: [
      30_000,
      45_000,
      60_000,
      75_000,
      90_000,
      105_000,
      120_000,
      135_000,
      150_000,
      165_000
    ]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()}
  def cast(%PlayerState{character_id: id} = caster, :self, level, definition) do
    toggle(:player, id, level, definition)
    {:ok, caster}
  end

  @impl Active
  def mob_cast(%MobState{instance_id: id} = caster, {:unit, :mob, id}, level, definition, _row) do
    toggle(:mob, id, level, definition)
    {:ok, caster}
  end

  defp toggle(type, id, level, definition) do
    StatusInterpreter.toggle_status(type, id, :sc_gatlingfever,
      val1: level,
      val2: 20 * level,
      val3: 20 + 10 * level,
      val4: 5 * level,
      caster_id: id,
      source_type: type,
      duration: Enum.fetch!(definition.duration, level - 1)
    )
  end
end
