defmodule Aesir.ZoneServer.Mmo.QuestManagement.QuestsTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.QuestManagement.QuestDefinition
  alias Aesir.ZoneServer.Mmo.QuestManagement.Quests

  setup do
    transcend = %QuestDefinition{id: 1000, title: "Transcend"}

    hunt = %QuestDefinition{
      id: 7393,
      title: "Shiny Silver Blade",
      targets: [%{mob_id: 2314, count: 10}, %{mob_id: 2311, count: 10}]
    }

    index = %{all: [transcend, hunt], by_id: %{1000 => transcend, 7393 => hunt}}

    :persistent_term.put(Quests, index)
    on_exit(fn -> :persistent_term.erase(Quests) end)

    %{transcend: transcend, hunt: hunt}
  end

  test "by_id resolves a known quest", %{transcend: transcend} do
    assert {:ok, ^transcend} = Quests.by_id(1000)
  end

  test "by_id resolves a quest with multiple targets", %{hunt: hunt} do
    assert {:ok, ^hunt} = Quests.by_id(7393)
  end

  test "by_id returns :error for an unknown quest id" do
    assert :error = Quests.by_id(999_999)
  end

  test "reload/0 rebuilds the index from the bootstrap fixture" do
    :persistent_term.erase(Quests)

    assert :ok = Quests.reload()
    assert {:ok, %QuestDefinition{id: 1000, title: "Transcend"}} = Quests.by_id(1000)
  end
end
