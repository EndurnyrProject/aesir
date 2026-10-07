defmodule Aesir.ZoneServer.Mmo.Skills.Professor.PfSoulburnTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.MagicAttack
  alias Aesir.ZoneServer.Mmo.Skills.Professor.PfSoulburn
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Resource

  setup :set_mimic_private

  setup do
    Mimic.copy(MagicAttack)
    Mimic.copy(Resource)

    test_pid = self()

    stub(Combat, :resolve_combatant, fn
      3001 -> {:ok, %{unit_type: :player, unit_id: 3001}}
      4001 -> {:ok, %{unit_type: :mob, unit_id: 4001}}
    end)

    stub(Resource, :read, fn {:player, 3001}, :sp -> {:ok, 40} end)

    stub(Resource, :drain_sp_percent, fn ref, 100 ->
      send(test_pid, {:drained, ref})
      :ok
    end)

    :ok
  end

  @caster %PlayerState{
    character_id: 1001,
    stats: %{current_state: %{hp: 500, sp: 90}, derived_stats: %{max_hp: 500, max_sp: 200}}
  }

  defp cast(level, roll),
    do:
      PfSoulburn.cast(@caster, {:unit, 3001}, level, PfSoulburn.definition(),
        rng: fn 100 -> roll end
      )

  test "only players can be siphoned" do
    reject(&Resource.drain_sp_percent/2)

    assert PfSoulburn.cast(@caster, {:unit, 4001}, 3, PfSoulburn.definition(),
             rng: fn 100 -> 1 end
           ) ==
             {:error, :invalid_target}
  end

  test "succeeds 30% plus 10% per level, capped at 70%" do
    assert Enum.map(1..5, &PfSoulburn.success_chance/1) == [40, 50, 60, 70, 70]
  end

  test "a successful level 3 roll empties the target's SP without damage" do
    reject(&MagicAttack.execute_magic_damage/4)

    assert {:ok, _caster} = cast(3, 60)
    assert_received {:drained, {:player, 3001}}
  end

  test "a successful level 5 roll also deals twice the target's SP, ignoring element" do
    test_pid = self()

    expect(MagicAttack, :execute_magic_damage, fn _caster, {:player, 3001}, 80, opts ->
      assert opts[:ignore_element]
      assert opts[:skip_range]
      send(test_pid, :damaged)
      {:ok, {:player, 3001}}
    end)

    assert {:ok, _caster} = cast(5, 70)
    assert_received :damaged
    assert_received {:drained, {:player, 3001}}
  end

  test "a failed level 5 roll burns the caster for twice the SP left on the paid pool" do
    reject(&Resource.drain_sp_percent/2)
    expect(MagicAttack, :deal_damage, fn {:player, 1001}, 60, :neutral, :skill -> :ok end)

    caster = put_in(@caster.stats.current_state.sp, 30)

    assert {:ok, burnt} =
             PfSoulburn.cast(caster, {:unit, 3001}, 5, PfSoulburn.definition(),
               rng: fn 100 -> 71 end
             )

    assert burnt.stats.current_state.sp == 0
  end

  test "a successful roll leaves the caster's own SP alone" do
    stub(MagicAttack, :execute_magic_damage, fn _caster, _target, _amount, _opts ->
      {:ok, {:player, 3001}}
    end)

    caster = put_in(@caster.stats.current_state.sp, 50)

    assert {:ok, untouched} =
             PfSoulburn.cast(caster, {:unit, 3001}, 3, PfSoulburn.definition(),
               rng: fn 100 -> 60 end
             )

    assert untouched.stats.current_state.sp == 50
  end

  test "spends its SP before the effect so a backfire burns the paid pool" do
    assert PfSoulburn.definition().cost_before_effect
  end

  test "a failed level 5 roll empties the caster" do
    reject(&Resource.drain_sp_percent/2)
    stub(MagicAttack, :deal_damage, fn {:player, 1001}, _damage, :neutral, :skill -> :ok end)

    assert {:ok, caster} = cast(5, 71)
    assert caster.stats.current_state.sp == 0
  end

  test "a failed lower-level roll only empties the caster's SP" do
    reject(&MagicAttack.deal_damage/4)

    assert {:ok, caster} = cast(2, 51)
    assert caster.stats.current_state.sp == 0
  end
end
