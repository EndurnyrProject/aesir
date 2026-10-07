defmodule Aesir.ZoneServer.Integration.GravitationDamageParityTest do
  @moduledoc """
  Real-session pre-renewal Gravitation Field damage restriction: while a High
  Wizard channels their own field, no other skill of theirs deals damage. The
  field's own ticks and an equipment proc running under the autocast flag are
  exempt; an ordinary cast still spends its SP, a status Autospell still pays
  its charge, and a Double Casting echo fired later is gated afresh.
  """
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log
  @moduletag game_mode: :pre_renewal
  @moduletag integration_re: false

  import Aesir.ZoneServer.HwProfessorFixture

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @high_wizard 4010
  @cold_bolt 14
  @gravitation 484
  @blue_gemstone 717
  @full_hp 100_000

  setup do
    on_exit(&ClusterTestHelper.clear_all/0)
    :ok
  end

  defp channel(wizard) do
    :ok =
      StatusStorage.apply_status(:player, wizard.character.id, :sc_gravitation,
        val1: 1,
        state: %{self?: true}
      )
  end

  defp sp(session), do: get_player_state(session.pid).stats.current_state.sp
  defp hp(mob), do: get_mob_state(mob.pid).hp

  defp attack_motion_ms(session) do
    aspd = get_player_state(session.pid).stats.derived_stats.aspd
    max((200 - aspd) * 10, 0)
  end

  test "an ordinary cast deals no damage but spends its SP" do
    wizard = start_caster(@high_wizard, %{"#{@cold_bolt}" => 1})
    mob = start_target({153, 150})
    channel(wizard)
    before = sp(wizard)

    cast(wizard, @cold_bolt, 1, mob.unit_id)

    assert eventually(fn -> sp(wizard) == before - 12 end, 8_000)
    assert hp(mob) == @full_hp
  end

  test "the field's own ticks still damage the units it holds" do
    wizard = start_caster(@high_wizard, %{"#{@gravitation}" => 1}, [{@blue_gemstone, 1}])
    mob = start_target({153, 150})
    id = wizard.character.id

    cast_ground(wizard, @gravitation, 1, {153, 150})

    assert eventually(fn -> hp(mob) < @full_hp end, 12_000)
    assert %{state: %{self?: true}} = StatusStorage.get_status(:player, id, :sc_gravitation)
  end

  test "an equipment proc lands under the autocast flag, its Double Casting echo does not" do
    wizard = start_caster(@high_wizard, %{})
    mob = start_target({153, 150})
    channel(wizard)

    :ok =
      StatusStorage.apply_status(:player, wizard.character.id, :sc_doublecast,
        val1: 7,
        state: %{chance: 100}
      )

    GenServer.cast(wizard.pid, {:skill, {:proc_cast, @cold_bolt, 1, {:unit, mob.unit_id}}})

    assert eventually(fn -> hp(mob) < @full_hp end)
    after_proc = hp(mob)

    refute eventually(fn -> hp(mob) < after_proc end, attack_motion_ms(wizard) + 500)
  end

  test "a status Autospell pays its charge without an exemption" do
    wizard = start_caster(@high_wizard, %{})
    mob = start_target({153, 150})
    channel(wizard)
    before = sp(wizard)

    GenServer.cast(wizard.pid, {:skill, {:auto_cast, @cold_bolt, 1, {:unit, mob.unit_id}}})

    assert eventually(fn -> sp(wizard) == before - 8 end)
    assert hp(mob) == @full_hp
  end
end
