defmodule Aesir.ZoneServer.Integration.CastCompletionStatusIntegrationTest do
  @moduledoc """
  A status that lands while a player casts never cancels the cast; the cast is
  judged when its bar completes. Stun fails only a damage cast, silently and
  without spending SP; a support cast still completes, and silence stops
  nothing already under way.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  import Aesir.ZoneServer.HwProfessorFixture

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Net.SkillCastFailed
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @mage 2
  @acolyte 4
  @fire_bolt 19
  @increase_agi 29

  setup do
    on_exit(&ClusterTestHelper.clear_all/0)
    :ok
  end

  defp casting?(session), do: get_player_state(session.pid).casting != nil
  defp sp(session), do: get_player_state(session.pid).stats.current_state.sp
  defp mob_hp(mob), do: get_mob_state(mob.pid).hp

  defp start_bolt(status) do
    mage = start_caster(@mage, %{"#{@fire_bolt}" => 3}, [], %{dex: 1, int: 1})
    on_exit(fn -> StatusStorage.clear_unit_statuses(:player, mage.character.id) end)
    mob = start_target({151, 150})
    flush_packets()

    cast(mage, @fire_bolt, 3, mob.unit_id)
    assert eventually(fn -> casting?(mage) end)
    :ok = StatusStorage.apply_status(:player, mage.character.id, status, duration: 60_000)
    {mage, mob}
  end

  test "a stun landing mid-cast fails the bolt silently at its end, spending nothing" do
    {mage, mob} = start_bolt(:sc_stun)
    sp_before = sp(mage)

    assert eventually(fn -> not casting?(mage) end, 8_000)
    assert mob_hp(mob) == 100_000
    assert sp(mage) == sp_before
    assert collect_packets_of_type(SkillCastFailed) == []
  end

  test "a silence landing mid-cast lets the bolt complete" do
    {mage, mob} = start_bolt(:sc_silence)

    assert eventually(fn -> mob_hp(mob) < 100_000 end, 8_000)
    refute casting?(mage)
  end

  test "a stun landing mid-cast lets a support cast complete" do
    acolyte = start_caster(@acolyte, %{"#{@increase_agi}" => 1}, [], %{dex: 1, int: 1})
    id = acolyte.character.id
    on_exit(fn -> StatusStorage.clear_unit_statuses(:player, id) end)

    cast(acolyte, @increase_agi, 1)
    assert eventually(fn -> casting?(acolyte) end)
    :ok = StatusStorage.apply_status(:player, id, :sc_stun, duration: 60_000)

    assert eventually(fn -> StatusStorage.has_status?(:player, id, :sc_increaseagi) end, 8_000)
  end
end
