defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaAutospellTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Sage.SaAutospell
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!

  @firebolt 19
  @coldbolt 14
  @lightningbolt 20
  @soulstrike 13
  @fireball 17
  @earthspike 90
  @frostdiver 15
  @thunderstorm 21
  @heavendrive 91

  @all_bolts %{
    @firebolt => 10,
    @coldbolt => 10,
    @lightningbolt => 10,
    @soulstrike => 10,
    @fireball => 10,
    @earthspike => 5,
    @frostdiver => 10,
    @thunderstorm => 10,
    @heavendrive => 5
  }

  describe "eligible_bolts/2 tiers" do
    test "autospell level 1 offers only the three basic bolts" do
      assert SaAutospell.eligible_bolts(@all_bolts, 1) == [@firebolt, @coldbolt, @lightningbolt]
    end

    # Each tier opens on `skill_lv > required`, never `>=` (clif.cpp:8446), so
    # every boundary below is asserted on both sides.
    test "the soulstrike/fireball tier opens at 4, not 3" do
      assert SaAutospell.eligible_bolts(@all_bolts, 3) == [@firebolt, @coldbolt, @lightningbolt]

      assert SaAutospell.eligible_bolts(@all_bolts, 4) == [
               @firebolt,
               @coldbolt,
               @lightningbolt,
               @soulstrike,
               @fireball
             ]
    end

    test "the earthspike/frostdiver tier opens at 7, not 6" do
      refute @earthspike in SaAutospell.eligible_bolts(@all_bolts, 6)
      refute @frostdiver in SaAutospell.eligible_bolts(@all_bolts, 6)
      assert @earthspike in SaAutospell.eligible_bolts(@all_bolts, 7)
      assert @frostdiver in SaAutospell.eligible_bolts(@all_bolts, 7)
    end

    test "the thunderstorm/heavendrive tier opens at 10, not 9" do
      refute @thunderstorm in SaAutospell.eligible_bolts(@all_bolts, 9)
      refute @heavendrive in SaAutospell.eligible_bolts(@all_bolts, 9)

      assert SaAutospell.eligible_bolts(@all_bolts, 10) == [
               @firebolt,
               @coldbolt,
               @lightningbolt,
               @soulstrike,
               @fireball,
               @earthspike,
               @frostdiver,
               @thunderstorm,
               @heavendrive
             ]
    end
  end

  describe "eligible_bolts/2 learned gating" do
    test "an unlearned bolt is never offered, however high the autospell level" do
      learned = Map.delete(@all_bolts, @coldbolt)

      refute @coldbolt in SaAutospell.eligible_bolts(learned, 10)
      assert @firebolt in SaAutospell.eligible_bolts(learned, 10)
    end

    test "a bolt learned at level 0 is treated as unlearned" do
      learned = Map.put(@all_bolts, @firebolt, 0)

      refute @firebolt in SaAutospell.eligible_bolts(learned, 10)
    end

    test "a caster who learned no bolts is offered nothing" do
      assert SaAutospell.eligible_bolts(%{}, 10) == []
    end
  end

  # skill.cpp:10709-10752. The Soul Linker branch (`maxlv = 10` under SC_SPIRIT
  # / SL_SAGE) is deliberately absent: Aesir has no Soul Linker.
  describe "max_level/2" do
    test "is half the autospell level, floored" do
      assert SaAutospell.max_level(10, 10) == 5
      assert SaAutospell.max_level(10, 9) == 4
      assert SaAutospell.max_level(10, 8) == 4
    end

    test "is capped by the learned level of the chosen bolt" do
      assert SaAutospell.max_level(3, 10) == 3
      assert SaAutospell.max_level(1, 10) == 1
    end

    test "never drops below 1, though autospell level 1 halves to 0" do
      assert SaAutospell.max_level(10, 1) == 1
    end
  end

  describe "metadata" do
    test "the catalog resolves id 279 with the renewal skill_db values" do
      assert {:ok, SaAutospell} = Catalog.active_module_for(:sa_autospell)
      assert {:ok, definition} = Catalog.by_id(279)

      assert definition.name == :sa_autospell
      assert definition.max_level == 10
      assert definition.target_type == :self
      assert definition.damage_type == :no_damage
      assert definition.status == :sc_autospell
      assert definition.sp_cost == List.duplicate(35, 10)
      assert definition.fixed_cast_time == List.duplicate(3_000, 10)
    end

    test "publishes the menu capability so an accepted reply routes back here" do
      assert {:ok, SaAutospell} = Catalog.menu_module_for(:sa_autospell)
    end
  end

  describe "cast/4" do
    test "stages the eligible bolts as a menu offer carrying the cast level" do
      assert {:ok, staged} = cast(@all_bolts, 4)

      assert staged.pending_menu_offer == %{
               skill_id: 279,
               kind: :SKILLS,
               entry_ids: [@firebolt, @coldbolt, @lightningbolt, @soulstrike, @fireball],
               level: 4
             }
    end

    # Without a bolt there is nothing to arm; failing here means the interpreter
    # charges no SP for the cast, since it only charges after the behaviour runs.
    test "fails the cast when the caster has learned no eligible bolt" do
      assert {:error, :no_eligible_skills} = cast(%{}, 10)
    end
  end

  describe "on_menu_reply/3" do
    test "arms the chosen bolt with the level-scaled duration and proc chance" do
      expect(StatusInterpreter, :apply_status, fn :player, 1, :sc_autospell, params ->
        assert params[:duration] == 210_000
        assert params[:state] == %{skill: :mg_firebolt, max_level: 2, chance: 8}
        :ok
      end)

      assert {:ok, _} = reply(@all_bolts, @firebolt, 4)
    end

    test "duration is 90 + 30 * level seconds across the range" do
      for {level, duration} <- [{1, 120_000}, {5, 240_000}, {10, 390_000}] do
        expect(StatusInterpreter, :apply_status, fn :player, 1, :sc_autospell, params ->
          assert params[:duration] == duration
          :ok
        end)

        assert {:ok, _} = reply(@all_bolts, @firebolt, level)
      end
    end

    test "proc chance is 2 * level, with no pre-renewal flat 5 added" do
      for level <- 1..10 do
        expect(StatusInterpreter, :apply_status, fn :player, 1, :sc_autospell, params ->
          assert params[:state].chance == 2 * level
          :ok
        end)

        assert {:ok, _} = reply(@all_bolts, @firebolt, level)
      end
    end

    test "the armed max_level is capped by how far the caster learned that bolt" do
      learned = Map.put(@all_bolts, @firebolt, 1)

      expect(StatusInterpreter, :apply_status, fn :player, 1, :sc_autospell, params ->
        assert params[:state].max_level == 1
        :ok
      end)

      assert {:ok, _} = reply(learned, @firebolt, 10)
    end

    # The player already paid the cast's SP, so a refused application must not be
    # swallowed as success: it surfaces for the caller to log.
    test "propagates a refused status application rather than reporting success" do
      expect(StatusInterpreter, :apply_status, fn :player, 1, :sc_autospell, _params ->
        {:error, :immune}
      end)

      assert {:error, :immune} = reply(@all_bolts, @firebolt, 4)
    end

    test "arms the bolt named by the reply, not the first offered" do
      expect(StatusInterpreter, :apply_status, fn :player, 1, :sc_autospell, params ->
        assert params[:state].skill == :mg_thunderstorm
        :ok
      end)

      assert {:ok, _} = reply(@all_bolts, @thunderstorm, 10)
    end
  end

  defp reply(learned, selected_id, level) do
    game_state = %PlayerState{
      character_id: 1,
      stats: %{progression: %{learned_skills: learned}}
    }

    SaAutospell.on_menu_reply(game_state, %{id: selected_id, extras: []}, level)
  end

  defp cast(learned, level) do
    {:ok, definition} = Catalog.by_id(279)

    game_state = %PlayerState{
      character_id: 1,
      stats: %{progression: %{learned_skills: learned}}
    }

    SaAutospell.cast(game_state, :self, level, definition)
  end
end
