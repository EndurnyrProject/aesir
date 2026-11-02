defmodule Aesir.ZoneServer.Mmo.Skill.ItemAuthorizedLevelTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Unit.Player.Handlers.ScriptEffectHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.SkillRequest
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule AuthorizedSkill do
    @behaviour Aesir.ZoneServer.Mmo.Skill.Active

    @impl true
    def cast(caster, :self, level, definition) do
      send(self(), {:item_level, level, Enum.at(definition.duration, level - 1)})
      {:ok, caster}
    end

    @impl true
    def validate(_caster, _target, _level, _definition), do: :ok
  end

  setup :set_mimic_private
  setup :verify_on_exit!
  setup :setup_ets_tables

  setup do
    character = %Character{
      id: 7_705,
      account_id: 7_705,
      name: "Item level",
      class: 0,
      base_level: 1,
      job_level: 1,
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      hp: 40,
      sp: 11,
      last_map: "prontera",
      last_x: 100,
      last_y: 100
    }

    player = PlayerState.new(character)
    :ok = UnitRegistry.register_player(player, self())

    definition = %Definition{
      id: 693,
      name: :test_item_authorized_level,
      display_name: "Authorized item level",
      max_level: 1,
      target_type: :self,
      damage_kind: :none,
      duration: List.duplicate(0, 5),
      cooldown: List.duplicate(300_000, 5)
    }

    stub(Catalog, :by_id, fn 693 -> {:ok, definition} end)

    stub(Catalog, :active_module_for, fn :test_item_authorized_level -> {:ok, AuthorizedSkill} end)

    %{player: player}
  end

  test "item script staging preserves the trusted over-max level before client selection", %{
    player: player
  } do
    state = %SessionState{game_state: player, connection_pid: self()}

    assert {{:ok, ^player}, staged} =
             ScriptEffectHandler.apply_op({:stage_item_skill, 693, 5}, state)

    assert staged.pending_item_skill == %{skill_id: 693, level: 5, keep_requirement?: false}

    for level <- [0, -1] do
      assert {{:error, :invalid_level}, ^state} =
               ScriptEffectHandler.apply_op({:stage_item_skill, 693, level}, state)
    end

    assert {:error, :invalid_level} = Interpreter.preflight_skill(player, 693, 5)
  end

  test "trusted over-max item casts keep scalar cooldowns with either requirement policy", %{
    player: player
  } do
    {:ok, definition} = Catalog.by_id(693)
    stub(Catalog, :by_id, fn 693 -> {:ok, %{definition | cooldown: [300_000]}} end)

    for keep? <- [false, true] do
      before = System.monotonic_time(:millisecond)

      assert {:instant, cast} =
               Interpreter.begin_item_cast(
                 player,
                 693,
                 5,
                 :self,
                 fn caster -> {:ok, caster} end,
                 keep?
               )

      after_cast = System.monotonic_time(:millisecond)
      assert is_integer(cast.skill_cooldowns[693])
      assert cast.skill_cooldowns[693] >= before + 300_000
      assert cast.skill_cooldowns[693] <= after_cast + 300_000
    end
  end

  test "trusted item casts retain levels beyond metadata maximum", %{player: player} do
    assert {:ok, cast} = Interpreter.item_cast(player, 693, 5, :self)
    assert_receive {:item_level, 5, 0}
    assert cast.skill_cooldowns[693] > System.monotonic_time(:millisecond)
  end

  test "staged item level wins over client input without relaxing normal casts", %{player: player} do
    state = %SessionState{
      game_state: player,
      connection_pid: self(),
      pending_item_skill: %{skill_id: 693, level: 5}
    }

    now = System.monotonic_time(:millisecond)

    for client_level <- [0, 1, 99] do
      assert {:use, %{origin: :item, level: 5}} =
               SkillRequest.targeted(state, 693, client_level, player.character_id, now)
    end

    assert {:error, :invalid_level} = Interpreter.preflight_skill(player, 693, 5)

    for invalid <- [0, -1, :invalid] do
      assert {:error, :invalid_level} = Interpreter.item_cast(player, 693, invalid, :self)
    end

    assert {:error, :invalid_level} = Interpreter.complete_item_cast(player, 693, 0, :self)
  end

  test "item begin and completion retain the level and pre-claim cooldown refusal", %{
    player: player
  } do
    assert {:instant, cast} =
             Interpreter.begin_item_cast(player, 693, 5, :self, fn caster ->
               send(self(), :item_claimed)
               {:ok, caster}
             end)

    assert_receive :item_claimed
    assert_receive {:item_level, 5, 0}
    assert cast.stats.current_state.sp == player.stats.current_state.sp

    assert {:error, _reason} =
             Interpreter.begin_item_cast(cast, 693, 5, :self, fn _caster ->
               flunk("cooldown refusal claimed another item")
             end)

    assert {:ok, _cast} = Interpreter.complete_item_cast(player, 693, 5, :self)
    assert_receive {:item_level, 5, 0}
  end
end
