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
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Builds the initial group state: the deterministic base damage stamped from the
  placer's stats at placement time (rAthena stamps trap damage at setup, so it
  survives the placer's later stat changes / departure). The per-trigger ±
  variance is rolled at fire time via `roll_damage/1`.
  """
  @spec place_state(non_neg_integer(), map()) :: %{base_damage: non_neg_integer()}
  def place_state(level, caster_stats) do
    %{base_damage: base_damage(level, caster_stats)}
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
  Whether `mover` is a hostile target for this trap.

  PvE-simplified: enemies are mobs; the owner and allied players never trigger a
  trap. NOTE: PvP / faction filtering is future work.
  """
  @spec enemy?(Group.t(), {atom(), integer()}) :: boolean()
  def enemy?(%Group{caster_type: ct, caster_id: cid}, {mover_type, mover_id}) do
    {mover_type, mover_id} != {ct, cid} and mover_type == :mob
  end

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
