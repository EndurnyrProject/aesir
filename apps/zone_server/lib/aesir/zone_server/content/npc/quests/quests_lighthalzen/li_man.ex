defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.LiMan do
  @moduledoc """
  A memory reveals a worker’s fate and his pendant.

  ## Behavior

  - Reveals the worker’s fate and gives the player his pendant.

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
        x: 99,
        y: 74,
        dir: 5,
        sprite: 48,
        name: "",
        scope: :shared,
        unique_name: "#li_Man"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :lhz_curse, 0) == 16 do
      witness_worker(ctx)
    else
      warp(ctx, "lhz_in01", 278, 162)
    end
  end

  defp witness_worker(ctx) do
    ctx
    |> mes("[???]")
    |> mes("It's over.")
    |> mes("I really want")
    |> mes("to quit. This is")
    |> mes("the end for me.")
    |> next()
    |> mes("[Peco Peco]")
    |> mes("^3131FFThis is the end!")
    |> mes("This is the end!^000000")
    |> next()
    |> mes("[???]")
    |> mes("He was right to say that")
    |> mes("we'd be paid well, but going")
    |> mes("through this much torture isn't")
    |> mes("worth any sum of money in the")
    |> mes("world to me. *Sigh* Money...")
    |> next()
    |> mes("[???]")
    |> mes("She must be so worried")
    |> mes("about me by now. And her")
    |> mes("health is so bad. I'm such")
    |> mes("a fool for leaving her behind.")
    |> next()
    |> mes("[Peco Peco]")
    |> mes("Such a fool!")
    |> mes("Such a fool!")
    |> mes("*Squaaawk~*")
    |> next()
    |> mes("[???]")
    |> mes("Damn it!")
    |> mes("Shut up, you stupid bird!")
    |> mes("Be quiet for just a minute!")
    |> next()
    |> mes("[Peco Peco]")
    |> mes("*Squaaaawk!*")
    |> mes("Death Penalty!")
    |> mes("Death Penalty!")
    |> next()
    |> mes("[???]")
    |> mes("Death penalty?")
    |> mes("Where'd you learn")
    |> mes("to say something weird")
    |> mes("like that? Huh. That's...")
    |> next()
    |> mes("..............")
    |> next()
    |> mes(".................")
    |> next()
    |> mes("....................")
    |> next()
    |> mes("......................")
    |> next()
    |> mes("[???]")
    |> mes("I'm the only one still")
    |> mes("in this room. Everyone")
    |> mes("else left and never came")
    |> mes("back. If they were... And")
    |> mes("I were to go out... Then...")
    |> mes("Maybe I better not leave.")
    |> next()
    |> mes("[???]")
    |> mes("If I could only give")
    |> mes("this pendant back to")
    |> mes("her, she wouldn't have")
    |> mes("to worry about me that")
    |> mes("much. But I might not")
    |> mes("be able to get back...")
    |> next()
    |> mes("[???]")
    |> mes("........")
    |> next()
    |> mes("[?????]")
    |> mes("Hey there, been")
    |> mes("waiting long? It's")
    |> mes("time for you to finish")
    |> mes("up your contract.")
    |> next()
    |> mes("[???]")
    |> mes("Finish up my...?")
    |> mes("N-no! I've decided!")
    |> mes("I'm not leaving this room!")
    |> next()
    |> mes("[?????]")
    |> mes("Hey hey, what the hell")
    |> mes("are you talking about?")
    |> mes("You came here to work,")
    |> mes("didn't you? And now it's")
    |> mes("time for you to collect, so...")
    |> next()
    |> mes("[???]")
    |> mes("N-no, l-let go of me!")
    |> mes("Please let me go!")
    |> mes("I want to see her again,")
    |> mes("please let me see her...!")
    |> next()
    |> mes("...")
    |> mes("......")
    |> next()
    |> mes("...")
    |> mes("......")
    |> mes(".........")
    |> next()
    |> mes("^3355FF*Clink*^000000")
    |> next()
    |> mes("[??]")
    |> mes("Hm? Who the hell")
    |> mes("brought in this cheap")
    |> mes("jewery? Someone must")
    |> mes("have forgotten to throw")
    |> mes("away their trash...")
    |> next()
    |> mes("[????]")
    |> mes("Yeah, it's just a")
    |> mes("cheap trinket. That")
    |> mes("pendant isn't even")
    |> mes("worth picking up.")
    |> next()
    |> mes("^3131FFYou pick up an old")
    |> mes("pendant from the ground.")
    |> mes("No matter how hard you try,")
    |> mes("you can't open its clasp to see")
    |> mes("what this pendant contains.^000000")
    |> set_char_var(:lhz_curse, 17)
    |> changequest(2090, 2091)
    |> give_item(7341, 1)
    |> close2()
    |> warp("lhz_in01", 278, 162)
  end
end
