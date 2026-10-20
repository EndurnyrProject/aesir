defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrDevotionTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter, as: SkillInterpreter
  alias Aesir.ZoneServer.Mmo.Skills.Crusader.CrDevotion
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  @crusader_id 4000
  @crusader_class 14
  @knight_class 7

  describe "catalog registration" do
    test "casts in 1.5 seconds plus 1.5 fixed in renewal and a flat 3 seconds in classic" do
      assert CrDevotion.definition(:renewal).cast_time == List.duplicate(1_500, 5)
      assert CrDevotion.definition(:renewal).fixed_cast_time == List.duplicate(1_500, 5)
      assert CrDevotion.definition(:pre_renewal).cast_time == List.duplicate(3_000, 5)
      assert CrDevotion.definition(:pre_renewal).fixed_cast_time == []
    end
  end

  describe "statuses" do
    test "both link statuses are non-persisted and cleared on a map change" do
      devotion = Registry.get_definition(:sc_devotion)
      devoted_by = Registry.get_definition(:sc_devoted_by)

      assert devotion.no_save
      assert devotion.remove_on_map_change
      assert devoted_by.no_save
      refute devoted_by.remove_on_map_change
    end
  end

  describe "gates" do
    test "refuses devoting yourself" do
      caster = register(player(@crusader_id, job_id: @crusader_class))

      assert {:error, :cannot_devote_self} =
               CrDevotion.validate(caster, {:unit, @crusader_id}, 1, definition())
    end

    test "refuses a target that is not a registered player" do
      caster = register(player(@crusader_id, job_id: @crusader_class))

      assert {:error, :target_not_found} =
               CrDevotion.validate(caster, {:unit, 9999}, 1, definition())
    end

    test "refuses a target in a different party" do
      caster = register(player(@crusader_id, job_id: @crusader_class, party_id: 1))
      register(player(4001, party_id: 2))

      assert {:error, :not_same_party} =
               CrDevotion.validate(caster, {:unit, 4001}, 1, definition())
    end

    test "refuses a partyless target even when the caster is partyless" do
      caster = register(player(@crusader_id, job_id: @crusader_class, party_id: 0))
      register(player(4001, party_id: 0))

      assert {:error, :not_same_party} =
               CrDevotion.validate(caster, {:unit, 4001}, 1, definition())
    end

    test "a Crusader-class target is refused after the requirement is paid" do
      caster = register(player(@crusader_id, job_id: @crusader_class))
      register(player(4001, job_id: @crusader_class))

      assert :ok = CrDevotion.validate(caster, {:unit, 4001}, 1, definition())

      assert {:failed, ^caster, :target_is_crusader} =
               CrDevotion.cast(caster, {:unit, 4001}, 1, definition())
    end

    test "a target beyond the base-level gap is refused after the requirement is paid" do
      caster = register(player(@crusader_id, job_id: @crusader_class, base_level: 90))
      register(player(4001, base_level: 79))

      assert :ok = CrDevotion.validate(caster, {:unit, 4001}, 1, definition())

      assert {:failed, ^caster, :level_gap_too_large} =
               CrDevotion.cast(caster, {:unit, 4001}, 1, definition())
    end

    test "accepts a target exactly at the base-level gap limit" do
      caster = register(player(@crusader_id, job_id: @crusader_class, base_level: 90))
      register(player(4001, base_level: 80))

      assert {:ok, ^caster} = CrDevotion.cast(caster, {:unit, 4001}, 1, definition())
    end

    test "a mob caster cannot devote" do
      assert {:error, :mob_cannot_devote} =
               CrDevotion.validate(mob_caster(), {:unit, 4001}, 1, definition())
    end
  end

  describe "homunculus and foreign-link gates" do
    test "the caster's own homunculus passes the party gate and is refused after the requirement is paid" do
      caster = register(player(@crusader_id, job_id: @crusader_class))
      register_homunculus(5001, @crusader_id)

      assert :ok = CrDevotion.validate(caster, {:unit, {:homunculus, 5001}}, 1, definition())

      assert {:failed, ^caster, :invalid_target} =
               CrDevotion.cast(caster, {:unit, {:homunculus, 5001}}, 1, definition())
    end

    test "a party member's homunculus passes the party gate through its owner" do
      caster = register(player(@crusader_id, job_id: @crusader_class, party_id: 1))
      register(player(4001, party_id: 1))
      register_homunculus(5002, 4001)

      assert :ok = CrDevotion.validate(caster, {:unit, {:homunculus, 5002}}, 1, definition())

      assert {:failed, ^caster, :invalid_target} =
               CrDevotion.cast(caster, {:unit, {:homunculus, 5002}}, 1, definition())
    end

    test "a stranger's homunculus is refused before the requirement is paid" do
      caster = register(player(@crusader_id, job_id: @crusader_class, party_id: 1))
      register(player(4001, party_id: 2))
      register_homunculus(5003, 4001)

      assert {:error, :not_same_party} =
               CrDevotion.validate(caster, {:unit, {:homunculus, 5003}}, 1, definition())
    end

    test "a target already devoted by another Crusader is refused after the requirement is paid" do
      caster = register(player(@crusader_id, job_id: @crusader_class))
      register(player(4001))

      :ok =
        StatusStorage.apply_status(:player, 4001, :sc_devotion,
          caster_id: 4002,
          duration: 30_000,
          state: %{peer: {:player, 4002}, link_id: make_ref(), range: 7}
        )

      assert {:failed, ^caster, :devoted_by_another} =
               CrDevotion.cast(caster, {:unit, 4001}, 1, definition())
    end

    test "re-casting on the Crusader's own devotee still refreshes it" do
      caster = register(player(@crusader_id, job_id: @crusader_class))
      register(player(4001))

      assert {:ok, _} = CrDevotion.cast(caster, {:unit, 4001}, 1, definition())
      assert {:ok, ^caster} = CrDevotion.cast(caster, {:unit, 4001}, 1, definition())
    end
  end

  describe "dead player targets" do
    test "a dead non-party player is refused before the requirement while a dead party member is skipped" do
      caster = register(player(@crusader_id, job_id: @crusader_class, party_id: 1))
      register(%{player(4001, party_id: 2) | action_state: :dead})
      register(%{player(4002, party_id: 1) | action_state: :dead})

      # The party gate runs before the requirement is paid; the dead-target
      # early return sits below it, inside the implementation.
      assert {:error, :not_same_party} =
               SkillInterpreter.complete_cast(caster, 255, 1, {:unit, 4001})

      assert {:skipped, _skipped, :target_dead} =
               SkillInterpreter.complete_cast(caster, 255, 1, {:unit, 4002})
    end
  end

  describe "slot cap" do
    test "the Crusader holds at most skill_lv devotees, re-cast refreshing rather than consuming a slot" do
      caster = register(player(@crusader_id, job_id: @crusader_class))
      register(player(4001))
      register(player(4002))
      register(player(4003))

      assert {:ok, ^caster} = CrDevotion.cast(caster, {:unit, 4001}, 2, definition())
      assert {:ok, ^caster} = CrDevotion.cast(caster, {:unit, 4002}, 2, definition())

      # A full devotee set is refused after the requirement is paid.
      assert {:failed, ^caster, :devotion_slots_full} =
               CrDevotion.cast(caster, {:unit, 4003}, 2, definition())

      assert {:ok, ^caster} = CrDevotion.cast(caster, {:unit, 4001}, 2, definition())

      assert devoted_by_count(@crusader_id) == 2
    end
  end

  describe "cast/4" do
    test "establishes both link records with a shared link id and the stored redirect range" do
      caster = register(player(@crusader_id, job_id: @crusader_class))
      register(player(4001))

      assert {:ok, ^caster} = CrDevotion.cast(caster, {:unit, 4001}, 3, definition())

      devotion = StatusStorage.get_status(:player, 4001, :sc_devotion)
      devoted_by = StatusStorage.get_status(:player, @crusader_id, :sc_devoted_by)

      assert devotion.state.peer == {:player, @crusader_id}
      assert devotion.state.range == 9
      assert is_reference(devotion.state.link_id)

      link = devoted_by.state.links[4001]
      assert link.peer == {:player, 4001}
      assert link.link_id == devotion.state.link_id
    end

    test "applies the tabulated duration on the devotee side" do
      caster = register(player(@crusader_id, job_id: @crusader_class))
      register(player(4001))

      assert {:ok, ^caster} = CrDevotion.cast(caster, {:unit, 4001}, 5, definition())

      devotion = StatusStorage.get_status(:player, 4001, :sc_devotion)
      assert devotion.expires_at - devotion.started_at == 90_000
    end

    test "re-casting on an existing devotee refreshes the link id without growing the set" do
      caster = register(player(@crusader_id, job_id: @crusader_class))
      register(player(4001))

      {:ok, _} = CrDevotion.cast(caster, {:unit, 4001}, 1, definition())
      first = StatusStorage.get_status(:player, 4001, :sc_devotion).state.link_id

      {:ok, _} = CrDevotion.cast(caster, {:unit, 4001}, 1, definition())
      second = StatusStorage.get_status(:player, 4001, :sc_devotion).state.link_id

      refute first == second
      assert devoted_by_count(@crusader_id) == 1

      link = StatusStorage.get_status(:player, @crusader_id, :sc_devoted_by).state.links[4001]
      assert link.link_id == second
    end
  end

  describe "teardown cascades" do
    test "removing the devotee side detaches it from the Crusader, retiring the entry when last" do
      caster = register(player(@crusader_id, job_id: @crusader_class))
      register(player(4001))
      {:ok, _} = CrDevotion.cast(caster, {:unit, 4001}, 1, definition())

      StatusInterpreter.remove_status(:player, 4001, :sc_devotion)

      refute StatusStorage.has_status?(:player, 4001, :sc_devotion)
      refute StatusStorage.has_status?(:player, @crusader_id, :sc_devoted_by)
    end

    test "removing one devotee leaves the other's link intact on the Crusader" do
      caster = register(player(@crusader_id, job_id: @crusader_class))
      register(player(4001))
      register(player(4002))
      {:ok, _} = CrDevotion.cast(caster, {:unit, 4001}, 2, definition())
      {:ok, _} = CrDevotion.cast(caster, {:unit, 4002}, 2, definition())

      StatusInterpreter.remove_status(:player, 4001, :sc_devotion)

      refute StatusStorage.has_status?(:player, 4001, :sc_devotion)
      assert devoted_by_count(@crusader_id) == 1
      assert StatusStorage.has_status?(:player, 4002, :sc_devotion)
    end

    test "removing the Crusader side cascades to every devotee" do
      caster = register(player(@crusader_id, job_id: @crusader_class))
      register(player(4001))
      register(player(4002))
      {:ok, _} = CrDevotion.cast(caster, {:unit, 4001}, 2, definition())
      {:ok, _} = CrDevotion.cast(caster, {:unit, 4002}, 2, definition())

      StatusInterpreter.remove_status(:player, @crusader_id, :sc_devoted_by)

      refute StatusStorage.has_status?(:player, @crusader_id, :sc_devoted_by)
      refute StatusStorage.has_status?(:player, 4001, :sc_devotion)
      refute StatusStorage.has_status?(:player, 4002, :sc_devotion)
    end

    test "a cross-map warp of either participant clears both sides" do
      caster = register(player(@crusader_id, job_id: @crusader_class))
      register(player(4001))
      {:ok, _} = CrDevotion.cast(caster, {:unit, 4001}, 1, definition())

      StatusInterpreter.remove_on_map_change(:player, 4001)

      refute StatusStorage.has_status?(:player, 4001, :sc_devotion)
      refute StatusStorage.has_status?(:player, @crusader_id, :sc_devoted_by)
    end
  end

  describe "per-tick self-heal" do
    test "keeps both sides while the peer records and units remain intact" do
      caster = register(player(@crusader_id, job_id: @crusader_class))
      register(player(4001))
      {:ok, _} = CrDevotion.cast(caster, {:unit, 4001}, 1, definition())

      StatusInterpreter.process_tick(:player, 4001, :sc_devotion)
      StatusInterpreter.process_tick(:player, @crusader_id, :sc_devoted_by)

      assert StatusStorage.has_status?(:player, 4001, :sc_devotion)
      assert StatusStorage.has_status?(:player, @crusader_id, :sc_devoted_by)
    end

    test "the devotee side keeps its link when the Crusader record was bulk-cleared" do
      caster = register(player(@crusader_id, job_id: @crusader_class))
      register(player(4001))
      {:ok, _} = CrDevotion.cast(caster, {:unit, 4001}, 1, definition())

      StatusStorage.clear_unit_statuses(:player, @crusader_id)

      StatusInterpreter.process_tick(:player, 4001, :sc_devotion)

      assert StatusStorage.has_status?(:player, 4001, :sc_devotion)
    end

    test "the Crusader side drops a devotee whose record was bulk-cleared, retiring the empty entry" do
      caster = register(player(@crusader_id, job_id: @crusader_class))
      register(player(4001))
      {:ok, _} = CrDevotion.cast(caster, {:unit, 4001}, 1, definition())

      StatusStorage.clear_unit_statuses(:player, 4001)

      StatusInterpreter.process_tick(:player, @crusader_id, :sc_devoted_by)

      refute StatusStorage.has_status?(:player, @crusader_id, :sc_devoted_by)
    end

    test "the Crusader side keeps live devotees while dropping a dead one" do
      caster = register(player(@crusader_id, job_id: @crusader_class))
      register(player(4001))
      register(player(4002))
      {:ok, _} = CrDevotion.cast(caster, {:unit, 4001}, 2, definition())
      {:ok, _} = CrDevotion.cast(caster, {:unit, 4002}, 2, definition())

      StatusStorage.clear_unit_statuses(:player, 4001)

      StatusInterpreter.process_tick(:player, @crusader_id, :sc_devoted_by)

      assert devoted_by_count(@crusader_id) == 1

      assert StatusStorage.get_status(:player, @crusader_id, :sc_devoted_by).state.links[4002]
    end
  end

  defp definition do
    {:ok, definition} = Catalog.by_name(:cr_devotion)
    definition
  end

  defp player(id, opts \\ []) do
    character = %Character{
      id: id,
      account_id: id,
      name: "Devotee#{id}",
      last_map: "prontera",
      last_x: 50,
      last_y: 50,
      sex: "M",
      hair: 1,
      hair_color: 0,
      clothes_color: 0,
      head_mid: 0,
      head_bottom: 0,
      robe: 0,
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: Keyword.get(opts, :base_level, 90),
      job_level: 50,
      class: Keyword.get(opts, :job_id, @knight_class),
      party_id: Keyword.get(opts, :party_id, 1)
    }

    PlayerState.new(character)
  end

  defp register(%PlayerState{character_id: id} = state) do
    :ok = UnitRegistry.register_unit(:player, id, PlayerState, state, self())
    :ok = SpatialIndex.add_player(id, state.x, state.y, state.map_name)
    state
  end

  defp register_homunculus(gid, owner_id) do
    state = %HomunculusState{
      id: gid,
      world_gid: gid,
      owner_character_id: owner_id,
      class_id: 6001,
      name: "DevotionHomunculus",
      lifecycle: :active,
      action_state: :idle,
      hp: 100,
      map_name: "prontera",
      x: 50,
      y: 50
    }

    :ok = UnitRegistry.register_unit(:homunculus, gid, HomunculusState, state, self())
    state
  end

  defp mob_caster do
    mob_data = %MobDefinition{
      id: 1004,
      aegis_name: "test_crusader",
      name: "Test Crusader",
      level: 50,
      hp: 1000,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      matk: 0,
      attack_range: 1,
      size: :medium,
      race: :formless,
      element: {:neutral, 1},
      walk_speed: 200,
      attack_delay: 1000,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300
    }

    spawn_ref = %MobSpawn{
      mob: 1004,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    MobState.new(9003, mob_data, spawn_ref, "prontera", 100, 100)
  end

  defp devoted_by_count(crusader_id) do
    case StatusStorage.get_status(:player, crusader_id, :sc_devoted_by) do
      nil -> 0
      entry -> map_size(entry.state.links)
    end
  end
end
