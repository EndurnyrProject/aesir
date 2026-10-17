defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Berserk do
  @moduledoc """
  Berserk (SC_BERSERK) triples maximum HP, suppresses recovery and most player
  actions, grants an infinite Endure rider, and drains 5% maximum HP every ten
  seconds. Renewal adds 200 to every weapon attack's skill ratio and 15 ASPD;
  pre-renewal adds 100 to the ratio and 30% ASPD rate. Natural expiry reduces
  HP to 100, but Dispel does not. Every end drops the Endure rider and blocks
  natural HP and SP regeneration for 300 seconds (a Regeneration with `val4`).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_berserk,
    no_dispel: false,
    no_clear_buff: false,
    no_save: true,
    properties: [
      :buff,
      :prevents_skills,
      :prevents_items,
      :prevents_chat,
      :prevents_equip_change
    ],
    target_types: [:player],
    tick_interval: 10_000,
    icon: :berserk,
    opt3: :berserk

  import Bitwise

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @regen_hp 0x01
  @regen_sp 0x02

  @impl true
  def modifiers(_instance, _context) do
    shared = %{
      max_hp_rate: 200,
      skill_ratio: if(GameMode.mode() == :renewal, do: 200, else: 100),
      flee_rate: -50,
      def_override: 0,
      mdef_override: 0,
      def2_rate: -100,
      mdef2_rate: -100,
      haste_rate: 25,
      hp_regen: -100,
      sp_regen: -100,
      skill_hp_regen_rate: -100,
      skill_sp_regen_rate: -100
    }

    Map.merge(shared, if(GameMode.mode() == :renewal, do: %{aspd: 15}, else: %{aspd_rate: 30}))
  end

  @impl true
  def on_apply({:player, id} = target, instance, _context) do
    _ =
      Interpreter.apply_status(:player, id, :sc_endure,
        val1: 10,
        val4: 1,
        duration: 300_000,
        caster_id: id
      )

    Helpers.set_vitals(target, hp: :max, sp: 0)
    {:ok, Helpers.put_state(instance, :penalty_armed, true)}
  end

  @impl true
  def on_tick(target, instance, %{target: %{hp: hp, max_hp: max_hp}}) do
    drain = div(max_hp * 5, 100)

    cond do
      hp <= drain ->
        :remove

      hp - drain <= 100 ->
        Helpers.deal_damage(target, drain)
        :remove

      true ->
        Helpers.deal_damage(target, drain)
        {:ok, instance}
    end
  end

  @impl true
  def on_damage(_target, _instance, _damage_info, %{target: %{hp: hp}}) when hp <= 100,
    do: :remove

  def on_damage(_target, instance, _damage_info, _context), do: {:ok, instance}

  @impl true
  def on_expire({:player, id} = target, %StatusEntry{state: state}, %{target: target_stats}) do
    penalize(target, state, target_stats)

    case StatusStorage.get_status(:player, id, :sc_endure) do
      %StatusEntry{val4: 1} -> Interpreter.remove_status(:player, id, :sc_endure)
      _ -> :ok
    end

    block_regeneration(id, target_stats)
  end

  # A holder already gone from the world has no HP left to set.
  defp penalize(_target, _state, target_stats) when target_stats == %{}, do: :ok

  defp penalize(target, state, %{hp: hp}) do
    if Map.get(state || %{}, :penalty_armed, false) and hp > 100 do
      Helpers.set_vitals(target, hp: 100)
    end
  end

  # The end blocks natural HP and SP regeneration (val4) for the skill's duration.
  defp block_regeneration(_id, target_stats) when target_stats == %{}, do: :ok

  defp block_regeneration(id, _target_stats) do
    _ =
      Interpreter.apply_status(:player, id, :sc_regeneration,
        val1: 10,
        val4: @regen_hp ||| @regen_sp,
        duration: 300_000,
        caster_id: id
      )

    :ok
  end
end
