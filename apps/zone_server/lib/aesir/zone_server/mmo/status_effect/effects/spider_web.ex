defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SpiderWeb do
  @moduledoc """
  Fiber Lock (SC_SPIDERWEB). The holder is rooted and loses half its FLEE.

  `val1` counts the webs that caught the holder during this hold; it never drops
  when a web goes. `state.slots` are the three web slots: each catch takes the
  first free slot, and a web leaving frees its slot for the next one.

  Ending the hold early (a fire attribute step, a cleanse, anything but running
  out) burns one web instead: slots whose web is gone are freed, the web with
  the least time left is torn down (the earliest slot on a tie), and the hold
  lasts while a slot still holds a web, unless the holder is dead. Running out
  ends the hold and leaves the webs standing. Death does not end it.

  Every fire element attribute step against the holder gains 100 element ratio
  points (renewal adds them to the ratio, pre-renewal doubles the damage) and
  ends the hold early as above. Identical in both modes.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_spiderweb,
    no_dispel: true,
    no_clear_buff: false,
    clear_buff_flags: [:debuff],
    no_save: true,
    remove_on_death: false,
    bypass_resistance: true,
    properties: [:debuff, :prevents_movement],
    flags: [:no_move],
    calc_flags: [:flee],
    icon: :spiderweb

  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @impl true
  def modifiers(_instance, _context), do: %{flee_rate: -50}

  @doc """
  An application never meets a held hold: only a unit not yet held is applied
  the status, and a web catching a held unit restarts its hold in place.
  """
  @impl true
  def overlap(_target, _held, _incoming), do: :fail

  @doc """
  Ends the holder's hold early for a fire attribute step, burning one web.

  Returns whether the unit was held, which is when the step gains the web bonus.
  """
  @spec consume(atom(), integer()) :: boolean()
  def consume(unit_type, unit_id) do
    if StatusStorage.has_status?(unit_type, unit_id, :sc_spiderweb) do
      Interpreter.remove_status(unit_type, unit_id, :sc_spiderweb)
      true
    else
      false
    end
  end

  @impl true
  def on_end_request({unit_type, unit_id}, %StatusEntry{state: %{slots: slots}} = entry, _ctx) do
    webs = Enum.map(slots, &live_web/1)
    slots = Enum.map(webs, &(&1 && &1.group_id))

    {slots, burned} =
      case burn_pick(webs) do
        nil -> {slots, nil}
        {%Group{group_id: group_id}, index} -> {List.replace_at(slots, index, nil), group_id}
      end

    tear_down = fn -> if burned, do: Manager.destroy_async(burned) end

    if living?(unit_type, unit_id) and Enum.any?(slots),
      do: {:keep, %{entry | state: %{entry.state | slots: slots}}, tear_down},
      else: {:end, tear_down}
  end

  def on_end_request(_target, _entry, _context), do: {:end, fn -> :ok end}

  defp live_web(nil), do: nil
  defp live_web(group_id), do: Storage.get(group_id)

  # The web with the least time left; `min_by` keeps the earliest slot on a tie.
  defp burn_pick(webs) do
    webs
    |> Enum.with_index()
    |> Enum.reject(fn {web, _index} -> is_nil(web) end)
    |> Enum.min_by(fn {%Group{expires_at: expires_at}, _index} -> expires_at end, fn -> nil end)
  end

  defp living?(unit_type, unit_id) do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {_module, state, _pid}} -> Unit.living?(state)
      _gone -> false
    end
  end
end
