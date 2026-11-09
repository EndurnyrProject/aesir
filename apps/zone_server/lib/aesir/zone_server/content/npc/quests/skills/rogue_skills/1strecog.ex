defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.RogueSkills.M1strecog do
  @moduledoc """
  Hidden trigger that starts the Close Confine training round when a player enters the arena.

  ## Behavior

  - On touch, enables the five-minute arena timer and the Kienna movement timer, then hides itself.

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
        map: "prt_are01",
        x: 150,
        y: 150,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#1strecog",
        trigger: {10, 10}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx) do
    ctx
    |> donpcevent("#1st5min::OnEnable")
    |> donpcevent("#1stmove::OnEnable")
    |> disablenpc("#1strecog")
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  # rAthena starts a click at the first label, so it runs this body too.
  def on_talk(ctx), do: on_event("OnTouch_", ctx)
end
