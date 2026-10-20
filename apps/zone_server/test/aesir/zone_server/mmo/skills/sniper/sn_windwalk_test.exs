defmodule Aesir.ZoneServer.Mmo.Skills.Sniper.SnWindwalkTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.Skills.Shared.PartySplash
  alias Aesir.ZoneServer.Mmo.Skills.Sniper.SnWindwalk
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :set_mimic_private

  test "buffs caster and nearby members, ignoring individual member failures" do
    caster = %PlayerState{character_id: 1, party_id: 10}
    definition = SnWindwalk.definition()
    stub(PartySplash, :nearby_member_ids, fn ^caster, 14 -> [2, 3] end)

    expect(StatusInterpreter, :apply_status, 3, fn :player, id, :sc_windwalk, params ->
      assert id in [1, 2, 3]
      assert params[:val1] == 10
      assert params[:caster_id] == 1
      assert params[:duration] == 400_000
      send(self(), {:buff, id})
      if id == 3, do: {:error, :prevented}, else: :ok
    end)

    assert {:ok, ^caster} = SnWindwalk.cast(caster, :self, 10, definition)
    for id <- [1, 2, 3], do: assert_received({:buff, ^id})
  end

  test "a refused caster application does not abort the party splash" do
    caster = %PlayerState{character_id: 1, party_id: 10}

    expect(StatusInterpreter, :apply_status, fn :player, 1, :sc_windwalk, _params ->
      {:error, :prevented}
    end)

    expect(PartySplash, :nearby_member_ids, fn ^caster, _radius -> [] end)

    assert {:ok, ^caster} = SnWindwalk.cast(caster, :self, 1, SnWindwalk.definition())
  end
end
