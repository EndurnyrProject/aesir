defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Dancing do
  @moduledoc """
  Performing lock for pre-renewal fields and renewal Moonlit Water Mill.

  The performer cannot attack and may use only the listed skills unless Longing
  relaxes an ensemble lock. Ending the lock ends its field. The state carries
  `upkeep` in seconds and `upkeep_sp` (default one), tripled under Longing.
  Every `upkeep` seconds a player pays it or stops performing, and stops too
  once the payment leaves no SP. A monster performer pays nothing but stops on
  that same beat if it has no SP.

  `root` is `:none` for mobile solo songs, `:ensemble` for ensembles freed by
  Longing, or `:always` for Moonlit and Hermode. Older entries infer the root
  from a positive partner character id in `val4`. A player walking without
  Longing is slowed by `500 - 40 * Lesson` percent, with the lesson frozen in
  `val3`; a monster is not slowed.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_dancing,
    no_dispel: true,
    no_clear_buff: true,
    overlap_ignore_level: true,
    no_save: true,
    bypass_resistance: true,
    remove_on_map_change: true,
    target_types: [:player, :mob],
    properties: [:prevents_attack, :prevents_skills],
    allow_skills: [316, 324, 304, 487],
    tick_interval: 1_000,
    icon: :bdplaying

  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @impl true
  @spec modifiers(StatusEntry.t(), Definition.context()) :: map()
  def modifiers(%StatusEntry{val3: lesson}, context) do
    unit_type = Map.get(context, :unit_type)

    slow =
      if unit_type == :mob or longing?(unit_type, Map.get(context, :target_id)),
        do: 0,
        else: 500 - 40 * (lesson || 0)

    %{sp_regen: -100, skill_sp_regen_rate: -100, movement_speed: slow}
  end

  @impl true
  @spec on_tick(Definition.target(), StatusEntry.t(), Definition.context()) ::
          {:ok, StatusEntry.t()} | :remove
  def on_tick(
        {type, id},
        %StatusEntry{state: %{upkeep: upkeep, ticks: ticks}} = entry,
        _context
      ) do
    updated = %{entry | state: %{entry.state | ticks: ticks + 1}}

    if rem(ticks + 1, upkeep) == 0 do
      with :ok <- pay_upkeep(type, id, entry),
           {:ok, {_module, state, _pid}} <- UnitRegistry.get_unit(type, id),
           true <- sp(state) > 0 do
        {:ok, updated}
      else
        _ -> :remove
      end
    else
      {:ok, updated}
    end
  end

  defp pay_upkeep(:player, id, entry) do
    amount = Map.get(entry.state, :upkeep_sp, 1) * if(longing?(:player, id), do: 3, else: 1)

    case UnitRegistry.get_unit(:player, id) do
      {:ok, {_module, _state, pid}} when is_pid(pid) -> PlayerSession.try_consume_sp(pid, amount)
      _gone -> {:error, :target_unavailable}
    end
  end

  defp pay_upkeep(_type, _id, _entry), do: :ok

  defp sp(%MobState{sp: sp}), do: sp
  defp sp(%{stats: %{current_state: %{sp: sp}}}), do: sp

  @impl true
  @spec after_damage_taken(Definition.target(), StatusEntry.t(), map(), Definition.context()) ::
          :ok | :remove
  def after_damage_taken(_target, _entry, %{damage: damage}, %{target: %{max_hp: max_hp}})
      when is_integer(max_hp) and max_hp > 0 do
    if damage > div(max_hp, 4), do: :remove, else: :ok
  end

  def after_damage_taken(_target, _entry, _hit, _context), do: :ok

  @impl true
  @spec on_expire(Definition.target(), StatusEntry.t(), Definition.context()) :: :ok
  def on_expire(_target, %StatusEntry{val2: group_id}, _context) when is_integer(group_id),
    do: Unit.destroy_async(group_id)

  def on_expire(_target, _entry, _context), do: :ok

  defp longing?(type, id), do: StatusStorage.has_status?(type, id, :sc_longing)
end
