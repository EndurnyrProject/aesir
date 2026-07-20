defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrKyrie do
  @moduledoc """
  Kyrie Eleison (PR_KYRIE). Applies a physical-damage barrier to a player.

  rAthena Renewal: `db/re/skill_db.yml:2581-2618` and
  `src/map/status.cpp:10332-10335,10914-10921`. The first status gate rejects
  mob carriers; the second block derives barrier HP and hit count from the
  target's max HP and selected skill level.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 73,
    name: :pr_kyrie,
    status: :sc_kyrie,
    display_name: "Kyrie Eleison",
    max_level: 10,
    target_type: :target_ally,
    damage_type: :no_damage,
    range: 9,
    cast_time: List.duplicate(1_600, 10),
    fixed_cast_time: List.duplicate(400, 10),
    after_cast_delay: List.duplicate(2_000, 10),
    sp_cost: [20, 20, 20, 25, 25, 25, 30, 30, 30, 35],
    duration: List.duplicate(120_000, 10)

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :invalid_target}
  def validate(_caster, :self, _level, _definition), do: :ok

  def validate(_caster, {:unit, target_id}, _level, _definition) do
    if UnitRegistry.unit_exists?(:player, target_id), do: :ok, else: {:error, :invalid_target}
  end

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, :invalid_target}
  def cast(%{character_id: caster_id} = caster, target, level, definition) do
    with {:ok, target_id, target_state} <- resolve_player_target(caster, target),
         :ok <-
           StatusInterpreter.apply_status(:player, target_id, :sc_kyrie,
             val1: level,
             val2: barrier_hp(target_state, level),
             val3: div(level, 2) + 5,
             caster_id: caster_id,
             duration: Enum.at(definition.duration, level - 1)
           ) do
      {:ok, caster}
    end
  end

  defp resolve_player_target(%{character_id: caster_id} = caster, :self),
    do: {:ok, caster_id, caster}

  defp resolve_player_target(_caster, {:unit, target_id}) do
    case UnitRegistry.get_unit(:player, target_id) do
      {:ok, {_module, target_state, _pid}} -> {:ok, target_id, target_state}
      {:error, :not_found} -> {:error, :invalid_target}
    end
  end

  defp barrier_hp(%{stats: %{derived_stats: %{max_hp: max_hp}}}, level),
    do: div(max_hp * (2 * level + 10), 100)
end
