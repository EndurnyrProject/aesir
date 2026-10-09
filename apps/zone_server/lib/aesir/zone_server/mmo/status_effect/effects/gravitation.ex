defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Gravitation do
  @moduledoc """
  Gravitation Field (SC_GRAVITATION), pre-renewal only.

  Every unit held by the field attacks 5% slower per level. The High Wizard's
  own instance (`state.self?`) is bound to the field group (`state.group_id`):
  it roots the caster, blocks their items, lets none of their other skills deal
  damage (`Interpreter.can_deal_skill_damage?/4`), ends when the caster takes
  damage, and tears the field down when it ends. Field occupants' instances are
  owned by the field and end when they leave it.

  Renewal casts Gravitation Field as an instant burst and never applies this
  status.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_gravitation,
    no_dispel: true,
    no_clear_buff: [renewal: true, pre_renewal: false],
    clear_buff_flags: [renewal: [], pre_renewal: [:remove_on_hermode]],
    no_save: true,
    properties: [:debuff],
    calc_flags: [:aspd_rate],
    immunity: [:boss],
    icon: :gravitation

  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager

  @impl true
  def modifiers(%{val1: level}, _context), do: %{aspd_rate: -5 * level}

  @impl true
  def on_damage(_target, %{state: %{self?: true}}, _damage_info, _context), do: :remove
  def on_damage(_target, instance, _damage_info, _context), do: {:ok, instance}

  @impl true
  def on_expire(_target, %{state: %{self?: true, group_id: group_id}}, _context)
      when is_integer(group_id) do
    Manager.destroy_async(group_id)
    :ok
  end

  def on_expire(_target, _instance, _context), do: :ok
end
