defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.Trap do
  @moduledoc """
  Shared helpers for Hunter trap ground-units (HT_LANDMINE, HT_BLASTMINE).

  Not a skill itself - it factors out the bits both traps share: the placer-time
  damage stamping, the per-trigger variance roll, the hostility check, and
  resolving the placer's live state for the misc execute path. Keeping the
  formula in one place makes the "verify vs rAthena" citations easy to tune.

  rAthena traps are live immediately (no arming delay) and fire on the first
  enemy contact.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # rAthena ITEMID_TRAP (Booby_Trap): the item returned when reclaiming one
  # placed Hunter trap.
  @trap_item_id 1065

  @doc """
  Builds the initial group state: the deterministic base damage stamped from the
  placer's stats at placement time (rAthena stamps trap damage at setup, so it
  survives the placer's later stat changes / departure) plus the typed trap
  lifecycle metadata consumed by manager-level reveal, reclaim, and spring
  operations. The per-trigger ±
  variance is rolled at fire time via `roll_damage/1`.
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
      base_damage: base_damage(level, caster_stats),
      trap: trap,
      ignore_land_protector: true
    }
  end

  # rAthena renewal trap base, verified vs battle.cpp:6354-6360 (shared by
  # HT_LANDMINE and HT_BLASTMINE under RENEWAL):
  #   skill_lv * DEX * (3.0 + BaseLv/100.0) * (1.0 + INT/35.0)
  # truncated to an integer. The `+ RA_RESEARCHTRAP*40` term is omitted
  # (Research Trap is unimplemented).
  @spec base_damage(non_neg_integer(), map()) :: non_neg_integer()
  def base_damage(level, %{dex: dex, int: int, base_level: base_level}) do
    trunc(level * dex * (3.0 + base_level / 100.0) * (1.0 + int / 35.0))
  end

  @doc """
  Applies the per-trigger damage variance, verified vs battle.cpp:6358:
  `damage += damage * (rnd()%20 - 10) / 100`, i.e. a -10% .. +9% adjustment
  (`rnd()%20` is 0..19). Rolled once per detonation.
  """
  @spec roll_damage(non_neg_integer()) :: integer()
  def roll_damage(base) do
    base + div(base * (:rand.uniform(20) - 11), 100)
  end

  @doc """
  Whether `mover` is a hostile PvE target relative to this trap's caster.

  Player traps target mobs. Mob traps target players and Homunculi. Same-side
  contacts do not trigger harmful traps; PvP and mob-on-mob targeting remain
  out of scope.
  """
  @spec enemy?(Group.t(), {atom(), integer()}) :: boolean()
  def enemy?(%Group{caster_type: :player}, {:mob, _mover_id}), do: true

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
