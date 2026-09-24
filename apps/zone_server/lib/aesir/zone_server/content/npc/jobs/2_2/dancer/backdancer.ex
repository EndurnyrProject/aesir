defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Dancer.Backdancer do
  @moduledoc """
  Lead background dancer that relays the Dancer job test's performance cues.

  ## Behavior

  - Cheers on a good move and looks shocked on a miss, then cues the other backdancers to do the same.

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
        x: 63,
        y: 110,
        dir: 4,
        sprite: 724,
        name: "Backdancer",
        scope: :shared,
        unique_name: "Backdancer#1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnSmile", ctx) do
    ctx
    |> emotion(:best)
    |> donpcevent("Backdancer#2::OnSmile")
    |> donpcevent("Backdancer#3::OnSmile")
    |> donpcevent("Backdancer#4::OnSmile")
  end

  def on_event("OnOmg", ctx) do
    ctx
    |> emotion(:huk)
    |> donpcevent("Backdancer#2::OnOmg")
    |> donpcevent("Backdancer#3::OnOmg")
    |> donpcevent("Backdancer#4::OnOmg")
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
