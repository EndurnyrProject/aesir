defmodule Aesir.ZoneServer.Integration.MobSkillEventsIntegrationTest do
  @moduledoc """
  A reactive monster's skill events end to end through the real sessions.

  The natural `MobSkillDb` rows are replaced per case with one reaction row, so
  each test isolates the producer it exercises: a cast aimed at the monster
  (the cast-targeted event), and a landed skill hit (the attack-type event and
  the skill-used event, which carries the hit's damage).

  The reaction itself is real: the monster's own session picks the row with the
  shared selector and casts it, so the assertion is its `last_skill_id`.
  """

  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.ZoneServer.Mmo.MobSkill.Db, as: MobSkillDb
  alias Aesir.ZoneServer.TestSupport.ClownSessions
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence

  @reaction 350
  @fire_bolt 19
  @steal 50
  @resurrection 54
  @blue_gemstone 717

  setup do
    ClownSessions.blank_map("prontera")
    :ok
  end

  defp reaction(condition) do
    %{
      skill: "NPC_AGIUP",
      skill_id: @reaction,
      state: :any,
      level: 1,
      target: :self,
      delay: 5_000,
      cancelable: true,
      cast_time: 0,
      rate: 10_000,
      emotion: nil,
      condition: condition
    }
  end

  defp reactive_mob(condition) do
    mob = start_mob_session(position: {151, 150}, max_hp: 100_000)

    stub(MobSkillDb, :rows_for, fn _mob_id -> [reaction(condition)] end)
    Mimic.allow(MobSkillDb, self(), mob.pid)

    mob
  end

  defp caster(skills, overrides \\ %{}) do
    :novice
    |> ClownSessions.character(
      "prontera",
      {150, 150},
      skills,
      Map.merge(%{int: 99, dex: 99}, overrides)
    )
    |> ClownSessions.start_session()
  end

  defp fire_bolt_caster, do: caster(%{@fire_bolt => 5})

  test "a cast aimed at a monster runs its cast-targeted rows" do
    mob = reactive_mob(%{type: :casttargeted, value: 0})
    session = fire_bolt_caster()

    ClownSessions.cast(session, @fire_bolt, 1, mob.unit_id)

    assert_eventually(fn -> get_mob_state(mob.pid).last_skill_id == @reaction end)
  end

  test "a landed skill hit runs the monster's attack-type rows" do
    mob = reactive_mob(%{type: :damagedgt, value: 0})
    session = fire_bolt_caster()

    ClownSessions.cast(session, @fire_bolt, 1, mob.unit_id)

    assert_eventually(fn -> get_mob_state(mob.pid).last_skill_id == @reaction end)
  end

  test "a landed skill hit runs the monster's skill-used rows" do
    mob = reactive_mob(%{type: :skillused, value: @fire_bolt})
    session = fire_bolt_caster()

    ClownSessions.cast(session, @fire_bolt, 1, mob.unit_id)

    assert_eventually(fn -> get_mob_state(mob.pid).last_skill_id == @reaction end)
  end

  describe "the cast-targeted gate in renewal" do
    @describetag game_mode: :renewal, integration_pre_re: false

    test "an instant cast without a cast time still runs its cast-targeted rows" do
      mob = reactive_mob(%{type: :casttargeted, value: 0})
      session = caster(%{@steal => 1}, %{class: 17})

      ClownSessions.cast(session, @steal, 1, mob.unit_id)

      assert_eventually(fn -> get_mob_state(mob.pid).last_skill_id == @reaction end)
    end
  end

  describe "the cast-targeted gate in pre-renewal" do
    @describetag game_mode: :pre_renewal, integration_re: false

    test "an instant cast the reference does not force runs no cast-targeted row" do
      mob = reactive_mob(%{type: :casttargeted, value: 0})
      session = caster(%{@steal => 1}, %{class: 17})

      ClownSessions.cast(session, @steal, 1, mob.unit_id)

      refute_eventually(fn -> get_mob_state(mob.pid).last_skill_id == @reaction end, 1_000)
    end

    test "an instant Resurrection at an undead monster runs its cast-targeted row" do
      mob =
        start_mob_session(position: {151, 150}, max_hp: 100_000, element: {:undead, 1})

      stub(MobSkillDb, :rows_for, fn _mob_id -> [reaction(%{type: :casttargeted, value: 0})] end)
      Mimic.allow(MobSkillDb, self(), mob.pid)

      session = caster(%{@resurrection => 4})
      # Resurrection needs its Blue Gemstone catalyst to reach its cast end.
      {:ok, _item} =
        InventoryPersistence.insert_item(session.character.id, %{
          nameid: @blue_gemstone,
          amount: 2,
          identify: 1
        })

      ClownSessions.cast(session, @resurrection, 4, mob.unit_id)

      assert_eventually(fn -> get_mob_state(mob.pid).last_skill_id == @reaction end)
    end
  end
end
