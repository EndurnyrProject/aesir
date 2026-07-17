defmodule Aesir.ZoneServer.Mmo.Skills.SaMagicrodTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.SaMagicrod
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  setup :verify_on_exit!

  @caster %{character_id: 1000}

  defp definition do
    {:ok, definition} = Catalog.by_id(276)
    definition
  end

  describe "definition" do
    test "mirrors rAthena skill_db 276: a self-cast level 5 magic buff costing 2 SP" do
      assert %{
               id: 276,
               name: :sa_magicrod,
               max_level: 5,
               target_type: :self,
               damage_type: :no_damage,
               damage_kind: :magic,
               status: :sc_magicrod,
               sp_cost: [2, 2, 2, 2, 2]
             } = definition()
    end

    # rAthena skill_db.yml:7708-7718 Duration1 = 400/600/800/1000/1200, i.e.
    # 400 + 200 * (level - 1) — sub-second up to level 3.
    test "is sub-second at low levels: duration is 400 + 200 * (level - 1) ms" do
      assert %{duration: [400, 600, 800, 1_000, 1_200]} = definition()

      for level <- 1..5 do
        assert Enum.at(definition().duration, level - 1) == 400 + 200 * (level - 1)
      end
    end

    test "casts instantly with a 1s after-cast delay" do
      assert %{cast_time: [], fixed_cast_time: [], after_cast_delay: [1_000 | _]} = definition()
    end
  end

  describe "cast/4" do
    test "applies sc_magicrod carrying val2 = 20 * level and the level's duration" do
      expect(StatusInterpreter, :apply_status, fn :player, 1000, :sc_magicrod, params ->
        assert params[:val1] == 3
        assert params[:val2] == 60
        assert params[:duration] == 800
        assert params[:caster_id] == 1000
        :ok
      end)

      assert {:ok, @caster} = SaMagicrod.cast(@caster, :self, 3, definition())
    end

    test "propagates an apply failure" do
      stub(StatusInterpreter, :apply_status, fn _, _, _, _ -> {:error, :already_active} end)

      assert {:error, :already_active} = SaMagicrod.cast(@caster, :self, 1, definition())
    end
  end
end
