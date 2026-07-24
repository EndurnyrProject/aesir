defmodule Aesir.ZoneServer.Unit.Player.Handlers.ScriptEffectHandlerFalconTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup
  import Bitwise

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtFalcon
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.ScriptEffectHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  @char_id 8003
  @falcon_bit Option.id(:falcon)
  @riding_bit Option.id(:riding)
  @ht_falcon_id HtFalcon.definition().id

  setup do
    stub(UnitRegistry, :get_unit_info, fn _unit_type, unit_id ->
      {:ok,
       %{
         unit_id: unit_id,
         unit_type: :player,
         race: :human,
         element: :neutral,
         element_level: 1,
         boss_flag: false,
         size: :medium,
         stats: %{level: 50, base_level: 50, str: 10, agi: 10, vit: 10, int: 10, dex: 10, luk: 10}
       }}
    end)

    stub(UnitRegistry, :update_unit_state, fn :player, @char_id, _gs -> :ok end)

    stub(SpatialIndex, :get_unit_position, fn :player, @char_id ->
      {:ok, {150, 150, "prontera"}}
    end)

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet, _opts -> :ok end)
    :ok
  end

  defp state(opts) do
    learned_skills =
      if Keyword.get(opts, :falconry_level, 1) > 0,
        do: %{@ht_falcon_id => Keyword.get(opts, :falconry_level, 1)},
        else: %{}

    character = %Character{
      id: @char_id,
      account_id: 3000,
      name: "Hunty",
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      sex: "M",
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
      base_level: 50,
      job_level: 50,
      class: 11,
      hp: 800,
      sp: 300,
      option: Keyword.get(opts, :option, 0),
      learned_skills: learned_skills
    }

    %{connection_pid: self(), game_state: PlayerState.new(character), interaction_lock: nil}
  end

  test "enables Falcon through FalconHandler and returns the refreshed game state" do
    expect(CharacterPersistence, :update_character, fn @char_id, %{option: option}, async: true ->
      assert option == (@riding_bit ||| @falcon_bit)
      :ok
    end)

    {reply, updated} =
      ScriptEffectHandler.apply_op({:set_falcon, true}, state(option: @riding_bit))

    assert {:ok, game_state} = reply
    assert game_state == updated.game_state
    assert (game_state.option &&& @falcon_bit) != 0
    assert StatusStorage.has_status?(:player, @char_id, :sc_falcon)
  end

  test "keeps an already-equipped Falcon idempotent" do
    reject(&CharacterPersistence.update_character/3)
    equipped = state(option: @riding_bit ||| @falcon_bit)

    assert {{:ok, game_state}, ^equipped} =
             ScriptEffectHandler.apply_op({:set_falcon, true}, equipped)

    assert game_state == equipped.game_state
  end

  test "returns the FalconHandler prerequisite error without changing state" do
    reject(&CharacterPersistence.update_character/3)
    base = state(falconry_level: 0, option: @riding_bit)

    assert {{:error, :falcon_skill_not_learned}, ^base} =
             ScriptEffectHandler.apply_op({:set_falcon, true}, base)

    refute StatusStorage.has_status?(:player, @char_id, :sc_falcon)
  end
end
