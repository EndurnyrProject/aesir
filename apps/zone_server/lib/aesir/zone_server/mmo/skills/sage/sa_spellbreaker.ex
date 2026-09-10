defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaSpellbreaker do
  @moduledoc """
  Spell Breaker (SA_SPELLBREAKER). Interrupts an enemy's cast at 9 cells for 10 SP:
  the target loses the interrupted skill's SP cost and the caster regains 25% per
  level above one of it. A target under Magic Rod absorbs the attempt instead and
  drains 20% of the caster's max SP. A status-immune target resists nine times in
  ten before anything happens. At level 5 the caster also siphons 2% of the target's
  max HP, healing half of it, never when the hit would be lethal.

  Renewal casts in 0.56 s plus 0.14 s fixed and never siphons HP from a
  status-immune target; pre-renewal casts in 0.7 s and siphons once the resistance
  roll has passed. Only mob targets are supported until player casts can be
  interrupted; a mob-only skill absent from the catalog costs 0 SP.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 277,
    name: :sa_spellbreaker,
    requires: [],
    display_name: "Spell Breaker",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :no_damage,
    damage_kind: :magic,
    range: 9,
    sp_cost: List.duplicate(10, 5),
    cast_time: [renewal: List.duplicate(560, 5), pre_renewal: List.duplicate(700, 5)],
    fixed_cast_time: [renewal: List.duplicate(140, 5), pre_renewal: []]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @default_rng &:rand.uniform/1
  @boss_failure_rate 90

  @doc """
  Breaks the target's cast, or transfers SP to it when it holds Magic Rod.

  `opts` accepts `:rng`, a `(pos_integer() -> pos_integer())` function for the
  boss failure roll, defaulting to `&:rand.uniform/1`.
  """
  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t(), keyword()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(caster, {:unit, target_id}, level, _definition, opts \\ []) do
    rng = Keyword.get(opts, :rng, @default_rng)

    with {:ok, unit_type, state, pid} <- resolve_target(target_id),
         :ok <- Targeting.validate_enemy(caster, state) do
      if StatusStorage.has_status?(unit_type, target_id, :sc_magicrod) do
        {:ok, feed_magic_rod(caster, unit_type, target_id)}
      else
        break_cast(caster, unit_type, pid, level, rng)
      end
    end
  end

  # Mobs first: a player and a mob can never share an id, and the mob branch is
  # the only one that resolves to a session with a cast to break.
  @spec resolve_target(non_neg_integer()) ::
          {:ok, :mob | :player, struct(), pid()} | {:error, :target_not_found}
  defp resolve_target(target_id) do
    case UnitRegistry.get_unit(:mob, target_id) do
      {:ok, {_module, state, pid}} ->
        {:ok, :mob, state, pid}

      {:error, :not_found} ->
        case UnitRegistry.get_unit(:player, target_id) do
          {:ok, {_module, state, pid}} -> {:ok, :player, state, pid}
          {:error, :not_found} -> {:error, :target_not_found}
        end
    end
  end

  # `Targeting.validate_enemy/2` rejects player targets until PvP lands, so this
  # clause is unreachable today. It fails explicitly rather than crashing the
  # caster's session, and marks the seam: giving players a spell-breakable cast
  # needs a `PlayerSession` counterpart to `MobSession.interrupt_cast/1`.
  @spec break_cast(PlayerState.t(), :mob | :player, pid(), pos_integer(), (pos_integer() ->
                                                                             pos_integer())) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  defp break_cast(_caster, :player, _pid, _level, _rng), do: {:error, :invalid_target}

  defp break_cast(caster, :mob, pid, level, rng) do
    state = MobSession.get_state(pid)
    boss? = MobState.is_boss?(state)

    with :ok <- ensure_casting(state),
         :ok <- roll_against_boss(boss?, rng),
         {:ok, %{skill_id: skill_id, level: cast_level}} <- MobSession.interrupt_cast(pid) do
      sp = interrupted_sp_cost(skill_id, cast_level)
      MobSession.zap_sp(pid, sp)

      caster
      |> adjust_sp(div(sp * (25 * (level - 1)), 100))
      |> siphon_hp(pid, level, boss?)
      |> then(&{:ok, &1})
    end
  end

  # Read before the interrupt, mirroring the reference's `ud->skilltimer` check:
  # a failed boss roll must leave the cast running, so it cannot be discovered by
  # interrupting first. A cast that completes between this read and the interrupt
  # simply yields `{:error, :not_casting}` from `interrupt_cast/1` instead.
  @spec ensure_casting(MobState.t()) :: :ok | {:error, :not_casting}
  defp ensure_casting(%MobState{casting: nil}), do: {:error, :not_casting}
  defp ensure_casting(%MobState{is_dead: true}), do: {:error, :not_casting}
  defp ensure_casting(%MobState{}), do: :ok

  @spec roll_against_boss(boolean(), (pos_integer() -> pos_integer())) :: :ok | {:error, :failed}
  defp roll_against_boss(false, _rng), do: :ok

  defp roll_against_boss(true, rng) do
    if rng.(100) <= @boss_failure_rate, do: {:error, :failed}, else: :ok
  end

  # Level 5 only. Renewal never siphons a status-immune target; classic does once
  # its one-in-ten interruption roll has passed.
  @spec siphon_hp(PlayerState.t(), pid(), pos_integer(), boolean()) :: PlayerState.t()
  defp siphon_hp(caster, _pid, level, _boss?) when level < 5, do: caster

  defp siphon_hp(caster, pid, _level, boss?) do
    if boss? and GameMode.mode() == :renewal, do: caster, else: siphon(caster, pid)
  end

  defp siphon(caster, pid) do
    # Re-read after the interrupt: it is the mob's liveness revalidation and the
    # source of the current HP the lethal check needs.
    state = MobSession.get_state(pid)
    damage = div(state.max_hp, 50)

    if not state.is_dead and damage > 0 and damage < state.hp do
      MobSession.apply_damage(pid, damage, caster.character_id)
      restore_hp(caster, div(damage, 2))
    else
      caster
    end
  end

  # 20% of the caster's *max* SP (`status_percent_damage`'s negative rate reads
  # max), never more than they have and never zero.
  @spec feed_magic_rod(PlayerState.t(), :mob | :player, non_neg_integer()) :: PlayerState.t()
  defp feed_magic_rod(%{stats: stats} = caster, unit_type, target_id) do
    amount = min(max(div(stats.derived_stats.max_sp * 20, 100), 1), stats.current_state.sp)

    Helpers.restore_sp({unit_type, target_id}, amount)
    adjust_sp(caster, -amount)
  end

  # A skill absent from the catalog cannot have been cast by a player, and every
  # mob-only `NPC_*` skill declares no SpCost; both contribute 0. Mob rows cast
  # above the skill's player max level (AL_DECAGI 48, MG_FIREBALL 43), so the SP
  # cost extrapolates past the defined table via the shared catalog accessor
  # rather than clamping to the top level.
  @spec interrupted_sp_cost(integer(), pos_integer()) :: non_neg_integer()
  defp interrupted_sp_cost(skill_id, level) do
    case Catalog.by_id(skill_id) do
      {:ok, %{sp_cost: sp_cost}} -> Catalog.sp_cost_at(sp_cost, level)
      :error -> 0
    end
  end

  @spec adjust_sp(PlayerState.t(), integer()) :: PlayerState.t()
  defp adjust_sp(caster, 0), do: caster

  defp adjust_sp(%{stats: stats} = caster, amount) do
    current = stats.current_state
    new_sp = clamp(current.sp + amount, stats.derived_stats.max_sp)
    %{caster | stats: %{stats | current_state: %{current | sp: new_sp}}}
  end

  @spec restore_hp(PlayerState.t(), non_neg_integer()) :: PlayerState.t()
  defp restore_hp(caster, 0), do: caster

  defp restore_hp(%{stats: stats} = caster, amount) do
    current = stats.current_state
    new_hp = clamp(current.hp + amount, stats.derived_stats.max_hp)
    %{caster | stats: %{stats | current_state: %{current | hp: new_hp}}}
  end

  @spec clamp(integer(), non_neg_integer()) :: non_neg_integer()
  defp clamp(value, max), do: value |> max(0) |> min(max)
end
