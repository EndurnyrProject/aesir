defmodule Aesir.ZoneServer.Mmo.MobSkill.DbTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.MobSkill.Db

  @pt_key Aesir.ZoneServer.Mmo.MobSkill.Db

  # Scorpion (1001) is a normal mob with its own NPC_POISON/NPC_FIREATTACK rows;
  # Osiris (1038) is a `:boss`-mode mob. Both exist in the real mob db, so they
  # drive the class-based global-row resolution deterministically.
  @normal_mob_id 1001
  @boss_mob_id 1038

  describe "rows_for/1 against real data" do
    setup do
      :ok = Db.reload()
    end

    test "returns a known mob's own rows with coerced shapes" do
      rows = Db.rows_for(@normal_mob_id)

      skills = Enum.map(rows, & &1.skill)
      assert "NPC_POISON" in skills
      assert "NPC_FIREATTACK" in skills

      assert Enum.all?(rows, &is_atom(&1.state))
      assert Enum.all?(rows, &is_atom(&1.target))
      assert Enum.all?(rows, &is_atom(&1.condition.type))
      assert Enum.all?(rows, &is_integer(&1.skill_id))
    end

    test "unknown mob id returns []" do
      assert Db.rows_for(999_999) == []
    end
  end

  describe "global-row resolution" do
    setup do
      own = %{skill: "OWN", state: :attack, condition: %{type: :always}}
      all = %{skill: "ALL", state: :attack, condition: %{type: :always}}
      boss = %{skill: "BOSS", state: :attack, condition: %{type: :always}}
      normal = %{skill: "NORMAL", state: :attack, condition: %{type: :always}}

      :persistent_term.put(@pt_key, %{
        by_id: %{@normal_mob_id => [own]},
        global_all: [all],
        global_boss: [boss],
        global_normal: [normal]
      })

      on_exit(fn -> :persistent_term.erase(@pt_key) end)
      :ok
    end

    test "a normal mob gets own + global_all + global_normal" do
      skills = @normal_mob_id |> Db.rows_for() |> Enum.map(& &1.skill)

      assert skills == ["OWN", "ALL", "NORMAL"]
      refute "BOSS" in skills
    end

    test "a boss mob gets own + global_all + global_boss" do
      skills = @boss_mob_id |> Db.rows_for() |> Enum.map(& &1.skill)

      assert skills == ["ALL", "BOSS"]
      refute "NORMAL" in skills
    end
  end

  describe "reload/0 and lazy index" do
    test "reload/0 rebuilds the cache" do
      :persistent_term.erase(@pt_key)

      assert Db.reload() == :ok
      assert :persistent_term.get(@pt_key) |> Map.has_key?(:by_id)
      assert Db.rows_for(@normal_mob_id) != []
    end

    test "lazily builds the index on first access" do
      :persistent_term.erase(@pt_key)

      assert Db.rows_for(@normal_mob_id) != []
    end
  end
end
