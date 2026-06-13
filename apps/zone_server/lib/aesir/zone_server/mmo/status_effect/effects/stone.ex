defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Stone do
  @moduledoc """
  Stone Curse (SC_STONE).

  Two-phase petrification: during :wait the target is slowed and gains MDEF,
  after 5 seconds the :stone phase petrifies completely with an earth element
  body, reduced DEF and increased MDEF. Earth element damage breaks it.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_stone,
    properties: [:debuff, :prevents_movement, :prevents_skills, :prevents_attack],
    calc_flags: [:def_ele, :def, :mdef, :speed],
    flags: [:no_move, :no_attack, :no_skill, :no_magic],
    prevented_by: [:sc_refresh, :sc_inspiration, :sc_protection],
    initial_phase: :wait

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  @wait_duration_ms 5_000

  @impl true
  def modifiers(%{phase: :wait}, _context), do: %{mdef: 25, movement_speed: -50}
  def modifiers(%{phase: :stone}, _context), do: %{element: :earth1, def: -50, mdef: 25}

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
