defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Cloaking do
  @moduledoc """
  Cloaking (SC_CLOAKING).

  Conceals the character while allowing movement. Doubles CRIT and adjusts
  movement speed by skill level (val1). Broken by taking damage.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_cloaking,
    properties: [:buff],
    calc_flags: [:cri, :speed],
    flags: [:cloak, :no_pick_item, :stop_attacking],
    prevented_by: [:sc_refresh, :sc_inspiration]

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  @impl true
  def modifiers(instance, context) do
    %{cri: Map.get(context.target, :cri, 0), movement_speed: speed_modifier(instance.val1)}
  end

  @impl true
  def on_apply(_target, instance, _context) do
    {:ok, put_state(instance, :cloaked, true)}
  end

  @impl true
  def on_damage(_target, _instance, _damage_info, _context), do: :remove

  defp speed_modifier(level) when level >= 10, do: -25
  defp speed_modifier(level) when level >= 3, do: -(30 - 3 * level)
  defp speed_modifier(_level), do: -300
end
