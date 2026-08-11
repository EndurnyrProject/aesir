defmodule Aesir.ZoneServer.Mmo.Skill.InterpreterNpcCastTest do
  use ExUnit.Case, async: false

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Npc.SkillCaster
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @target_id 1_001

  setup :setup_ets_tables

  test "casts Heal on a registered player" do
    register_player()
    Phoenix.PubSub.subscribe(Aesir.PubSub, "player:#{@target_id}")

    caster = caster()

    assert {:ok, ^caster} = Interpreter.npc_cast(caster, :al_heal, 10, {:unit, @target_id})
    assert_receive {:combat, {:apply_heal, 1_145, 2_001}}
  end

  test "applies Increase AGI at its clamped maximum level" do
    register_player()
    caster = caster()

    assert {:ok, ^caster} = Interpreter.npc_cast(caster, :al_incagi, 99, {:unit, @target_id})

    assert %{val1: 10, val2: 12, source_id: 2_001} =
             StatusStorage.get_status(:player, @target_id, :sc_increaseagi)
  end

  test "rejects unavailable skill shapes and caster facilities" do
    caster = caster()

    assert {:error, :unknown_skill} =
             Interpreter.npc_cast(caster, :missing_skill, 1, {:unit, @target_id})

    assert {:error, :unknown_skill} =
             Interpreter.npc_cast(caster, 999_999, 1, {:unit, @target_id})

    assert {:error, :passive_skill} =
             Interpreter.npc_cast(caster, :mc_pushcart, 1, {:unit, @target_id})

    assert {:error, :unsupported_skill} =
             Interpreter.npc_cast(caster, :mg_thunderstorm, 1, {:unit, @target_id})

    assert {:error, :unsupported_skill} =
             Interpreter.npc_cast(caster, :mg_firebolt, 1, {:unit, @target_id})

    assert {:error, :missing_caster_facilities} =
             Interpreter.npc_cast(caster, :pr_strecovery, 1, {:unit, @target_id})
  end

  test "rejects an unsupported caster and invalid cast shape" do
    assert {:error, :unsupported_caster} =
             Interpreter.npc_cast(%{}, :al_heal, 1, {:unit, @target_id})

    assert {:error, :invalid_level} =
             Interpreter.npc_cast(caster(), :al_heal, 0, {:unit, @target_id})

    assert {:error, :invalid_level} = Interpreter.npc_cast(caster(), :al_heal, 1, :self)
  end

  defp caster, do: SkillCaster.new(2_001, 99, 60, {150, 150}, "prontera")

  defp register_player do
    player =
      %Character{
        id: @target_id,
        account_id: @target_id,
        name: "NpcCastTarget",
        last_map: "prontera",
        last_x: 150,
        last_y: 150,
        class: 0,
        base_level: 1,
        job_level: 1,
        sex: "M",
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1
      }
      |> PlayerState.new()

    :ok = UnitRegistry.register_unit(:player, @target_id, PlayerState, player, self())
  end

  defp setup_ets_tables(context), do: Aesir.TestEtsSetup.setup_ets_tables(context)
end
