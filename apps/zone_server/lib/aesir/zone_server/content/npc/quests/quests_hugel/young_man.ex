defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.YoungMan do
  @moduledoc """
  Thierry searches for a cure for his fiancee Euslan.

  ## Behavior

  - Tells the player about his research and the danger he faces.
  - Makes medicine after receiving five Runes of the Darkness.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "odin_tem01",
        x: 130,
        y: 134,
        dir: 4,
        sprite: 774,
        name: "Young Man",
        scope: :shared,
        unique_name: "Young Man#Hu_Quest"
      }
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :hg_ma1, 0) do
      8 -> meet_thierry(ctx)
      9 -> ask_for_trust(ctx)
      10 -> warn_thierry(ctx)
      11 -> gather_runes(ctx)
      12 -> deliver_medicine(ctx)
      _ -> wait_for_euslan(ctx)
    end
  end

  defp meet_thierry(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Young Man]")
      |> mes("Hm? Oh, an adventurer.")
      |> mes("There's more and more")
      |> mes("of you coming to visit this")
      |> mes("Odin Shrine nowadays.")
      |> next()
      |> select(["Mr. Thierry?"])

    {ctx, _} =
      ctx
      |> mes("[Thierry]")
      |> mes("...?!")
      |> mes("H-how do you")
      |> mes("know my name?")
      |> mes("Do I know you")
      |> mes("from somewhere?")
      |> next()
      |> select(["Tell him about Euslan"])

    {ctx, _} =
      ctx
      |> mes("[Thierry]")
      |> mes("Oh, Euslan sent you to me?")
      |> mes("I'm so sorry that you had to")
      |> mes("go through so much trouble.")
      |> mes("Still, I'm glad to hear from her. Please let her know that I'm")
      |> mes("coming home soon, would you?")
      |> next()
      |> select(["What are you doing here?"])

    ctx
    |> mes("[Thierry]")
    |> mes("Well, um, I'm sorry.")
    |> mes("I can't really go into the")
    |> mes("details, but I'm doing this")
    |> mes("work to find a cure for")
    |> mes("Euslan's disease. It's not")
    |> mes("curable by modern medicine...")
    |> close()
    |> set_char_var(:hg_ma1, 9)
    |> changequest(8048, 8049)
  end

  defp ask_for_trust(ctx) do
    ctx
    |> mes("[Thierry]")
    |> mes("I can't tell you more")
    |> mes("than that. Please just")
    |> mes("trust me on this. In the")
    |> mes("meantime, would you tell")
    |> mes("Euslan that I should be")
    |> mes("coming home very soon?")
    |> close()
  end

  defp warn_thierry(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Thierry]")
      |> mes("Oh, I thought you")
      |> mes("already left Odin Shrine.")
      |> mes("You don't have anything ")
      |> mes("else to tell me, do you?")
      |> next()
      |> select(["Warn Thierry about Suspicious Men"])

    ctx
    |> mes("[Thierry]")
    |> mes("What?! It's just what")
    |> mes("I thought! They were just")
    |> mes("using me this whole time...!")
    |> mes("Still, I can't leave this")
    |> mes("place just yet... I can't...")
    |> next()
    |> mes("[Thierry]")
    |> mes("I guess it all started when")
    |> mes("Euslan contracted that weird")
    |> mes("disease. None of the doctors")
    |> mes("knew what it was, none of them")
    |> mes("could do anything about it.")
    |> mes("It was totally devastating...")
    |> next()
    |> mes("[Thierry]")
    |> mes("Finally, I took her to see")
    |> mes("Mawong, who told us that he")
    |> mes("actually met someone that had")
    |> mes("that disease, and that there")
    |> mes("was a way for me to cure it.")
    |> mes("I had to take my chances...")
    |> next()
    |> mes("[Thierry]")
    |> mes("Mawong told me that the cure")
    |> mes("was somewhere near the Odin")
    |> mes("Shrine in Hugel. As you already")
    |> mes("know, this place is incredibly")
    |> mes("dangerous. But I don't care.")
    |> mes("I'll do anything for Euslan.")
    |> next()
    |> mes("[Thierry]")
    |> mes("Of course, I only told Euslan")
    |> mes("that I'd be looking around the")
    |> mes("Schwarzwald Republic... If she")
    |> mes("knew I was at the Odin Shrine,")
    |> mes("she'd worry too much about me.")
    |> next()
    |> mes("[Thierry]")
    |> mes("Once I got here, I didn't")
    |> mes("know what to do, or what I was")
    |> mes("even looking for. Then, I ran")
    |> mes("into these strange men, and")
    |> mes("told them my story out of my")
    |> mes("frustration over my situation.")
    |> next()
    |> mes("[Thierry]")
    |> mes("It seemed like a miracle")
    |> mes("when they said that they knew")
    |> mes("how to cure Euslan. They told")
    |> mes("me that they were a research")
    |> mes("team working on a project")
    |> mes("related to my dilemna.")
    |> next()
    |> mes("[Thierry]")
    |> mes("I didn't even think twice")
    |> mes("about it: I immediately")
    |> mes("accepted their offer to")
    |> mes("join them. I did whatever")
    |> mes("research they asked while")
    |> mes("I searched for Euslan's cure...")
    |> next()
    |> mes("[Thierry]")
    |> mes("Later, I overheard them")
    |> mes("talking, and I learned that")
    |> mes("they were really Rekenber")
    |> mes("Corporation agents. Their")
    |> mes("project had nothing to do")
    |> mes("with medicine or my Euslan...")
    |> next()
    |> mes("[Thierry]")
    |> mes("Their true goal is to improve")
    |> mes("their guardian technology by")
    |> mes("finding the remains of some")
    |> mes("giant beneath the Odin Shrine.")
    |> mes("Still, working with them gave")
    |> mes("me access to so many resources.")
    |> next()
    |> mes("[Thierry]")
    |> mes("I've actually been able to")
    |> mes("find a cure for Euslan's")
    |> mes("illness through my research")
    |> mes("with those men, so I can't")
    |> mes("quit now. I still need to make")
    |> mes("that medicine for Euslan!")
    |> next()
    |> mes("[Thierry]")
    |> mes("So, behind their backs, I've")
    |> mes("been using their guardians to")
    |> mes("gather the ingredients needed")
    |> mes("for my fiancee's medicine. But")
    |> mes("if they're planning to get rid of me, I've just run out of time.")
    |> next()
    |> mes("[Thierry]")
    |> mes("It doesn't matter what")
    |> mes("happens to me, but I must")
    |> mes("save Euslan. I only need")
    |> mes("^FF00005 Runes of the Darkness^000000 to")
    |> mes("finish that medicine. Please")
    |> mes("help me get them, adventurer...")
    |> next()
    |> mes("[Thierry]")
    |> mes("You're the only one I can")
    |> mes("trust to save Euslan. In the")
    |> mes("meantime, I'll be hiding from")
    |> mes("those men right over here.")
    |> mes("If they get me, I'll never be")
    |> mes("able to make the medicine!")
    |> close()
    |> set_char_var(:hg_ma1, 11)
    |> changequest(8050, 8051)
  end

  defp missing_runes(ctx) do
    ctx
    |> mes("[Thierry]")
    |> mes("I understand that gathering")
    |> mes("materials here in the Odin")
    |> mes("Shrine is difficult, but try to")
    |> mes("get me ^3355FF5 Runes of the Darkness^000000")
    |> mes("as soon as you can. My Euslan")
    |> mes("really needs that medicine...")
    |> close()
  end

  defp make_medicine(ctx) do
    ctx
    |> mes("[Thierry]")
    |> mes("Oh! You really brought me")
    |> mes("the Runes of the Darkness!")
    |> mes("I can finally make the medicine")
    |> mes("that will save my dear Euslan.")
    |> mes("I... I can't thank you enough")
    |> mes("for this. I'm so happy...")
    |> next()
    |> mes("[Thierry]")
    |> mes("Please give me a moment:")
    |> mes("I want to make this right")
    |> mes("away. Let's see, ah, here")
    |> mes("are my research notes...")
    |> next()
    |> mes("......")
    |> mes(".........")
    |> mes("............")
    |> next()
    |> mes("[Thierry]")
    |> mes("It's finally done. This")
    |> mes("medicine will cure Euslan.")
    |> mes("If you'd do one last thing")
    |> mes("for me, please bring this to")
    |> mes("her. I've got to sneak away")
    |> mes("later after things calm down.")
    |> next()
    |> mes("[Thierry]")
    |> mes("Please understand that")
    |> mes("I want to see her as soon")
    |> mes("as I can, but I have to wait")
    |> mes("until those Rekenber agents")
    |> mes("stop searching for me. And let")
    |> mes("Eslan know I'll come home soon.")
    |> next()
    |> mes("^3355FFYou received the")
    |> mes("medicine that Thierry")
    |> mes("has made to give to Euslan.^000000")
    |> close()
    |> delitem(7511, 5)
    |> set_char_var(:hg_ma1, 12)
    |> changequest(8051, 8052)
  end

  defp deliver_medicine(ctx) do
    ctx
    |> mes("[Thierry]")
    |> mes("Please give that")
    |> mes("medicine to Euslan as")
    |> mes("soon as you can: her life")
    |> mes("depends on it. Please let")
    |> mes("her know that I'm coming")
    |> mes("home as soon as I can.")
    |> close()
  end

  defp wait_for_euslan(ctx) do
    ctx
    |> mes("[Researcher]")
    |> mes("I'm sorry, Euslan...")
    |> mes("Please just wait for")
    |> mes("me a little while longer.")
    |> mes("I swear I'll come home to you!")
    |> close()
  end

  defp gather_runes(ctx) do
    if count_item(ctx, 7511) < 5, do: missing_runes(ctx), else: make_medicine(ctx)
  end
end
