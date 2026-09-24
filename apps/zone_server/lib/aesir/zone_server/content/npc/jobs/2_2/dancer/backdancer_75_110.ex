defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Dancer.Backdancer75110 do
  @moduledoc """
  Background dancer that reacts to the Dancer job test's performance cues.

  ## Behavior

  - Cheers when the lead backdancer signals a good move and looks shocked on a miss.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kalen
    - Fredzilla
    - Lupus
    - L0ne_W0lf
    - Samuray22
    - Brainstorm
    - Kisuka
    - Euphy
    - Vicious
    - Lance
    - Skotlex

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "job_duncer",
        x: 75,
        y: 110,
        dir: 4,
        sprite: 724,
        name: "Backdancer",
        scope: :shared,
        unique_name: "Backdancer#4"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnSmile", ctx), do: emotion(ctx, :best)
  def on_event("OnOmg", ctx), do: emotion(ctx, :huk)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
