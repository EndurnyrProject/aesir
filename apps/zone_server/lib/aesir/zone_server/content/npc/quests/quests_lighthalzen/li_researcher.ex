defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.LiResearcher do
  @moduledoc """
  A memory reveals Varmunt’s work for the corporation.

  ## Behavior

  - Replays Varmunt’s research and advances the curse.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22
    - Gepard
    - Euphy
    - Joseph
    - Capuche
    - JohnnyPlayy
    - Persian
    - Vicious_Pucca
    - aoa00
    - Evera
    - MasterOfMuppets
    - Lupus
    - Lord Gywall
    - DeNy
    - Vicious
    - Playtester
    - Silent
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_que01",
        x: 29,
        y: 24,
        dir: 3,
        sprite: 754,
        name: "",
        scope: :shared,
        unique_name: "#li_researcher"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if count_item(ctx, 7345) > 0 and get_char_var(ctx, :lhz_curse, 0) == 12 do
      witness_research(ctx)
    else
      warp(ctx, "lhz_in01", 206, 129)
    end
  end

  defp witness_research(ctx) do
    ctx =
      ctx
      |> mes("Doctor Varmunt,")
      |> mes("you've finally agreed")
      |> mes("to join us. Welcome!")
      |> next()

    ctx
    |> emotion(:sweat, getnpcid(ctx, "#li_Varmunt"))
    |> mes("[Varmunt]")
    |> mes("Well, I don't know if I agree")
    |> mes("with this company's policies,")
    |> mes("but the project you're offering")
    |> mes("seems to be an opportunity that")
    |> mes("comes once in a lifetime, so...")
    |> next()
    |> emotion(:best)
    |> mes("[??]")
    |> mes("To be honest, this project")
    |> mes("can only be a success with")
    |> mes("your cooperation. We need")
    |> mes("your genius and will provide")
    |> mes("whatever you require.")
    |> next()
    |> mes("[Varmunt]")
    |> mes("I'm flattered.")
    |> mes("And of course, I'll")
    |> mes("do my best. It's just")
    |> mes("that this deal sounds")
    |> mes("too good to be true...")
    |> next()
    |> mes("............")
    |> next()
    |> soundeffect("loli_ruri_stand.wav", 0)
    |> mes(".................")
    |> next()
    |> soundeffect("loli_ruri_stand.wav", 0)
    |> mes("...................")
    |> next()
    |> soundeffect("loli_ruri_stand.wav", 0)
    |> mes(".....................")
    |> next()
    |> mes(".......................")
    |> next()
    |> mes("[??]")
    |> mes("Amazing. You've accomplished")
    |> mes("what most have thought to be")
    |> mes("impossible ahead of schedule.")
    |> mes("An imitation of Ymir's Heart!")
    |> mes("This will surely spur Airship")
    |> mes("and Guardian development~!")
    |> next()
    |> mes("[Varmunt]")
    |> mes("I still don't believe that")
    |> mes("were able to do it. This is")
    |> mes("a huge leap for science, even")
    |> mes("if this imitation isn't as powerful as the real Ymir's Heart.")
    |> next()
    |> mes("[??]")
    |> mes("Come, we must celebrate!")
    |> mes("Let's go outside and have")
    |> mes("a toast in your honor! Ha ha~")
    |> next()
    |> mes("............")
    |> next()
    |> soundeffect("loli_ruri_stand.wav", 0)
    |> mes(".................")
    |> next()
    |> soundeffect("loli_ruri_stand.wav", 0)
    |> mes("....................")
    |> next()
    |> soundeffect("loli_ruri_stand.wav", 0)
    |> mes("......................")
    |> next()
    |> mes("[??]")
    |> mes("But why, Doctor Varmunt?")
    |> mes("If you're unhappy with the")
    |> mes("Rekenber Corporation for")
    |> mes("any reason whatsoever...")
    |> next()
    |> mes("[Varmunt]")
    |> mes("Well, I don't really")
    |> mes("have a reason to remain")
    |> mes("now that we've accomplished")
    |> mes("what I've agreed to do. It's time for me to return and work on")
    |> mes("my personal research.")
    |> next()
    |> mes("[??]")
    |> mes("Please, Doctor Varmunt,")
    |> mes("reconsider! You may have")
    |> mes("full use of our facilities to")
    |> mes("conduct your research. I'm")
    |> mes("willing to make you an offer.")
    |> next()
    |> mes("[Varmunt]")
    |> mes("No, I can't...")
    |> mes("If I continue to work")
    |> mes("here, I'm afraid I might")
    |> mes("make a lot of people")
    |> mes("unhappy. But, thank")
    |> mes("you for everything.")
    |> next()
    |> mes("[??]")
    |> mes("Wait...")
    |> mes("Doctor Varmunt.")
    |> mes("You forgot your cane.")
    |> next()
    |> mes("[Varmunt]")
    |> mes("Since when have you")
    |> mes("seen me use a cane?")
    |> mes("And even if I did,")
    |> mes("that one isn't mi--")
    |> next()
    |> mes("...")
    |> next()
    |> mes("...")
    |> mes("......")
    |> next()
    |> mes("...")
    |> mes("......")
    |> mes(".........")
    |> set_char_var(:lhz_curse, 13)
    |> close2()
    |> warp("lhz_in01", 206, 129)
  end
end
