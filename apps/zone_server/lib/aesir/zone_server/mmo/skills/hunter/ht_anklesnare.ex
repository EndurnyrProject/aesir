defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtAnklesnare do
  @moduledoc """
  Ankle Snare (HT_ANKLESNARE).

  Captures one hostile PvE unit on contact: the movement-lock status is applied
  directly to the target, the trap becomes visible and captured with a matching
  link id, and the target is pulled onto the trap cell through its owning
  session. Either side ending releases only the matching peer; stale links
  self-heal through status ticks and finite durations.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 117,
    name: :ht_anklesnare,
    display_name: "Ankle Snare",
    max_level: 5,
    target_type: :ground,
    damage_type: :no_damage,
    range: 3,
    hit_interval: 1_000,
    unit_duration: [250_000, 200_000, 150_000, 100_000, 50_000],
    sp_cost: List.duplicate(12, 5),
    item_cost: [%{id: 1065, amount: 1}]

  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.Trap
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Ground
  @base_durations [4_000, 8_000, 12_000, 16_000, 20_000]

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
       visibility: :party_only
     }}
  end

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  @spec on_touch(Group.t(), {atom(), integer()}) :: {:ok, Group.t()}
  def on_touch(%Group{} = group, mover) do
    if Trap.enemy?(group, mover), do: capture(group, mover), else: {:ok, group}
  end

  @impl Ground
  @spec on_expire(Group.t()) :: :ok
  def on_expire(%Group{} = group) do
    remove_matching_status(group)
    :ok
  end

  @doc "Returns the AGI-reduced capture duration with its caster-level floor."
  @spec capture_duration(1..5, non_neg_integer(), non_neg_integer()) :: pos_integer()
  def capture_duration(level, target_agi, caster_base_level) do
    base = Enum.fetch!(@base_durations, level - 1)
    max(base - div(base * target_agi, 200), 30 * (caster_base_level + 100))
  end

  defp capture(%Group{} = group, {target_type, target_id}) do
    with {:ok, %{stats: target_stats}} <- UnitRegistry.get_unit_info(target_type, target_id),
         {:ok, %{stats: caster_stats}} <-
           UnitRegistry.get_unit_info(group.caster_type, group.caster_id),
         link_id = System.unique_integer([:positive]),
         duration = capture_duration(group.level, target_stats.agi, caster_stats.base_level),
         :ok <-
           Interpreter.apply_status(target_type, target_id, :sc_anklesnare,
             duration: duration,
             caster_id: group.caster_id,
             source_type: group.caster_type,
             state: %{group_id: group.group_id, link_id: link_id}
           ) do
      {x, y} = group.center
      Knockback.pull_to(target_type, target_id, x, y)
      {:ok, captured_group(group, target_type, target_id, duration, link_id)}
    else
      _ineligible -> {:ok, group}
    end
  end

  defp captured_group(
         %Group{state: %{trap: %TrapState{} = trap}} = group,
         type,
         id,
         duration,
         link_id
       ) do
    %{
      group
      | visibility: :public,
        target_type: type,
        target_id: id,
        expires_at: System.monotonic_time(:millisecond) + duration,
        state: Map.put(group.state, :trap, %{trap | phase: :captured, link_id: link_id})
    }
  end

  defp remove_matching_status(%Group{
         group_id: group_id,
         target_type: target_type,
         target_id: target_id,
         state: %{trap: %TrapState{phase: :captured, link_id: link_id}}
       }) do
    remove_matching_status(target_type, target_id, group_id, link_id)
  end

  defp remove_matching_status(_group), do: :ok

  defp remove_matching_status(target_type, target_id, group_id, link_id) do
    case StatusStorage.get_status(target_type, target_id, :sc_anklesnare) do
      %StatusEntry{state: %{group_id: ^group_id, link_id: ^link_id}} ->
        StatusStorage.update_status(target_type, target_id, :sc_anklesnare, fn entry ->
          %{entry | state: Map.put(entry.state, :group_id, nil)}
        end)

        Interpreter.remove_status(target_type, target_id, :sc_anklesnare)

      _stale_or_absent ->
        :ok
    end
  end
end
