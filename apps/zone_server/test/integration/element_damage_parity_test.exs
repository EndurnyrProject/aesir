defmodule Aesir.ZoneServer.Integration.ElementDamageParityTest do
  @moduledoc """
  Where real hits take their attribute steps, observed through Fiber Lock webs: every
  fire attribute step burns one web. A renewal player's weapon hit steps each weapon
  and equipment component of both hands; a classic weapon hit and a bolt hit step once.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  import Aesir.ZoneServer.HwProfessorFixture

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage, as: SkillUnitStorage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @professor 4017
  @fire_bolt 19

  setup do
    on_exit(&ClusterTestHelper.clear_all/0)
    :ok
  end

  defp web_mob(webs) do
    mob = start_target({151, 150})
    now = System.monotonic_time(:millisecond)

    groups =
      for index <- 1..webs do
        gid = System.unique_integer([:positive])

        :ok =
          SkillUnitStorage.insert(%Group{
            group_id: gid,
            skill_id: 405,
            skill_name: :pf_spiderweb,
            level: 1,
            caster_id: 1,
            caster_type: :player,
            map_name: map(),
            center: {151, 150},
            cells: [{151, 150}],
            next_tick_at: nil,
            expires_at: now + 60_000 + index * 1_000,
            interval: 1_000,
            state: %{}
          })

        gid
      end

    :ok =
      StatusInterpreter.apply_status(:mob, mob.unit_id, :sc_spiderweb,
        duration: 60_000,
        state: %{groups: groups},
        bypass_resistance: true
      )

    mob
  end

  defp webs(mob) do
    case StatusStorage.get_status(:mob, mob.unit_id, :sc_spiderweb) do
      %{state: %{groups: groups}} -> length(groups)
      nil -> 0
    end
  end

  test "a fire weapon hit burns one web per fire attribute step" do
    attacker = start_caster(@professor, %{})
    :ok = PlayerSession.apply_status(attacker.pid, :sc_fireweapon, val1: 1, duration: 60_000)
    mob = web_mob(3)

    stats = PlayerSession.get_current_stats(attacker.pid)
    player = get_player_state(attacker.pid)
    _ = Combat.execute_attack(stats, player, mob.unit_id)

    # Renewal steps weapon and equipment ATK of both hands with the endowed fire
    # element, four fire steps for three webs; classic steps the hit once.
    expected = if GameMode.mode() == :renewal, do: 0, else: 2
    assert eventually(fn -> webs(mob) == expected end)
  end

  test "a multi-hit fire bolt takes one attribute step for all its hits" do
    professor = start_caster(@professor, %{"#{@fire_bolt}" => 3})
    mob = web_mob(2)

    assert eventually(fn ->
             PlayerState.act_ready?(
               get_player_state(professor.pid),
               System.monotonic_time(:millisecond)
             )
           end)

    cast(professor, @fire_bolt, 3, mob.unit_id)

    assert eventually(fn -> webs(mob) == 1 end, 8_000)
  end
end
