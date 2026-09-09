defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Stone do
  @moduledoc """
  Stone Curse (SC_STONE).

  Two-phase petrification. The applying skill sizes the whole status; the first
  five seconds are the :wait phase, in which the target only gains MDEF, and the
  remainder is the :stone phase, which petrifies completely with an earth element
  body, reduced DEF and increased MDEF. Earth element damage breaks it.

  Petrification stops movement through the `:no_move` flag (the petrify body
  state), not through a speed-rate penalty: the speed calculation never consults
  this status. It therefore carries no `:speed` calc flag and no
  `:movement_speed` modifier.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_stone,
    no_dispel: false,
    properties: [:debuff, :prevents_movement, :prevents_skills, :prevents_attack],
    calc_flags: [:def_ele, :def, :mdef],
    flags: [:no_move, :no_attack, :no_skill, :no_magic],
    prevented_by: [:sc_refresh, :sc_inspiration, :sc_protection],
    initial_phase: :wait,
    tick_interval: 1_000,
    opt1: :stone

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  @wait_duration_ms 5_000

  @impl true
  def modifiers(%{phase: :wait}, _context), do: %{mdef: 25}

  def modifiers(%{phase: :stone}, _context),
    do: %{element_override: {:earth, 1}, def: -50, mdef: 25}

  @impl true
  def on_tick(_target, %{phase: :wait} = instance, _context) do
    if elapsed_ms(instance) >= @wait_duration_ms do
      {:ok, %{instance | phase: :stone}}
    else
      {:ok, instance}
    end
  end

  def on_tick(_target, instance, _context), do: {:ok, instance}

  @impl true
  def on_damage(_target, %{phase: :stone}, %{element: :earth}, _context), do: :remove
  def on_damage(_target, instance, _damage_info, _context), do: {:ok, instance}
end
