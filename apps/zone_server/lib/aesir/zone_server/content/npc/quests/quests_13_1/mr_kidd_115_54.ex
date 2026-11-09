defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.MrKidd11554 do
  @moduledoc """
  Mr. Kidd's hidden placeholder in the ruined eastern Morocc, revealed by the quest and
  hidden again on boot.

  ## Behavior

  - Says nothing when talked to: the reference body ends the script immediately.
  - Hides itself on boot and when disabled, and reveals itself when enabled.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_dan02",
        x: 115,
        y: 54,
        dir: 5,
        sprite: 884,
        name: "Mr. Kidd",
        scope: :shared,
        unique_name: "Mr. Kidd#moc_extra01"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @npc "Mr. Kidd#moc_extra01"

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  # The reference's `OnInit` label is empty, so booting falls through into `OnDisable`.
  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, @npc)
  def on_event("OnDisable", ctx), do: disablenpc(ctx, @npc)
  def on_event("OnEnable", ctx), do: enablenpc(ctx, @npc)
end
