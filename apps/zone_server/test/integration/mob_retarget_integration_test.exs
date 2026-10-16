defmodule Aesir.ZoneServer.Integration.MobRetargetIntegrationTest do
  @moduledoc """
  A hit monster retargets its last attacker after the hit's walk delay, through
  its own session's attacked event, as far as its skill state lets it.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.ZoneServer.Unit.Mob.MobSession

  @normal_attack %{
    dmg_type: :physical,
    is_short: true,
    element: :neutral,
    skill_id: nil,
    skill_level: nil,
    basic_attack?: true,
    weapon_attack?: true,
    div: 1
  }

  test "the latest attacker, not the top damage dealer, becomes the target after the walk delay" do
    {first, second, mob} = arrange([:can_move, :can_attack, :change_target_melee])

    MobSession.apply_damage(mob.pid, 50, first, @normal_attack)
    assert get_mob_state(mob.pid).target_ref == nil
    assert_eventually(fn -> get_mob_state(mob.pid).target_ref == first end)

    MobSession.apply_damage(mob.pid, 10, second, @normal_attack)
    assert_eventually(fn -> get_mob_state(mob.pid).target_ref == second end)
  end

  test "a mob in its attack state without change_target_melee keeps its target" do
    {first, second, mob} = arrange([:can_move, :can_attack])

    MobSession.apply_damage(mob.pid, 50, first, @normal_attack)
    assert_eventually(fn -> get_mob_state(mob.pid).target_ref == first end)

    MobSession.apply_damage(mob.pid, 10, second, @normal_attack)
    # The event fires after the mob's 400 ms damage motion.
    Process.sleep(450)
    assert_eventually(fn -> get_mob_state(mob.pid).attacked_ref == nil end)
    assert get_mob_state(mob.pid).target_ref == first
  end

  defp arrange(modes) do
    first = start_player_session(id: 8_801, position: {150, 151}, map_name: "prontera")
    second = start_player_session(id: 8_802, position: {151, 151}, map_name: "prontera")

    mob =
      start_mob_session(
        map_name: "prontera",
        position: {151, 150},
        max_hp: 10_000,
        atk: 1,
        atk2: 1,
        modes: modes,
        awake: true
      )

    on_exit(fn -> end_mob_session(mob) end)

    {{:player, first.character.id}, {:player, second.character.id}, mob}
  end
end
