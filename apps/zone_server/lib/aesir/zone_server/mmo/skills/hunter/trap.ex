defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.Trap do
  @moduledoc """
  Shared helpers for Hunter trap ground-units (HT_LANDMINE, HT_BLASTMINE).

  Not a skill itself - it factors out the bits the traps share: the placer-time
  damage stamping, the per-trigger variance roll, the hostility check, and
  resolving the placer's live state for the misc execute path.

  Traps are live immediately (no arming delay) and fire on the first enemy
  contact.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # the trap item (Booby Trap): the item returned when reclaiming one
  # placed Hunter trap.
  @trap_item_id 1065

  @doc """
  Builds the initial group state: the deterministic base damage stamped from the
  placer's stats at placement time (so it survives the placer's later stat changes
  or departure) plus the typed trap lifecycle metadata consumed by manager-level
  reveal, reclaim, and spring operations. The renewal per-trigger variance is
  rolled at fire time via `roll_damage/1`.
  """
  @spec place_state(non_neg_integer(), map(), Group.t()) :: map()
  def place_state(level, caster_stats, %Group{} = group) do
    origin = Map.get(group.state, :cast_origin, :direct)

    {:ok, trap} =
      TrapState.new(%{
        reclaim_item_id: @trap_item_id,
        claymore_spendable?: claymore_spendable?(group.skill_name),
        natural_expiry: natural_expiry(group.skill_name),
        return_item_on_expiry?:
          group.caster_type == :player and origin == :normal and
            Map.get(group.state, :paid_return?, false)
      })

    %{
      base_damage: base_damage(level, caster_stats, group.skill_name),
      trap: trap,
      ignore_land_protector: true
    }
  end

  @doc """
  The damage stamped on a mine at placement.

  Renewal: level × DEX × (3 + base level / 100) × (1 + INT / 35), the same for every
  mine (the Research Trap term is omitted until that skill exists). Pre-renewal:
  level × a per-mine DEX term × (100 + INT) / 100, where Land Mine reads DEX + 75,
  Blast Mine DEX / 2 + 50, and Claymore Trap DEX / 2 + 75. Other traps stamp 0.
  """
  @spec base_damage(non_neg_integer(), map(), atom()) :: non_neg_integer()
  def base_damage(level, %{dex: dex, int: int, base_level: base_level}, skill_name) do
    case GameMode.mode() do
      :renewal ->
        trunc(level * dex * (3.0 + base_level / 100.0) * (1.0 + int / 35.0))

      :pre_renewal ->
        trunc(level * classic_dex_term(skill_name, dex) * (100.0 + int) / 100.0)
    end
  end

  defp classic_dex_term(:ht_landmine, dex), do: dex + 75.0
  defp classic_dex_term(:ht_blastmine, dex), do: dex / 2.0 + 50.0
  defp classic_dex_term(:ht_claymoretrap, dex), do: dex / 2.0 + 75.0
  defp classic_dex_term(_other, _dex), do: 0.0

  @doc """
  The per-detonation variance. Renewal adjusts the stamped damage by -10% to +9%
  (one roll of twenty steps); pre-renewal mines deal the stamped damage exactly.
  """
  @spec roll_damage(non_neg_integer()) :: integer()
  def roll_damage(base) do
    case GameMode.mode() do
      :renewal -> base + div(base * (:rand.uniform(20) - 11), 100)
      :pre_renewal -> base
    end
  end

  @doc """
  Whether `mover` may trigger this trap relative to its exact caster group.

  Player traps follow the supported field policy, including active versus maps.
  Mob traps retain their PvE player and Homunculus hostility.
  """
  @spec enemy?(Group.t(), {atom(), integer()}) :: boolean()
  def enemy?(%Group{caster_type: :player, caster_id: caster_id}, {:player, caster_id}),
    do: false

  def enemy?(%Group{caster_type: :player} = group, {mover_type, mover_id}) do
    with {:ok, {_caster_module, caster, _caster_pid}} <-
           UnitRegistry.get_unit(:player, group.caster_id),
         {:ok, {_target_module, target, _target_pid}} <-
           UnitRegistry.get_unit(mover_type, mover_id) do
      Targeting.validate_field_target(group, caster, target) == :ok
    else
      _unavailable -> false
    end
  end

  def enemy?(%Group{caster_type: :mob}, {mover_type, _mover_id})
      when mover_type in [:player, :homunculus],
      do: true

  def enemy?(%Group{}, {_mover_type, _mover_id}), do: false

  defp claymore_spendable?(skill_name),
    do:
      skill_name in [
        :ht_landmine,
        :ht_blastmine,
        :ht_shockwave,
        :ht_flasher,
        :ht_sandman,
        :ht_freezingtrap,
        :ht_claymoretrap
      ]

  defp natural_expiry(skill_name) when skill_name in [:ht_blastmine, :ht_claymoretrap],
    do: :become_used

  defp natural_expiry(_skill_name), do: :drop_item

  @doc """
  Resolves the placer's live state struct (needed by `Combat.execute_misc_*`),
  or `:error` when the placer is gone.
  """
  @spec resolve_caster(Group.t()) :: {:ok, struct()} | :error
  def resolve_caster(%Group{caster_type: ct, caster_id: cid}) do
    case UnitRegistry.get_unit(ct, cid) do
      {:ok, {_module, caster_state, _pid}} -> {:ok, caster_state}
      _ -> :error
    end
  end
end
