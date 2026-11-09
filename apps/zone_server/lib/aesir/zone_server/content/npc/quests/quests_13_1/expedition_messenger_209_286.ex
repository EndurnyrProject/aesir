defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.ExpeditionMessenger209286 do
  @moduledoc """
  The expedition messenger who vanishes into thin air the moment the player talks to him.

  ## Behavior

  - Says nothing, then vanishes as the player tries to talk to him.
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
        map: "mid_camp",
        x: 209,
        y: 286,
        dir: 3,
        sprite: 998,
        name: "Expedition Messenger",
        scope: :shared,
        unique_name: "Expedition Messenger#3",
        trigger: {4, 4}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @npc "Expedition Messenger#3"

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Expedition Agent]")
    |> mes("...")
    |> next()
    |> disablenpc(@npc)
    |> mes(
      "- When you tried to talk to him, he disappeared into thin air. He looked like someone on a very important mission... -"
    )
    |> close()
  end

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, @npc)
  def on_event("OnEnable", ctx), do: enablenpc(ctx, @npc)
  def on_event("OnDisable", ctx), do: disablenpc(ctx, @npc)
end
