defmodule Aesir.ZoneServer.Script.VitalityPotionsTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    stub(CharacterPersistence, :update_stats, fn _, _, _ -> :ok end)

    player =
      PlayerState.new(%Character{
        id: 34_100,
        account_id: 34_100,
        name: "Vitality",
        class: 0,
        base_level: 99,
        job_level: 1,
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        hp: 1,
        sp: 1,
        last_map: "prontera",
        last_x: 150,
        last_y: 150
      })

    :ok = UnitRegistry.register_unit(:player, player.character_id, PlayerState, player, self())
    state = %SessionState{game_state: player, connection_pid: self()}
    %{ctx: Ctx.from_session(state, {:item, 12422})}
  end

  test "a status start updates the inline maximum before the following percentage heal", %{
    ctx: ctx
  } do
    old_max = ctx.game_state.stats.derived_stats.max_hp
    updated = Dsl.sc_start(ctx, :sc_promote_health_reserch, 500_000, [1, 1, 0, 0])
    assert updated.game_state.stats.derived_stats.max_hp == old_max + 830
    assert updated.session_state.game_state == updated.game_state

    healed = Dsl.percent_heal(updated, hp: 1)
    assert healed.game_state.stats.current_state.hp == 1 + div(old_max + 830, 100)
  end
end
