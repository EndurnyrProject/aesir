defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SpiderWebTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.SpiderWeb

  setup :set_mimic_private

  setup do
    Mimic.copy(Manager)
    :ok
  end

  @target {:mob, 9_701}
  @instance %{state: %{groups: [51, 52]}}

  test "halves the holder's FLEE" do
    assert SpiderWeb.modifiers(@instance, %{}) == %{flee_rate: -50}
  end

  @tag game_mode: :pre_renewal
  test "pre-renewal fire damage doubles and burns the web" do
    assert SpiderWeb.absorb_damage(@target, @instance, %{element: :fire, damage: 300}, %{}) ==
             {:remove, 600}
  end

  @tag game_mode: :renewal
  test "renewal fire adds 100 ratio points to the element step and burns the web" do
    # Without a live target the fire ratio cannot be read, so it falls back to doubling.
    assert SpiderWeb.absorb_damage(@target, @instance, %{element: :fire, damage: 300}, %{}) ==
             {:remove, 600}

    assert SpiderWeb.boosted(300, 1.5) == 300 + div(300 * 100, 150)
  end

  test "other elements pass through" do
    assert SpiderWeb.absorb_damage(@target, @instance, %{element: :water, damage: 300}, %{}) ==
             {:ok, 300, @instance}
  end

  test "ending the hold tears down every web" do
    test_pid = self()
    stub(Manager, :destroy_async, fn gid -> send(test_pid, {:destroyed, gid}) end)

    assert SpiderWeb.on_expire(@target, @instance, %{}) == :ok
    assert_received {:destroyed, 51}
    assert_received {:destroyed, 52}
  end
end
