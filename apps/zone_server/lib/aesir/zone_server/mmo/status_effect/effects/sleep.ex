defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Sleep do
  @moduledoc """
  Sleep (SC_SLEEP).

  The target is asleep and cannot act. Any damage wakes it up.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_sleep,
    properties: [:debuff, :prevents_movement, :prevents_skills, :prevents_attack],
    flags: [:no_move, :no_attack, :no_skill, :no_magic],
    prevented_by: [:sc_refresh, :sc_inspiration, :sc_sleep, :sc_protection],
    opt1: :sleep

  @impl true
  def on_damage(_target, _instance, _damage_info, _context), do: :remove
end
