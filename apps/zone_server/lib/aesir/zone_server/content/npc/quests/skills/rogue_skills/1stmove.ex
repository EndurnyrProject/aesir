defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.RogueSkills.M1stmove do
  @moduledoc """
  Hidden timer that makes Kienna appear at a random spot during Close Confine training.

  ## Behavior

  - Announces Kienna's arrival, then reveals one of her eight placements at random.
  - Hides every Kienna after a few seconds, restarts its own cycle, and warps everyone on the
    training map back to the arena entrance.

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
        x: 135,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#1stmove"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @kiennas ~w(Kienna#1st Kienna#2nd Kienna#3rd Kienna#4th Kienna#5th Kienna#6th Kienna#7th Kienna#8th)

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, "#1stmove")
  def on_event("OnEnable", ctx), do: ctx |> enablenpc("#1stmove") |> initnpctimer()

  def on_event("OnTimer3000", ctx) do
    mapannounce(
      ctx,
      "prt_are01",
      "Kienna will appear in 1 second. Please approach her as closely as possible.",
      1,
      "0x00ff00"
    )
  end

  def on_event("OnTimer5000", ctx), do: enablenpc(ctx, Enum.at(@kiennas, Enum.random(1..8) - 1))
  def on_event("OnTimer8000", ctx), do: Enum.reduce(@kiennas, ctx, &disablenpc(&2, &1))

  def on_event("OnTimer9000", ctx) do
    ctx
    |> stopnpctimer()
    |> donpcevent("#1stmove::OnEnable")
    |> mapwarp("prt_are01", "prt_are01", 150, 150)
  end

  def on_event("OnDisable", ctx), do: ctx |> stopnpctimer() |> disablenpc("#1stmove")

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  # rAthena starts a click at the first label, so it runs this body too.
  def on_talk(ctx), do: on_event("OnInit", ctx)
end
