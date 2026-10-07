defmodule Aesir.ZoneServer.Mmo.Skill.OriginTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Origin

  @proc %{invocation: :auto, autocast_flag?: true}
  @status_proc %{invocation: :auto, autocast_flag?: false}
  @item %{invocation: :item, autocast_flag?: false}

  @firebolt %{
    skill: :mg_firebolt,
    caster: {:player, 42},
    invocation: :direct,
    autocast_flag?: false
  }

  test "is nil outside a skill invocation" do
    assert Origin.current() == nil
    refute Origin.autocast?({:player, 42})
  end

  test "exposes the current skill and caster inside an invocation" do
    Origin.with_skill(:mg_firebolt, {:player, 42}, fn ->
      assert Origin.current() == @firebolt
    end)

    assert Origin.current() == nil
  end

  test "restores the outer origin after a nested invocation" do
    Origin.with_skill(:mg_firebolt, {:player, 42}, fn ->
      Origin.with_skill(:wz_stormgust, {:mob, 7}, fn ->
        assert Origin.current() == %{
                 skill: :wz_stormgust,
                 caster: {:mob, 7},
                 invocation: :direct,
                 autocast_flag?: false
               }
      end)

      assert Origin.current() == @firebolt
    end)

    assert Origin.current() == nil
  end

  test "restores the outer origin when a nested invocation raises" do
    Origin.with_skill(:mg_firebolt, {:player, 42}, fn ->
      assert_raise RuntimeError, "cast failed", fn ->
        Origin.with_skill(:wz_stormgust, {:mob, 7}, fn -> raise "cast failed" end)
      end

      assert Origin.current() == @firebolt
    end)

    assert Origin.current() == nil
  end

  test "clears the origin when an invocation raises" do
    assert_raise RuntimeError, "cast failed", fn ->
      Origin.with_skill(:mg_firebolt, nil, fn -> raise "cast failed" end)
    end

    assert Origin.current() == nil
  end

  describe "invocation scope" do
    test "records the invocation kind and the autocast flag only for a flagged scope" do
      Origin.with_skill(:mg_firebolt, {:player, 42}, @item, fn ->
        assert %{invocation: :item, autocast_flag?: false} = Origin.current()
        refute Origin.autocast?({:player, 42})
      end)

      Origin.with_skill(:mg_firebolt, {:player, 42}, @status_proc, fn ->
        assert %{invocation: :auto, autocast_flag?: false} = Origin.current()
        refute Origin.autocast?({:player, 42})
      end)

      Origin.with_skill(:mg_firebolt, {:player, 42}, @proc, fn ->
        assert %{invocation: :auto, autocast_flag?: true} = Origin.current()
        assert Origin.autocast?({:player, 42})
      end)

      refute Origin.autocast?({:player, 42})
    end

    test "the flag belongs to the caster that set it" do
      Origin.with_skill(:mg_firebolt, {:player, 42}, @proc, fn ->
        refute Origin.autocast?({:player, 43})
        refute Origin.autocast?({:mob, 42})
        refute Origin.autocast?(nil)
      end)
    end

    test "a nested unflagged invocation keeps the enclosing caster's flag" do
      Origin.with_skill(:mg_firebolt, {:player, 42}, @proc, fn ->
        Origin.with_skill(:wz_stormgust, {:player, 42}, @status_proc, fn ->
          assert %{invocation: :auto, autocast_flag?: true} = Origin.current()
        end)

        Origin.with_skill(:wz_stormgust, {:player, 42}, fn ->
          assert %{invocation: :direct, autocast_flag?: true} = Origin.current()
        end)

        assert Origin.autocast?({:player, 42})
      end)
    end

    test "a nested flagged invocation resets the flag instead of restoring it" do
      Origin.with_skill(:mg_firebolt, {:player, 42}, @proc, fn ->
        Origin.with_skill(:wz_stormgust, {:player, 42}, @proc, fn ->
          assert Origin.autocast?({:player, 42})
        end)

        refute Origin.autocast?({:player, 42})
        assert %{skill: :mg_firebolt, autocast_flag?: false} = Origin.current()
      end)
    end

    test "identity restoration does not resurrect a flag reset inside the invocation" do
      Origin.with_skill(:mg_firebolt, {:player, 42}, @proc, fn ->
        Origin.with_skill(:wz_stormgust, {:player, 42}, fn ->
          Origin.set_autocast_flag({:player, 42}, false)
        end)

        refute Origin.autocast?({:player, 42})
      end)
    end

    test "a flagged invocation resets the flag when it raises" do
      assert_raise RuntimeError, "cast failed", fn ->
        Origin.with_skill(:mg_firebolt, {:player, 42}, @proc, fn -> raise "cast failed" end)
      end

      refute Origin.autocast?({:player, 42})
      assert Origin.current() == nil
    end

    test "resetting another caster's flag leaves the holder's flag alone" do
      Origin.with_skill(:mg_firebolt, {:player, 42}, @proc, fn ->
        Origin.set_autocast_flag({:player, 43}, false)
        assert Origin.autocast?({:player, 42})
      end)
    end

    test "a NPC cast has no flag to set" do
      Origin.with_skill(:mg_firebolt, nil, @proc, fn ->
        assert %{caster: nil, autocast_flag?: false} = Origin.current()
        refute Origin.autocast?(nil)
      end)
    end
  end
end
