defmodule Aesir.ZoneServer.Mmo.StatusEffect.AbsorbDamageTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup
  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.HandedAttack
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage, as: SkillUnitStorage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule PassThroughStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_passthrough,
      no_dispel: false,
      properties: [:buff]
  end

  defmodule HalfStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_half,
      no_dispel: false,
      properties: [:buff]

    @impl true
    def absorb_damage(_target, instance, %{damage: damage}, _context) do
      {:ok, div(damage, 2), instance}
    end
  end

  defmodule BlockOnceStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_block_once,
      no_dispel: false,
      properties: [:buff]

    import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

    @impl true
    def on_apply(_target, instance, _context) do
      {:ok, put_state(instance, :hits_remaining, 2)}
    end

    @impl true
    def absorb_damage(_target, instance, _hit_info, _context) do
      case instance.state.hits_remaining - 1 do
        n when n <= 0 -> {:remove, 0}
        n -> {:ok, 0, put_state(instance, :hits_remaining, n)}
      end
    end
  end

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

  describe "absorb_damage/4" do
    test "passes damage through unchanged with the default callback" do
      target_id = 1
      setup_player_mock(target_id)
      Registry.register_module(PassThroughStatus)
      :ok = Interpreter.apply_status(:player, target_id, :sc_test_passthrough)

      assert 100 = Interpreter.absorb_damage(:player, target_id, 100, %{dmg_type: :physical})
    end

    test "a reducing status lowers the damage" do
      target_id = 2
      setup_player_mock(target_id)
      Registry.register_module(HalfStatus)
      :ok = Interpreter.apply_status(:player, target_id, :sc_test_half)

      assert 50 = Interpreter.absorb_damage(:player, target_id, 100, %{dmg_type: :physical})
    end

    test "a blocking status removes itself after exhausting its budget" do
      target_id = 3
      setup_player_mock(target_id)
      Registry.register_module(BlockOnceStatus)
      :ok = Interpreter.apply_status(:player, target_id, :sc_test_block_once)

      assert 0 = Interpreter.absorb_damage(:player, target_id, 100, %{dmg_type: :physical})
      assert StatusStorage.has_status?(:player, target_id, :sc_test_block_once)

      assert 0 = Interpreter.absorb_damage(:player, target_id, 100, %{dmg_type: :physical})
      refute StatusStorage.has_status?(:player, target_id, :sc_test_block_once)
    end

    test "no active statuses returns the damage unchanged" do
      target_id = 4
      setup_player_mock(target_id)

      assert 77 = Interpreter.absorb_damage(:player, target_id, 77, %{dmg_type: :magic})
    end
  end

  describe "aggregate weapon swings" do
    test "Lex Aeterna doubles and consumes once for both components" do
      target_id = 8
      target_pid = setup_player_mock(target_id)
      :ok = Interpreter.apply_status(:player, target_id, :sc_aeterna)

      expect(PlayerSession, :apply_damage, fn ^target_pid, 300, {:player, 99} -> :ok end)

      {settled, :ok} = apply_swing(target_pid, target_id)

      assert settled.primary.damage == 200
      assert settled.secondary.damage == 100
      refute StatusStorage.has_status?(:player, target_id, :sc_aeterna)
    end

    test "Kyrie spends one hit and one aggregate shield amount" do
      target_id = 9
      target_pid = setup_player_mock(target_id)

      :ok =
        Interpreter.apply_status(:player, target_id, :sc_kyrie, val2: 1_000, val3: 5)

      expect(PlayerSession, :apply_damage, fn ^target_pid, 0, {:player, 99} -> :ok end)

      {settled, :ok} = apply_swing(target_pid, target_id)

      assert settled.primary.damage + settled.secondary.damage == 0

      assert %{state: %{shield_hp: 850, hits_remaining: 4}} =
               StatusStorage.get_status(:player, target_id, :sc_kyrie)
    end

    test "Energy Coat drains SP and reduces the aggregate once" do
      target_id = 10
      target_pid = setup_player_mock(target_id)
      :ok = Interpreter.apply_status(:player, target_id, :sc_energycoat)

      expect(PlayerSession, :consume_sp, fn ^target_pid, 3 -> :ok end)
      expect(PlayerSession, :apply_damage, fn ^target_pid, 105, {:player, 99} -> :ok end)

      {settled, :ok} = apply_swing(target_pid, target_id)

      assert settled.primary.damage == 70
      assert settled.secondary.damage == 35
      assert StatusStorage.has_status?(:player, target_id, :sc_energycoat)
    end

    test "Safety Wall spends one hit and one aggregate shield amount" do
      target_id = 11
      target_pid = setup_player_mock(target_id)
      start_safetywall(%{hits_remaining: 6, shield_hp: 9_500})

      :ok = Interpreter.apply_status(:player, target_id, :sc_safetywall, val2: 42)
      expect(PlayerSession, :apply_damage, fn ^target_pid, 0, {:player, 99} -> :ok end)

      {settled, :ok} = apply_swing(target_pid, target_id)

      assert settled.primary.damage + settled.secondary.damage == 0

      assert %Group{state: %{hits_remaining: 5, shield_hp: 9_350}} =
               SkillUnitStorage.get(42)
    end
  end

  describe "Kyrie absorb_damage" do
    test "blocks physical hits until hit budget exhausts, then expires" do
      target_id = 5
      setup_player_mock(target_id)

      :ok =
        Interpreter.apply_status(:player, target_id, :sc_kyrie, val2: 10_000, val3: 2)

      assert 0 = Interpreter.absorb_damage(:player, target_id, 100, %{dmg_type: :physical})
      assert StatusStorage.has_status?(:player, target_id, :sc_kyrie)

      assert 0 = Interpreter.absorb_damage(:player, target_id, 100, %{dmg_type: :physical})
      refute StatusStorage.has_status?(:player, target_id, :sc_kyrie)
    end

    test "expires when shield_hp is drained even before hits run out" do
      target_id = 6
      setup_player_mock(target_id)

      :ok = Interpreter.apply_status(:player, target_id, :sc_kyrie, val2: 50, val3: 10)

      assert 50 = Interpreter.absorb_damage(:player, target_id, 100, %{dmg_type: :physical})
      refute StatusStorage.has_status?(:player, target_id, :sc_kyrie)
    end

    test "passes magic hits through unchanged" do
      target_id = 7
      setup_player_mock(target_id)

      :ok = Interpreter.apply_status(:player, target_id, :sc_kyrie, val2: 10_000, val3: 5)

      assert 100 = Interpreter.absorb_damage(:player, target_id, 100, %{dmg_type: :magic})
      assert StatusStorage.has_status?(:player, target_id, :sc_kyrie)
    end
  end

  defp start_safetywall(state) do
    manager =
      start_supervised!({Manager, name: nil, schedule_tick: fn _pid, _interval -> :ok end})

    Process.put({Manager, :server}, manager)

    SkillUnitStorage.insert(%Group{
      group_id: 42,
      skill_id: 12,
      skill_name: :mg_safetywall,
      level: 5,
      caster_id: 2_000,
      caster_type: :player,
      map_name: "prontera",
      center: {100, 100},
      cells: [{100, 100}],
      next_tick_at: 0,
      expires_at: 0,
      interval: 1_000,
      state: state
    })
  end

  defp apply_swing(target_pid, target_id) do
    DamageApplication.apply_weapon_swing(
      :player,
      target_pid,
      target_id,
      %HandedAttack{
        primary: %{damage: 100, is_critical: false},
        secondary: %{damage: 50, is_critical: false},
        raw_total: 150,
        display_divisions: 1,
        outcome: :hit,
        primary_element: :neutral
      },
      %{
        dmg_type: :physical,
        is_short: true,
        element: :neutral,
        skill_id: nil,
        skill_level: nil,
        from_caster?: true
      },
      99
    )
  end

  defp setup_player_mock(player_id) do
    Mimic.copy(Aesir.ZoneServer.Mmo.StatusEffect.Resistance)
    Mimic.copy(UnitRegistry)

    player_pid = spawn(fn -> Process.sleep(:infinity) end)

    stub(UnitRegistry, :get_unit_info, fn _unit_type, _unit_id ->
      {:ok,
       %{
         unit_id: player_id,
         unit_type: :player,
         race: :human,
         element: :neutral,
         element_level: 1,
         boss_flag: false,
         size: :medium,
         stats: %{
           max_hp: 1000,
           max_sp: 100,
           hp: 800,
           sp: 80,
           level: 50,
           base_level: 50,
           str: 10,
           agi: 10,
           vit: 10,
           int: 10,
           dex: 10,
           luk: 10,
           mdef: 5
         }
       }}
    end)

    player_state = %PlayerState{
      character_id: player_id,
      action_state: :idle,
      stats: %{current_state: %{hp: 800}}
    }

    stub(UnitRegistry, :get_unit, fn :player, ^player_id ->
      {:ok, {PlayerState, player_state, player_pid}}
    end)

    stub(Aesir.ZoneServer.Mmo.StatusEffect.Resistance, :roll_success, fn _ -> true end)
    player_pid
  end
end
