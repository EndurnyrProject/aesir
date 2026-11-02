defmodule Aesir.ZoneServer.Mmo.Skills.Other.CashPartySkillsTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.SkillCastFailed
  alias Aesir.Net.SkillEffect
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skills.Other.AllPartyflee
  alias Aesir.ZoneServer.Mmo.Skills.Other.CashAssumptio
  alias Aesir.ZoneServer.Mmo.Skills.Other.CashBlessing
  alias Aesir.ZoneServer.Mmo.Skills.Other.CashIncagi
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.TrapTestHelper
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.Stats.Calculator
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule CooldownProbe do
    @moduledoc false
    alias Aesir.ZoneServer.Mmo.Skills.Other.AllPartyflee

    def validate(caster, target, level, definition),
      do: AllPartyflee.validate(caster, target, level, definition)

    def cast(caster, target, level, definition) do
      send(self(), {:effect_cooldown, caster.skill_cooldowns[693]})
      AllPartyflee.cast(caster, target, level, definition)
    end
  end

  setup :set_mimic_private
  setup :setup_ets_tables

  setup do
    player =
      PlayerState.new(%Character{
        id: 7_710,
        account_id: 7_710,
        name: "Cash skills",
        class: 0,
        base_level: 1,
        job_level: 1,
        str: 1,
        agi: 1,
        vit: 1,
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
    stub(Resistance, :roll_success, fn _ -> true end)
    Mimic.copy(Persistence)
    stub(Persistence, :transaction, fn fun -> fun.() end)
    stub(Persistence, :update_item, fn item, attrs -> {:ok, struct!(item, attrs)} end)
    stub(CharacterPersistence, :update_character, fn _id, _attrs, _opts -> :ok end)
    observer = self()

    stub(Broadcast, :to_player, fn _id, packet ->
      send(observer, {:private, packet})
      :ok
    end)

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet ->
      send(observer, {:visual, packet})
      :ok
    end)

    %{player: player}
  end

  test "cash solo uses self while party flee fails after claim and cooldown", %{player: player} do
    for {id, level, status, duration} <- [
          {689, 10, :sc_blessing, 240_000},
          {690, 10, :sc_increaseagi, 240_000},
          {691, 5, :sc_assumptio, 100_000}
        ] do
      before = System.monotonic_time(:millisecond)
      assert {:instant, cast, effects} = Interpreter.begin_item_cast(player, id, level, :self)
      after_cast = System.monotonic_time(:millisecond)
      assert {:player, {:status_events, [{status, :apply}]}} in effects
      assert cast.stats.current_state.sp == player.stats.current_state.sp
      entry = StatusStorage.get_status(:player, player.character_id, status)
      assert entry.val1 == level
      assert entry.source_id == player.character_id
      assert entry.expires_at >= before + duration
      assert entry.expires_at <= after_cast + duration
    end

    before = System.monotonic_time(:millisecond)

    claim = fn caster ->
      send(self(), :claimed)
      {:ok, caster}
    end

    assert {:instant, failed, effects} = Interpreter.begin_item_cast(player, 693, 1, :self, claim)
    after_cast = System.monotonic_time(:millisecond)
    assert_receive :claimed
    assert {:player, {:status_events, []}} in effects
    assert {:player, {:skill_failed, 693}} in effects
    assert failed.skill_cooldowns[693] >= before + 300_000
    assert failed.skill_cooldowns[693] <= after_cast + 300_000
    refute StatusStorage.has_status?(:player, player.character_id, :sc_partyflee)

    assert {:error, _reason} =
             Interpreter.begin_item_cast(failed, 693, 1, :self, fn _ ->
               flunk("cooldown refusal must not claim another item")
             end)

    refute_receive :claimed, 0
  end

  test "party flee cooldown is already armed when its paid effect starts", %{player: player} do
    stub(Catalog, :active_module_for, fn :all_partyflee -> {:ok, CooldownProbe} end)
    before = System.monotonic_time(:millisecond)
    assert {:instant, _cast, _effects} = Interpreter.begin_item_cast(player, 693, 1, :self)
    assert_receive {:effect_cooldown, deadline}
    assert is_integer(deadline) and deadline >= before + 300_000
  end

  test "renewal party flee retains staged five with a one millisecond empty-selection status", %{
    player: player
  } do
    level = if GameMode.mode() == :renewal, do: 5, else: 1

    player = %{
      player
      | party_id: 10,
        pending_map_load: nil,
        inventory: %{0 => %InventoryItem{id: 1, nameid: 12311, amount: 2}}
    }

    :ok = UnitRegistry.update_unit_state(:player, player.character_id, player)
    stub(PartyManager, :get, fn 10 -> {:ok, party(player.character_id)} end)
    state = staged(player, 693, level, 12311)
    before = System.monotonic_time(:millisecond)
    assert {:noreply, cast} = SkillHandler.handle_use_skill(state, 693, 99, player.character_id)
    after_cast = System.monotonic_time(:millisecond)
    held = StatusStorage.get_status(:player, player.character_id, :sc_partyflee)
    assert held.val1 == level
    assert held.started_at in before..after_cast
    assert held.expires_at == held.started_at + 1
    assert cast.game_state.inventory[0].amount == 1
    assert cast.game_state.stats.generation == player.stats.generation
    assert cast.game_state.stats.combat_stats.flee == player.stats.combat_stats.flee
    assert_receive {:visual, %SkillEffect{skill_id: 693, level: ^level}}
    refute_receive {:visual, %SkillEffect{skill_id: 693}}, 0

    calculated = Calculator.calculate_stats(cast.game_state.stats, player.character_id)
    assert calculated.combat_stats.flee == player.stats.combat_stats.flee + 10 * level
    observed = %{cast | game_state: %{cast.game_state | stats: calculated}}

    events =
      StatusInterpreter.expire_status_events_if_current(
        :player,
        player.character_id,
        :sc_partyflee,
        held
      )

    assert events == [{:sc_partyflee, :removed}]
    expired = StatusManager.refresh_events(observed, events)
    assert expired.game_state.stats.combat_stats.flee == calculated.combat_stats.flee
    assert expired.game_state.stats.generation == calculated.generation
    refute StatusStorage.has_status?(:player, player.character_id, :sc_partyflee)
  end

  test "staged solo party flee spends one item and reports failure without a full fold", %{
    player: player
  } do
    player = %{player | inventory: %{0 => %InventoryItem{id: 1, nameid: 12311, amount: 2}}}
    state = staged(player, 693, 1, 12311)
    assert {:noreply, cast} = SkillHandler.handle_use_skill(state, 693, 1, player.character_id)
    assert cast.game_state.inventory[0].amount == 1
    assert cast.game_state.stats.generation == player.stats.generation
    assert cast.game_state.skill_cooldowns[693] > System.monotonic_time(:millisecond)
    assert_receive {:private, %SkillCastFailed{skill_id: 693}}
    refute_receive {:visual, %SkillEffect{skill_id: 693}}, 0

    again = staged(cast.game_state, 693, 1, 12311)
    assert {:noreply, refused} = SkillHandler.handle_use_skill(again, 693, 1, player.character_id)
    assert refused.game_state.inventory[0].amount == 1
    assert refused.game_state.skill_cooldowns[693] == cast.game_state.skill_cooldowns[693]
  end

  test "cash item skills display independent recipient results with original caster immunity", %{
    player: player
  } do
    caster_id = player.character_id
    player = %{player | party_id: 10, pending_map_load: nil}
    normal = %{player | character_id: caster_id + 1, account_id: caster_id + 1, x: 114, y: 114}
    immune = %{player | character_id: caster_id + 2, account_id: caster_id + 2}
    immune = put_in(immune.stats.modifiers.equipment, %{no_magic_damage: 100})
    dead = %{player | character_id: caster_id + 3, account_id: caster_id + 3, action_state: :dead}
    for member <- [player, normal, immune, dead], do: UnitRegistry.register_player(member, self())
    party = party(caster_id)

    members =
      Map.new([player, normal, immune, dead], fn p ->
        {p.character_id, Member.new(p.character_id, "Cash", 1, true, "prontera")}
      end)

    stub(PartyManager, :get, fn 10 -> {:ok, %{party | members: members}} end)

    for {id, level, status, item} <- [
          {689, 10, :sc_blessing, 14588},
          {690, 10, :sc_increaseagi, 14589},
          {691, 5, :sc_assumptio, 14590},
          {693, 1, :sc_partyflee, 12311}
        ] do
      holder = %{player | inventory: %{0 => %InventoryItem{id: 1, nameid: item, amount: 2}}}

      assert {:noreply, cast} =
               SkillHandler.handle_use_skill(staged(holder, id, level, item), id, 99, caster_id)

      assert cast.game_state.inventory[0].amount == 1
      assert cast.game_state.stats.generation == player.stats.generation
      assert StatusStorage.has_status?(:player, caster_id, status)

      assert %{source_id: ^caster_id} =
               StatusStorage.get_status(:player, normal.character_id, status)

      refute StatusStorage.has_status?(:player, immune.character_id, status)
      refute StatusStorage.has_status?(:player, dead.character_id, status)

      for {recipient, result} <- [{player, 1}, {normal, 1}, {immune, 0}] do
        target_id = recipient.character_id
        source_id = if id == 693, do: caster_id, else: target_id

        assert_receive {:visual,
                        %SkillEffect{
                          skill_id: ^id,
                          level: ^level,
                          target_id: ^target_id,
                          src_id: ^source_id,
                          result: ^result
                        }}
      end

      refute_receive {:visual, %SkillEffect{skill_id: ^id}}, 0
    end
  end

  test "non-player cash casts preserve the actual target and source without party fanout" do
    caster = TrapTestHelper.mob(5_010)
    recipient = TrapTestHelper.mob(5_011)
    :ok = UnitRegistry.register_unit(:mob, caster.instance_id, MobState, caster, self())
    :ok = UnitRegistry.register_unit(:mob, recipient.instance_id, MobState, recipient, self())
    reject(&PartyManager.get/1)

    for {module, level, status} <- [
          {CashBlessing, 10, :sc_blessing},
          {CashIncagi, 10, :sc_increaseagi},
          {CashAssumptio, 5, :sc_assumptio},
          {AllPartyflee, 1, :sc_partyflee}
        ] do
      assert {:ok, ^caster} =
               module.cast(
                 caster,
                 {:unit, {:mob, recipient.instance_id}},
                 level,
                 module.definition()
               )

      assert %{source_type: :mob, source_id: source_id} =
               StatusStorage.get_status(:mob, recipient.instance_id, status)

      assert source_id == caster.instance_id
      refute StatusStorage.has_status?(:mob, caster.instance_id, status)
    end
  end

  defp staged(player, id, level, item) do
    %SessionState{
      game_state: player,
      connection_pid: self(),
      pending_item_skill: %{
        skill_id: id,
        level: level,
        keep_requirement?: false,
        item_index: 0,
        item_nameid: item
      }
    }
  end

  defp party(id) do
    %PartyState{
      party_id: 10,
      name: "Cash",
      leader_char_id: id,
      exp_share: false,
      item_pickup_share: false,
      members: %{id => Member.new(id, "Cash skills", 1, true, "prontera")}
    }
  end
end
