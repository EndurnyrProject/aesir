defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.CommandTimer do
  @moduledoc """
  The invisible command timer of the Morocc expedition camp that cycles the expedition
  messengers.

  ## Behavior

  - Hides itself on boot and on a click, and when disabled.
  - On enable reveals itself, restarts its timer and re-arms it on every disable.
  - Every hour hides both expedition messengers and re-enables itself.

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
        x: 2,
        y: 2,
        dir: 3,
        sprite: 997,
        name: "Command Timer",
        scope: :shared,
        unique_name: "Command Timer#edq",
        trigger: {4, 4}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @npc "Command Timer#edq"
  @expedition_messenger_2 "Expedition Messenger#2::OnDisable"
  @expedition_messenger_3 "Expedition Messenger#3::OnDisable"
  @rearm "Command Timer#edq::OnEnable"

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: disablenpc(ctx, @npc)

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, @npc)
  def on_event("OnEnable", ctx), do: ctx |> enablenpc(@npc) |> stopnpctimer() |> initnpctimer()
  def on_event("OnDisable", ctx), do: ctx |> disablenpc(@npc) |> stopnpctimer()

  def on_event("OnTimer3600000", ctx) do
    ctx
    |> donpcevent(@expedition_messenger_2)
    |> donpcevent(@expedition_messenger_3)
    |> donpcevent(@rearm)
  end
end
