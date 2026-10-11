defmodule Aesir.ZoneServer.Mmo.StatusEffect.DamageStageOrderTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :verify_on_exit!
  setup :setup_ets_tables

  @target 4_242
  @long_weapon_skill %{dmg_type: :physical, is_short: false, skill_id: 46, skill_level: 1}
  @melee %{dmg_type: :physical, is_short: true, skill_id: nil}

  describe "stage classification" do
    test "every status implementing absorb_damage has a fixed damage stage" do
      staged = MapSet.new(Interpreter.absorb_stages())

      unstaged =
        for module <- Effects.all(),
            :absorb_damage in module.__status_capabilities__(),
            module.id() not in staged,
            do: module.id()

      assert unstaged == []
      refute :sc_magicrod in staged
    end

    test "direct magic is missed after common reductions, while unit-origin magic passes" do
      pid = player(sp: 10, max_sp: 100)
      apply!(:sc_magicrod, val1: 5, val2: 100)
      apply!(:sc_energycoat)
      test_pid = self()

      stub(PlayerSession, :restore_sp, fn ^pid, amount ->
        send(test_pid, {:sp_refund, amount})
        :ok
      end)

      hit = %{
        dmg_type: :magic,
        is_short: false,
        skill_id: 19,
        skill_level: 10,
        from_caster?: true
      }

      {damage, info} = DamageApplication.prepare_unit_damage(:player, @target, 100, hit, 111)
      assert damage == 0
      assert info.magic_rod_miss?
      assert_received {:sp_refund, 30}

      {damage, info} =
        DamageApplication.prepare_unit_damage(
          :player,
          @target,
          100,
          %{hit | from_caster?: false},
          111
        )

      assert damage > 0
      refute info[:magic_rod_miss?]
    end
  end

  describe "common damage arithmetic" do
    test "Defending Aura subtracts before a skill's Blinding Mist quarter" do
      player(sp: 100, max_sp: 100)
      apply!(:sc_fogwall)
      apply!(:sc_defender, val1: 5)

      assert Interpreter.absorb_damage(:player, @target, 101, @long_weapon_skill) == 16
    end

    @tag game_mode: :renewal
    test "renewal runs Lex Aeterna, Energy Coat and Mental Strength in order" do
      pid = player(sp: 100, max_sp: 100)
      apply!(:sc_steelbody)
      apply!(:sc_energycoat)
      apply!(:sc_aeterna)
      expect(PlayerSession, :consume_sp, fn ^pid, 3 -> :ok end)

      assert Interpreter.absorb_damage(:player, @target, 19, @melee) == 2
      refute StatusStorage.has_status?(:player, @target, :sc_aeterna)
    end

    @tag game_mode: :pre_renewal
    test "classic halves after Lex Aeterna doubles on an ordinary map" do
      player(sp: 100, max_sp: 100)
      apply!(:sc_assumptio, val1: 5)
      apply!(:sc_aeterna)

      assert Interpreter.absorb_damage(:player, @target, 19, @melee) == 19
    end

    test "Energy Coat that cannot charge still reduces the hit and ends" do
      player(sp: 1, max_sp: 1_000)
      apply!(:sc_energycoat)
      reject(PlayerSession, :consume_sp, 2)

      assert Interpreter.absorb_damage(:player, @target, 101, @melee) == 95
      refute StatusStorage.has_status?(:player, @target, :sc_energycoat)
    end

    test "Energy Coat whose charge rounds to zero SP ends after reducing" do
      player(sp: 30, max_sp: 30)
      apply!(:sc_energycoat)
      reject(PlayerSession, :consume_sp, 2)

      assert Interpreter.absorb_damage(:player, @target, 100, @melee) == 70
      refute StatusStorage.has_status?(:player, @target, :sc_energycoat)
    end

    @tag game_mode: :renewal
    test "a status tick takes no attack stage" do
      player(sp: 100, max_sp: 100)
      apply!(:sc_steelbody)
      apply!(:sc_aeterna)

      assert Interpreter.absorb_damage(:player, @target, 50, %{
               dmg_type: :magic,
               status_tick?: true
             }) == 50

      assert StatusStorage.has_status?(:player, @target, :sc_aeterna)
    end
  end

  describe "blocking" do
    test "Kyrie Eleison spends its budget on the hit Energy Coat already reduced" do
      pid = player(sp: 100, max_sp: 100)
      apply!(:sc_kyrie, val2: 1_000, val3: 5)
      apply!(:sc_energycoat)
      expect(PlayerSession, :consume_sp, fn ^pid, 3 -> :ok end)

      assert Interpreter.absorb_damage(:player, @target, 100, @melee) == 0

      assert %{state: %{shield_hp: 930, hits_remaining: 4}} =
               StatusStorage.get_status(:player, @target, :sc_kyrie)
    end

    test "Kyrie Eleison spends a magic hit's budget and count without absorbing it" do
      player(sp: 100, max_sp: 100)
      apply!(:sc_kyrie, val2: 1_000, val3: 5)

      assert Interpreter.absorb_damage(:player, @target, 100, %{dmg_type: :magic, skill_id: 19}) ==
               100

      assert %{state: %{shield_hp: 900, hits_remaining: 4}} =
               StatusStorage.get_status(:player, @target, :sc_kyrie)
    end

    test "Holy Light ends Kyrie Eleison after spending it" do
      player(sp: 100, max_sp: 100)
      apply!(:sc_kyrie, val2: 1_000, val3: 5)

      assert Interpreter.absorb_damage(:player, @target, 100, %{dmg_type: :magic, skill_id: 156}) ==
               100

      refute StatusStorage.has_status?(:player, @target, :sc_kyrie)
    end

    test "Pneuma blocks a long-range misc hit" do
      player(sp: 100, max_sp: 100)
      apply!(:sc_pneuma)

      assert Interpreter.absorb_damage(:player, @target, 100, %{
               dmg_type: :misc,
               is_short: false,
               skill_id: 129
             }) == 0
    end

    @tag game_mode: :pre_renewal
    test "Lex Aeterna is consumed before classic Basilica blocks the hit" do
      player(sp: 100, max_sp: 100)
      apply!(:sc_basilica, val1: 5)
      apply!(:sc_aeterna)

      assert Interpreter.absorb_damage(:player, @target, 100, Map.put(@melee, :attacker, nil)) ==
               0

      refute StatusStorage.has_status?(:player, @target, :sc_aeterna)
    end
  end

  defp apply!(status_id, params \\ []) do
    :ok = Interpreter.apply_status(:player, @target, status_id, params)
  end

  defp player(vitals) do
    Mimic.copy(Resistance)
    stub(Resistance, :roll_success, fn _ -> true end)
    stub(Resistance, :roll_rate, fn _ -> true end)

    pid = spawn(fn -> Process.sleep(:infinity) end)
    stats = Map.merge(%{max_hp: 1_000, hp: 1_000, level: 50, base_level: 50}, Map.new(vitals))

    stub(UnitRegistry, :get_unit_info, fn _unit_type, _unit_id ->
      {:ok,
       %{
         unit_id: @target,
         unit_type: :player,
         race: :human,
         element: :neutral,
         element_level: 1,
         boss_flag: false,
         size: :medium,
         stats: stats
       }}
    end)

    state = %PlayerState{
      character_id: @target,
      action_state: :idle,
      stats: %{current_state: stats}
    }

    stub(UnitRegistry, :get_unit, fn
      :player, @target -> {:ok, {PlayerState, state, pid}}
      _type, _id -> {:error, :not_found}
    end)

    pid
  end
end
