defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Hiding do
  @moduledoc """
  Hiding (SC_HIDING).

  Conceals the character underground. Broken by taking damage. Movement while
  hidden requires Tunnel Drive.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_hiding,
    no_dispel: true,
    properties: [:buff, :conceals, :prevents_movement],
    calc_flags: [:speed],
    flags: [:hide, :no_move, :no_pick_item, :no_consume_item, :stop_attacking],
    end_on_start: [:sc_closeconfine, :sc_closeconfine2],
    prevented_by: [:sc_refresh, :sc_inspiration],
    no_save: true,
    icon: :hiding,
    option: :hide

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  @impl true
  def modifiers(_instance, _context), do: %{hiding: true}

  @impl true
  def on_apply(_target, instance, _context) do
    {:ok, put_state(instance, :hidden, true)}
  end

  @impl true
  def on_damage(_target, _instance, _damage_info, _context), do: :remove
end
