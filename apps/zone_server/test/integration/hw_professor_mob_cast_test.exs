defmodule Aesir.ZoneServer.Integration.HwProfessorMobCastTest do
  @moduledoc "Real mob-skill dispatch of Ganbantein and Fiber Lock in both modes."
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  import Aesir.ZoneServer.HwProfessorFixture

  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage, as: SkillUnitStorage
  alias Aesir.ZoneServer.Mmo.Skills.HighWizard.HwGanbantein
  alias Aesir.ZoneServer.Mmo.StatusStorage

  test "a mob Ganbantein row clears a trap around its target" do
    Mimic.copy(HwGanbantein)

    stub(HwGanbantein, :cast, fn caster, target, level, definition ->
      Mimic.call_original(HwGanbantein, :cast, [
        caster,
        target,
        level,
        definition,
        [rng: fn 100 -> 1 end]
      ])
    end)

    player = start_player_session(id: 99_201, base_level: 99, position: {155, 150})
    on_exit(fn -> if Process.alive?(player.pid), do: end_player_session(player) end)

    mob = start_target({150, 150})
    trap = register_trap({156, 150}, mob.unit_id)

    MobSession.set_target(mob.pid, {:player, player.character.id})
    row = %{skill: "HW_GANBANTEIN", skill_id: 483, level: 1, target: :target}

    assert :ok = Executor.execute(get_mob_state(mob.pid), row)
    assert eventually(fn -> SkillUnitStorage.get(trap) == nil end)
  end

  test "a mob Fiber Lock row webs its player target" do
    player = start_player_session(id: 99_202, base_level: 99, position: {155, 150})
    on_exit(fn -> if Process.alive?(player.pid), do: end_player_session(player) end)

    mob = start_target({150, 150})
    MobSession.set_target(mob.pid, {:player, player.character.id})
    row = %{skill: "PF_SPIDERWEB", skill_id: 405, level: 1, target: :target}

    assert :ok = Executor.execute(get_mob_state(mob.pid), row)

    assert eventually(fn ->
             StatusStorage.has_status?(:player, player.character.id, :sc_spiderweb)
           end)

    assert [_web] = SkillUnitStorage.get_groups_by_caster(:mob, mob.unit_id)
  end
end
