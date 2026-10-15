defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaSpellbreaker do
  @moduledoc """
  Spell Breaker (SA_SPELLBREAKER). Interrupts an enemy's cast at 9 cells for 10 SP:
  the target loses the interrupted skill's SP cost (a monster loses none) and the
  caster regains 25% per level above one of it. A target that is not casting
  costs the SP for nothing. A player under Magic Rod absorbs the attempt instead
  and drains 20% of the caster's max SP. A status-immune monster resists nine times in ten. At level 5
  the caster also siphons 2% of the target's max HP, healing half of it, never
  when the hit would be lethal; players are siphoned only on versus maps.

  Renewal casts in 0.56 s plus 0.14 s fixed and never siphons HP from a
  status-immune monster; pre-renewal casts in 0.7 s and siphons once the
  resistance roll has passed. A mob-only skill absent from the catalog costs 0 SP.
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
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @default_rng &:rand.uniform/1
  @immune_failure_rate 90

  @doc """
  Breaks the target's cast, or transfers SP to a player holding Magic Rod.

  `opts` accepts `:rng`, a `(pos_integer() -> pos_integer())` function for the
  status-immune failure roll, defaulting to `&:rand.uniform/1`.
  """
  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t(), keyword()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(caster, {:unit, target_id}, level, _definition, opts \\ []) do
    rng = Keyword.get(opts, :rng, @default_rng)

    with {:ok, unit_type, state, pid} <- resolve_target(target_id),
         :ok <- Targeting.validate_enemy(caster, state) do
      if unit_type == :player and StatusStorage.has_status?(:player, target_id, :sc_magicrod),
        do: {:ok, feed_magic_rod(caster, :player, target_id)},
        else: {:ok, break_cast(caster, unit_type, state, pid, level, rng)}
    end
  end

  # Mobs first: a player and a mob can never share an id.
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

  # A player target is read from its registry snapshot and interrupted
  # asynchronously: a synchronous call could deadlock two players breaking each
  # other's casts. Players are never status-immune.
  @spec break_cast(
          PlayerState.t(),
          :mob | :player,
          struct(),
          pid(),
          pos_integer(),
          (pos_integer() -> pos_integer())
        ) :: PlayerState.t()
  defp break_cast(
         caster,
         :player,
         %PlayerState{casting: %{skill_id: id, skill_level: lv}} = target,
         pid,
         level,
         _rng
       ) do
    PlayerSession.interrupt_cast(pid)
    sp = interrupted_sp_cost(id, lv)
    PlayerSession.consume_sp(pid, sp)

    caster
    |> adjust_sp(div(sp * (25 * (level - 1)), 100))
    |> siphon_player(target, pid, level)
  end

  defp break_cast(caster, :player, _not_casting, _pid, _level, _rng), do: caster

  defp break_cast(caster, :mob, _snapshot, pid, level, rng) do
    state = MobSession.get_state(pid)
    immune? = status_immune?(state)

    with :ok <- ensure_casting(state),
         :ok <- roll_against_immunity(immune?, rng),
         {:ok, %{skill_id: skill_id, level: cast_level}} <- MobSession.interrupt_cast(pid) do
      sp = interrupted_sp_cost(skill_id, cast_level)

      caster
      |> adjust_sp(div(sp * (25 * (level - 1)), 100))
      |> siphon_mob(pid, level, immune?)
    else
      _nothing_broken -> caster
    end
  end

  # Read before the interrupt, mirroring the reference's `ud->skilltimer` check:
  # a failed immunity roll must leave the cast running.
  @spec ensure_casting(MobState.t()) :: :ok | {:error, :not_casting}
  defp ensure_casting(%MobState{casting: nil}), do: {:error, :not_casting}
  defp ensure_casting(%MobState{is_dead: true}), do: {:error, :not_casting}
  defp ensure_casting(%MobState{}), do: :ok

  defp status_immune?(%MobState{mob_data: %{modes: modes}}), do: :status_immune in modes
  defp status_immune?(_state), do: false

  @spec roll_against_immunity(boolean(), (pos_integer() -> pos_integer())) ::
          :ok | {:error, :failed}
  defp roll_against_immunity(false, _rng), do: :ok

  defp roll_against_immunity(true, rng) do
    if rng.(100) <= @immune_failure_rate, do: {:error, :failed}, else: :ok
  end

  # Level 5 only. Renewal never siphons a status-immune target; classic does once
  # its one-in-ten interruption roll has passed.
  defp siphon_mob(caster, _pid, level, _immune?) when level < 5, do: caster

  defp siphon_mob(caster, pid, _level, immune?) do
    if immune? and GameMode.mode() == :renewal do
      caster
    else
      # Re-read after the interrupt for liveness and the current HP.
      state = MobSession.get_state(pid)

      if state.is_dead,
        do: caster,
        else: zap(caster, div(state.max_hp, 50), state.hp, &MobSession.zap_hp(pid, &1))
    end
  end

  # Level 5 only, and only on versus maps.
  defp siphon_player(caster, %PlayerState{map_name: map, stats: stats}, pid, level) do
    if level >= 5 and Targeting.versus_map?(map),
      do:
        zap(
          caster,
          div(stats.derived_stats.max_hp, 50),
          stats.current_state.hp,
          &PlayerSession.zap_hp(pid, &1)
        ),
      else: caster
  end

  # A siphon that would be lethal deals nothing; the caster heals half of it.
  defp zap(caster, damage, target_hp, apply) do
    if damage > 0 and damage < target_hp do
      apply.(damage)
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
