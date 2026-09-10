defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlCrucis do
  @moduledoc """
  Signum Crucis (AL_CRUCIS). Self-centered splash that applies the permanent
  SC_SIGNUMCRUCIS DEF debuff to enemies that pass a landing roll.

  Only undead and demon enemies can carry the debuff: a target counts as undead
  by its undead defence element only (the default detection mode), or as demon by
  race, and everything else in range is left
  alone whatever the roll says. Players are excluded by construction, since a
  player is never undead or demon in either mode.

  Each eligible enemy within fifteen cells rolls `rate = 25 + 4*level +
  (caster_base_level - target_base_level)`. On success, the target receives
  `sc_signumcrucis`, a permanent DEF cut of `10 + 4*level` percent. SP is
  consumed whether or not any enemy is hit (deducted by the cast interpreter
  after `cast/4` returns).

  Renewal: a 350ms variable cast plus a fixed 150ms, then two seconds of
  after-cast delay.

  Pre-renewal: a flat 500ms cast with no fixed component, and the same two
  seconds of after-cast delay. The splash radius, landing roll, DEF cut and
  permanence are identical in both modes.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 32,
    name: :al_crucis,
    display_name: "Signum Crucis",
    max_level: 10,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :magic,
    splash_radius: 15,
    sp_cost: List.duplicate(35, 10),
    cast_time: [renewal: List.duplicate(350, 10), pre_renewal: List.duplicate(500, 10)],
    fixed_cast_time: [renewal: List.duplicate(150, 10), pre_renewal: []],
    after_cast_delay: List.duplicate(2_000, 10)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%{character_id: caster_id} = caster, :self, level, definition) do
    %{base_level: caster_base_level} = PlayerState.get_stats(caster)
    splash_enemies(caster_id, caster_base_level, level, definition)
    {:ok, caster}
  end

  defp splash_enemies(caster_id, caster_base_level, level, definition) do
    case SpatialIndex.get_unit_position(:player, caster_id) do
      {:ok, {cx, cy, map_name}} ->
        map_name
        |> Combat.splash_targets({cx, cy}, definition.splash_radius, caster_id)
        |> Enum.each(&try_apply_to_target(&1, level, caster_id, caster_base_level))

      {:error, _} ->
        :ok
    end
  end

  defp try_apply_to_target({unit_type, target_id}, level, caster_id, caster_base_level) do
    with {:ok, {_module, target_state, _pid}} <- UnitRegistry.get_unit(unit_type, target_id),
         true <- Unit.living?(target_state),
         {:ok, combatant} <- Combat.resolve_combatant(target_id),
         true <- eligible?(combatant) do
      rate = 25 + 4 * level + (caster_base_level - combatant.progression.base_level)

      if :rand.uniform(100) <= rate do
        StatusInterpreter.apply_status(unit_type, target_id, :sc_signumcrucis,
          val1: level,
          val2: 10 + 4 * level,
          caster_id: caster_id
        )
      end
    else
      _ -> :ok
    end
  end

  @spec eligible?(map()) :: boolean()
  defp eligible?(combatant), do: RaceModifiers.undead_or_demon?(combatant)
end
