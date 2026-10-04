defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.MagicPower do
  @moduledoc """
  Mystical Amplification (SC_MAGICPOWER). Raises MATK by 5% per level.

  Renewal: multiplies base plus weapon MATK (before flat item MATK) for the
  whole duration. Pre-renewal: multiplies final MATK and ends once an offensive
  magic skill the holder casts has resolved, so that spell is the one amplified;
  weapon, support and no-damage casts keep it, and so does a cancelled cast.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_magicpower,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:matk],
    no_save: true,
    icon: :magicpower

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Catalog

  @impl true
  def modifiers(%{val1: level}, _context) do
    case GameMode.mode() do
      :renewal -> %{base_matk_rate: 5 * level}
      :pre_renewal -> %{matk_rate: 5 * level}
    end
  end

  @impl true
  def on_committed_action(_target, instance, {:skill_resolved, skill_id}, _context) do
    if GameMode.mode() == :pre_renewal and offensive_magic?(skill_id),
      do: :remove,
      else: {:ok, instance}
  end

  def on_committed_action(_target, instance, _action, _context), do: {:ok, instance}

  defp offensive_magic?(skill_id) do
    match?({:ok, %{damage_type: :damage, damage_kind: :magic}}, Catalog.by_id(skill_id))
  end
end
