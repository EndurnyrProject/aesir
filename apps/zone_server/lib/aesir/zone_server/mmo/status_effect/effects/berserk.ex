defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Berserk do
  @moduledoc """
  Berserk (SC_BERSERK) triples maximum HP, suppresses recovery and most player
  actions, grants an infinite Endure rider, and drains 5% maximum HP every ten
  seconds. Renewal adds 200% ATK and 15 ASPD; pre-renewal adds 100% ATK and
  30% ASPD rate. Natural expiry reduces HP to 100, but Dispel does not.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_berserk,
    no_dispel: false,
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

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @impl true
  def modifiers(_instance, _context) do
    shared = %{
      max_hp_rate: 200,
      atk_rate: if(GameMode.mode() == :renewal, do: 200, else: 100),
      flee_rate: -50,
      def_override: 0,
      mdef_override: 0,
      def2_rate: -100,
      mdef2_rate: -100,
      movement_speed: -25,
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
  def on_expire({:player, id} = target, %StatusEntry{state: state}, %{target: %{hp: hp}}) do
    if Map.get(state || %{}, :penalty_armed, false) and hp > 100 do
      Helpers.set_vitals(target, hp: 100)
    end

    case StatusStorage.get_status(:player, id, :sc_endure) do
      %StatusEntry{val4: 1} -> Interpreter.remove_status(:player, id, :sc_endure)
      _ -> :ok
    end
  end
end
