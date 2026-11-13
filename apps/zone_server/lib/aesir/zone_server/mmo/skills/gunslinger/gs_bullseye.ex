defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsBullseye do
  @moduledoc """
  Bull's Eye fires one shot for 500% weapon damage against a Brute,
  Demi-Human or player-race target that is not status-immune, and 100%
  otherwise. A landed hit on one of those races that the target survives
  rolls a 0.1% coma. It ignores attack cards, Auto Guard and Cicada and never
  crits. Renewal casts in 800 ms plus 200 ms fixed with a one-second delay;
  pre-renewal casts in 500 ms without a delay.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 503,
    name: :gs_bullseye,
    display_name: "Bull's Eye",
    max_level: 1,
    requires: [],
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :weapon,
    range: -9,
    element: :weapon,
    ignore_atk_card: true,
    ignore_auto_guard: true,
    ignore_cicada: true,
    require_ammo: [
      :arrow,
      :dagger,
      :bullet,
      :shell,
      :grenade,
      :shuriken,
      :kunai,
      :cannonball,
      :throw_weapon
    ],
    ammo_qty: [1],
    sp_cost: [30],
    sphere_cost: [1],
    cast_time: [renewal: [800], pre_renewal: [500]],
    fixed_cast_time: [renewal: [200], pre_renewal: []],
    after_cast_delay: [renewal: [1000], pre_renewal: []]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.Coma
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @behaviour Active

  @coma_races [:brute, :demi_human, :player_human, :player_doram]

  @impl Active
  def cast(caster, {:unit, target}, level, definition) do
    with :ok <- strike(caster, target, level, definition), do: {:ok, caster}
  end

  @impl Active
  def mob_cast(%MobState{} = caster, {:unit, type, id}, level, definition, _row),
    do: strike(caster, {type, id}, level, definition)

  @doc "The skill ratio against a target: 500 for a vulnerable race, else 100."
  @spec ratio(Combatant.t()) :: pos_integer()
  def ratio(%Combatant{race: race, status_immune: false}) when race in @coma_races, do: 500
  def ratio(%Combatant{}), do: 100

  defp strike(caster, target, level, definition) do
    case Combat.execute_skill_attack(caster, target,
           skill_id: definition.id,
           skill_level: level,
           skill_ratio: {:target, &ratio/1},
           skip_range: true,
           skip_crit: true,
           report_hit: true
         ) do
      {:ok, %{hit?: true, target_survives?: true}} -> coma(target)
      {:ok, _report} -> :ok
      {:error, _reason} = error -> error
    end
  end

  defp coma(target) do
    with {:ok, %Combatant{race: race, unit_type: type, unit_id: id}} when race in @coma_races <-
           TargetResolver.resolve_combatant(target) do
      Coma.attempt(type, id, rate: 10)
    end

    :ok
  end
end
