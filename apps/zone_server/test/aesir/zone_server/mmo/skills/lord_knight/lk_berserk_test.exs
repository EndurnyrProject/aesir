defmodule Aesir.ZoneServer.Mmo.Skills.LordKnight.LkBerserkTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestWait

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.QuestPersistence
  alias Aesir.ZoneServer.Unit.Player.StatusPersistence

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    Mimic.copy(Persistence)
    Mimic.copy(CharacterPersistence)
    Mimic.copy(StatusPersistence)
    Mimic.copy(QuestPersistence)
    stub(Persistence, :load_inventory, fn _ -> [] end)

    stub(CharacterPersistence, :update_character, fn _id, _changes, _opts ->
      {:ok, %Character{}}
    end)

    stub(CharacterPersistence, :update_stats, fn _id, _changes, _opts -> {:ok, %Character{}} end)
    stub(StatusPersistence, :restore_on_spawn, fn state -> state end)
    stub(StatusPersistence, :save_statuses, fn _ -> :ok end)
    stub(QuestPersistence, :load_on_spawn, fn state -> state end)
    :ok
  end

  test "a session cast triples max HP, fully heals, empties SP, and blocks player actions" do
    assert {:ok, definition} = Catalog.by_name(:lk_berserk)
    assert definition.id == 359
    assert definition.sp_cost == [200]
    assert definition.duration == [300_000]

    character = %Character{
      id: 5_120,
      account_id: 5_121,
      name: "LK",
      last_map: "prontera",
      last_x: 50,
      last_y: 50,
      sex: "M",
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 90,
      job_level: 50,
      class: 7,
      hp: 40,
      sp: 500
    }

    {:ok, pid} = PlayerSession.start_link(%{character: character, connection_pid: self()})
    before = PlayerSession.get_state(pid).game_state.stats.derived_stats.max_hp
    GenServer.cast(pid, {:skill, {:auto_cast, 359, 1, :self}})

    assert_eventually(fn ->
      stats = PlayerSession.get_state(pid).game_state.stats

      stats.derived_stats.max_hp == 3 * before and
        stats.current_state.hp == stats.derived_stats.max_hp and
        stats.current_state.sp == 0 and
        match?(%{val4: 1}, StatusStorage.get_status(:player, character.id, :sc_endure))
    end)

    assert StatusStorage.has_status?(:player, character.id, :sc_berserk)
    refute Interpreter.can_use_skill?(:player, character.id)
    refute Interpreter.can_use_item?(:player, character.id)
    refute Interpreter.can_chat?(:player, character.id)
    assert Interpreter.equip_change_blocked?(:player, character.id)

    :ok = Interpreter.remove_status(:player, character.id, :sc_berserk)
    refute StatusStorage.has_status?(:player, character.id, :sc_endure)
  end
end
