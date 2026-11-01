defmodule Aesir.ZoneServer.Mmo.Skills.Swordsman.SelfprovokeParityTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.SkillEffect
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.Combat.DamageInputs
  alias Aesir.ZoneServer.Mmo.Combat.EquipComa
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter, as: SkillInterpreter
  alias Aesir.ZoneServer.Mmo.Skills.Swordsman.SmSelfprovoke
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Provoke
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.TrapTestHelper
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :verify_on_exit!
  setup :setup_ets_tables

  setup do
    player =
      PlayerState.new(%Character{
        id: 7_706,
        account_id: 7_706,
        name: "Self provoke",
        class: 0,
        base_level: 1,
        job_level: 1,
        str: 1,
        agi: 1,
        vit: 10,
        int: 1,
        dex: 1,
        luk: 1,
        hp: 40,
        sp: 11,
        last_map: "prontera",
        last_x: 100,
        last_y: 100
      })

    :ok = UnitRegistry.register_player(player, self())
    %{player: player}
  end

  test "provoke changes player soft defense but not hard defense or hit", %{player: player} do
    assert :ok =
             Interpreter.apply_status(:player, player.character_id, :sc_provoke,
               val1: 1,
               caster_id: player.character_id,
               duration: 30_000,
               bypass_resistance: true
             )

    held = StatusStorage.get_status(:player, player.character_id, :sc_provoke)
    assert held.val2 == 5
    assert held.val3 == 10
    modifiers = Interpreter.get_all_modifiers(:player, player.character_id)
    assert Map.get(modifiers, :hit, 0) == 0
    assert Map.get(modifiers, :def_rate, 0) == 0

    defender = PlayerState.to_combatant(player)
    defender = %{defender | combat_stats: %{defender.combat_stats | def: 100, soft_def: 100}}

    assert {100, 90} =
             DamageInputs.physical_defense(
               defender,
               nil,
               :normal,
               :omit_equipment_def_ignore,
               modifiers
             )
  end

  test "self provoke applies through status defense without the enemy chance roll", %{
    player: player
  } do
    assert {:local_effects, ^player, effects} =
             SmSelfprovoke.cast(player, :self, 1, SmSelfprovoke.definition())

    assert {:player, {:status_events, [{:sc_provoke, :apply}]}} in effects
    assert {:player, {:skill_visual, 6, 1}} in effects
    assert {:player, {:conditional_cast_cancel}} in effects
    entry = StatusStorage.get_status(:player, player.character_id, :sc_provoke)
    assert entry.val2 == 5
    assert entry.val3 == 10
    assert entry.expires_at == entry.started_at + 30_000
  end

  test "the item cast returns local consequences without dropping them", %{player: player} do
    assert {:instant, ^player, effects} = SkillInterpreter.begin_item_cast(player, 473, 1, :self)
    assert {:player, {:skill_visual, 6, 1}} in effects
  end

  test "the owning handler applies the selected status and shows only the ordinary visual", %{
    player: player
  } do
    observer = self()
    stub(CharacterPersistence, :update_character, fn _id, _attrs, _opts -> :ok end)

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet ->
      send(observer, {:visual, packet})
      :ok
    end)

    player = put_in(player.stats.progression.learned_skills, %{473 => 1})
    :ok = UnitRegistry.update_unit_state(:player, player.character_id, player)
    state = %SessionState{game_state: player, connection_pid: self()}

    assert {:noreply, updated} = SkillHandler.handle_use_skill(state, 473, 1, player.character_id)
    assert updated.game_state.stats.generation == player.stats.generation
    assert Map.get(updated.game_state.stats.modifiers.status_effects, :atk_rate) == 5
    assert_receive {:visual, %SkillEffect{skill_id: 6, level: 1}}
    refute_receive {:visual, %SkillEffect{skill_id: 473}}, 0
  end

  test "undead immunity is silent and unrelated protection statuses do not block provoke", %{
    player: player
  } do
    {:ok, info} = UnitRegistry.get_unit_info(:player, player.character_id)
    stub(UnitRegistry, :get_unit_info, fn :player, _id -> {:ok, %{info | element: :undead}} end)

    assert {:local_effects, ^player, [{:player, {:status_events, []}}]} =
             SmSelfprovoke.cast(player, :self, 1, SmSelfprovoke.definition())

    refute StatusStorage.has_status?(:player, player.character_id, :sc_provoke)
    stub(UnitRegistry, :get_unit_info, fn :player, _id -> {:ok, info} end)
    :ok = StatusStorage.apply_status(:player, player.character_id, :sc_refresh)
    :ok = StatusStorage.apply_status(:player, player.character_id, :sc_inspiration)

    assert {:local_effects, ^player, effects} =
             SmSelfprovoke.cast(player, :self, 1, SmSelfprovoke.definition())

    assert {:player, {:skill_visual, 6, 1}} in effects
    refute Enum.any?(effects, &match?({:player, {:skill_failed, _}}, &1))
  end

  test "equipment coma settles in the owning handler without a self-message", %{player: player} do
    Mimic.copy(EquipComa)
    stub(EquipComa, :bonus?, fn _combatant -> true end)
    stub(EquipComa, :trigger?, fn _attacker, _target -> true end)
    stub(CharacterPersistence, :update_character, fn _id, _attrs, _opts -> :ok end)
    stub(CharacterPersistence, :update_stats, fn _id, _attrs, _opts -> :ok end)
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    player = put_in(player.stats.progression.learned_skills, %{473 => 1})
    :ok = UnitRegistry.update_unit_state(:player, player.character_id, player)

    assert {:noreply, updated} =
             SkillHandler.handle_use_skill(
               %SessionState{game_state: player, connection_pid: self()},
               473,
               1,
               player.character_id
             )

    assert updated.game_state.stats.current_state.hp == 1
    assert updated.game_state.stats.current_state.sp == 1
    refute_received {:"$gen_cast", {:unit, {:apply_coma, _, _}}}
  end

  test "conditional interruption does not cancel protected or non-cancellable casts", %{
    player: player
  } do
    protected =
      put_in(
        player.stats,
        [Access.key!(:modifiers), Access.key!(:equipment), :no_cast_cancel2],
        1
      )

    for {stats, interruptible} <- [{player.stats, false}, {protected, true}] do
      casting = %{player | stats: stats, casting: %{interruptible: interruptible}}
      state = %SessionState{game_state: casting, connection_pid: self()}
      assert SkillHandler.interrupt_cast_on_damage(state) == state
    end
  end

  test "non-player self provoke applies the real status and taunts its own unit" do
    mob = TrapTestHelper.mob(5_006)
    :ok = UnitRegistry.register_unit(:mob, mob.instance_id, MobState, mob, self())
    observer = self()

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet ->
      send(observer, {:visual, packet})
      :ok
    end)

    assert {:ok, ^mob} = SmSelfprovoke.cast(mob, :self, 1, SmSelfprovoke.definition())
    assert %{val2: 5, val3: 10} = StatusStorage.get_status(:mob, mob.instance_id, :sc_provoke)
    assert_receive {:"$gen_cast", {:ai, {:provoke, {:mob, 5_006}}}}
    assert_receive {:visual, %SkillEffect{skill_id: 6}}
  end

  test "a refused status start reports failure without a successful skill visual", %{
    player: player
  } do
    stub(Interpreter, :apply_status_with_events, fn :player, _id, :sc_provoke, _params ->
      {:error, :prevented, []}
    end)

    assert {:local_effects, ^player, effects} =
             SmSelfprovoke.cast(player, :self, 1, SmSelfprovoke.definition())

    assert effects == [{:player, {:status_events, []}}, {:player, {:skill_failed, 473}}]
  end

  test "loaded provoke values and non-player level-ten initialization are retained", %{
    player: player
  } do
    assert :ok =
             Interpreter.apply_status(:player, player.character_id, :sc_provoke,
               loaded: true,
               duration: 20_000,
               val1: 1,
               val2: 17,
               val3: 23
             )

    held = StatusStorage.get_status(:player, player.character_id, :sc_provoke)
    assert {held.val2, held.val3} == {17, 23}

    stub(UnitRegistry, :unit_exists?, fn :mob, 5_006 -> true end)
    instance = %StatusEntry{held | val1: 10, source_id: 5_006, source_type: :mob}

    assert {:ok, initialized} =
             Provoke.on_apply({:player, player.character_id}, instance, %{loaded: false})

    assert {initialized.val2, initialized.val3} == {0, 100}
    assert Provoke.modifiers(initialized, %{unit_type: :mob}).def_rate == -100
  end
end
