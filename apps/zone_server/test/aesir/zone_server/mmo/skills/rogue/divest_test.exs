defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.DivestTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.RgStriparmor
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.RgStriphelm
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.RgStripshield
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.RgStripweapon
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.StripCommon
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
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

  @skills [
    {RgStripweapon, 215, :rg_stripweapon, "Divest Weapon", :right_hand, :sc_stripweapon, 0},
    {RgStripshield, 216, :rg_stripshield, "Divest Shield", :left_hand, :sc_stripshield, 0},
    {RgStriparmor, 217, :rg_striparmor, "Divest Armor", :armor, :sc_striparmor, 40},
    {RgStriphelm, 218, :rg_striphelm, "Divest Helm", :head_top, :sc_striphelm, 40}
  ]

  test "all four skills are discovered with their Renewal definitions" do
    Catalog.reload()

    for {module, id, name, display_name, _slot, _status, _val2} <- @skills do
      assert {:ok, ^module} = Catalog.active_module_for(name)
      assert {:ok, definition} = Catalog.by_id(id)
      assert definition.name == name
      assert definition.display_name == display_name
      assert definition.max_level == 5
      assert definition.target_type == :target_enemy
      assert definition.damage_type == :no_damage
      assert definition.range == 1
    end
  end

  test "success rate uses the Renewal level and DEX formula within roll bounds" do
    assert StripCommon.strip_success_rate(1, 50, 50) == 100
    assert StripCommon.strip_success_rate(5, 90, 40) == 400
    assert StripCommon.strip_success_rate(1, 0, 100) == 0
    assert StripCommon.strip_success_rate(5, 1_000, 0) == 1_000
  end

  test "duration uses the level base, DEX bonus, and mob bonus" do
    assert StripCommon.strip_duration_ms(1, 50, 50, :player) == 75_001
    assert StripCommon.strip_duration_ms(5, 50, 50, :player) == 135_005
    assert StripCommon.strip_duration_ms(3, 70, 50, :player) == 115_003
    assert StripCommon.strip_duration_ms(3, 70, 50, :mob) == 130_003
    assert StripCommon.strip_duration_ms(1, 0, 100, :player) == 75_001
  end

  test "a successful cast divests each player slot with its status options" do
    caster = player(@caster_id)
    target = player(@target_id)
    stub_stats(caster, target)
    stub(TargetResolver, :resolve, fn {:player, @target_id} -> {:ok, self(), target, :player} end)
    stub(StripCommon, :roll_success?, fn _level, _caster_dex, _target_dex -> true end)

    for {module, _id, _name, _display_name, slot, _status, val2} <- @skills do
      expect(PlayerSession, :strip_equip, fn target_pid, ^slot, opts ->
        assert target_pid == self()

        assert opts == [
                 duration: 115_002,
                 val2: val2,
                 caster_id: @caster_id,
                 source_type: :player
               ]

        :ok
      end)

      assert {:ok, ^caster} =
               module.cast(caster, {:unit, {:player, @target_id}}, 2, definition(module))
    end
  end

  test "a successful cast applies each matching status to a mob" do
    caster = player(@caster_id)
    target = mob(@target_id)
    stub_stats(caster, target)
    stub(TargetResolver, :resolve, fn {:mob, @target_id} -> {:ok, self(), target, :mob} end)
    stub(StripCommon, :roll_success?, fn _level, _caster_dex, _target_dex -> true end)

    for {module, _id, _name, _display_name, _slot, status, val2} <- @skills do
      expect(StatusInterpreter, :apply_status, fn :mob, @target_id, ^status, opts ->
        assert Keyword.equal?(opts,
                 bypass_resistance: true,
                 duration: 130_002,
                 val2: val2,
                 caster_id: @caster_id,
                 source_type: :player
               )

        :ok
      end)

      assert {:ok, ^caster} =
               module.cast(caster, {:unit, {:mob, @target_id}}, 2, definition(module))
    end
  end

  test "a mob caster uses its own DEX and identity" do
    caster = mob(@caster_id)
    target = player(@target_id)
    stub(PlayerState, :get_stats, fn ^target -> %{dex: 20} end)
    stub(MobState, :get_stats, fn ^caster -> %{dex: 30} end)
    stub(TargetResolver, :resolve, fn {:player, @target_id} -> {:ok, self(), target, :player} end)
    stub(StripCommon, :roll_success?, fn _level, _caster_dex, _target_dex -> true end)

    expect(PlayerSession, :strip_equip, fn target_pid, :right_hand, opts ->
      assert target_pid == self()
      assert opts == [duration: 80_001, val2: 0, caster_id: @caster_id, source_type: :mob]
      :ok
    end)

    assert {:ok, ^caster} =
             RgStripweapon.cast(
               caster,
               {:unit, {:player, @target_id}},
               1,
               definition(RgStripweapon)
             )
  end

  test "a failed roll leaves the target unchanged" do
    caster = player(@caster_id)
    target = player(@target_id)
    stub_stats(caster, target)
    stub(TargetResolver, :resolve, fn {:player, @target_id} -> {:ok, self(), target, :player} end)
    stub(StripCommon, :roll_success?, fn _level, _caster_dex, _target_dex -> false end)
    reject(&PlayerSession.strip_equip/3)
    reject(&StatusInterpreter.apply_status/4)

    assert {:ok, ^caster} =
             RgStripweapon.cast(
               caster,
               {:unit, {:player, @target_id}},
               2,
               definition(RgStripweapon)
             )
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

  defp player(id), do: %PlayerState{character_id: id}

  defp mob(id) do
    %MobState{
      instance_id: id,
      mob_id: 1_002,
      mob_data: %{},
      spawn_ref: nil,
      map_name: "prontera",
      x: 10,
      y: 10,
      hp: 100,
      max_hp: 100,
      sp: 100,
      max_sp: 100,
      spawned_at: 0
    }
  end
end
