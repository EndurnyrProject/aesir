defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtAnklesnare do
  @moduledoc """
  Ankle Snare (HT_ANKLESNARE).

  The first enemy within one cell of the snare is caught: it is held in place
  (Ankle) for the level's base time less AGI/200 of it, never under
  30 × (caster level + 100) ms, and pulled onto the snare unless it resists
  being moved (a siege map, a knockback-immune monster, no-knockback gear, a
  pre-renewal Basilica caster). The snare then catches nothing more and lasts
  as long as the hold, never past its own lifetime; when it ends, so does its
  target's hold. A target already held more strongly keeps that hold, and the
  snare lasts as long as it. If the hold cannot start, the snare is spent for
  3 s and its trap item returns when it runs out.

  Renewal: bosses and status-immune monsters never set it off. Pre-renewal:
  they are caught for a fifth of the base time. Otherwise the modes agree: a
  single-cell snare lasting 250 s down to 50 s by level, a 4 to 20 s base hold,
  for 12 SP and one trap.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 117,
    name: :ht_anklesnare,
    requires: [],
    display_name: "Ankle Snare",
    max_level: 5,
    target_type: :ground,
    damage_type: :no_damage,
    range: 3,
    hit_interval: 1_000,
    unit_duration: [250_000, 200_000, 150_000, 100_000, 50_000],
    sp_cost: List.duplicate(12, 5),
    item_cost: [%{id: 1065, amount: 1}]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.Trap
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Ground
  @base_durations [4_000, 8_000, 12_000, 16_000, 20_000]
  @failed_catch_ms 3_000

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: center, level: level, caster_type: type, caster_id: id} = group) do
    definition = definition()
    {:ok, %{stats: stats}} = UnitRegistry.get_unit_info(type, id)

    {:ok,
     %{
       cells: [center],
       state: Trap.place_state(level, stats, group),
       interval: definition.hit_interval,
       duration: Enum.fetch!(definition.unit_duration, level - 1),
       unit_range: 1,
       visibility: Trap.visibility(:ht_anklesnare)
     }}
  end

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  @spec unit_targets(Group.t(), Ground.cell(), [{atom(), integer()}]) :: [{atom(), integer()}]
  def unit_targets(%Group{} = group, _cell, refs) do
    refs = Trap.unit_targets(group, refs)

    case GameMode.mode() do
      :renewal -> Enum.reject(refs, &Trap.status_immune?/1)
      :pre_renewal -> refs
    end
  end

  @impl Ground
  @spec on_unit_hit(Group.t(), Ground.cell(), {atom(), integer()}, integer()) :: {:ok, Group.t()}
  def on_unit_hit(%Group{} = group, _cell, target, now) do
    with true <- Trap.armed?(group),
         {:ok, _caster} <- Trap.resolve_caster(group),
         {:ok, hold_ms} <- hold_duration(group, target) do
      {:ok, catch_target(group, target, hold_ms, now)}
    else
      _inert -> {:ok, group}
    end
  end

  @impl Ground
  @spec on_expire(Group.t()) :: :ok
  def on_expire(%Group{state: %{caught: {type, id}}}) do
    Interpreter.remove_status(type, id, :sc_ankle)
    :ok
  end

  def on_expire(%Group{}), do: :ok

  @doc """
  The hold time: the level's base time (a fifth of it against a status-immune
  target, `boss?`) less AGI/200 of it, never under 30 × (caster level + 100).
  """
  @spec capture_duration(1..5, non_neg_integer(), non_neg_integer(), boolean()) :: pos_integer()
  def capture_duration(level, target_agi, caster_level, boss? \\ false) do
    base = Enum.fetch!(@base_durations, level - 1)
    base = if boss?, do: div(base, 5), else: base
    max(base - div(base * target_agi, 200), 30 * (caster_level + 100))
  end

  defp hold_duration(%Group{} = group, {type, id} = target) do
    with {:ok, %{stats: target_stats}} <- UnitRegistry.get_unit_info(type, id),
         {:ok, %{stats: caster_stats}} <-
           UnitRegistry.get_unit_info(group.caster_type, group.caster_id) do
      boss? = GameMode.mode() == :pre_renewal and Trap.status_immune?(target)
      {:ok, capture_duration(group.level, target_stats.agi, caster_stats.base_level, boss?)}
    end
  end

  defp catch_target(%Group{center: {x, y}} = group, {type, id} = target, hold_ms, now) do
    case Interpreter.apply_status(type, id, :sc_ankle,
           val1: group.level,
           val2: group.group_id,
           duration: hold_ms,
           caster_id: group.caster_id,
           source_type: group.caster_type
         ) do
      :ok ->
        Knockback.pull_to(type, id, x, y, blown_immunity: true)

        group
        |> Trap.transition(:captured, now, held_ms(type, id, hold_ms))
        |> caught(target)

      _failed ->
        group
        |> Trap.transition(:spent, now, @failed_catch_ms)
        |> Map.put(:visibility, :public)
    end
  end

  defp caught(%Group{} = group, target),
    do: %{group | visibility: :public, state: Map.put(group.state, :caught, target)}

  # A stronger hold already held is kept, so the snare lasts as long as it.
  defp held_ms(type, id, hold_ms) do
    case StatusStorage.get_status(type, id, :sc_ankle) do
      %StatusEntry{expires_at: expires_at} when is_integer(expires_at) ->
        max(expires_at - System.monotonic_time(:millisecond), 0)

      _other ->
        hold_ms
    end
  end
end
