defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.MagicPower do
  @moduledoc """
  Mystical Amplification (SC_MAGICPOWER). Raises MATK by 5% per level.

  Renewal: multiplies base plus weapon MATK, before flat MATK, for the whole
  duration. Pre-renewal: the status starts unarmed and grants nothing; the start
  of the holder's next offensive magic cast arms it, multiplying final MATK, and
  the start of the following one ends it, so exactly one spell is amplified.
  Weapon, no-damage and support casts neither arm nor end it.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_magicpower,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:matk],
    no_save: true,
    icon: :magicpower

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Catalog

  @impl true
  def modifiers(%{val1: level} = instance, _context) do
    if GameMode.mode() == :renewal or armed?(instance),
      do: %{base_matk_rate: 5 * level},
      else: %{}
  end

  @impl true
  def on_committed_action(_target, instance, {:skill, skill_id}, _context) do
    cond do
      GameMode.mode() == :renewal or not offensive_magic?(skill_id) -> {:ok, instance}
      armed?(instance) -> :remove
      true -> {:ok, put_state(instance, :armed, true)}
    end
  end

  def on_committed_action(_target, instance, _action, _context), do: {:ok, instance}

  defp armed?(%{state: %{armed: true}}), do: true
  defp armed?(_instance), do: false

  defp offensive_magic?(skill_id) do
    match?({:ok, %{damage_type: :damage, damage_kind: :magic}}, Catalog.by_id(skill_id))
  end
end
