defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.DivestTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Net.SkillEffect
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.RgStriparmor
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.RgStriphelm
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.RgStripshield
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.RgStripweapon
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.StripCommon
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!

  setup do
    Mimic.copy(TargetResolver)
    Mimic.copy(PlayerSession)
    Mimic.copy(StatusInterpreter)
    Mimic.copy(PlayerState)
    Mimic.copy(MobState)
    Mimic.copy(StripCommon)
    :ok
  end

  @caster_id 1_000
  @target_id 2_000

  @sp_costs [
    {215, [17, 19, 21, 23, 25]},
    {216, [12, 14, 16, 18, 20]},
    {217, [17, 19, 21, 23, 25]},
    {218, [12, 14, 16, 18, 20]}
  ]

  @skills [
    {RgStripweapon, 215, :rg_stripweapon, "Divest Weapon", :right_hand, :sc_stripweapon},
    {RgStripshield, 216, :rg_stripshield, "Divest Shield", :left_hand, :sc_stripshield},
    {RgStriparmor, 217, :rg_striparmor, "Divest Armor", :armor, :sc_striparmor},
    {RgStriphelm, 218, :rg_striphelm, "Divest Helm", :head_top, :sc_striphelm}
  ]

  test "success rate uses the Renewal level and DEX formula within roll bounds" do
    assert StripCommon.strip_success_rate(1, 50, 50) == 100
    assert StripCommon.strip_success_rate(5, 90, 40) == 400
    assert StripCommon.strip_success_rate(1, 0, 100) == 0
    assert StripCommon.strip_success_rate(5, 1_000, 0) == 1_000
  end

  test "duration uses the level base, DEX bonus, and non-player bonus" do
    assert StripCommon.strip_duration_ms(1, 50, 50, :player) == 75_001
    assert StripCommon.strip_duration_ms(5, 50, 50, :player) == 135_005
    assert StripCommon.strip_duration_ms(3, 70, 50, :player) == 115_003
    assert StripCommon.strip_duration_ms(3, 70, 50, :mob) == 130_003
    assert StripCommon.strip_duration_ms(3, 70, 50, :homunculus) == 130_003
    assert StripCommon.strip_duration_ms(1, 0, 100, :player) == 75_001
  end

  test "Divest All's rate never drops below its level floor" do
    assert StripCommon.fullstrip_success_rate(1, 50, 50) == 70
    assert StripCommon.fullstrip_success_rate(5, 90, 40) == 250
    assert StripCommon.fullstrip_success_rate(5, 1, 99) == 150
  end

  test "a successful cast sends each player target one request for its slot" do
    caster = player(@caster_id)
    target = player(@target_id, 12)
    stub_stats(caster, target)
    stub(TargetResolver, :resolve, fn {:player, @target_id} -> {:ok, self(), target, :player} end)
    stub(StripCommon, :roll_success?, fn _rate -> true end)

    for {module, id, _name, _display_name, slot, _status} <- @skills do
      expect(PlayerSession, :strip_equip, fn target_pid, [^slot], opts ->
        assert target_pid == self()

        assert Keyword.equal?(opts,
                 duration: 115_002,
                 caster_id: @caster_id,
                 source_type: :player,
                 skill_id: id,
                 level: 2,
                 kind: :divest,
                 src_id: @caster_id,
                 target_id: @target_id,
                 origin: {"prontera", 12, 10},
                 report_to: @caster_id
               )

        :ok
      end)

      assert {:ok, ^caster} =
               module.cast(caster, {:unit, {:player, @target_id}}, 2, definition(module))
    end
  end

  test "a successful cast applies each unprotected status to a mob" do
    caster = player(@caster_id)
    target = mob(@target_id)
    stub_stats(caster, target)
    stub(TargetResolver, :resolve, fn {:mob, @target_id} -> {:ok, self(), target, :mob} end)
    stub(StripCommon, :roll_success?, fn _rate -> true end)
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)

    for {module, _id, _name, _display_name, _slot, status} <- @skills do
      expect(StatusInterpreter, :apply_status, fn :mob, @target_id, ^status, opts ->
        assert Keyword.equal?(opts,
                 bypass_resistance: true,
                 duration: 130_002,
                 caster_id: @caster_id,
                 source_type: :player
               )

        :ok
      end)

      assert {:ok, ^caster} =
               module.cast(caster, {:unit, {:mob, @target_id}}, 2, definition(module))
    end
  end

  test "a mob's Chemical Protection blocks its slot and the player caster sees the failure" do
    caster = player(@caster_id)
    target = mob(@target_id)
    stub_stats(caster, target)
    stub(TargetResolver, :resolve, fn {:mob, @target_id} -> {:ok, self(), target, :mob} end)
    stub(StripCommon, :roll_success?, fn _rate -> true end)
    stub(StatusStorage, :has_status?, fn :mob, @target_id, status -> status == :sc_cp_armor end)
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    reject(&StatusInterpreter.apply_status/4)
    expect(SkillHandler, :report_cast_failure, fn 217, @caster_id, :skill_failed -> :ok end)

    assert {:ok, ^caster} =
             RgStriparmor.cast(caster, {:unit, {:mob, @target_id}}, 2, definition(RgStriparmor))
  end

  test "a mob caster uses its own DEX and identity and is never told of a failure" do
    caster = mob(@caster_id)
    target = player(@target_id)
    stub(PlayerState, :get_stats, fn ^target -> %{dex: 20} end)
    stub(MobState, :get_stats, fn ^caster -> %{dex: 30} end)
    stub(TargetResolver, :resolve, fn {:player, @target_id} -> {:ok, self(), target, :player} end)
    stub(StripCommon, :roll_success?, fn _rate -> true end)

    expect(PlayerSession, :strip_equip, fn target_pid, [:right_hand], opts ->
      assert target_pid == self()
      assert opts[:duration] == 80_001
      assert opts[:caster_id] == @caster_id
      assert opts[:source_type] == :mob
      assert opts[:report_to] == nil
      :ok
    end)

    assert {:ok, ^caster} =
             RgStripweapon.cast(
               caster,
               {:unit, {:player, @target_id}},
               1,
               definition(RgStripweapon)
             )

    stub(StripCommon, :roll_success?, fn _rate -> false end)
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    reject(&SkillHandler.report_cast_failure/3)

    assert {:ok, ^caster} =
             RgStripweapon.cast(
               caster,
               {:unit, {:player, @target_id}},
               1,
               definition(RgStripweapon)
             )
  end

  test "a failed roll shows a failed effect and tells the player caster" do
    caster = player(@caster_id)
    target = player(@target_id, 12)
    stub_stats(caster, target)
    stub(TargetResolver, :resolve, fn {:player, @target_id} -> {:ok, self(), target, :player} end)
    stub(StripCommon, :roll_success?, fn _rate -> false end)
    reject(&PlayerSession.strip_equip/3)
    reject(&StatusInterpreter.apply_status/4)
    expect(SkillHandler, :report_cast_failure, fn 215, @caster_id, :skill_failed -> :ok end)

    expect(Broadcast, :to_in_range, fn "prontera", 12, 10, _range, packet ->
      assert %SkillEffect{skill_id: 215, src_id: @caster_id, target_id: @target_id, result: 0} =
               packet

      :ok
    end)

    assert {:ok, ^caster} =
             RgStripweapon.cast(
               caster,
               {:unit, {:player, @target_id}},
               2,
               definition(RgStripweapon)
             )
  end

  test "a trap target cannot be stripped" do
    caster = player(@caster_id)
    trap = %{map_name: "prontera", x: 11, y: 10}
    stub(TargetResolver, :resolve, fn {:skill_unit, 9} -> {:ok, nil, trap, :skill_unit} end)
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    reject(&StatusInterpreter.apply_status/4)
    expect(SkillHandler, :report_cast_failure, fn 215, @caster_id, :skill_failed -> :ok end)

    assert {:ok, ^caster} =
             RgStripweapon.cast(caster, {:unit, {:skill_unit, 9}}, 2, definition(RgStripweapon))
  end

  defp definition(module) do
    {:ok, definition} = Catalog.by_id(module.definition().id)
    definition
  end

  defp stub_stats(caster, target) do
    stub(PlayerState, :get_stats, fn
      ^caster -> %{dex: 70}
      ^target -> %{dex: 20}
    end)

    stub(MobState, :get_stats, fn ^target -> %{dex: 20} end)
  end

  defp player(id, x \\ 10), do: %PlayerState{character_id: id, map_name: "prontera", x: x, y: 10}

  defp mob(id) do
    %MobState{
      instance_id: id,
      mob_id: 1_002,
      mob_data: Aesir.TestMob.definition(),
      spawn_ref: nil,
      map_name: "prontera",
      x: 10,
      y: 10,
      hp: 100,
      sp: 100,
      spawned_at: 0
    }
    |> Aesir.TestMob.publish(max_hp: 100, max_sp: 100)
  end

  @tag game_mode: :renewal
  test "renewal carries the source's cast table and SP" do
    Catalog.reload()

    for {id, sp_cost} <- @sp_costs do
      assert {:ok, definition} = Catalog.by_id(id)
      assert definition.cast_time == [560, 720, 880, 1_140, 1_200]
      assert definition.fixed_cast_time == [140, 180, 220, 260, 300]
      assert definition.after_cast_delay == List.duplicate(1_000, 5)
      assert definition.sp_cost == sp_cost
    end
  end

  @tag game_mode: :pre_renewal
  test "classic carries the source's one-second cast and SP" do
    Catalog.reload()

    for {id, sp_cost} <- @sp_costs do
      assert {:ok, definition} = Catalog.by_id(id)
      assert definition.cast_time == List.duplicate(1_000, 5)
      assert definition.fixed_cast_time == []
      assert definition.after_cast_delay == List.duplicate(1_000, 5)
      assert definition.sp_cost == sp_cost
    end
  end
end
