defmodule Aesir.ZoneServer.Integration.HighWizardSkillsTest do
  @moduledoc "Real-session High Wizard coverage: Soul Drain, Gravitation Field and Ganbantein."
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  import Aesir.ZoneServer.HwProfessorFixture

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage, as: SkillUnitStorage
  alias Aesir.ZoneServer.Mmo.Skills.HighWizard.HwGanbantein
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @high_wizard 4010
  @cold_bolt 14
  @soul_drain 364
  @magic_power 366
  @gravitation 484
  @ganbantein 483

  setup do
    on_exit(&ClusterTestHelper.clear_all/0)
    :ok
  end

  test "Soul Drain refunds SP when a Cold Bolt kills a monster" do
    wizard = start_caster(@high_wizard, %{"#{@cold_bolt}" => 1, "#{@soul_drain}" => 10})
    mob = start_target({153, 150}, hp: 1, max_hp: 1, level: 50)
    before = sp(wizard)

    cast(wizard, @cold_bolt, 1, mob.unit_id)

    # 12 SP for the bolt, then 50 * (95 + 150) / 100 = 122 back from the kill.
    assert eventually(fn -> sp(wizard) == before - 12 + 122 end, 8_000)
  end

  @tag game_mode: :pre_renewal, integration_re: false
  test "a hit on the channelling High Wizard collapses the Gravitation Field" do
    wizard = start_caster(@high_wizard, %{"#{@gravitation}" => 1}, [{717, 1}])
    id = wizard.character.id

    cast_ground(wizard, @gravitation, 1, {155, 150})

    assert eventually(fn -> SkillUnitStorage.get_groups_by_caster(:player, id) != [] end, 8_000)
    assert %{state: %{self?: true}} = StatusStorage.get_status(:player, id, :sc_gravitation)

    PlayerSession.apply_damage(wizard.pid, 10)

    assert eventually(fn ->
             SkillUnitStorage.get_groups_by_caster(:player, id) == [] and
               not StatusStorage.has_status?(:player, id, :sc_gravitation)
           end)
  end

  @tag game_mode: :renewal, integration_pre_re: false
  test "renewal Gravitation Field bursts every enemy within two cells and places no field" do
    wizard = start_caster(@high_wizard, %{"#{@gravitation}" => 1})
    near = start_target({156, 150})
    edge = start_target({157, 152})
    outside = start_target({159, 150})

    cast_ground(wizard, @gravitation, 1, {155, 150})

    assert eventually(fn -> hp(near) < 100_000 and hp(edge) < 100_000 end, 8_000)
    assert hp(outside) == 100_000
    assert SkillUnitStorage.get_groups_by_caster(:player, wizard.character.id) == []
  end

  @tag game_mode: :pre_renewal, integration_re: false
  test "pre-renewal Mystical Amplification amplifies exactly the next offensive spell" do
    wizard = start_caster(@high_wizard, %{"#{@cold_bolt}" => 1, "#{@magic_power}" => 10})
    mob = start_target({153, 150})
    id = wizard.character.id
    base = matk(wizard)

    cast(wizard, @magic_power, 10)
    assert eventually(fn -> StatusStorage.has_status?(:player, id, :sc_magicpower) end, 8_000)
    assert matk(wizard) == base
    await_act(wizard)

    cast(wizard, @cold_bolt, 1, mob.unit_id)
    assert eventually(fn -> matk(wizard) == div(base * 150, 100) end)
    assert eventually(fn -> get_player_state(wizard.pid).casting == nil end, 8_000)
    await_act(wizard)

    cast(wizard, @cold_bolt, 1, mob.unit_id)
    assert eventually(fn -> not StatusStorage.has_status?(:player, id, :sc_magicpower) end)
    assert eventually(fn -> matk(wizard) == base end)
  end

  test "Ganbantein clears a trap under its area" do
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

    wizard = start_caster(@high_wizard, %{"#{@ganbantein}" => 1}, [{715, 1}, {717, 1}])
    Mimic.allow(HwGanbantein, self(), wizard.pid)
    owner = start_target({170, 170})
    trap = register_trap({156, 151}, owner.unit_id)

    cast_ground(wizard, @ganbantein, 1, {155, 150})

    assert eventually(fn -> SkillUnitStorage.get(trap) == nil end, 8_000)
  end

  defp sp(session), do: get_player_state(session.pid).stats.current_state.sp
  defp hp(mob), do: get_mob_state(mob.pid).hp
  defp matk(session), do: get_player_state(session.pid).stats.combat_stats.matk_max

  defp await_act(session) do
    assert eventually(
             fn ->
               PlayerState.act_ready?(
                 get_player_state(session.pid),
                 System.monotonic_time(:millisecond)
               )
             end,
             8_000
           )
  end
end
