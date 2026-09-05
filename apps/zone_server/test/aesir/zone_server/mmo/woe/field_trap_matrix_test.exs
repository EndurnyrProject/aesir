defmodule Aesir.ZoneServer.Mmo.Woe.FieldTrapMatrixTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skills.Alchemist.AmDemonstration
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtAnklesnare
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtBlastmine
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtClaymoretrap
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtFlasher
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtFreezingtrap
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtLandmine
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtSandman
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtShockwave
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtSkidtrap
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.Trap
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @traps [
    {HtSkidtrap, :ht_skidtrap, 115, {:status, :sc_stop}},
    {HtLandmine, :ht_landmine, 116, {:damage_status, :sc_stun}},
    {HtAnklesnare, :ht_anklesnare, 117, {:status, :sc_anklesnare}},
    {HtShockwave, :ht_shockwave, 118, :sp},
    {HtSandman, :ht_sandman, 119, {:status, :sc_sleep}},
    {HtFlasher, :ht_flasher, 120, {:status, :sc_blind}},
    {HtFreezingtrap, :ht_freezingtrap, 121, {:damage_status, :sc_freeze}},
    {HtBlastmine, :ht_blastmine, 122, :damage},
    {HtClaymoretrap, :ht_claymoretrap, 123, :damage}
  ]

  setup do
    :ok = MapFlags.reload()
    Mimic.copy(HitCalculations)
    stub(Resistance, :roll_success, fn _chance -> true end)
    stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)
    :ok
  end

  for {module, skill_name, skill_id, effect} <- @traps do
    @module module
    @skill_name skill_name
    @skill_id skill_id
    @effect effect

    test "#{skill_name} applies its real effect to friendly and enemy players in active versus" do
      caster = player(13_001, {140, 140}, party_id: 7)
      friendly = player(13_002, {150, 150}, party_id: 7)
      enemy = player(13_003, {160, 160}, party_id: 8)

      :ok = MapFlags.set_runtime("prontera", :pvp, true)

      for target <- [friendly, enemy] do
        target_ref = {:player, target.character.id}
        target_position = target.position
        group = trap_group(@skill_name, @skill_id, caster.character.id, target_position)
        before = get_player_state(target.pid)

        assert triggered?(@module.on_touch(group, target_ref))
        assert_effect(@effect, target, before)
      end
    end
  end

  test "Demonstration damages friendly and enemy players on the same active field tick" do
    caster = player(13_011, {150, 150}, party_id: 7, str: 80, dex: 80)
    friendly = player(13_012, {151, 150}, party_id: 7)
    enemy = player(13_013, {150, 151}, party_id: 8)
    group = group(:am_demonstration, 229, caster.character.id, {150, 150})
    friendly_hp = hp(friendly)
    enemy_hp = hp(enemy)

    :ok = MapFlags.set_runtime("prontera", :pvp, true)

    assert {:ok, %Group{}} = AmDemonstration.on_interval(group, 500)
    assert_eventually(fn -> hp(friendly) < friendly_hp and hp(enemy) < enemy_hp end)
  end

  test "Quagmire applies support to friendly and enemy players in its active field" do
    caster = player(13_021, {150, 150}, guild_id: 7)
    friendly = player(13_022, {151, 150}, guild_id: 7)
    enemy = player(13_023, {150, 151}, guild_id: 8)
    group = live_quagmire_group(caster.character.id, [friendly.position, enemy.position])

    :ok = MapFlags.set_runtime("prontera", :gvg, true)
    assert :ok = Manager.register(group)
    assert :ok = Manager.trigger(group.group_id, {:player, friendly.character.id}, :on_touch)
    assert :ok = Manager.trigger(group.group_id, {:player, enemy.character.id}, :on_touch)

    assert StatusStorage.has_status?(:player, friendly.character.id, :sc_quagmire)
    assert StatusStorage.has_status?(:player, enemy.character.id, :sc_quagmire)
  end

  test "off-hours castle, PvE, and mob-owned trap contact keep their prior hostility" do
    caster = player(13_031, {150, 150}, party_id: 7)
    friendly = player(13_032, {151, 150}, party_id: 7)
    mob = start_mob_session(unit_id: 13_033, position: {152, 150}, hp: 1_000, max_hp: 1_000)
    group = trap_group(:ht_landmine, 116, caster.character.id, friendly.position)

    refute Trap.enemy?(group, {:player, friendly.character.id})
    assert Trap.enemy?(group, {:mob, mob.unit_id})

    :ok = MapFlags.set_runtime("prontera", :gvg_castle, true)
    refute Trap.enemy?(group, {:player, friendly.character.id})
    assert Trap.enemy?(group, {:mob, mob.unit_id})

    mob_group = %{group | caster_type: :mob, caster_id: mob.unit_id}
    assert Trap.enemy?(mob_group, {:player, friendly.character.id})
    refute Trap.enemy?(mob_group, {:mob, mob.unit_id})
  end

  test "Skid Trap may trigger in an active castle but central ground immunity blocks movement" do
    caster = player(13_041, {150, 150}, party_id: 7)
    friendly = player(13_042, {151, 150}, party_id: 7)
    group = trap_group(:ht_skidtrap, 115, caster.character.id, friendly.position)

    :ok = MapFlags.set_runtime("prontera", :gvg_castle, true)
    :ok = MapFlags.set_runtime("prontera", :gvg, true)

    assert triggered?(HtSkidtrap.on_touch(group, {:player, friendly.character.id}))
    assert StatusStorage.has_status?(:player, friendly.character.id, :sc_stop)
    assert_eventually(fn -> position(friendly) == friendly.position end)
  end

  defp player(id, position, opts) do
    player =
      start_player_session(
        id: id,
        account_id: id,
        name: "Trap#{id}",
        position: position,
        hp: 5_000,
        max_hp: 5_000,
        sp: 1_000,
        max_sp: 1_000,
        str: Keyword.get(opts, :str, 20),
        agi: 1,
        vit: 0,
        dex: Keyword.get(opts, :dex, 20),
        luk: 0
      )

    :sys.replace_state(player.pid, fn session ->
      game_state = %{
        session.game_state
        | party_id: Keyword.get(opts, :party_id, 0),
          guild_id: Keyword.get(opts, :guild_id, 0)
      }

      %{session | game_state: game_state}
    end)

    :ok = UnitRegistry.update_unit_state(:player, id, get_player_state(player.pid))
    player
  end

  defp trap_group(skill_name, skill_id, caster_id, center) do
    group = group(skill_name, skill_id, caster_id, center)
    state = Trap.place_state(1, %{dex: 20, int: 20, base_level: 50}, group)
    %{group | origin: {elem(center, 0) - 1, elem(center, 1)}, state: state}
  end

  defp live_quagmire_group(caster_id, cells) do
    now = System.monotonic_time(:millisecond)

    :wz_quagmire
    |> group(92, caster_id, {150, 150})
    |> Map.merge(%{
      cells: cells,
      created_at: now,
      next_tick_at: now + 1_000,
      expires_at: now + 10_000,
      interval: 1_000
    })
  end

  defp group(skill_name, skill_id, caster_id, center) do
    %Group{
      group_id: System.unique_integer([:positive]),
      skill_name: skill_name,
      skill_id: skill_id,
      level: 1,
      caster_type: :player,
      caster_id: caster_id,
      map_name: "prontera",
      center: center,
      cells: [center],
      state: %{}
    }
  end

  defp triggered?(:expire), do: true
  defp triggered?({:expire, _commands}), do: true
  defp triggered?({:ok, %Group{target_id: target_id}}) when not is_nil(target_id), do: true
  defp triggered?(_result), do: false

  defp assert_effect({:status, status}, target, _before) do
    assert StatusStorage.has_status?(:player, target.character.id, status)
  end

  defp assert_effect({:damage_status, status}, target, before) do
    assert_eventually(fn -> hp(target) < before.stats.current_state.hp end)
    assert StatusStorage.has_status?(:player, target.character.id, status)
  end

  defp assert_effect(:damage, target, before) do
    assert_eventually(fn -> hp(target) < before.stats.current_state.hp end)
  end

  defp assert_effect(:sp, target, before) do
    assert_eventually(fn -> sp(target) < before.stats.current_state.sp end)
  end

  defp hp(player), do: get_player_state(player.pid).stats.current_state.hp
  defp sp(player), do: get_player_state(player.pid).stats.current_state.sp
  defp position(player), do: {get_player_state(player.pid).x, get_player_state(player.pid).y}
end
