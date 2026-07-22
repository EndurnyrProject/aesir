defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlCrucis do
  @moduledoc """
  Signum Crucis (AL_CRUCIS). Self-centered splash that applies the permanent
  SC_SIGNUMCRUCIS DEF debuff to enemies that pass a landing roll.

  Each enemy in splash range rolls `rate = 25 + 4*level + (caster_base_level -
  target_base_level)`. On success, the target receives `sc_signumcrucis` with no
  expiry (permanent). SP is consumed whether or not any enemy is hit (deducted by
  the cast interpreter after `cast/4` returns).

  rAthena renewal: `SplashArea: 15`, `CastTime: 350`, `FixedCastTime: 150`,
  `AfterCastActDelay: 2000`, `Requires: SpAmount: 35`.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 32,
    name: :al_crucis,
    display_name: "Signum Crucis",
    max_level: 10,
    target_type: :self,
    damage_type: :no_damage,
    splash_radius: 15,
    sp_cost: List.duplicate(35, 10),
    cast_time: List.duplicate(350, 10),
    fixed_cast_time: List.duplicate(150, 10),
    after_cast_delay: List.duplicate(2_000, 10)

  alias Aesir.ZoneServer.Mmo.Combat
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
         {:ok, combatant} <- Combat.resolve_combatant(target_id) do
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
end
