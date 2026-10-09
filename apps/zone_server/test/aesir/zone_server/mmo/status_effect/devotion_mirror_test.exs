defmodule Aesir.ZoneServer.Mmo.StatusEffect.DevotionMirrorTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Efst
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Crusader.CrAutoguard
  alias Aesir.ZoneServer.Mmo.Skills.Crusader.CrDefender
  alias Aesir.ZoneServer.Mmo.Skills.Crusader.CrDevotion
  alias Aesir.ZoneServer.Mmo.Skills.Crusader.CrReflectshield
  alias Aesir.ZoneServer.Mmo.StatusEffect.DevotionMirror
  alias Aesir.ZoneServer.Mmo.StatusEffect.Dispel
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  @crusader_id 4000
  @crusader_class 14
  @knight_class 7

  describe "copy on devotion cast" do
    test "devoting while Defender is on mirrors it at the Crusader's level with mirrored_from" do
      caster = register(player(@crusader_id, job_id: @crusader_class))
      register(player(4001))
      register(player(4002))

      {:ok, ^caster} = CrDefender.cast(caster, :self, 3, def_of(:cr_defender))

      {:ok, _} = CrDevotion.cast(caster, {:unit, 4001}, 2, def_of(:cr_devotion))
      {:ok, _} = CrDevotion.cast(caster, {:unit, 4002}, 2, def_of(:cr_devotion))

      for id <- [4001, 4002] do
        entry = StatusStorage.get_status(:player, id, :sc_defender)
        assert %StatusEntry{val1: 3, state: %{mirrored_from: @crusader_id}} = entry
      end
    end

    test "no toggle active means nothing is mirrored onto the new devotee" do
      caster = register(player(@crusader_id, job_id: @crusader_class))
      register(player(4001))

      {:ok, _} = CrDevotion.cast(caster, {:unit, 4001}, 1, def_of(:cr_devotion))

      for status <- DevotionMirror.mirrored_statuses() do
        refute StatusStorage.has_status?(:player, 4001, status)
      end
    end
  end

  describe "fan-out on toggle" do
    test "toggling on mid-devotion adds mirrors to all devotees" do
      caster = register(player(@crusader_id, job_id: @crusader_class))
      register(player(4001))
      register(player(4002))

      {:ok, _} = CrDevotion.cast(caster, {:unit, 4001}, 2, def_of(:cr_devotion))
      {:ok, _} = CrDevotion.cast(caster, {:unit, 4002}, 2, def_of(:cr_devotion))

      {:ok, ^caster} = CrAutoguard.cast(caster, :self, 5, def_of(:cr_autoguard))

      for id <- [4001, 4002] do
        entry = StatusStorage.get_status(:player, id, :sc_autoguard)
        assert %StatusEntry{val1: 5, state: %{mirrored_from: @crusader_id}} = entry
      end
    end

    test "toggling off removes the mirror from every devotee" do
      caster = register(player(@crusader_id, job_id: @crusader_class))
      register(player(4001))
      register(player(4002))

      {:ok, _} = CrReflectshield.cast(caster, :self, 4, def_of(:cr_reflectshield))
      {:ok, _} = CrDevotion.cast(caster, {:unit, 4001}, 2, def_of(:cr_devotion))
      {:ok, _} = CrDevotion.cast(caster, {:unit, 4002}, 2, def_of(:cr_devotion))

      assert StatusStorage.has_status?(:player, 4001, :sc_reflectshield)
      assert StatusStorage.has_status?(:player, 4002, :sc_reflectshield)

      {:ok, ^caster} = CrReflectshield.cast(caster, :self, 4, def_of(:cr_reflectshield))

      refute StatusStorage.has_status?(:player, 4001, :sc_reflectshield)
      refute StatusStorage.has_status?(:player, 4002, :sc_reflectshield)
    end

    test "a Crusader with no devotees fanning a toggle is a no-op" do
      caster = register(player(@crusader_id, job_id: @crusader_class))

      assert {:ok, ^caster} = CrDefender.cast(caster, :self, 1, def_of(:cr_defender))
      assert StatusStorage.has_status?(:player, @crusader_id, :sc_defender)
    end
  end

  describe "link break" do
    test "breaking one link removes only that devotee's mirrors; others keep theirs" do
      caster = register(player(@crusader_id, job_id: @crusader_class))
      register(player(4001))
      register(player(4002))

      {:ok, _} = CrDefender.cast(caster, :self, 3, def_of(:cr_defender))
      {:ok, _} = CrDevotion.cast(caster, {:unit, 4001}, 2, def_of(:cr_devotion))
      {:ok, _} = CrDevotion.cast(caster, {:unit, 4002}, 2, def_of(:cr_devotion))

      StatusInterpreter.remove_status(:player, 4001, :sc_devotion)

      refute StatusStorage.has_status?(:player, 4001, :sc_defender)

      assert %StatusEntry{state: %{mirrored_from: @crusader_id}} =
               StatusStorage.get_status(:player, 4002, :sc_defender)
    end

    test "the Crusader-side mass teardown removes mirrors from every devotee" do
      caster = register(player(@crusader_id, job_id: @crusader_class))
      register(player(4001))
      register(player(4002))

      {:ok, _} = CrDefender.cast(caster, :self, 3, def_of(:cr_defender))
      {:ok, _} = CrDevotion.cast(caster, {:unit, 4001}, 2, def_of(:cr_devotion))
      {:ok, _} = CrDevotion.cast(caster, {:unit, 4002}, 2, def_of(:cr_devotion))

      StatusInterpreter.remove_status(:player, @crusader_id, :sc_devoted_by)

      refute StatusStorage.has_status?(:player, 4001, :sc_defender)
      refute StatusStorage.has_status?(:player, 4002, :sc_defender)
    end

    test "the link break also ends a devotee's own copy of a mirrored status" do
      caster = register(player(@crusader_id, job_id: @crusader_class))
      register(player(4001))

      :ok = StatusInterpreter.apply_status(:player, 4001, :sc_defender, val1: 1)
      {:ok, _} = CrDevotion.cast(caster, {:unit, 4001}, 1, def_of(:cr_devotion))

      StatusInterpreter.remove_status(:player, 4001, :sc_devotion)

      refute StatusStorage.has_status?(:player, 4001, :sc_defender)
    end
  end

  describe "no re-fan" do
    test "a mirror landing on a devotee does not cascade to that devotee's own devotees" do
      caster = register(player(@crusader_id, job_id: @crusader_class))
      register(player(4001))
      register(player(4002))

      {:ok, _} = CrDevotion.cast(caster, {:unit, 4001}, 1, def_of(:cr_devotion))

      :ok =
        StatusInterpreter.apply_status(:player, 4001, :sc_devoted_by,
          caster_id: 4001,
          state: %{links: %{4002 => %{peer: {:player, 4002}, link_id: make_ref()}}}
        )

      {:ok, ^caster} = CrDefender.cast(caster, :self, 2, def_of(:cr_defender))

      assert %StatusEntry{state: %{mirrored_from: @crusader_id}} =
               StatusStorage.get_status(:player, 4001, :sc_defender)

      refute StatusStorage.has_status?(:player, 4002, :sc_defender)
    end
  end

  describe "any end of the Crusader's own status" do
    test "a dispelled Crusader leaves no devotee shielded" do
      caster = register(player(@crusader_id, job_id: @crusader_class))
      register(player(4001))

      {:ok, _} = CrDevotion.cast(caster, {:unit, 4001}, 1, def_of(:cr_devotion))
      {:ok, _} = CrDefender.cast(caster, :self, 3, def_of(:cr_defender))
      {:ok, _} = CrReflectshield.cast(caster, :self, 3, def_of(:cr_reflectshield))
      {:ok, _} = CrAutoguard.cast(caster, :self, 3, def_of(:cr_autoguard))

      :ok = Dispel.dispel({:player, @crusader_id})

      for status <- [:sc_defender, :sc_reflectshield, :sc_autoguard] do
        refute StatusStorage.has_status?(:player, 4001, status)
      end
    end

    test "the Crusader's status ending ends a devotee's own copy too" do
      caster = register(player(@crusader_id, job_id: @crusader_class))
      register(player(4001))

      {:ok, _} = CrDevotion.cast(caster, {:unit, 4001}, 1, def_of(:cr_devotion))
      :ok = StatusInterpreter.apply_status(:player, @crusader_id, :sc_endure, val1: 1)
      :ok = StatusInterpreter.apply_status(:player, 4001, :sc_endure, val1: 9, duration: 60_000)

      StatusInterpreter.remove_status(:player, @crusader_id, :sc_endure)

      refute StatusStorage.has_status?(:player, 4001, :sc_endure)
    end
  end

  test "neither the Crusader's Endure ending nor the link ending ends an infinite Endure" do
    caster = register(player(@crusader_id, job_id: @crusader_class))
    register(player(4001))

    {:ok, _} = CrDevotion.cast(caster, {:unit, 4001}, 1, def_of(:cr_devotion))
    :ok = StatusInterpreter.apply_status(:player, @crusader_id, :sc_endure, val1: 1)
    :ok = StatusInterpreter.apply_status(:player, 4001, :sc_endure, val1: 1, val4: 1)

    StatusInterpreter.remove_status(:player, @crusader_id, :sc_endure)
    assert StatusStorage.has_status?(:player, 4001, :sc_endure)

    StatusInterpreter.remove_status(:player, 4001, :sc_devotion)
    assert StatusStorage.has_status?(:player, 4001, :sc_endure)
  end

  describe "copies" do
    test "a started copy takes the Crusader's values and duration and shows no icon" do
      caster = register(player(@crusader_id, job_id: @crusader_class))
      register(player(4001))

      {:ok, _} = CrDevotion.cast(caster, {:unit, 4001}, 1, def_of(:cr_devotion))
      {:ok, _} = CrAutoguard.cast(caster, :self, 4, def_of(:cr_autoguard))

      own = StatusStorage.get_status(:player, @crusader_id, :sc_autoguard)
      copy = StatusStorage.get_status(:player, 4001, :sc_autoguard)

      assert %StatusEntry{val1: 4, state: %{block_chance: 18}} = own
      assert %StatusEntry{val1: 4, state: %{block_chance: 18, mirrored_from: @crusader_id}} = copy
      assert_in_delta copy.expires_at, own.expires_at, 50
      assert StatusEntry.no_icon?(copy)

      refute Enum.any?(
               StatusDisplay.active_icons(:player, 4001),
               &(&1.efst == Efst.id(:autoguard))
             )
    end

    test "a link copies the Crusader's toggles at their level without the start values" do
      caster = register(player(@crusader_id, job_id: @crusader_class))
      register(player(4001))

      {:ok, _} = CrAutoguard.cast(caster, :self, 4, def_of(:cr_autoguard))
      {:ok, _} = CrDefender.cast(caster, :self, 2, def_of(:cr_defender))
      {:ok, _} = CrDevotion.cast(caster, {:unit, 4001}, 1, def_of(:cr_devotion))

      guard = StatusStorage.get_status(:player, 4001, :sc_autoguard)
      defender = StatusStorage.get_status(:player, 4001, :sc_defender)

      assert %StatusEntry{val1: 4, state: %{block_chance: 0}} = guard
      assert %StatusEntry{val1: 2, state: %{reduction: 0, aspd_penalty: 0}} = defender
      refute StatusEntry.no_icon?(defender)

      now = System.monotonic_time(:millisecond)
      assert_in_delta guard.expires_at - now, 300_000, 100
      assert_in_delta defender.expires_at - now, 180_000, 100
    end

    test "Endure is mirrored, except an infinite one or on siege ground" do
      caster = register(player(@crusader_id, job_id: @crusader_class))
      register(player(4001))
      {:ok, _} = CrDevotion.cast(caster, {:unit, 4001}, 1, def_of(:cr_devotion))

      :ok =
        StatusInterpreter.apply_status(:player, @crusader_id, :sc_endure,
          val1: 3,
          duration: 16_000
        )

      assert %StatusEntry{val1: 3, state: %{mirrored_from: @crusader_id}} =
               StatusStorage.get_status(:player, 4001, :sc_endure)

      StatusInterpreter.remove_status(:player, @crusader_id, :sc_endure)

      :ok =
        StatusInterpreter.apply_status(:player, @crusader_id, :sc_endure,
          val1: 3,
          val4: 1,
          duration: 16_000
        )

      refute StatusStorage.has_status?(:player, 4001, :sc_endure)

      StatusInterpreter.remove_status(:player, @crusader_id, :sc_endure)
      :ok = SpatialIndex.add_player(@crusader_id, 50, 50, "prt_gld")
      :ok = MapFlags.set_runtime("prt_gld", :gvg, true)
      on_exit(fn -> MapFlags.clear_runtime("prt_gld", :gvg) end)

      :ok =
        StatusInterpreter.apply_status(:player, @crusader_id, :sc_endure,
          val1: 3,
          duration: 16_000
        )

      refute StatusStorage.has_status?(:player, 4001, :sc_endure)
    end
  end

  defp def_of(name) do
    {:ok, definition} = Catalog.by_name(name)
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
    state
  end
end
