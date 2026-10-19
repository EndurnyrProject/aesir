defmodule Aesir.ZoneServer.Mmo.StatusEffect.MobParametersTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.MobManagement
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Swordsman.SmProvoke
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  setup do
    {:ok, form} = MobManagement.get_mob_by_id(1002)
    spawn = %MobSpawn{mob: form.id, amount: 1, respawn_time: 0, spawn_area: nil}
    mob = MobState.new(701, form, spawn, "prontera", 100, 100)
    :ok = UnitRegistry.register_unit(:mob, mob.instance_id, MobState, mob, self())
    %{id: mob.instance_id}
  end

  test "ordinary monster starts initialize held values while loaded entries retain their latch",
       %{id: id} do
    concentration = if GameMode.mode() == :renewal, do: 11, else: 15

    cases = [
      {:sc_decreaseagi, %{val2: 5}},
      {:sc_increaseagi, %{val2: 5}},
      {:sc_concentrate, %{val2: 5, val3: 0, val4: 0}},
      {:sc_quagmire, %{val2: 30}},
      {:sc_magicpower, %{val3: 15}},
      {:sc_concentration, %{val2: concentration, val3: 30, val4: concentration}},
      {:sc_mindbreaker, %{val2: 60, val3: 36}},
      {:sc_provoke, %{val2: 11, val3: 20}},
      {:sc_truesight, %{val2: 30, val3: 9}},
      {:sc_stripweapon, %{val2: 25}},
      {:sc_stripshield, %{val2: 15}},
      {:sc_striparmor, %{val2: 40}},
      {:sc_striphelm, %{val2: 40}},
      {:sc_angelus, %{val2: 15}},
      {:sc_impositio, %{val2: 15}},
      {:sc_explosionspirits, %{val2: 150}},
      {:sc_windwalk, %{val2: 2}},
      {:sc_change, %{val2: 90, val3: 60}},
      {:sc_twohandquicken, %{val2: 300}},
      {:sc_adrenaline, %{val3: 300}},
      {:sc_adrenaline2, %{val3: 300}},
      {:sc_aspdpotion0, %{val2: 100}},
      {:sc_aspdpotion1, %{val2: 150}},
      {:sc_aspdpotion2, %{val2: 200}},
      {:sc_aspdpotion3, %{val2: 250}},
      {:sc_fleet, %{val2: 90}},
      {:sc_avoid, %{val2: 30}}
    ]

    drum_battle =
      if GameMode.mode() == :renewal, do: %{val2: 30, val3: 45}, else: %{val2: 100, val3: 8}

    cases =
      if GameMode.mode() == :renewal do
        cases ++
          [
            {:sc_whistle, %{val2: 24, val3: 20}},
            {:sc_humming, %{val2: 12}},
            {:sc_fortunekiss, %{val2: 30}},
            {:sc_assncross, %{val2: 5}},
            {:sc_ensemblefatigue, %{val2: 30}},
            {:sc_emergency_move, %{val2: 25}}
          ]
      else
        cases ++
          [
            {:sc_spearquicken, %{val2: 230}},
            {:sc_gravitation, %{val2: 150}}
          ]
      end

    cases = cases ++ [{:sc_drumbattle, drum_battle}]

    params = [val1: 3, val2: 91, val3: 92, val4: 93, duration: 10_000, bypass_resistance: true]

    for {status, expected} <- cases do
      assert :ok = Interpreter.apply_status(:mob, id, status, params)
      entry = StatusStorage.get_status(:mob, id, status)
      assert Map.take(entry, Map.keys(expected)) == expected
      assert :ok = Interpreter.apply_status(:mob, id, status, Keyword.put(params, :loaded, true))
      entry = StatusStorage.get_status(:mob, id, status)
      assert {entry.val1, entry.val2, entry.val3, entry.val4} == {3, 91, 92, 93}
      assert :ok = Interpreter.remove_status(:mob, id, status)
    end
  end

  test "Deluge's latched HP rate follows the source table and wraps past level five", %{id: id} do
    {:ok, form} = MobManagement.get_mob_by_id(1002)
    spawn = %MobSpawn{mob: form.id, amount: 1, respawn_time: 0, spawn_area: nil}
    mob = MobState.new(id, %{form | element: {:water, 2}}, spawn, "prontera", 100, 100)
    :ok = UnitRegistry.register_unit(:mob, id, MobState, mob, self())

    for {level, rate, enchant} <- [
          {1, 5, 10},
          {2, 9, 14},
          {3, 12, 17},
          {4, 14, 19},
          {5, 15, 20},
          {6, 5, 10},
          {7, 9, 14}
        ] do
      assert :ok =
               Interpreter.apply_status(:mob, id, :sc_deluge,
                 val1: level,
                 duration: 10_000,
                 bypass_resistance: true
               )

      assert %{val2: ^rate, val3: ^enchant} = StatusStorage.get_status(:mob, id, :sc_deluge)
      assert :ok = Interpreter.remove_status(:mob, id, :sc_deluge)
    end
  end

  test "an own-cast and a received adrenaline keep their source buckets", %{id: id} do
    for status <- [:sc_adrenaline, :sc_adrenaline2], val2 <- [0, 1] do
      assert :ok =
               Interpreter.apply_status(:mob, id, status,
                 val1: 3,
                 val2: val2,
                 duration: 10_000,
                 bypass_resistance: true
               )

      assert %{val3: bucket} = StatusStorage.get_status(:mob, id, status)
      assert bucket == if(val2 == 0, do: 200, else: 300)
      assert :ok = Interpreter.remove_status(:mob, id, status)
    end
  end

  test "Concentration starts finite Endure only on an ordinary start and ends only finite Endure",
       %{id: id} do
    params = [val1: 3, duration: 10_000, bypass_resistance: true]

    assert :ok =
             Interpreter.apply_status(
               :mob,
               id,
               :sc_concentration,
               Keyword.put(params, :loaded, true)
             )

    refute StatusStorage.has_status?(:mob, id, :sc_endure)
    assert :ok = Interpreter.remove_status(:mob, id, :sc_concentration)

    assert :ok = Interpreter.apply_status(:mob, id, :sc_concentration, params)

    assert %{val1: 1, val4: 0, expires_at: expires_at} =
             StatusStorage.get_status(:mob, id, :sc_endure)

    assert is_integer(expires_at)
    assert :ok = Interpreter.remove_status(:mob, id, :sc_concentration)
    refute StatusStorage.has_status?(:mob, id, :sc_endure)

    assert :ok =
             Interpreter.apply_status(:mob, id, :sc_endure,
               val1: 1,
               val4: 1,
               duration: 10_000,
               loaded: true
             )

    assert :ok = Interpreter.apply_status(:mob, id, :sc_concentration, params)
    assert :ok = Interpreter.remove_status(:mob, id, :sc_concentration)
    assert %{val4: 1} = StatusStorage.get_status(:mob, id, :sc_endure)
  end

  test "field and Blessing parameters latch the recipient's defense element and race at start", %{
    id: id
  } do
    {:ok, form} = MobManagement.get_mob_by_id(1002)
    spawn = %MobSpawn{mob: form.id, amount: 1, respawn_time: 0, spawn_area: nil}
    renewal? = GameMode.mode() == :renewal

    for {element, race, blessing, classic} <- [
          {:water, :formless, 3, {0, 0, 12}},
          {:fire, :formless, 3, {30, 0, 0}},
          {:wind, :demon, 0, {0, 9, 0}},
          {:undead, :formless, 0, {0, 0, 0}},
          {:water, :undead, 3, {0, 0, 12}}
        ] do
      {classic_volcano, classic_gale, classic_deluge} = classic

      mob =
        MobState.new(id, %{form | element: {element, 2}, race: race}, spawn, "prontera", 100, 100)

      :ok = UnitRegistry.register_unit(:mob, id, MobState, mob, self())
      params = [val1: 3, val2: 99, duration: 10_000, bypass_resistance: true]

      for {status, bonus} <- [
            {:sc_blessing, blessing},
            {:sc_volcano, if(renewal?, do: 20, else: classic_volcano)},
            {:sc_violentgale, if(renewal?, do: 9, else: classic_gale)},
            {:sc_deluge, if(renewal?, do: 12, else: classic_deluge)}
          ] do
        assert :ok = Interpreter.apply_status(:mob, id, status, params)
        entry = StatusStorage.get_status(:mob, id, status)
        assert entry.val2 == bonus
        if status != :sc_blessing, do: assert(entry.val3 == 17)
        assert :ok = Interpreter.remove_status(:mob, id, status)
      end
    end
  end

  test "a real monster's level-ten Provoke initializes its NPC branch and records its source type",
       %{id: id} do
    {:ok, {_, target, _}} = UnitRegistry.get_unit(:mob, id)
    caster = %{target | instance_id: id + 1}
    :ok = UnitRegistry.register_unit(:mob, caster.instance_id, MobState, caster, self())
    {:ok, skill} = Catalog.by_name(:sm_provoke)
    assert {:ok, ^caster} = SmProvoke.cast(caster, {:unit, {:mob, id}}, 10, skill)

    assert %{val2: 0, val3: 100, source_type: :mob} =
             StatusStorage.get_status(:mob, id, :sc_provoke)
  end

  test "loaded classic Magic Power's armed val4 ends on the next offensive invocation", %{id: id} do
    {:ok, skill} = Catalog.by_name(:mg_coldbolt)

    assert :ok =
             Interpreter.apply_status(:mob, id, :sc_magicpower,
               val1: 5,
               val3: 25,
               val4: 1,
               duration: 10_000,
               loaded: true
             )

    if GameMode.mode() == :pre_renewal do
      assert :changed = Interpreter.on_committed_action(:mob, id, {:skill, skill.id})
      refute StatusStorage.has_status?(:mob, id, :sc_magicpower)
      assert_received {:"$gen_cast", {:casting, {:status_changed, :sc_magicpower, :removed}}}
    else
      assert :unchanged = Interpreter.on_committed_action(:mob, id, {:skill, skill.id})
      assert StatusStorage.has_status?(:mob, id, :sc_magicpower)
    end
  end

  test "ordinary and loaded monster admission both reject explicitly player-only source-capable statuses",
       %{id: id} do
    for status <- [:sc_berserk, :sc_marionette, :sc_marionette2, :sc_defset, :sc_mdefset],
        loaded <- [false, true] do
      assert {:error, :ineligible_target} =
               Interpreter.apply_status(:mob, id, status,
                 val1: 1,
                 duration: 10_000,
                 loaded: loaded
               )

      refute StatusStorage.has_status?(:mob, id, status)
    end
  end
end
