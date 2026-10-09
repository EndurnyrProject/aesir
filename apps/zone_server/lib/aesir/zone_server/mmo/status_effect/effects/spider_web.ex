defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SpiderWeb do
  @moduledoc """
  Fiber Lock (SC_SPIDERWEB). The holder is rooted by up to three webs (their
  group ids in `state.groups`) and loses half its FLEE.

  Every fire element attribute step against the holder gains 100 element ratio
  points (renewal adds them to the ratio, pre-renewal doubles the damage) and
  burns the web closest to running out through `consume/2`; the hold lasts while
  a web remains. Identical in both modes.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_spiderweb,
    no_dispel: true,
    no_clear_buff: false,
    clear_buff_flags: [:debuff],
    no_save: true,
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

  @impl true
  def modifiers(_instance, _context), do: %{flee_rate: -50}

  @doc """
  Burns the holder's web closest to running out, ending the hold with the last one.

  Returns whether the unit was held, which is when a fire attribute step gains the
  web bonus. Webs already gone are dropped.
  """
  @spec consume(atom(), integer()) :: boolean()
  def consume(unit_type, unit_id) do
    case StatusStorage.get_status(unit_type, unit_id, :sc_spiderweb) do
      %StatusEntry{state: %{groups: groups}} = entry ->
        if claim(unit_type, unit_id, entry, burn_plan(groups)),
          do: true,
          else: consume(unit_type, unit_id)

      _not_held ->
        false
    end
  end

  # Claims the burn against the read entry, so concurrent fire steps each burn
  # their own web; a lost race reads the entry again. The burned web is torn
  # down only after the claim, and the last web ends the hold through its
  # expiry lifecycle, which tears down every web.
  defp claim(unit_type, unit_id, entry, :end_hold),
    do: Interpreter.remove_status_if_current(unit_type, unit_id, :sc_spiderweb, entry)

  defp claim(unit_type, unit_id, entry, {:burn, burned, left}) do
    replacement = %{entry | state: Map.put(entry.state, :groups, left)}

    if StatusStorage.replace_status_if_current(
         unit_type,
         unit_id,
         :sc_spiderweb,
         entry,
         replacement
       ) do
      Manager.destroy_async(burned)
      true
    else
      false
    end
  end

  @impl true
  def on_expire(_target, %{state: %{groups: groups}}, _context) do
    Enum.each(groups, &Manager.destroy_async/1)
    :ok
  end

  def on_expire(_target, _instance, _context), do: :ok

  # Picks the live web with the least time left to burn; with one web or none
  # left the hold ends. Webs already gone are dropped.
  defp burn_plan(groups) do
    case Enum.filter(groups, &match?(%Group{}, Storage.get(&1))) do
      many when length(many) > 1 ->
        shortest = Enum.min_by(many, &Storage.get(&1).expires_at)
        {:burn, shortest, many -- [shortest]}

      _one_or_none ->
        :end_hold
    end
  end
end
