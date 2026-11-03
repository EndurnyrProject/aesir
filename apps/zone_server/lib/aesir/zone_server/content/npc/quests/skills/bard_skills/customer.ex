defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.BardSkills.Customer do
  @moduledoc """
  A drunk patron in the Morocc pub who acts out the effects of Pang Voice for the Bard skill quest.

  ## Behavior

  - Two drunks argue about drinks until one suddenly loses control of his body, while a Bard in
    the room watches and giggles.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - L0ne_W0lf
    - DracoRPG

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
    quests/skills/bard_skills.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "morocc_in",
        x: 178,
        y: 73,
        dir: 3,
        sprite: 54,
        name: "Customer",
        scope: :shared,
        unique_name: "Customer#bard_skill01"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Little Bit Drunken Guy]")
    |> mes("What do you think")
    |> mes("is the best drink in")
    |> mes("all the world? I think")
    |> mes("the Tri-- Tristan? What")
    |> mes("was it called again?")
    |> next()
    |> mes("[More Drunken Guy]")
    |> mes("Oh! 13 Year Old Tristan?")
    |> mes("That's a great drink, sure,")
    |> mes("but it's way too expensive for")
    |> mes("anything less than a special")
    |> mes("occasion. ^333333*Hiccup*^000000 Personally,")
    |> mes("I really like Ver... Uh, Ver...")
    |> next()
    |> mes("[Little Bit Drunken Guy]")
    |> mes("Vermilion on the Beach?")
    |> mes("Yeah, that's really good,")
    |> mes("you'll pass out after just")
    |> mes("having one shot! Yeah...")
    |> mes("Tro... Tropical! People say")
    |> mes("that's good too. Wait, what?")
    |> next()
    |> mes("[Little Bit Drunken Guy]")
    |> mes("H-hey...! ^333333*Hiccup!*^000000")
    |> mes("What are you doing?!")
    |> mes("K-keep your hands to")
    |> mes("yourself! Do I look")
    |> mes("like a woman to you?")
    |> next()
    |> mes("[More Drunken Guy]")
    |> mes("What are you talking")
    |> mes("about? Wh-what?! Why")
    |> mes("are my arms all wrapped")
    |> mes("around you? S-sorry, I was")
    |> mes("trying to just go that w--")
    |> mes("I wasn't trying to hug you!")
    |> next()
    |> mes("[Little Bit Drunken Guy]")
    |> mes("Bumping into me,")
    |> mes("I understand. But a full")
    |> mes("blown hug? Come on, now!")
    |> mes("That was totally on purpose!")
    |> mes("Wh-what? My h-hand! It's...")
    |> mes("It's moving my itself?!")
    |> next()
    |> mes("[More Drunken Guy]")
    |> mes("Ack! Wh-what are")
    |> mes("you doing! S-stop")
    |> mes("touching my butt!")
    |> next()
    |> mes("^3355FFA Bard in the room")
    |> mes("watches the two drunk")
    |> mes("men intently and giggles")
    |> mes("at their stupor. Remember:")
    |> mes("drinking too much isn't good!^000000")
    |> close()
  end
end
