defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.FogWall do
  @moduledoc """
  Blinding Mist (SC_FOGWALL), held by every unit standing in the fog.

  In the common damage stage, after Defending Aura, skill hits on the holder lose
  a quarter of their damage (the removed amount truncated) and normal ranged
  weapon hits keep a truncated quarter; the Dragon Breath skills are exempt.
  Normal ranged attacks against the holder lose 50 hit rate.
  The holder's Blind does not run out while it stays in the fog. Leaving the fog
  ends a player's Blind and leaves anyone else blinded for 30 s more. Identical
  in both modes.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_fogwall,
    no_dispel: true,
    no_clear_buff: false,
    clear_buff_flags: [:remove_on_hermode],
    no_save: true,
    properties: [:debuff],
    immunity: [:boss],
    tick_interval: 1_000,
    icon: :fogwall

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @blind_hold_ms 5_000
  @blind_after_ms 30_000
  # NPC_DRAGONBREATH, RK_DRAGONBREATH, RK_DRAGONBREATH_WATER
  @dragon_breaths [731, 2008, 5004]

  @impl true
  def modifiers(_instance, _context), do: %{normal_ranged_hit_taken_flat: 50}

  @impl true
  def absorb_damage(_target, instance, %{damage: damage} = hit, _context) do
    skill_id = Map.get(hit, :skill_id)

    cond do
      skill_id in @dragon_breaths -> {:ok, damage, instance}
      is_integer(skill_id) -> {:ok, damage - div(damage * 25, 100), instance}
      long_weapon?(hit) -> {:ok, div(damage, 4), instance}
      true -> {:ok, damage, instance}
    end
  end

  defp long_weapon?(%{dmg_type: :physical, is_short: false}), do: true
  defp long_weapon?(_hit), do: false

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
