defmodule Aesir.ZoneServer.Mmo.Skills.AlHealTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.AlHeal
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!

  @caster %{character_id: 1000}
  @ally_id 2000

  describe "Catalog lookups" do
    test "by_id(28) resolves al_heal" do
      assert {:ok, def} = Catalog.by_id(28)
      assert def.name == :al_heal
    end

    test "by_name(:al_heal) resolves" do
      assert {:ok, def} = Catalog.by_name(:al_heal)
      assert def.id == 28
    end
  end

  describe "cast/4 — player/ally target" do
    setup do
      stub(PlayerState, :get_stats, fn _caster ->
        %{base_level: 50, int: 50, matk: 50}
      end)

      stub(Combat, :resolve_combatant, fn _id ->
        {:ok, %{race: :demi_human}}
      end)

      {:ok, definition} = Catalog.by_id(28)
      {:ok, definition: definition}
    end

    test "healing self calls apply_heal on caster_id with the computed amount",
         %{definition: definition} do
      # div(div(50+50, 5) * 30 * 5, 10) + 50 = 300 + 50 = 350
      expect(Combat, :apply_heal, fn 1000, 350, 1000 -> :ok end)

      assert {:ok, @caster} = AlHeal.cast(@caster, :self, 5, definition)
    end

    test "healing an ally calls apply_heal on target_id with source_id",
         %{definition: definition} do
      expect(Combat, :apply_heal, fn @ally_id, 350, 1000 -> :ok end)

      assert {:ok, @caster} = AlHeal.cast(@caster, {:unit, @ally_id}, 5, definition)
    end
  end

  describe "cast/4 — undead/demon target deals holy damage instead of healing" do
    setup do
      stub(PlayerState, :get_stats, fn _caster ->
        %{base_level: 50, int: 50, matk: 50}
      end)

      {:ok, definition} = Catalog.by_id(28)
      {:ok, definition: definition}
    end

    for race <- [:undead, :demon] do
      test "#{race} target calls execute_magic_damage with :holy, not apply_heal",
           %{definition: definition} do
        stub(Combat, :resolve_combatant, fn _id -> {:ok, %{race: unquote(race)}} end)

        expect(Combat, :execute_magic_damage, fn _caster, @ally_id, 350, opts ->
          assert Keyword.fetch!(opts, :element) == :holy
          assert Keyword.fetch!(opts, :skill_id) == 28
          assert Keyword.fetch!(opts, :skill_level) == 5
          :ok
        end)

        assert {:ok, @caster} = AlHeal.cast(@caster, {:unit, @ally_id}, 5, definition)
      end
    end
  end

  describe "heal amount formula (renewal: base = div(lv+int,5)*30*lv/10 + matk)" do
    setup do
      stub(Combat, :resolve_combatant, fn _id -> {:ok, %{race: :demi_human}} end)
      {:ok, definition} = Catalog.by_id(28)
      {:ok, definition: definition}
    end

    test "lv1 @ base_level=10, int=10, matk=0 → 12", %{definition: definition} do
      stub(PlayerState, :get_stats, fn _ -> %{base_level: 10, int: 10, matk: 0} end)
      # div(div(20,5)*30*1, 10) + 0 = div(4*30, 10) = 12
      expect(Combat, :apply_heal, fn 1000, 12, 1000 -> :ok end)
      AlHeal.cast(@caster, :self, 1, definition)
    end

    test "lv10 @ base_level=99, int=50, matk=100 → 970", %{definition: definition} do
      stub(PlayerState, :get_stats, fn _ -> %{base_level: 99, int: 50, matk: 100} end)
      # div(div(149,5)*30*10, 10) + 100 = div(29*300, 10) + 100 = 870 + 100 = 970
      expect(Combat, :apply_heal, fn 1000, 970, 1000 -> :ok end)
      AlHeal.cast(@caster, :self, 10, definition)
    end

    test "lv5 @ base_level=50, int=50, matk=50 → 350", %{definition: definition} do
      stub(PlayerState, :get_stats, fn _ -> %{base_level: 50, int: 50, matk: 50} end)
      # div(div(100,5)*30*5, 10) + 50 = div(20*150, 10) + 50 = 300 + 50 = 350
      expect(Combat, :apply_heal, fn 1000, 350, 1000 -> :ok end)
      AlHeal.cast(@caster, :self, 5, definition)
    end

    test "rolls the heal MATK band within [base + heal_matk_min, base + heal_matk_max - 1]",
         %{definition: definition} do
      # base = div(div(100,5)*30*5, 10) = 300; heal band 10..20 -> heal in [310, 319].
      # Heal uses heal_matk_min/max (base_matk + weapon variance, NO flat MATK).
      stub(PlayerState, :get_stats, fn _ ->
        %{base_level: 50, int: 50, matk: 999, heal_matk_min: 10, heal_matk_max: 20}
      end)

      test_pid = self()
      stub(Combat, :apply_heal, fn 1000, amount, 1000 -> send(test_pid, {:heal, amount}) end)

      for _ <- 1..200, do: AlHeal.cast(@caster, :self, 5, definition)
      amounts = for _ <- 1..200, do: receive(do: ({:heal, a} -> a))

      assert Enum.all?(amounts, fn a -> a >= 310 and a <= 319 end)
      assert length(Enum.uniq(amounts)) > 1
    end

    test "heal_matk_min == heal_matk_max heals the exact deterministic value",
         %{definition: definition} do
      stub(PlayerState, :get_stats, fn _ ->
        %{base_level: 50, int: 50, matk: 999, heal_matk_min: 50, heal_matk_max: 50}
      end)

      # 300 + roll(50, 50) = 350; flat combat matk (999) is intentionally ignored
      expect(Combat, :apply_heal, fn 1000, 350, 1000 -> :ok end)
      AlHeal.cast(@caster, :self, 5, definition)
    end
  end
end
