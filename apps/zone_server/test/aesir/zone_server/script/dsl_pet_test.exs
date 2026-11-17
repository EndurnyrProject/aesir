defmodule Aesir.ZoneServer.Script.DslPetTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @apple 619
  @red_potion 501

  test "an item script stages the catch with the used item as the default lure" do
    assert %Ctx{session_effects: [{:pet, {:catchpet, @apple, 0}}]} = Dsl.catchpet(ctx())

    assert %Ctx{session_effects: [{:pet, {:catchpet, @red_potion, 2}}]} =
             Dsl.catchpet(ctx(), @red_potion, 2)
  end

  test "catchpet fails without a lure outside an item script or with an unknown lure" do
    npc_ctx = %{ctx() | source: {:npc, __MODULE__}}

    assert %Ctx{session_effects: [], failures: [{:catchpet, :no_lure}]} = Dsl.catchpet(npc_ctx)

    assert %Ctx{session_effects: [], failures: [{:catchpet, :invalid_lure}]} =
             Dsl.catchpet(ctx(), 999_999_999)
  end

  test "birthpet stages the egg list" do
    assert %Ctx{session_effects: [{:pet, {:birthpet}}]} = Dsl.birthpet(ctx())
  end

  defp ctx do
    %Ctx{
      char_id: 1,
      account_id: 2,
      connection_pid: self(),
      game_state: %PlayerState{character_id: 1, account_id: 2},
      source: {:item, @apple}
    }
  end
end
