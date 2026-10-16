defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.Trap do
  @moduledoc """
  Shared helpers for the Hunter traps.

  Not a skill itself - it factors out what the traps share: the placer-time
  damage stamping, the per-trigger variance roll, the hostility check, the
  visibility, and the sprung transition.

  A trap is one cell that acts on the skill-unit timer: every pass, any unit
  within one cell of it that the trap may affect sets it off, however the unit
  got there. An armed trap goes off once; afterwards it lingers as a used trap
  for 1.5 s, never past its own lifetime, and affects nobody. A trap whose
  caster is gone does nothing.

  In renewal the traps flagged as hidden are seen only by their caster and the
  caster's party until revealed; Blast Mine and Claymore Trap are always seen.
  Every trap is seen in pre-renewal.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat.AttackSpeed
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # the trap item (Booby Trap): the item returned when reclaiming one
  # placed Hunter trap.
  @trap_item_id 1065

  @sprung_lifetime 1_500

  @hidden_traps [
    :ht_skidtrap,
    :ht_landmine,
    :ht_anklesnare,
    :ht_shockwave,
    :ht_sandman,
    :ht_flasher,
    :ht_freezingtrap,
    :ht_talkiebox
  ]

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

  # Blast Mine (and renewal's Claymore Trap) turns into a used trap when its
  # time runs out, without going off; the other traps return their item.
  defp natural_expiry(:ht_blastmine), do: :become_used

  defp natural_expiry(:ht_claymoretrap) do
    case GameMode.mode() do
      :renewal -> :become_used
      :pre_renewal -> :drop_item
    end
  end

  defp natural_expiry(_skill_name), do: :drop_item

  @doc """
  Who sees a newly placed trap: in renewal a hidden trap is seen only by its
  caster and the caster's party; otherwise everyone.
  """
  @spec visibility(atom()) :: Group.visibility()
  def visibility(skill_name) do
    if GameMode.mode() == :renewal and skill_name in @hidden_traps,
      do: :party_only,
      else: :public
  end

  @doc "Whether the trap is armed (can still go off)."
  @spec armed?(Group.t()) :: boolean()
  def armed?(%Group{state: %{trap: %TrapState{phase: :armed}}}), do: true
  def armed?(%Group{}), do: false

  @doc """
  Keeps the units an armed trap may go off on: those its caster may target
  with it (`enemy?/2`), while the caster is present. A used, caught or spent
  trap affects nobody.
  """
  @spec unit_targets(Group.t(), [Ref.t()]) :: [Ref.t()]
  def unit_targets(%Group{} = group, refs) do
    if armed?(group) and match?({:ok, _caster}, resolve_caster(group)),
      do: Enum.filter(refs, &(living?(&1) and enemy?(group, &1))),
      else: []
  end

  defp living?({unit_type, unit_id}) do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {_module, state, _pid}} -> Unit.living?(state)
      _gone -> false
    end
  end

  @doc """
  The trap after going off: used for 1.5 s from `now`, never past its own
  lifetime.
  """
  @spec spring(Group.t(), integer()) :: Group.t()
  def spring(%Group{} = group, now), do: transition(group, :used, now, @sprung_lifetime)

  @doc """
  Moves the trap to `phase` for `lifetime` ms from `now`, never past its own
  lifetime.
  """
  @spec transition(Group.t(), TrapState.phase(), integer(), non_neg_integer()) :: Group.t()
  def transition(%Group{state: %{trap: %TrapState{} = trap}} = group, phase, now, lifetime) do
    %{
      group
      | expires_at: capped_expiry(group.expires_at, now + lifetime),
        state: %{group.state | trap: %{trap | phase: phase}}
    }
  end

  defp capped_expiry(expires_at, deadline) when is_integer(expires_at),
    do: min(expires_at, deadline)

  defp capped_expiry(_expires_at, deadline), do: deadline

  @doc "Whether the unit is immune to statuses: a boss or status-immune monster."
  @spec status_immune?(Ref.t()) :: boolean()
  def status_immune?({:mob, mob_id}) do
    case UnitRegistry.get_unit(:mob, mob_id) do
      {:ok, {MobState, mob, _pid}} ->
        MobState.is_boss?(mob) or :status_immune in (mob.mob_data.modes || [])

      _other ->
        false
    end
  end

  def status_immune?(_ref), do: false

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

  @doc """
  The trapper's attack motion (status amotion) in milliseconds: half a
  player's attack delay, a monster's own attack motion.
  """
  @spec amotion(PlayerState.t() | MobState.t()) :: non_neg_integer()
  def amotion(%PlayerState{stats: stats}), do: AttackSpeed.amotion_from_stats(stats)

  def amotion(%MobState{} = mob), do: MobState.get_attack_motion(mob)
end
