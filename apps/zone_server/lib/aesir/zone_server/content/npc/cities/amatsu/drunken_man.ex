defmodule Aesir.ZoneServer.Content.Npc.Cities.Amatsu.DrunkenMan do
  @moduledoc """
  Complains drunkenly about his wife and refuses to share his alcohol.

  ## Behavior

  - Responds differently when told to go home or invited to drink.

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
        x: 185,
        y: 115,
        dir: 3,
        sprite: 765,
        name: "Drunken Man",
        scope: :shared,
        unique_name: "Drunken Man#ama"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Kosake]")
      |> mes("*Hiccup*...My wife is just like,")
      |> mes("...like a man...*Hiccup*...")
      |> mes("I'm going to really...*Hiccup*...not go home this time...Hiccup")
      |> next()
      |> select(["Stop drinking and go home", "Let's drink together"])

    if choice == 1 do
      complain_about_wife(ctx)
    else
      refuse_to_share(ctx)
    end
  end

  defp complain_about_wife(ctx) do
    ctx
    |> mes("[Kosake]")
    |> mes("What?! Do you want me to get")
    |> mes("hit by my wife's big fist?")
    |> mes("That's right! I said 'big fist!'")
    |> next()
    |> mes("[Kosake]")
    |> mes("Sad to say, I married a woman")
    |> mes("with man hands...")
    |> mes("Big, strong hands that can kill a tiger.")
    |> next()
    |> mes("[Druken Man]")
    |> mes("It was in Ko...Koko-something")
    |> mes("town. She hit me because I")
    |> mes("lost some money...*Hiccup*")
    |> next()
    |> mes("[Druken Man]")
    |> mes("Life~~ is~~ nothing~~~")
    |> mes("What is zeny~~~~ ")
    |> mes("*Hiccup*...... *Hiccup*.......")
    |> mes(".......................")
    |> mes("........Z.z..z...zzz...")
    |> close()
  end

  defp refuse_to_share(ctx) do
    ctx
    |> mes("[Kosake]")
    |> mes("Heh heh... nice lad...")
    |> mes("But you know *Hiccup*")
    |> mes("I can't give you any of mine! Heheheh...")
    |> next()
    |> mes("[Kosake]")
    |> mes("If you buy me a drink, I will think about it...Hehehe...*Hiccup*..")
    |> close()
  end
end
