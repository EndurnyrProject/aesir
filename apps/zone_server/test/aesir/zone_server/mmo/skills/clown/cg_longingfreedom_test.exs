defmodule Aesir.ZoneServer.Mmo.Skills.Clown.CgLongingfreedomTest do
  use ExUnit.Case, async: true
  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Skills.Clown.CgLongingfreedom
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  setup do
    caster = PlayerStateFixture.build(%{character_id: 17, stats: %{combat_stats: %CombatStats{}}})
    :ok = UnitRegistry.register_player(caster, self())
    %{caster: caster}
  end

  test "only a non-Moonlit ensemble lock permits Longing", %{caster: caster} do
    assert {:error, :not_in_ensemble} = validate(caster)

    for params <- [[val1: 319, state: %{root: :none}], [val1: 395, state: %{root: :always}]] do
      :ok = StatusStorage.apply_status(:player, 17, :sc_dancing, params)
      assert {:error, :not_in_ensemble} = validate(caster)
    end

    :ok =
      StatusStorage.apply_status(:player, 17, :sc_dancing, val1: 309, state: %{root: :ensemble})

    assert :ok = validate(caster)
  end

  test "legacy partner locks permit Longing and an active Longing cannot be renewed", %{
    caster: caster
  } do
    :ok = StatusStorage.apply_status(:player, 17, :sc_dancing, val1: 309, val4: 18)
    assert :ok = validate(caster)
    assert {:ok, ^caster} = CgLongingfreedom.cast(caster, :self, 3, CgLongingfreedom.definition())

    assert %{val1: 3, started_at: started, expires_at: expires} =
             StatusStorage.get_status(:player, 17, :sc_longing)

    assert expires - started == 180_000
    assert {:error, :already_active} = validate(caster)
  end

  defp validate(caster),
    do: CgLongingfreedom.validate(caster, :self, 3, CgLongingfreedom.definition())
end
