defmodule Aesir.ZoneServer.Mmo.Skills.Assassin.AsSonicaccelTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Assassin.AsSonicaccel

  test "publishes the Assassin-owned quest passive" do
    Catalog.reload()
    {:ok, definition} = Catalog.by_id(1003)

    assert definition.name == :as_sonicaccel
    assert definition.display_name == "Sonic Acceleration"
    assert definition.max_level == 1
    assert definition.target_type == :passive
    assert definition.quest_skill
    assert definition.quest_owner_job == :assassin
    assert {:ok, AsSonicaccel} = Catalog.passive_module_for(:as_sonicaccel)
  end
end
