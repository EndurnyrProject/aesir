defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsCracker do
  @moduledoc """
  Cracker spends one coin and ammunition to stun a player or mob. Its chance
  falls from 65% by 5 points per cell to a minimum of 30%. Stun lasts 4.5
  seconds in renewal and 5 seconds in pre-renewal.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 508,
    name: :gs_cracker,
    display_name: "Cracker",
    max_level: 1,
    requires: [],
    target_type: :target_enemy,
    damage_type: :no_damage,
    damage_kind: :weapon,
    element: :weapon,
    range: -9,
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
    sp_cost: [10],
    sphere_cost: [1],
    after_cast_delay: [1000]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  def cast(%PlayerState{} = caster, {:unit, target}, level, _definition) do
    case TargetResolver.resolve_target_position(target) do
      {:ok, type, {x, y, _map}} when type in [:player, :mob] ->
        {_, id} = if is_tuple(target), do: target, else: {type, target}
        distance = Geometry.chebyshev_distance(caster.x, caster.y, x, y)
        duration = if GameMode.mode() == :renewal, do: 4_500, else: 5_000

        StatusInterpreter.apply_status(type, id, :sc_stun,
          val1: level,
          duration: duration,
          success_rate: max(65 - 5 * distance, 30),
          caster_id: caster.character_id,
          source_type: :player
        )

        {:ok, caster}

      {:ok, _type, _position} ->
        {:ok, caster}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def cast(caster, _target, _level, _definition), do: {:ok, caster}
end
