defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AmSpheremine do
  @moduledoc """
  Summons a Marine Sphere at the targeted map cell for thirty seconds.

  The living per-owner cap is checked during skill validation so a rejected
  cast spends neither SP nor its Marine Sphere Bottle.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 233,
    name: :am_spheremine,
    display_name: "Sphere Mine",
    max_level: 5,
    target_type: :ground,
    damage_type: :no_damage,
    range: 1,
    sp_cost: List.duplicate(10, 5),
    item_cost: [%{id: 7_138, amount: 1}],
    cast_time: List.duplicate(1_600, 5),
    fixed_cast_time: List.duplicate(400, 5),
    after_cast_delay: List.duplicate(500, 5)

  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @mob_id 1_142
  @cap 3

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, atom()}
  def validate(%{character_id: owner_id}, {:ground, _x, _y}, _level, _definition) do
    if UnitRegistry.count_living_owned_mobs(owner_id, @mob_id) < @cap do
      :ok
    else
      {:error, :summon_cap_reached}
    end
  end

  def validate(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(caster, {:ground, x, y}, _level, _definition) do
    case Coordinator.summon_mob(caster.map_name, @mob_id, x, y,
           owner_player_id: caster.character_id,
           lifetime_ms: 30_000,
           no_exp: true,
           no_drops: false
         ) do
      {:ok, _instance_id} -> {:ok, caster}
      {:error, reason} -> {:error, reason}
    end
  end

  def cast(_caster, _target, _level, _definition), do: {:error, :invalid_target}
end
