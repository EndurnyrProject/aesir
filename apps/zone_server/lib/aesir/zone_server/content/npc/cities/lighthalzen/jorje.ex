defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Jorje do
  @moduledoc """
  Shares one of Jorje's anxious remarks when someone approaches his workspace.

  ## Behavior

  - Triggers on approach and randomly presents one of three remarks about his work and saving money.

  ## Credits

  - Original from rAthena, authors and Contributors
    - erKURITA
    - Au{R}oN (Translated by Alan)
    - $ephiroth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in01",
        x: 144,
        y: 53,
        dir: 3,
        sprite: 98,
        name: "Jorje",
        scope: :shared,
        unique_name: "Jorje#zero",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    case Enum.random(1..3) do
      1 ->
        ctx
        |> mes("[Jorje]")
        |> mes("Arrrgh, I don't")
        |> mes("have any time for")
        |> mes("talking! I'm in the")
        |> mes("middle of an important")
        |> mes("task! H-hold on a second!")
        |> close()

      2 ->
        ctx
        |> mes("[Jorje]")
        |> mes("D-don't come any")
        |> mes("closer! Anyone who")
        |> mes("comes near me might")
        |> mes("just screw me up! Back off!")
        |> close()

      3 ->
        ctx
        |> mes("[Jorje]")
        |> mes("Oh man...")
        |> mes("I've been working so")
        |> mes("hard and haven't taken")
        |> mes("any breaks. I think I'll")
        |> mes("reward myself and buy")
        |> mes("something like maybe--")
        |> next()
        |> mes("[Jorje]")
        |> mes("No! No, I'm not")
        |> mes("gonna buy anything!")
        |> mes("I've got my future wife")
        |> mes("to think about! Must...")
        |> mes("Save... More... Money!")
        |> close()
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
