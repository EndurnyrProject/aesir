defmodule Aesir.ZoneServer.Integration.AlchemistPotionPitcherTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Homunculus
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.HomunculusPrivateState
  alias Aesir.Net.SkillCast
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Combat.PotionRecovery
  alias Aesir.ZoneServer.Mmo.Skills.Alchemist.AmPotionpitcher
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @moduletag :capture_log

  @skill_id 231
  @red_potion 501
  @map "hom_pitcher_map"

  test "incoming cast preserves exact seeded player recovery and settles once" do
    caster = start_alchemist(potions: 2, homunculus: false, vit: 10)
    damage_to(caster.pid, 1)

    seed = {11, 22, 33}
    seed_session(caster.pid, seed)
    :rand.seed(:exsss, seed)
    roll = 45 + :rand.uniform(21) - 1
    caster_amount = AmPotionpitcher.scale_caster_bonus(roll, 1, 0)

    before = PlayerSession.get_state(caster.pid).game_state

    expected_recovery =
      PotionRecovery.recover({:potion, :hp, caster_amount}, %{
        learning_potion: 0,
        effective_vit: PlayerStats.get_effective_stat(before.stats, :vit),
        effective_int: PlayerStats.get_effective_stat(before.stats, :int),
        item_heal_rate: PlayerStats.get_item_heal_rate(before.stats)
      })

    cast(caster.pid, caster.character.id)

    assert_eventually(fn -> current_hp(caster.pid) == 1 + expected_recovery end)
    after_cast = PlayerSession.get_state(caster.pid).game_state

    assert after_cast.stats.current_state.sp == before.stats.current_state.sp - 1
    assert after_cast.act_delay_until != before.act_delay_until
    assert Inventory.held_amount(after_cast.inventory, @red_potion) == 1

    assert Repo.get_by!(InventoryItem, char_id: caster.character.id, nameid: @red_potion).amount ==
             1
  end

  test "incoming cast delivers to an external party player and settles once" do
    caster = start_alchemist(potions: 2, homunculus: false, vit: 10)
    recipient = start_alchemist(name: "PartyRecipient", potions: 0, homunculus: false, vit: 10)
    set_party(caster.pid, 7)
    set_party(recipient.pid, 7)
    damage_to(recipient.pid, 1)

    seed = {44, 55, 66}
    seed_session(caster.pid, seed)
    :rand.seed(:exsss, seed)
    roll = 45 + :rand.uniform(21) - 1
    caster_amount = AmPotionpitcher.scale_caster_bonus(roll, 1, 0)

    before_caster = PlayerSession.get_state(caster.pid).game_state
    recipient_state = PlayerSession.get_state(recipient.pid).game_state

    expected_recovery =
      PotionRecovery.recover({:potion, :hp, caster_amount}, %{
        learning_potion: 0,
        effective_vit: PlayerStats.get_effective_stat(recipient_state.stats, :vit),
        effective_int: PlayerStats.get_effective_stat(recipient_state.stats, :int),
        item_heal_rate: PlayerStats.get_item_heal_rate(recipient_state.stats)
      })

    cast(caster.pid, recipient.character.id)

    assert_eventually(fn -> current_hp(recipient.pid) == 1 + expected_recovery end)
    after_cast = PlayerSession.get_state(caster.pid).game_state

    assert after_cast.stats.current_state.sp == before_caster.stats.current_state.sp - 1
    assert after_cast.act_delay_until != before_caster.act_delay_until
    assert Inventory.held_amount(after_cast.inventory, @red_potion) == 1

    assert Repo.get_by!(InventoryItem, char_id: caster.character.id, nameid: @red_potion).amount ==
             1
  end

  test "owner Homunculus receives post-rounding HP times three, capped, and publishes immediately" do
    caster = start_alchemist(potions: 2, homunculus: true, hom_hp: 100)
    gid = homunculus(caster.pid).world_gid
    flush_packets()

    cast(caster.pid, gid)

    assert_eventually(fn -> homunculus(caster.pid).hp > 100 end)
    assert homunculus(caster.pid).hp in homunculus_hp_results(100)
    assert_receive {:packet_sent, %HomunculusPrivateState{world_gid: ^gid}, _channel}, 500
  end

  test "owner Homunculus SP follows canonical recovery without the HP multiplier" do
    caster = start_alchemist(potions: 1, homunculus: true, hom_sp: 150, potion_id: 505)
    gid = homunculus(caster.pid).world_gid

    cast(caster.pid, gid, 5)

    assert_eventually(fn -> homunculus(caster.pid).sp > 150 end)
    assert homunculus(caster.pid).sp in 198..200
  end

  test "foreign Homunculus is rejected even for party members" do
    caster = start_alchemist(potions: 1, homunculus: true)
    foreign = start_alchemist(name: "ForeignOwner", potions: 0, homunculus: true)
    set_party(caster.pid, 7)
    set_party(foreign.pid, 7)
    gid = homunculus(foreign.pid).world_gid
    before_hp = homunculus(foreign.pid).hp
    before = PlayerSession.get_state(caster.pid).game_state

    cast(caster.pid, gid)
    barrier(caster.pid)

    after_cast = PlayerSession.get_state(caster.pid).game_state
    assert after_cast.stats.current_state.sp == before.stats.current_state.sp
    assert Inventory.held_amount(after_cast.inventory, @red_potion) == 1
    assert homunculus(foreign.pid).hp == before_hp
  end

  test "typed Homunculus wins a same-number player collision" do
    caster = start_alchemist(potions: 1, homunculus: true, hom_hp: 100)
    gid = homunculus(caster.pid).world_gid
    player = PlayerSession.get_state(caster.pid).game_state
    UnitRegistry.register_unit(:player, gid, PlayerState, %{player | character_id: gid}, self())
    on_exit(fn -> UnitRegistry.unregister_unit(:player, gid) end)

    cast(caster.pid, gid)

    assert_eventually(fn -> homunculus(caster.pid).hp > 100 end)
  end

  test "missing potion and insufficient SP spend nothing and deliver nothing" do
    missing = start_alchemist(potions: 0, homunculus: true, hom_hp: 100)
    missing_gid = homunculus(missing.pid).world_gid
    cast(missing.pid, missing_gid)
    barrier(missing.pid)
    assert homunculus(missing.pid).hp == 100
    assert PlayerSession.get_state(missing.pid).game_state.stats.current_state.sp == 100

    empty_sp = start_alchemist(name: "NoSp", potions: 1, homunculus: true, hom_hp: 100, sp: 0)
    empty_gid = homunculus(empty_sp.pid).world_gid
    cast(empty_sp.pid, empty_gid)
    barrier(empty_sp.pid)
    state = PlayerSession.get_state(empty_sp.pid)
    assert state.homunculus.hp == 100
    assert Inventory.held_amount(state.game_state.inventory, @red_potion) == 1
  end

  test "inventory persistence failure preserves item and SP and delivers nothing" do
    caster = start_alchemist(potions: 1, homunculus: true, hom_hp: 100)
    gid = homunculus(caster.pid).world_gid
    Mimic.copy(InventoryOps)
    stub(InventoryOps, :apply_change, fn _char_id, _old, _new, _change -> {:error, :db_down} end)
    Mimic.allow(InventoryOps, self(), caster.pid)

    cast(caster.pid, gid)
    barrier(caster.pid)

    state = PlayerSession.get_state(caster.pid)
    assert state.homunculus.hp == 100
    assert state.game_state.stats.current_state.sp == 100
    assert Inventory.held_amount(state.game_state.inventory, @red_potion) == 1
  end

  test "target disappearing after settlement safely no-ops with normal costs settled" do
    caster = start_alchemist(potions: 1, homunculus: true, hom_hp: 100)
    gid = homunculus(caster.pid).world_gid
    Mimic.copy(InventoryOps)

    stub(InventoryOps, :apply_change, fn _char_id, _old, new_inventory, _change ->
      UnitRegistry.unregister_unit(:homunculus, gid)
      {:ok, new_inventory}
    end)

    Mimic.allow(InventoryOps, self(), caster.pid)
    cast(caster.pid, gid)
    barrier(caster.pid)

    state = PlayerSession.get_state(caster.pid)
    assert state.homunculus.hp == 100
    assert state.game_state.stats.current_state.sp == 99
    assert Inventory.held_amount(state.game_state.inventory, @red_potion) == 0
    assert state.game_state.act_delay_until != 0
  end

  defp start_alchemist(opts) do
    unique = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.changeset(%{
        userid: "pitcher_#{unique}",
        user_pass: "password",
        email: "pitcher-#{unique}@example.com"
      })
      |> Repo.insert!()

    character =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: Keyword.get(opts, :name, "Pitcher#{unique}"),
        class: 18,
        base_level: 50,
        job_level: 50,
        hp: 1_000,
        max_hp: 1_000,
        sp: Keyword.get(opts, :sp, 100),
        max_sp: 100,
        vit: Keyword.get(opts, :vit, 5),
        int: 5,
        learned_skills: %{"227" => 0, "231" => 5},
        last_map: @map,
        last_x: 50,
        last_y: 50
      })
      |> Repo.insert!()

    insert_potion(character.id, Keyword.get(opts, :potion_id, @red_potion), opts[:potions])

    if Keyword.get(opts, :homunculus, false) do
      insert_homunculus(character.id, opts)
    end

    character = Repo.preload(character, [:inventory_items, :homunculus])
    session = start_player_session(character: character, map_name: @map, position: {50, 50})
    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)
    flush_packets()
    session
  end

  defp insert_potion(_character_id, _item_id, 0), do: :ok

  defp insert_potion(character_id, item_id, amount) do
    %InventoryItem{}
    |> InventoryItem.changeset(%{char_id: character_id, nameid: item_id, amount: amount})
    |> Repo.insert!()
  end

  defp insert_homunculus(character_id, opts) do
    %Homunculus{}
    |> Homunculus.changeset(%{
      character_id: character_id,
      class_id: 6_001,
      name: "Hildr",
      lifecycle: "active",
      level: 50,
      hp: Keyword.get(opts, :hom_hp, 800),
      max_hp: 1_000,
      sp: Keyword.get(opts, :hom_sp, 150),
      max_sp: 200,
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
      active_remaining_ms: 1_800_000,
      learned_skills: %{},
      cooldowns: %{},
      ai_config: %{}
    })
    |> Repo.insert!()
  end

  defp set_party(pid, party_id) do
    :sys.replace_state(pid, fn state ->
      game_state = %{state.game_state | party_id: party_id}
      StateCommit.commit(state, game_state)
    end)
  end

  defp damage_to(pid, hp) do
    state = PlayerSession.get_state(pid).game_state
    PlayerSession.apply_damage(pid, state.stats.current_state.hp - hp, nil)
    assert_eventually(fn -> current_hp(pid) == hp end)
  end

  defp seed_session(pid, seed) do
    :sys.replace_state(pid, fn state ->
      :rand.seed(:exsss, seed)
      state
    end)
  end

  defp cast(pid, target_id, level \\ 1) do
    simulate_incoming_message(pid, %SkillCast{
      skill_id: @skill_id,
      level: level,
      target_id: target_id
    })
  end

  defp barrier(pid), do: PlayerSession.get_state(pid)
  defp current_hp(pid), do: PlayerSession.get_state(pid).game_state.stats.current_state.hp
  defp homunculus(pid), do: PlayerSession.get_state(pid).homunculus

  defp homunculus_hp_results(start_hp) do
    for roll <- 45..65 do
      caster_amount = AmPotionpitcher.scale_caster_bonus(roll, 1, 0)
      min(start_hp + div(caster_amount * 120, 100) * 3, 1_000)
    end
  end
end
