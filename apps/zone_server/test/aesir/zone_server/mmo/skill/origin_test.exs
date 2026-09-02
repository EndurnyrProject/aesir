defmodule Aesir.ZoneServer.Mmo.Skill.OriginTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Origin

  test "is nil outside a skill invocation" do
    assert Origin.current() == nil
  end

  test "exposes the current skill and caster inside an invocation" do
    Origin.with_skill(:mg_firebolt, {:player, 42}, fn ->
      assert Origin.current() == %{skill: :mg_firebolt, caster: {:player, 42}}
    end)

    assert Origin.current() == nil
  end

  test "restores the outer origin after a nested invocation" do
    Origin.with_skill(:mg_firebolt, {:player, 42}, fn ->
      Origin.with_skill(:wz_stormgust, {:mob, 7}, fn ->
        assert Origin.current() == %{skill: :wz_stormgust, caster: {:mob, 7}}
      end)

      assert Origin.current() == %{skill: :mg_firebolt, caster: {:player, 42}}
    end)

    assert Origin.current() == nil
  end

  test "restores the outer origin when a nested invocation raises" do
    Origin.with_skill(:mg_firebolt, {:player, 42}, fn ->
      assert_raise RuntimeError, "cast failed", fn ->
        Origin.with_skill(:wz_stormgust, {:mob, 7}, fn -> raise "cast failed" end)
      end

      assert Origin.current() == %{skill: :mg_firebolt, caster: {:player, 42}}
    end)

    assert Origin.current() == nil
  end

  test "clears the origin when an invocation raises" do
    assert_raise RuntimeError, "cast failed", fn ->
      Origin.with_skill(:mg_firebolt, nil, fn -> raise "cast failed" end)
    end

    assert Origin.current() == nil
  end
end
