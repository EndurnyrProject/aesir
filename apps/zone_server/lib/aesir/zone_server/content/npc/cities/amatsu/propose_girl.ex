defmodule Aesir.ZoneServer.Content.Npc.Cities.Amatsu.ProposeGirl do
  @moduledoc """
  Explains the proposal legend surrounding Amatsu's ancient cherry tree.

  ## Behavior

  - Marks the tree conversation as Hutari Shioko's perspective.
  - Describes the legend's Saturday proposal and Sunday reply conditions.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "amatsu",
        x: 269,
        y: 221,
        dir: 1,
        sprite: 758,
        name: "Propose Girl",
        scope: :shared,
        unique_name: "Propose Girl#ama"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> set_char_var(:jap_tree, 1)
    |> mes("[Hutari Shioko]")
    |> mes("It is a pleasure to meet you.")
    |> mes("My name is Hutari Shioko.")
    |> mes("My hobby is listening to music.")
    |> mes("I'm an avid fan of classical music.")
    |> next()
    |> mes("[Hutari Shioko]")
    |> mes("There is an old story about")
    |> mes("the hill in our town.")
    |> mes("Have you heard this story before?")
    |> next()
    |> mes("[Hutari Shioko]")
    |> mes("It is said that if you propose")
    |> mes("under that tree, you and your")
    |> mes("lover will live a happy life for all eternity.")
    |> next()
    |> mes("[Hutari Shioko]")
    |> mes("However, the proposal can not be")
    |> mes(
      "done at any given time. The legend states that it can only be done on Saturday evenings."
    )
    |> next()
    |> mes("[Hutari Shioko]")
    |> mes("After the proposal, the reply must")
    |> mes("be answered before Sunday evening. This is the most crucial part of it.")
    |> next()
    |> emotion(:bigthrob)
    |> mes("[Hutari Shioko]")
    |> mes("If you like someone...")
    |> mes("You should try proposing")
    |> mes("under that tree. I'm sure ")
    |> mes("happy things will happen, if you do.")
    |> close()
  end
end
