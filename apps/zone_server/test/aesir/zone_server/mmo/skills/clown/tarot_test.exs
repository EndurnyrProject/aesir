defmodule Aesir.ZoneServer.Mmo.Skills.Clown.TarotTest do
  use ExUnit.Case, async: false
  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.EquipBreak
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skills.Clown.Tarot
  alias Aesir.ZoneServer.Mmo.Skills.Clown.TarotDeck
  alias Aesir.ZoneServer.Mmo.StatusEffect.ClearBuffs
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Resource
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    Mimic.copy(Resource)
    Mimic.copy(Cell)
    Mimic.copy(DamageApplication)
    caster = player(17)
    target = player(18)
    for p <- [caster, target], do: UnitRegistry.register_player(p, self())
    stub(TarotDeck, :roll, fn 100 -> 1 end)
    %{caster: caster, target: target}
  end

  test "a failed roll draws nothing", %{caster: caster} do
    stub(TarotDeck, :roll, fn 100 -> 100 end)
    reject(&TarotDeck.draw/0)
    assert {:error, :failed} = Tarot.play(caster, {:player, 18}, 5)
  end

  test "an immunity marker prevents the roll and draw", %{caster: caster} do
    :ok = StatusStorage.apply_status(:player, 18, :sc_tarotcard)
    reject(&TarotDeck.roll/1)
    reject(&TarotDeck.draw/0)
    assert {:error, :immune} = Tarot.play(caster, {:player, 18}, 5)
  end

  test "the Emperium is not an eligible target", %{caster: caster} do
    target = mob(42, 1288)
    :ok = UnitRegistry.register_unit(:mob, 42, MobState, target, self())
    reject(&TarotDeck.draw/0)
    assert {:error, :invalid_target} = Tarot.play(caster, {:mob, 42}, 5)
  end

  @tag game_mode: :pre_renewal
  test "classic Basilica prevents a card", %{caster: caster} do
    :ok = StatusStorage.apply_status(:player, 18, :sc_basilica)
    reject(&TarotDeck.draw/0)
    assert {:error, :invalid_target} = Tarot.play(caster, {:player, 18}, 5)
  end

  test "Fool drains all maximum SP", %{caster: caster} do
    stub(TarotDeck, :draw, fn -> :fool end)
    expect(Resource, :drain_sp_percent, fn {:player, 18}, 100 -> :ok end)
    assert {:ok, :fool} = Tarot.play(caster, {:player, 18}, 5)
  end

  test "High Priestess clears the target's buffs", %{caster: caster} do
    stub(TarotDeck, :draw, fn -> :high_priestess end)
    expect(ClearBuffs, :clear, fn {:player, 18}, [:buffs, :chem_protect] -> :ok end)
    assert {:ok, :high_priestess} = Tarot.play(caster, {:player, 18}, 5)
  end

  for {card, status} <- [{:magician, :sc_incmatkrate}, {:strength, :sc_incatkrate}] do
    test "#{card} reduces its attack rate by fifty percent for thirty seconds", %{caster: caster} do
      stub(TarotDeck, :draw, fn -> unquote(card) end)
      assert {:ok, unquote(card)} = Tarot.play(caster, {:player, 18}, 5)

      assert %{
               val1: -50,
               source_id: 17,
               source_type: :player,
               started_at: started,
               expires_at: expires
             } =
               StatusStorage.get_status(:player, 18, unquote(status))

      assert expires - started == 30_000
    end
  end

  test "Sun reduces all five rates by twenty percent", %{caster: caster} do
    stub(TarotDeck, :draw, fn -> :sun end)
    assert {:ok, :sun} = Tarot.play(caster, {:player, 18}, 5)

    for status <- [
          :sc_incatkrate,
          :sc_incmatkrate,
          :sc_inchitrate,
          :sc_incfleerate,
          :sc_incdefrate
        ] do
      assert %{val1: -20, started_at: started, expires_at: expires} =
               StatusStorage.get_status(:player, 18, status)

      assert expires - started == 30_000
    end
  end

  @tag game_mode: :renewal
  test "renewal Sun prevents further Tarot draws", %{caster: caster} do
    stub(TarotDeck, :draw, fn -> :sun end)
    assert {:ok, :sun} = Tarot.play(caster, {:player, 18}, 5)
    assert StatusStorage.has_status?(:player, 18, :sc_tarotcard)
    assert {:error, :immune} = Tarot.play(caster, {:player, 18}, 5)
  end

  @tag game_mode: :pre_renewal
  test "classic Sun grants no immunity marker", %{caster: caster} do
    stub(TarotDeck, :draw, fn -> :sun end)
    assert {:ok, :sun} = Tarot.play(caster, {:player, 18}, 5)
    refute StatusStorage.has_status?(:player, 18, :sc_tarotcard)
  end

  test "mob-originated cards preserve caster identity", %{target: _target} do
    caster = mob(19, 1002)
    :ok = UnitRegistry.register_unit(:mob, 19, MobState, caster, self())
    stub(TarotDeck, :draw, fn -> :strength end)
    assert {:ok, :strength} = Tarot.play(caster, {:player, 18}, 5)

    assert %{source_id: 19, source_type: :mob} =
             StatusStorage.get_status(:player, 18, :sc_incatkrate)
  end

  test "Chariot deals one thousand misc damage and attempts exactly one equipment break", %{
    caster: caster,
    target: target
  } do
    stub(TarotDeck, :draw, fn -> :chariot end)
    expect_fixed(caster, 1000, true)

    expect(EquipBreak, :resolve_slot, fn 10_000, {:player, 18, stats}, slot ->
      assert stats == target.stats
      assert slot in [:armor, :shield, :helm]
      [{:target, slot}]
    end)

    expect(PlayerSession, :break_equip, fn pid, slot ->
      assert pid == self()
      assert slot in [:armor, :shield, :helm]
      :ok
    end)

    assert {:ok, :chariot} = Tarot.play(caster, {:player, 18}, 5)
  end

  test "Chariot does not break equipment after its lethal hit", %{caster: caster} do
    stub(TarotDeck, :draw, fn -> :chariot end)
    expect_fixed(caster, 1000, false)
    reject(&EquipBreak.resolve_slot/3)
    assert {:ok, :chariot} = Tarot.play(caster, {:player, 18}, 5)
  end

  test "Devil deals six thousand six hundred sixty-six and curses both attack rates", %{
    caster: caster
  } do
    prepare_curse_target()
    stub(TarotDeck, :draw, fn -> :devil end)
    expect_fixed(caster, 6666, true)
    assert {:ok, :devil} = Tarot.play(caster, {:player, 18}, 5)

    for status <- [:sc_incatkrate, :sc_incmatkrate],
        do: assert(%{val1: -50} = StatusStorage.get_status(:player, 18, status))

    assert StatusStorage.has_status?(:player, 18, :sc_curse)
  end

  test "Devil stops inflicting statuses after a lethal hit", %{caster: caster} do
    stub(TarotDeck, :draw, fn -> :devil end)
    expect_fixed(caster, 6666, false)
    assert {:ok, :devil} = Tarot.play(caster, {:player, 18}, 5)

    for status <- [:sc_incatkrate, :sc_incmatkrate, :sc_curse],
        do: refute(StatusStorage.has_status?(:player, 18, status))
  end

  test "Tower deals four thousand four hundred forty-four fixed misc damage", %{caster: caster} do
    stub(TarotDeck, :draw, fn -> :tower end)
    expect_fixed(caster, 4444, true)
    assert {:ok, :tower} = Tarot.play(caster, {:player, 18}, 5)
  end

  test "Lovers heals a player and randomly warps them outside versus maps", %{caster: caster} do
    stub(TarotDeck, :draw, fn -> :lovers end)
    expect(DamageApplication, :apply_heal, fn :player, 18, 2000, 17 -> :ok end)
    stub(Targeting, :versus_map?, fn "prontera" -> false end)
    expect(Cell, :random_traversable, fn "prontera" -> {:ok, {20, 20}} end)

    expect(PlayerSession, :warp, fn pid, "prontera", 20, 20 ->
      assert pid == self()
      :ok
    end)

    assert {:ok, :lovers} = Tarot.play(caster, {:player, 18}, 5)
  end

  test "Lovers heals but does not warp on a versus map", %{caster: caster} do
    stub(TarotDeck, :draw, fn -> :lovers end)
    expect(DamageApplication, :apply_heal, fn :player, 18, 2000, 17 -> :ok end)
    stub(Targeting, :versus_map?, fn "prontera" -> true end)
    reject(&Cell.random_traversable/1)
    reject(&PlayerSession.warp/4)
    assert {:ok, :lovers} = Tarot.play(caster, {:player, 18}, 5)
  end

  test "Lovers heals and teleports a mob", %{caster: caster} do
    :ok = UnitRegistry.register_unit(:mob, 42, MobState, mob(42, 1002), self())
    stub(TarotDeck, :draw, fn -> :lovers end)
    stub(Targeting, :versus_map?, fn "prontera" -> false end)
    expect(DamageApplication, :apply_heal, fn :mob, 42, 2000, 17 -> :ok end)

    expect(MobSession, :teleport, fn pid ->
      assert pid == self()
      :ok
    end)

    assert {:ok, :lovers} = Tarot.play(caster, {:mob, 42}, 5)
  end

  test "Wheel of Fortune plays two further draws", %{caster: caster} do
    expect(TarotDeck, :draw, fn -> :wheel_of_fortune end)
    expect(TarotDeck, :draw, fn -> :magician end)
    expect(TarotDeck, :draw, fn -> :strength end)
    assert {:ok, :wheel_of_fortune} = Tarot.play(caster, {:player, 18}, 5)
    assert %{val1: -50} = StatusStorage.get_status(:player, 18, :sc_incmatkrate)
    assert %{val1: -50} = StatusStorage.get_status(:player, 18, :sc_incatkrate)
  end

  test "Hanged Man inflicts one of Ankle, Freeze or Stone", %{caster: caster} do
    stub(TarotDeck, :draw, fn -> :hanged_man end)
    assert {:ok, :hanged_man} = Tarot.play(caster, {:player, 18}, 5)

    statuses =
      for id <- [:sc_ankle, :sc_freeze, :sc_stonewait],
          status = StatusStorage.get_status(:player, 18, id),
          status != nil,
          do: status

    assert [status] = statuses
    if status.type == :sc_ankle, do: assert(status.expires_at - status.started_at == 30_000)
  end

  test "Death applies coma then Curse and Poison to a player", %{caster: caster} do
    prepare_curse_target()
    stub(TarotDeck, :draw, fn -> :death end)

    expect(PlayerSession, :apply_coma, fn pid, {:player, 17} ->
      assert pid == self()
      :ok
    end)

    assert {:ok, :death} = Tarot.play(caster, {:player, 18}, 5)
    assert StatusStorage.has_status?(:player, 18, :sc_curse)
    assert StatusStorage.has_status?(:player, 18, :sc_poison)
  end

  test "Death skips coma on a boss mob", %{caster: caster} do
    target = mob(42, 1002)

    boss = %{
      target
      | mob_data: %{
          target.mob_data
          | modes: Enum.uniq([:boss, :status_immune | target.mob_data.modes])
        }
    }

    :ok = UnitRegistry.register_unit(:mob, 42, MobState, boss, self())
    stub(TarotDeck, :draw, fn -> :death end)
    reject(&MobSession.apply_coma/2)
    assert {:ok, :death} = Tarot.play(caster, {:mob, 42}, 5)
  end

  test "Temperance confuses the target for thirty seconds through its status defense",
       %{caster: caster} do
    stub(TarotDeck, :draw, fn -> :temperance end)
    stub(Resistance, :roll_rate, fn _rate -> true end)
    assert {:ok, :temperance} = Tarot.play(caster, {:player, 18}, 5)

    assert %{started_at: start, expires_at: expires} =
             StatusStorage.get_status(:player, 18, :sc_confusion)

    expected = if GameMode.mode() == :renewal, do: 32_000, else: 27_000
    assert expires - start == expected
  end

  test "Star stuns the target", %{caster: caster} do
    stub(TarotDeck, :draw, fn -> :star end)
    assert {:ok, :star} = Tarot.play(caster, {:player, 18}, 5)
    assert StatusStorage.has_status?(:player, 18, :sc_stun)
  end

  defp prepare_curse_target do
    {:ok, {_module, target, _pid}} = UnitRegistry.get_unit(:player, 18)
    :ok = UnitRegistry.update_unit_state(:player, 18, put_in(target.stats.base_stats.luk, 1))
    stub(Resistance, :roll_success, fn _ -> true end)
    stub(Resistance, :roll_rate, fn _ -> true end)
  end

  defp expect_fixed(caster, damage, survives) do
    expect(Combat, :execute_misc_attack, fn ^caster, {:player, 18}, opts ->
      assert opts[:skill_id] == 489
      assert opts[:skill_level] == 5
      assert opts[:base_damage] == damage
      assert opts[:ignore_element]
      assert opts[:report_hit]
      {:ok, %{hit?: true, damage: damage, target_survives?: survives, coma?: false}}
    end)
  end

  defp player(id) do
    PlayerState.new(%Character{
      id: id,
      account_id: id,
      name: "Tarot #{id}",
      class: 0,
      base_level: 50,
      job_level: 1,
      sex: "M",
      last_map: "prontera",
      last_x: 10,
      last_y: 10,
      hp: 20_000,
      sp: 100,
      str: 10,
      agi: 10,
      vit: 0,
      int: 10,
      dex: 10,
      luk: 0
    })
  end

  defp mob(id, monster_id) do
    {:ok, definition} = Mobs.by_id(monster_id)

    spawn = %MobSpawn{
      mob: monster_id,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %MobSpawn.SpawnArea{x: 10, y: 10, xs: 0, ys: 0}
    }

    MobState.new(id, definition, spawn, "prontera", 10, 10)
  end
end
