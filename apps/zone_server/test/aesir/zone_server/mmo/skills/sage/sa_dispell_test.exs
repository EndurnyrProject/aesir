defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaDispellTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Guild.Relations
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skills.Sage.SaDispell
  alias Aesir.ZoneServer.Mmo.StatusEffect.Dispel
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context

  @target_id 2000

  defp caster, do: %PlayerState{character_id: 1000}

  defp definition do
    {:ok, definition} = Catalog.by_name(:sa_dispell)
    definition
  end

  describe "metadata" do
    @tag game_mode: :renewal
    test "matches the rAthena renewal table" do
      definition = definition()

      assert definition.max_level == 5
      assert definition.damage_type == :no_damage
      assert definition.range == 9
      assert definition.cast_time == List.duplicate(1_600, 5)
      assert definition.fixed_cast_time == List.duplicate(400, 5)
      assert definition.item_cost == [%{id: 715, amount: 1}]
    end

    @tag game_mode: :pre_renewal
    test "classic casts in 2 seconds" do
      definition = definition()
      assert definition.cast_time == List.duplicate(2_000, 5)
      assert definition.fixed_cast_time == []
      assert definition.item_cost == [%{id: 715, amount: 1}]
    end
  end

  describe "validate/4" do
    test "a player in an allied guild passes the relation check" do
      Mimic.copy(Relations)

      caster = %PlayerState{character_id: 1000, party_id: 0, guild_id: 5}
      target = %PlayerState{character_id: @target_id, party_id: 0, guild_id: 7}

      stub(UnitRegistry, :get_unit, fn :player, @target_id -> {:ok, {nil, target, self()}} end)
      stub(Relations, :friendly?, fn 5, 7 -> true end)

      assert :ok = SaDispell.validate(caster, {:unit, @target_id}, 1, definition())
    end

    test "a player who is neither a comrade nor an enemy fails" do
      Mimic.copy(Relations)

      caster = %PlayerState{character_id: 1000, party_id: 0, guild_id: 5}
      target = %PlayerState{character_id: @target_id, party_id: 0, guild_id: 7}

      stub(UnitRegistry, :get_unit, fn :player, @target_id -> {:ok, {nil, target, self()}} end)
      stub(Relations, :friendly?, fn _caster_guild, _target_guild -> false end)

      stub(Targeting, :validate_enemy_relation_allow_dead, fn _caster, _target ->
        {:error, :invalid_target}
      end)

      assert {:error, :invalid_target} =
               SaDispell.validate(caster, {:unit, @target_id}, 1, definition())
    end
  end

  describe "cast/5" do
    setup do
      Mimic.copy(Dispel)
      Mimic.copy(UnitRegistry)
      stub(UnitRegistry, :unit_exists?, fn :mob, _id -> false end)
      :ok
    end

    test "dispels the target when the roll succeeds" do
      test_pid = self()

      stub(Dispel, :dispel, fn target ->
        send(test_pid, {:dispelled, target})
        :ok
      end)

      # 50 + 10*3 = 80: a roll of 80 is the last success.
      assert {:ok, %PlayerState{}} =
               SaDispell.cast(caster(), {:unit, @target_id}, 3, definition(),
                 rng: fn 100 -> 80 end
               )

      assert_received {:dispelled, {:player, @target_id}}
    end

    test "does nothing when the roll fails" do
      reject(&Dispel.dispel/1)

      # 50 + 10*3 = 80: a roll of 81 is the first failure.
      assert {:ok, %PlayerState{}} =
               SaDispell.cast(caster(), {:unit, @target_id}, 3, definition(),
                 rng: fn 100 -> 81 end
               )
    end
  end
end
