defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtTalkiebox do
  @moduledoc """
  Talkie Box (HT_TALKIEBOX), a hidden single-cell trap that speaks its
  caster-supplied text when a non-owner player steps on it.

  Placement requires the client's staged text-input reply (`cast_with_input/5`);
  every other cast entry point (`cast/4`, hit by direct/item/auto/mob attempts)
  refuses with `:skill_input_required` and places no group. Not claymore
  spendable and not a harmful trap: any non-owner player triggers it, monsters
  and the owner do not.

  Activation materializes the trap's visible used cell first (the manager's
  ordinary hidden -> visible transition), then the next interval tick
  broadcasts the stored text as a `ChatMessage` keyed on that cell's freshly
  allocated id, and the used cell is removed five seconds later through the
  same `expires_at` timing index every trap already uses - no new timer.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 125,
    name: :ht_talkiebox,
    display_name: "Talkie Box",
    max_level: 1,
    target_type: :ground,
    damage_type: :no_damage,
    range: 3,
    hit_interval: 1_000,
    unit_duration: [600_000],
    sp_cost: [1],
    item_cost: [%{id: 1065, amount: 1}]

  alias Aesir.Net.ChatMessage
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit, as: SkillUnit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.Trap
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active
  @behaviour Ground

  @used_duration 5_000

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:error, :skill_input_required}
  def cast(_caster, _target, _level, _definition), do: {:error, :skill_input_required}

  @impl Active
  @spec cast_with_input(
          PlayerState.t(),
          Active.target(),
          pos_integer(),
          Definition.t(),
          String.t()
        ) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast_with_input(%PlayerState{} = caster, {:ground, x, y}, level, definition, text) do
    paid_return? = Map.has_key?(caster, :character_id) and definition.item_cost != []

    case SkillUnit.place(caster, definition.name, level, {x, y},
           origin: :normal,
           state: %{paid_return?: paid_return?, message: text}
         ) do
      {:ok, _group} -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end

  def cast_with_input(_caster, _target, _level, _definition, _text), do: {:error, :invalid_target}

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: center, level: level, caster_type: ct, caster_id: cid} = group) do
    definition = definition()
    {:ok, %{stats: stats}} = UnitRegistry.get_unit_info(ct, cid)

    {:ok,
     %{
       cells: [center],
       state: Trap.place_state(level, stats, group),
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level - 1),
       visibility: :party_only
     }}
  end

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(
        %Group{state: %{trap: %TrapState{phase: :used}, message: message}} = group,
        _now
      )
      when is_binary(message) do
    announce(group, message)
  end

  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  @spec on_touch(Group.t(), {atom(), integer()}) :: {:ok, Group.t()} | :expire
  def on_touch(
        %Group{
          caster_type: :player,
          caster_id: caster_id,
          state: %{trap: %TrapState{phase: :armed}}
        } = group,
        {:player, mover_id}
      )
      when mover_id != caster_id do
    {:ok, activate(group)}
  end

  def on_touch(%Group{} = group, _mover), do: {:ok, group}

  defp activate(%Group{state: %{trap: trap} = state} = group) do
    %{
      group
      | visibility: :public,
        expires_at: System.monotonic_time(:millisecond) + @used_duration,
        state: %{state | trap: %{trap | phase: :used}}
    }
  end

  defp announce(group, message) do
    case Storage.get_cells_by_group(group.group_id) do
      [%Cell{cell_id: cell_id} | _] ->
        {cx, cy} = group.center
        packet = %ChatMessage{gid: cell_id, message: message}
        Broadcast.to_in_range(group.map_name, cx, cy, Config.view_range(), packet)

        {:ok, %{group | state: %{group.state | message: nil}}}

      [] ->
        {:ok, group}
    end
  end
end
