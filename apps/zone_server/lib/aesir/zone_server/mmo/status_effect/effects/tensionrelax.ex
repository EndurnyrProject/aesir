defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Tensionrelax do
  @moduledoc """
  Tension Relax (SC_TENSIONRELAX) triples the natural and skill HP
  regeneration tick rates while sitting in both Renewal and pre-renewal. While
  overweight the natural regeneration keeps running at normal speed instead.
  It ends on standing, full HP, or after 180 seconds.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_tensionrelax,
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:remove_on_hermode],
    no_save: true,
    properties: [:buff],
    calc_flags: [:regen],
    tick_interval: 1_000,
    target_types: [:player],
    icon: :tensionrelax

  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @impl true
  @spec modifiers(StatusEntry.t(), map()) :: %{
          hp_regen_tick_rate: 200,
          skill_hp_regen_tick_rate: 200
        }
  def modifiers(_instance, _context),
    do: %{hp_regen_tick_rate: 200, skill_hp_regen_tick_rate: 200}

  @impl true
  @spec on_tick({:player, integer()}, StatusEntry.t(), map()) :: {:ok, StatusEntry.t()} | :remove
  def on_tick({:player, id}, instance, %{target: %{hp: hp, max_hp: max_hp}}) do
    case UnitRegistry.get_unit(:player, id) do
      {:ok, {_module, %{action_state: :sitting}, _pid}} when hp < max_hp -> {:ok, instance}
      _ -> :remove
    end
  end
end
