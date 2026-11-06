defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.RogueSkills.Npc do
  @moduledoc """
  Hidden controller that shows and hides the book-stealing Killer in the Close Confine quest.

  ## Behavior

  - Starts hidden; when enabled it starts a timer that reveals the Killer after one second.
  - Hides the Killer again after two minutes and hides itself after two and a half minutes.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - 2Spiritual Kid
    - DracoRPG
    - L0ne_W0lf
    - Samuray22
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "in_rogue",
        x: 359,
        y: 177,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#killershow01"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, "#killershow01")
  def on_event("OnEnable", ctx), do: ctx |> enablenpc("#killershow01") |> initnpctimer()
  def on_event("OnDisable", ctx), do: ctx |> stopnpctimer() |> disablenpc("#killershow01")
  def on_event("OnTimer1000", ctx), do: enablenpc(ctx, "Killer#Rogueguild")
  def on_event("OnTimer120000", ctx), do: disablenpc(ctx, "Killer#Rogueguild")

  def on_event("OnTimer150000", ctx),
    do: ctx |> disablenpc("Killer#Rogueguild") |> disablenpc("#killershow01")

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  # rAthena starts a click at the first label, so it runs this body too.
  def on_talk(ctx), do: on_event("OnInit", ctx)
end
