defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsYuno.Metto do
  @moduledoc """
  Metto pursues his flight research.

  ## Behavior

  - Reports his progress as the player undermines his colleagues.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - L0ne_W0lf
    - kobra_k88
    - Darkchild
    - Lupus
    - Samuray22
    - akrus

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno_in03",
        x: 26,
        y: 39,
        dir: 3,
        sprite: 709,
        name: "Metto",
        scope: :shared,
        unique_name: "Metto#juno"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx = mes(ctx, "[Metto]")

    case get_char_var(ctx, :metto_q, 0) do
      0 ->
        ctx
        |> mes(
          "In the Lab today, in the Lab tomorrow! Everyday is filled with research! Even if it takes my entire life, I will not give up until I have made a new Juno..."
        )
        |> next()
        |> mes("[Metto]")
        |> mes(
          "A new Juno in which all will bask in the light of my genius! If I can just harness the power of flight... I know I can do it!"
        )
        |> next()
        |> mes("[Metto]")
        |> mes(
          "^FF0000Wagan^000000 said that my idea was crazy and impossible. But I am no fool, I won't be swayed by his words of mockery!"
        )
        |> close()

      1 ->
        ctx
        |> set_char_var(:metto_q, 2)
        |> mes(
          "I'm going to ask my colleague ^FF0000Stangckle^000000 to help me. I am sure he will be more than willing to help out an old friend."
        )
        |> next()
        |> mes("[Metto]")
        |> mes(
          "If I had that fellow's help, this would be much easier. Pray! Pray to whatever God you believe that we will succeed!"
        )
        |> close()

      3 ->
        ctx
        |> set_char_var(:metto_q, 4)
        |> mes(
          "What? That punk Stangckle said he doesn't want to help me?! This is not good. This will slow my research considerably."
        )
        |> next()
        |> mes("[Metto]")
        |> mes("...")
        |> mes("What will")
        |> mes("I do now?!")
        |> next()
        |> mes("[Metto]")
        |> mes(
          "Luckily, I have a back up plan. I am positive that my friend and colleague ^FF0000Kato^000000 will lend his aid."
        )
        |> next()
        |> mes("[Metto]")
        |> mes("If I can only study his super robot, Great Z, I can continue my research...")
        |> next()
        |> mes("[Metto]")
        |> mes(
          "I guess if Stangckle doesn't want to help me, he can have it his way. I must continue my research, whether or not he helps me."
        )
        |> next()
        |> mes("[Metto]")
        |> mes("Expect great things, young friend. Muahahahha.")
        |> close()

      5 ->
        ctx
        |> set_char_var(:metto_q, 6)
        |> mes(
          "What? You mean to tell me that the very thing I need to continue my research, the mighty Great Z, has been destroyed?!!"
        )
        |> next()
        |> mes("[Metto]")
        |> mes("Nooooo~!! Why? Why would they do that? Are the Gods cursing me?!")
        |> next()
        |> mes("[Metto]")
        |> mes("Wait, I need...")
        |> mes("To calm down...")
        |> next()
        |> mes("[Metto]")
        |> mes(
          "If I can just get the help of professor ^FF0000CiCi^000000 with his Riding Engine theory, I might be able to finish my research..."
        )
        |> next()
        |> mes("[Metto]")
        |> mes("I still")
        |> mes("have hope!")
        |> mes("Ha! Ha! Ha!")
        |> close()

      7 ->
        ctx
        |> set_char_var(:metto_q, 8)
        |> mes("...")
        |> next()
        |> mes("[Metto]")
        |> mes("...")
        |> mes("......")
        |> next()
        |> mes("[Metto]")
        |> mes(
          "How can this happen 3 times in a row? Its true, the Gods have forsaken me! I'm ruined... RUINED!!!"
        )
        |> next()
        |> mes("[Metto]")
        |> mes(
          "What can I do now...? Has the time really come for me to forfeit all my years of research?"
        )
        |> next()
        |> mes("[Metto]")
        |> mes("I know I've disappointed you, but please, forget all about me.")
        |> next()
        |> mes("[Metto]")
        |> mes(
          "Who would do this to me? What kind of malicious person would shatter a man's dreams??"
        )
        |> next()
        |> mes("[Metto]")
        |> mes(
          "I'm tired of this. I think that the time has come for me to give up. It's all over. Please don't be too disappointed..."
        )
        |> close()

      8 ->
        ctx
        |> mes(
          "Maybe I should look into a job change. I hear it is a popular decision these days."
        )
        |> next()
        |> mes("[Metto]")
        |> mes(
          "I wonder what I should look into? All I know for sure is that I don't want to be scientist anymore. I'm done with research..."
        )
        |> close()

      _ ->
        ctx
        |> mes(
          "I better get going to check this new thing out. What are you still doing here? I'll be leaving in a bit."
        )
        |> next()
        |> mes("[Metto]")
        |> mes("I need to get ready! You go ahead and take off, I'll be going out soon.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
