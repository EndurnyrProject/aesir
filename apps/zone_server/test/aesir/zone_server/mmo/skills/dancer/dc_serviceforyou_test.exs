defmodule Aesir.ZoneServer.Mmo.Skills.Dancer.DcServiceForYouTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skills.Dancer.DcServiceForYou
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  Mimic.copy(PartyManager)

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Catalog.reload()
    :ok
  end

  test "definition matches the pinned Gypsy's Kiss table" do
    assert {:ok, DcServiceForYou} = Catalog.active_module_for(:dc_serviceforyou)
    assert {:ok, definition} = Catalog.by_id(330)

    assert definition.name == :dc_serviceforyou
    assert definition.display_name == "Gypsy's Kiss"
    assert definition.max_level == 10
    assert definition.target_type == :self
    assert definition.require_weapon == [:musical, :whip]
    assert definition.range == 15
    assert definition.duration == List.duplicate(180_000, 10)
    assert definition.sp_cost == Enum.to_list(60..87//3)
    assert definition.cast_time == List.duplicate(1_000, 10)
    assert definition.fixed_cast_time == List.duplicate(300, 10)
    assert definition.after_cast_delay == List.duplicate(300, 10)
    assert definition.cooldown == List.duplicate(20_000, 10)
  end

  test "completion snapshots the level as the Gypsy's Kiss status value" do
    caster = player()
    :ok = UnitRegistry.register_unit(:player, 1, PlayerState, caster, self())

    for level <- [1, 10] do
      assert {:ok, result} =
               DcServiceForYou.cast(caster, :self, level, DcServiceForYou.definition())

      assert %{val1: ^level} = status = StatusStorage.get_status(:player, 1, :sc_serviceforyou)
      assert status.expires_at - status.started_at == 180_000
      assert result.last_song == %{skill_id: 330, level: level}
    end
  end

  test "completion snapshots only living online nearby party members for the full duration" do
    caster = party_player(1, party_id: 10)
    nearby = party_player(2, x: 115, y: 115)

    for recipient <- [
          caster,
          nearby,
          party_player(3, x: 116),
          party_player(4, map: "geffen"),
          dead_party_player(5, x: 105),
          party_player(6, x: 105)
        ] do
      register(recipient)
    end

    stub(PartyManager, :get, fn 10 ->
      {:ok,
       %PartyState{
         party_id: 10,
         name: "Party",
         leader_char_id: 1,
         exp_share: false,
         members: %{
           1 => member(1),
           2 => member(2),
           3 => member(3),
           4 => member(4),
           5 => member(5),
           6 => %{member(6) | online: false},
           7 => member(7)
         }
       }}
    end)

    assert {:ok, _result} =
             DcServiceForYou.cast(caster, :self, 10, DcServiceForYou.definition())

    assert StatusStorage.has_status?(:player, 1, :sc_serviceforyou)

    assert %{expires_at: expires_at, started_at: started_at} =
             StatusStorage.get_status(:player, 2, :sc_serviceforyou)

    assert expires_at - started_at == 180_000

    for excluded_id <- 3..6 do
      refute StatusStorage.has_status?(:player, excluded_id, :sc_serviceforyou)
    end

    register(party_player(7, x: 105))
    refute StatusStorage.has_status?(:player, 7, :sc_serviceforyou)

    :ok = UnitRegistry.update_unit_state(:player, 2, %{nearby | x: 116})
    assert %{expires_at: ^expires_at} = StatusStorage.get_status(:player, 2, :sc_serviceforyou)
  end

  test "MaxSP increases by 10 percent at level 1 and 20 percent at level 10 through stats" do
    recipient = party_player(1, party_id: 0, class: 0, base_level: 50, job_level: 30)
    :ok = UnitRegistry.register_unit(:player, 1, PlayerState, recipient, self())
    baseline = Stats.calculate_stats(recipient.stats, 1, []).derived_stats.max_sp
    assert baseline == 66

    for {level, rate, expected_max_sp} <- [{1, 10, 72}, {10, 20, 79}] do
      :ok =
        StatusInterpreter.apply_status(:player, 1, :sc_serviceforyou,
          val1: level,
          caster_id: 1,
          duration: 180_000
        )

      boosted = Stats.calculate_stats(recipient.stats, 1, []).derived_stats.max_sp
      assert boosted == expected_max_sp
      assert boosted == trunc(baseline * (100 + rate) / 100)

      :ok = StatusInterpreter.remove_status(:player, 1, :sc_serviceforyou)
    end
  end

  test "a recipient pays reduced SP for an ordinary skill through the generic cost pipeline" do
    caster = player()
    :ok = UnitRegistry.register_unit(:player, 1, PlayerState, caster, self())

    for {level, expected_cost} <- [{1, 42}, {10, 38}] do
      :ok =
        StatusInterpreter.apply_status(:player, 1, :sc_serviceforyou,
          val1: level,
          caster_id: 1,
          duration: 180_000
        )

      assert {:ok, cast} = Interpreter.cast(cast_state(), 29, 10, :self)
      assert 100 - cast.stats.current_state.sp == expected_cost

      :ok = StatusInterpreter.remove_status(:player, 1, :sc_serviceforyou)
      :ok = StatusInterpreter.remove_status(:player, 1, :sc_increaseagi)
    end
  end

  defp cast_state do
    %{
      character_id: 1,
      x: 100,
      y: 100,
      map_name: "prontera",
      skill_cooldowns: %{},
      act_delay_until: 0,
      stats: %{
        base_stats: %{dex: 1, int: 1},
        current_state: %{sp: 100, hp: 100},
        derived_stats: %{max_sp: 200, max_hp: 100},
        progression: %{learned_skills: %{29 => 10}}
      }
    }
  end

  defp party_player(id, opts) do
    %Character{
      id: id,
      account_id: id,
      name: "Player#{id}",
      last_map: Keyword.get(opts, :map, "prontera"),
      last_x: Keyword.get(opts, :x, 100),
      last_y: Keyword.get(opts, :y, 100),
      class: Keyword.get(opts, :class, 20),
      base_level: Keyword.get(opts, :base_level, 100),
      job_level: Keyword.get(opts, :job_level, 50),
      sex: "F",
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
      party_id: Keyword.get(opts, :party_id, 10)
    }
    |> PlayerState.new()
  end

  defp dead_party_player(id, opts) do
    state = party_player(id, opts)
    put_in(state.stats.current_state.hp, 0)
  end

  defp register(state) do
    :ok = UnitRegistry.register_unit(:player, state.character_id, PlayerState, state, self())
  end

  defp member(id), do: Member.new(id, "Player#{id}", 100, true, "prontera")

  defp player do
    %Character{
      id: 1,
      account_id: 1,
      name: "Dancer",
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
      class: 20,
      base_level: 100,
      job_level: 50,
      sex: "F",
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
      party_id: 0
    }
    |> PlayerState.new()
  end
end
