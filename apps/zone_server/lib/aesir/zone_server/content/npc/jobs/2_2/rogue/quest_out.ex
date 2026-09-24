defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Rogue.QuestOut do
  @moduledoc """
  Marks the Rogue job test tunnel as cleared and returns the candidate to the Rogue Guild.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Samuray22
    - Brainstorm
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "in_rogue",
        x: 370,
        y: 320,
        dir: 0,
        sprite: 45,
        name: "quest_out",
        scope: :shared,
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    ctx |> set_char_var(:ROGUE_Q, 16) |> warp("in_rogue", 378, 113)
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
