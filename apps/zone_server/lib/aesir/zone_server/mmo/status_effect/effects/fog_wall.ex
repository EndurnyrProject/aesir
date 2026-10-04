defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.FogWall do
  @moduledoc """
  Blinding Mist (SC_FOGWALL), held by every unit standing in the fog.

  Skill hits on the holder lose a quarter of their damage, normal ranged weapon
  hits three quarters, and normal ranged attacks against it lose 50 hit rate.
  The holder's Blind does not run out while it stays in the fog. Leaving the fog
  ends a player's Blind and leaves anyone else blinded for 30 s more. Identical
  in both modes.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_fogwall,
    no_dispel: true,
    no_save: true,
    properties: [:debuff],
    immunity: [:boss],
    tick_interval: 1_000,
    icon: :fogwall

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @blind_hold_ms 5_000
  @blind_after_ms 30_000

  @impl true
  def modifiers(_instance, _context), do: %{normal_ranged_hit_taken_flat: 50}

  @impl true
  def absorb_damage(_target, instance, %{damage: damage, skill_id: skill_id} = hit, _context)
      when is_integer(skill_id) and damage > 0 do
    if Map.get(hit, :status_tick?, false),
      do: {:ok, damage, instance},
      else: {:ok, damage - div(damage * 25, 100), instance}
  end

  def absorb_damage(
        _target,
        instance,
        %{damage: damage, dmg_type: :physical, is_short: false},
        _context
      )
      when damage > 0,
      do: {:ok, div(damage, 4), instance}

  def absorb_damage(_target, instance, %{damage: damage}, _context), do: {:ok, damage, instance}

  @impl true
  def on_tick({type, id}, instance, _context) do
    hold_until = System.monotonic_time(:millisecond) + @blind_hold_ms
    extend_blind(type, id, hold_until, &max(&1, hold_until))
    {:ok, instance}
  end

  @impl true
  def on_expire({:player, id}, _instance, _context) do
    Interpreter.remove_status(:player, id, :sc_blind)
    :ok
  end

  def on_expire({type, id}, _instance, _context) do
    until = System.monotonic_time(:millisecond) + @blind_after_ms
    extend_blind(type, id, until, fn _current -> until end)
    :ok
  end

  defp extend_blind(type, id, _until, update) do
    if StatusStorage.has_status?(type, id, :sc_blind) do
      StatusStorage.update_status(type, id, :sc_blind, fn entry ->
        %{entry | expires_at: update.(entry.expires_at)}
      end)
    end
  end
end
