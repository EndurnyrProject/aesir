defmodule Aesir.ZoneServer.Mmo.QuestManagement.QuestsTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.DbTestSetup
  alias Aesir.ZoneServer.Mmo.QuestManagement.QuestDefinition
  alias Aesir.ZoneServer.Mmo.QuestManagement.Quests

  @tag :tmp_dir
  test "reload installs the import override and keeps other quests available",
       %{tmp_dir: root} = context do
    on_exit(&Quests.reload/0)
    {:ok, tmp_dir: base} = DbTestSetup.configure_root(context, "quests")

    File.write!(Path.join(base, "quests.yml"), """
    - id: 10
      title: Base quest
    - id: 20
      title: Unchanged quest
    """)

    assert :ok = Quests.reload()
    assert {:ok, %QuestDefinition{title: "Base quest"}} = Quests.by_id(10)
    assert :error = Quests.by_id(30)

    overlay = Path.join([root, "import", "quests"])
    File.mkdir_p!(overlay)

    File.write!(Path.join(overlay, "quests.yml"), """
    - id: 10
      title: Replacement quest
    - id: 30
      title: Added quest
    """)

    assert :ok = Quests.reload()
    assert {:ok, %QuestDefinition{title: "Replacement quest"}} = Quests.by_id(10)
    assert {:ok, %QuestDefinition{title: "Unchanged quest"}} = Quests.by_id(20)
    assert {:ok, %QuestDefinition{title: "Added quest"}} = Quests.by_id(30)
  end
end
