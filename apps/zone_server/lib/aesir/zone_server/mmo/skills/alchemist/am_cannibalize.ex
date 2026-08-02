defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AmCannibalize do
  @moduledoc """
  Cultivates one level-selected plant at the targeted map cell.

  Each plant class has its own living per-owner cap. The cap is checked during
  skill validation so a rejected cast spends neither SP nor its Plant Bottle.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 232,
    name: :am_cannibalize,
    display_name: "Bio Cannibalize",
    max_level: 5,
    target_type: :ground,
    damage_type: :no_damage,
    range: 4,
    sp_cost: List.duplicate(20, 5),
    item_cost: [%{id: 7_137, amount: 1}],
    cast_time: List.duplicate(1_600, 5),
    fixed_cast_time: List.duplicate(400, 5),
    after_cast_delay: List.duplicate(500, 5)

  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @mobs [1_589, 1_579, 1_575, 1_555, 1_590]
  @lifetimes [300_000, 240_000, 180_000, 120_000, 60_000]

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, atom()}
  def validate(%{character_id: owner_id}, {:ground, _x, _y}, level, _definition) do
    mob_id = Enum.fetch!(@mobs, level - 1)

    if UnitRegistry.count_living_owned_mobs(owner_id, mob_id) < 6 - level do
      :ok
    else
      {:error, :summon_cap_reached}
    end
  end

  def validate(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(caster, {:ground, x, y}, level, _definition) do
    mob_id = Enum.fetch!(@mobs, level - 1)
    lifetime_ms = Enum.fetch!(@lifetimes, level - 1)
    base_level = caster.stats.progression.base_level

    case Coordinator.summon_mob(caster.map_name, mob_id, x, y,
           owner_player_id: caster.character_id,
           hp_override: 1_500 + 200 * level + 10 * base_level,
           lifetime_ms: lifetime_ms,
           no_exp: true,
           no_drops: true
         ) do
      {:ok, _instance_id} -> {:ok, caster}
      {:error, reason} -> {:error, reason}
    end
  end

  def cast(_caster, _target, _level, _definition), do: {:error, :invalid_target}
end
