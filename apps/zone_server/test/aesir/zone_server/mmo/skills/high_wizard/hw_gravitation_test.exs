defmodule Aesir.ZoneServer.Mmo.Skills.HighWizard.HwGravitationTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skills.HighWizard.HwGravitation
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private

  setup do
    Mimic.copy(SkillAttack)
    Mimic.copy(Storage)
    :ok
  end

  defp player do
    PlayerState.new(%Character{
      id: 1001,
      account_id: 1001,
      name: "HighWizard",
      class: 4010,
      sex: "M",
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
      base_level: 99,
      hp: 100,
      sp: 100
    })
  end

  defp group(level) do
    %Group{
      group_id: 77,
      skill_id: 484,
      skill_name: :hw_gravitation,
      level: level,
      caster_id: 1001,
      caster_type: :player,
      map_name: "prontera",
      center: {110, 100},
      cells: [],
      next_tick_at: 0,
      expires_at: 0,
      interval: 1_000,
      state: %{}
    }
  end

  defp cast(caster, level),
    do: HwGravitation.cast(caster, {:ground, 110, 100}, level, HwGravitation.definition())

  @tag game_mode: :renewal
  test "renewal bursts 2 hits per level in radius 2 with line of sight and places nothing" do
    caster = player()
    reject(&Unit.place/4)

    expect(Combat, :execute_magic_splash, fn ^caster, {110, 100}, 2, opts ->
      assert opts[:hit_count] == 6
      assert opts[:skill_ratio] == 300
      assert opts[:element] == :neutral
      assert opts[:line_of_sight]
      []
    end)

    assert {:ok, ^caster} = cast(caster, 3)
  end

  @tag game_mode: :renewal
  test "renewal bursts nothing when the target cell is under Land Protector" do
    caster = player()
    stub(Storage, :land_protected?, fn "prontera", 110, 100 -> true end)
    reject(&Combat.execute_magic_splash/4)

    assert {:ok, ^caster} = cast(caster, 3)
  end

  @tag game_mode: :pre_renewal
  test "pre-renewal places the field and binds the caster's own status to it" do
    caster = player()
    reject(&Combat.execute_magic_splash/4)
    expect(Unit, :place, fn ^caster, :hw_gravitation, 3, {110, 100} -> {:ok, group(3)} end)

    expect(StatusInterpreter, :apply_status, fn :player, 1001, :sc_gravitation, params ->
      assert params[:val1] == 3
      assert params[:duration] == 7_000
      assert params[:state] == %{self?: true, group_id: 77}
      :ok
    end)

    assert {:ok, ^caster} = cast(caster, 3)
  end

  test "on_place covers a 5x5 field ticking every second for 4 s plus 1 s per level" do
    assert {:ok, placement} = HwGravitation.on_place(group(4))

    assert length(placement.cells) == 25
    assert placement.interval == 1_000
    assert placement.duration == 8_000
  end

  test "the Emperium takes a flat 400 per tick" do
    emperium = struct(MobState, mob_id: 1288, instance_id: 77)
    stub(UnitRegistry, :get_unit, fn :mob, 77 -> {:ok, {MobState, emperium, self()}} end)

    assert HwGravitation.tick_damage({:mob, 77}, 5) == 400
  end

  test "each interval deals 200 + 200 per level fixed misc damage to every enemy inside" do
    caster = player()
    test_pid = self()

    stub(UnitRegistry, :get_unit, fn
      :player, 1001 -> {:ok, {PlayerState, caster, self()}}
      _type, _id -> {:error, :not_found}
    end)

    stub(Combat, :splash_targets, fn "prontera", {110, 100}, 2, _caster ->
      [{:mob, 5}, {:player, 6}]
    end)

    stub(SkillAttack, :execute_misc_attack, fn ^caster, ref, opts ->
      send(
        test_pid,
        {:hit, ref, opts[:base_damage], opts[:ignore_element] and opts[:bypass_reductions]}
      )

      :ok
    end)

    assert {:ok, _group} = HwGravitation.on_interval(group(2), 0)

    assert_received {:hit, {:mob, 5}, 600, true}
    assert_received {:hit, {:player, 6}, 600, true}
  end
end
