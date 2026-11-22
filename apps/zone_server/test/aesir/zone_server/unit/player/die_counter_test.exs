defmodule Aesir.ZoneServer.Unit.Player.DieCounterTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.ZoneServer.Factory

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Unit.Player.DieCounter
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @super_novice 23
  @novice 0

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    stub(UnitRegistry, :update_unit_state, fn _, _, _ -> :ok end)
    stub(CharacterPersistence, :update_character, fn _, _, _ -> {:ok, %Character{}} end)
    :ok
  end

  defp session(job_id, deaths) do
    player =
      build(:player_state,
        character_id: 5,
        account_id: 6,
        vars: %{DieCounter.var() => deaths},
        stats: %{progression: %{job_id: job_id}, generation: 3}
      )

    build(:session_state, game_state: player)
  end

  test "a Super Novice's first death persists the counter and recalculates in full" do
    expect(CharacterPersistence, :update_character, fn 5,
                                                       %{vars: %{"PC_DIE_COUNTER" => 1}},
                                                       async: true ->
      {:ok, %Character{}}
    end)

    expect(StatusManager, :recalculate_after_status_change, fn state -> state end)

    state = DieCounter.increment(session(@super_novice, 0))

    assert DieCounter.count(state.game_state) == 1
    assert state.game_state.stats.generation == 4
  end

  test "later deaths and other jobs only persist the counter" do
    reject(&StatusManager.recalculate_after_status_change/1)

    assert DieCounter.count(DieCounter.increment(session(@super_novice, 1)).game_state) == 2

    novice = DieCounter.increment(session(@novice, 0))
    assert {DieCounter.count(novice.game_state), novice.game_state.stats.generation} == {1, 3}
  end

  test "a negative or unchanged value changes nothing" do
    reject(&CharacterPersistence.update_character/3)
    state = session(@super_novice, 2)

    assert DieCounter.put(state, -1) == state
    assert DieCounter.put(state, 2) == state
  end
end
