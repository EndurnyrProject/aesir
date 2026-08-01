defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsAdrenalineTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skill.PartyBuff
  alias Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsAdrenaline
  alias Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsAdrenaline2
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment

  setup_all do
    Mimic.copy(PartyBuff)
    :ok
  end

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    :ok = Catalog.reload()
  end

  test "both Adrenaline Rush skills are active with their exact costs and durations" do
    assert {:ok, BsAdrenaline} = Catalog.active_module_for(:bs_adrenaline)
    assert {:ok, BsAdrenaline2} = Catalog.active_module_for(:bs_adrenaline2)

    assert {:ok, adrenaline} = Catalog.by_id(111)
    assert adrenaline.splash_radius == 14
    assert adrenaline.sp_cost == [20, 23, 26, 29, 32]
    assert adrenaline.duration == [30_000, 60_000, 90_000, 120_000, 150_000]
    assert adrenaline.require_weapon == [:one_handed_axe, :two_handed_axe, :mace]

    assert {:ok, adrenaline2} = Catalog.by_id(459)
    assert adrenaline2.splash_radius == 14
    assert adrenaline2.sp_cost == [64]
    assert adrenaline2.duration == [150_000]
  end

  test "a caster without an axe or mace fails before applying any status" do
    reject(&PartyBuff.apply/5)

    assert {:error, :wrong_weapon} = Interpreter.cast(player(), 111, 1, :self)
  end

  test "Adrenaline Rush passes caster-derived params and skips an ineligible weapon" do
    caster = player(1301)
    definition = BsAdrenaline.definition()

    expect(PartyBuff, :apply, fn ^caster, :sc_adrenaline, params, 14, eligible? ->
      assert params == [val1: 4, caster_id: 1, duration: 120_000]
      assert eligible?.(player(1301))
      refute eligible?.(player(1201))
      :ok
    end)

    assert {:ok, ^caster} = BsAdrenaline.cast(caster, :self, 4, definition)
  end

  test "Advanced Adrenaline Rush always fails its unavailable prerequisite" do
    assert {:error, :missing_adrenaline_empowerment} =
             BsAdrenaline2.validate(player(1301), :self, 1, BsAdrenaline2.definition())
  end

  test "Advanced Adrenaline Rush excludes ranged specialty weapons and two-handed staves" do
    accepted = BsAdrenaline2.definition().require_weapon

    for weapon <- [
          :bow,
          :revolver,
          :rifle,
          :gatling,
          :shotgun,
          :grenade_launcher,
          :huuma,
          :two_handed_staff
        ] do
      refute weapon in accepted
    end
  end

  test "Advanced Adrenaline Rush is complete behind its prerequisite gate" do
    caster = player(1301)
    definition = BsAdrenaline2.definition()

    expect(PartyBuff, :apply, fn ^caster, :sc_adrenaline2, params, 14, eligible? ->
      assert params == [val1: 1, caster_id: 1, duration: 150_000]
      assert eligible?.(player(1301))
      refute eligible?.(player(1701))
      :ok
    end)

    assert {:ok, ^caster} = BsAdrenaline2.cast(caster, :self, 1, definition)
  end

  defp player(weapon_id \\ nil) do
    character = %Character{
      id: 1,
      account_id: 1,
      name: "Blacksmith",
      class: 10,
      base_level: 99,
      job_level: 50,
      sex: "M",
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
      hp: 500,
      max_hp: 500,
      sp: 500,
      max_sp: 500,
      learned_skills: %{"111" => 5, "459" => 1}
    }

    state = PlayerState.new(character)
    %Stats{} = stats = state.stats
    %{state | stats: %Stats{stats | equipment: %Equipment{right_hand: weapon_id}}}
  end
end
