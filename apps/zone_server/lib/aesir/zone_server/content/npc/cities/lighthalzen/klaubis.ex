defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Klaubis do
  @moduledoc """
  Answers tourists' questions about life and rumors in Lighthalzen.

  ## Behavior

  - Discusses her family's history in the city.
  - Comments on the quiet city sights and the Serial Axe Murderer rumor.

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
        map: "lighthalzen",
        x: 230,
        y: 182,
        dir: 4,
        sprite: 866,
        name: "Klaubis",
        scope: :shared,
        unique_name: "Klaubis#zen3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Klaubis]")
      |> mes("Excuse me, but are you")
      |> mes("a tourist? Well, welcome")
      |> mes("to Lighthalzen! This city")
      |> mes("has everything we need,")
      |> mes("but it can be a little too")
      |> mes("quiet and uneventful here.")
      |> next()
      |> select([
        "Have you lived in here long?",
        "I agree.",
        "Have you heard about the serial killer?"
      ])

    case choice do
      1 ->
        ctx
        |> mes("[Klaubis]")
        |> mes("Yes, our family has")
        |> mes("lived in this city for a")
        |> mes("long time, starting with")
        |> mes("my great grandfather. Let's")
        |> mes("see, my family's been here")
        |> mes("for about two hundred years.")
        |> next()
        |> mes("[Klaubis]")
        |> mes("You'd be surprised how")
        |> mes("many people stay in their")
        |> mes("hometowns. Even if you do")
        |> mes("leave, though, you can always")
        |> mes("come back. It wouldn't be your hometown if you couldn't, right?")
        |> close()

      2 ->
        ctx
        |> mes("[Klaubis]")
        |> mes("Yes, the atmosphere")
        |> mes("can get pretty listless")
        |> mes("around here. But still,")
        |> mes("there are plenty of nice")
        |> mes("sights to enjoy here in")
        |> mes("Lighthalzen, so look around~")
        |> close()

      3 ->
        ctx
        |> mes("[Klaubis]")
        |> mes("You mean the Serial")
        |> mes("Axe Murderer? I thought")
        |> mes("that was an old ghost story.")
        |> mes("Hm. I think that lady inside")
        |> mes("the Weapon Shop would")
        |> mes("know more about that tale...")
        |> close()

      _ ->
        ctx
    end
  end
end
