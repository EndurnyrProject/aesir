defmodule Aesir.ZoneServer.Integration.MobCastIntegrationTest do
  @moduledoc """
  End-to-end coverage that the `SA_DISPELL` and `SA_LANDPROTECTOR` rows shipped
  in `priv/db/mob_skills/mob_skills.yml` actually resolve into effects.

  Both drive real rows read from `MobSkill.Db` through the real
  `MobSkill.Executor` against a real, live `PlayerSession`: the data is the
  fixture, so a catalog or archetype regression that silently degrades these
  rows back to `:stub` fails here.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.ZoneServer.Mmo.MobSkill.Db
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage

  # Wounded Morocc: carries both a level 5 `SA_DISPELL` row and a level 5
  # `SA_LANDPROTECTOR` row. Level 5 makes the archetype's `50 + 10*lv`% roll a
  # certainty, so the assertions do not depend on randomness.
  @mob_id 3235
  @map "prontera"

  setup :set_mimic_private
  setup :verify_on_exit!

  defp row!(skill_name) do
    row = Enum.find(Db.rows_for(@mob_id), &(&1.skill == skill_name and &1.level == 5))

    assert row != nil,
           "mob #{@mob_id} must still ship a level 5 #{skill_name} row (this test's fixture)"

    row
  end

  defp caster_targeting(char_id) do
    mob = spawn_test_mob(@map, {150, 150}, mob_id: @mob_id)
    %{get_mob_state(mob.pid) | target_id: char_id}
  end

  describe "SA_DISPELL rows" do
    test "a mob dispel strips the player's buffs and debuffs, sparing no_dispel statuses" do
      player = start_player_session(id: 9_801, name: "Dispelled", base_level: 50)
      char_id = player.character.id

      on_exit(fn -> StatusStorage.clear_unit_statuses(:player, char_id) end)

      :ok =
        StatusInterpreter.apply_status(:player, char_id, :sc_blessing,
          val1: 10,
          duration: 1_800_000
        )

      :ok = StatusInterpreter.apply_status(:player, char_id, :sc_poison, duration: 1_800_000)
      :ok = StatusInterpreter.apply_status(:player, char_id, :sc_bleeding, duration: 1_800_000)
      :ok = StatusInterpreter.apply_status(:player, char_id, :sc_hiding, duration: 1_800_000)

      assert :ok = Executor.execute(caster_targeting(char_id), row!("SA_DISPELL"))

      refute StatusStorage.has_status?(:player, char_id, :sc_blessing)

      # Debuffs go too. rAthena's Dispell (src/map/skills/mage/dispell.cpp:36-72)
      # iterates the whole status_db and ends everything not flagged SCF_NODISPELL:
      # there is no buff/debuff distinction. Poison and Bleeding are NOT flagged
      # NoDispell in db/re/status.yml, so a mob dispel cures them - it is not a
      # bug to "fix" back into a buff-only strip.
      refute StatusStorage.has_status?(:player, char_id, :sc_poison)
      refute StatusStorage.has_status?(:player, char_id, :sc_bleeding)

      # SC_HIDING is NoDispell in db/re/status.yml.
      assert StatusStorage.has_status?(:player, char_id, :sc_hiding)
    end

    test "a mob dispel never consults the PvP gate" do
      player = start_player_session(id: 9_802, name: "PveOnly", base_level: 50)
      char_id = player.character.id

      on_exit(fn -> StatusStorage.clear_unit_statuses(:player, char_id) end)

      :ok =
        StatusInterpreter.apply_status(:player, char_id, :sc_blessing,
          val1: 10,
          duration: 1_800_000
        )

      # Mob -> player is PvE: the attacker is not a player, so the cast has no
      # business in Targeting.validate_enemy's PvP branch and must not reach it.
      # The gate exemption is structural - keep it that way.
      reject(&Targeting.validate_enemy/2)

      assert :ok = Executor.execute(caster_targeting(char_id), row!("SA_DISPELL"))

      refute StatusStorage.has_status?(:player, char_id, :sc_blessing)
    end
  end

  describe "SA_LANDPROTECTOR rows" do
    test "a mob land protector row places a real LP field cast by the mob" do
      player = start_player_session(id: 9_803, name: "Protected", base_level: 50)
      char_id = player.character.id

      assert :ok = Executor.execute(caster_targeting(char_id), row!("SA_LANDPROTECTOR"))

      assert %Group{} = group = Enum.find(Storage.all(), &(&1.skill_name == :sa_landprotector))
      assert group.caster_type == :mob
      assert group.level == 5
      assert Group.land_protector?(group)
      assert group.cells != []

      on_exit(fn -> Storage.delete(group.group_id) end)
    end
  end
end
