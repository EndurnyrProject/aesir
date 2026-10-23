defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AmCannibalize do
  @moduledoc """
  Cultivates one level-selected plant at the targeted map cell.

  Each plant class has its own living per-owner cap, counted among the
  caster's own flora summons standing on the caster's map only. The cast is
  refused at its begin, so a rejected cast spends neither SP nor its Plant
  Bottle. Another plant class out also refuses the cast: the reference's
  shipped summon setting enables that rule in both modes.

  Renewal: a 1.6 s cast plus 0.4 s fixed. Pre-renewal: a 2 s cast. Costs, delay,
  and lifetimes are shared.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 232,
    name: :am_cannibalize,
    requires: [],
    display_name: "Bio Cannibalize",
    max_level: 5,
    target_type: :ground,
    damage_type: :no_damage,
    range: 4,
    sp_cost: List.duplicate(20, 5),
    item_cost: [%{id: 7_137, amount: 1}],
    cast_time: [renewal: List.duplicate(1_600, 5), pre_renewal: List.duplicate(2_000, 5)],
    fixed_cast_time: [renewal: List.duplicate(400, 5), pre_renewal: []],
    after_cast_delay: List.duplicate(500, 5),
    damage_kind: :none

  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @mobs [1_589, 1_579, 1_575, 1_555, 1_590]
  @lifetimes [300_000, 240_000, 180_000, 120_000, 60_000]

  @doc """
  The cast-begin cap: at most `6 - level` of this level's plant may stand on
  the caster's map, and no other plant class may be out beside this one.
  """
  @impl Active
  @spec begin_attempt(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, :summon_cap_reached}
  def begin_attempt(
        %{character_id: owner_id, map_name: map_name} = caster,
        {:ground, _x, _y},
        level,
        _definition
      ) do
    mob_id = Enum.fetch!(@mobs, level - 1)
    {flora, plants} = UnitRegistry.count_owned_summons(owner_id, map_name, :flora, mob_id)

    if plants >= 6 - level or plants != flora,
      do: {:error, :summon_cap_reached},
      else: {:ok, caster}
  end

  def begin_attempt(caster, _target, _level, _definition), do: {:ok, caster}

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :invalid_target}
  def validate(%PlayerState{}, {:ground, _x, _y}, _level, _definition), do: :ok
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
           summon_kind: :flora,
           master_speed: PlayerState.base_walk_speed(),
           hp_override: 1_500 + 200 * level + 10 * base_level,
           lifetime_ms: lifetime_ms,
           no_exp: true,
           no_drops: true
         ) do
      {:ok, _instance_id} ->
        {:ok, caster}

      # A failed spawn summons nothing without failing the cast: the reference
      # only enters its setup block when the spawn returned a mob.
      {:error, _reason} ->
        {:ok, caster}
    end
  end

  def cast(_caster, _target, _level, _definition), do: {:error, :invalid_target}
end
