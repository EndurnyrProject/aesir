defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsComodo.CampgroundLad do
  @moduledoc """
  Rotute shares stories at the campground.

  ## Behavior

  - Changes his conversation as the doomed swords quest progresses.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Evera
    - Samuray22
    - Brainstorm

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "comodo",
        x: 209,
        y: 314,
        dir: 4,
        sprite: 706,
        name: "Campground Lad",
        scope: :shared,
        unique_name: "Campground Lad#cmd"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx =
      case get_char_var(ctx, :dmdswrd_Q, 0) do
        v when v in [0, 1] ->
          ctx
          |> mes("[Rotute]")
          |> mes("Years ago, there was a huge")
          |> mes("quest to retrieve 4 rare swords")
          |> mes("of incredible power, supposedly")
          |> mes("the strongest swords ever made!")
          |> mes("But you know, there's a strange")
          |> mes("rumor about a secret 5th sword.")
          |> next()
          |> mes("[Rotute]")
          |> mes("This 5th sword is supposed")
          |> mes("to be hidden near Glastheim.")
          |> mes("If it does exist, it might have")
          |> mes("the power to change the world!")
          |> mes("Isn't that freakin' scary?")

        v when v in [2, 3] ->
          ctx
          |> mes("[Rotute]")
          |> mes("Hey, isn't that Koserahserah?")
          |> mes("That's the best seasoning that")
          |> mes("you can have for meat dishes!")
          |> mes("Oh, you got that from the Chief")
          |> mes("to give to Rochito? Wow, they")
          |> mes("must be really good friends...")

        _ ->
          ctx
          |> mes("[Rotute]")
          |> mes("Hello, thanks for helping")
          |> mes("out Rockha, Rochito and")
          |> mes("Emralhandas. They've known")
          |> mes("me since I was born, so it's")
          |> mes("like they're family to me.")
          |> next()
          |> mes("[Rotute]")
          |> mes("One of the reasons that")
          |> mes("they brought me here to")
          |> mes("Comodo was so that I could")
          |> mes("finally meet Tausupa. But...")
          |> mes("I guess he's too busy now.")
          |> mes("Still, I like this place!")
      end

    close(ctx)
  end
end
