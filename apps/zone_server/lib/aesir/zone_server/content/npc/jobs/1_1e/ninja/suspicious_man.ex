defmodule Aesir.ZoneServer.Content.Npc.Jobs.M11e.Ninja.SuspiciousMan do
  @moduledoc """
  Red Leopard Joe, disguised as a tourist, who answers Kuuga Gai's letter in the Ninja job quest.

  ## Behavior

  - Asks applicants carrying Kuuga Gai's letter to gather 5 Cyfars and 1 Phracon.
  - Takes the minerals, reveals himself, and sends applicants back to Amatsu with his reply.
  - Offers another trip to Amatsu until the reply is delivered.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Legionaire
    - Kisuka
    - Lupus
    - Playtester
    - SinSloth
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "einbroch",
        x: 184,
        y: 194,
        dir: 3,
        sprite: 881,
        name: "Suspicious Man",
        scope: :shared,
        unique_name: "Suspicious Man#nq"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :NINJ_Q, 0) do
      1 -> ask_for_minerals(ctx)
      2 -> check_minerals(ctx)
      3 -> offer_return_trip(ctx)
      step -> talk_after_reply(ctx, step)
    end
  end

  defp ask_for_minerals(ctx) do
    player = "[#{char_name(ctx, 0)}]"

    {ctx, choice} =
      ctx
      |> mes("[Suspicious Man]")
      |> mes("I've traveled to many")
      |> mes("countries, but I've never")
      |> mes("been on a building as high")
      |> mes("as Einbroch Tower. All the")
      |> mes("buildings in my hometown")
      |> mes("are tiny in comparison...")
      |> next()
      |> mes(player)
      |> mes("Oh, are you from")
      |> mes("Amatsu? I'm looking")
      |> mes("for someone named")
      |> mes("Wildcat Joe from there.")
      |> next()
      |> mes("[Suspicious Man]")
      |> mes("...No. No, I'm actually")
      |> mes("from Izlude, and I'm only")
      |> mes("here in Einbroch for some")
      |> mes("minerals. Tell me, why are")
      |> mes("you looking for this Wildcat Joe?")
      |> next()
      |> mes(player)
      |> mes("Well, I need to deliver")
      |> mes("this letter to him and")
      |> mes("get his response so that")
      |> mes("I can become a Ninja.")
      |> next()
      |> mes("[Suspicious Man]")
      |> mes("Really? Now that I think")
      |> mes("about it, I do think that I've")
      |> mes("run once or twice into him")
      |> mes("in this town. Though, he prefers to be called ''Red Leopard Joe,''")
      |> mes("instead of ''Wildcat Joe.''")
      |> next()
      |> mes(player)
      |> mes("I really want to help you")
      |> mes("find him, but first I need")
      |> mes("to find the minerals that")
      |> mes("I'm looking for. If you don't")
      |> mes("mind, would you help me?")
      |> mes("Then I can help you find Joe.")
      |> next()
      |> select(["Don't worry, I'll find him alone.", "Sure, I'll help you."])

    if choice == 1 do
      ctx
      |> mes("[Suspicious Man]")
      |> mes("You sure about that...?")
      |> mes("Red Leopard Joe is a true")
      |> mes("master of disguise. You'll")
      |> mes("need all the help you can")
      |> mes("get to find him...")
      |> close()
    else
      ctx
      |> mes("[Suspicious Man]")
      |> mes("Great, I'm glad to")
      |> mes("hear that. Please")
      |> mes("help me find")
      |> mes("^3355FF5 Cyfars^000000 and")
      |> mes("^3355FF1 Phracon^000000.")
      |> set_char_var(:NINJ_Q, 2)
      |> changequest(6015, 6016)
      |> close()
    end
  end

  defp check_minerals(ctx) do
    if count_item(ctx, 7053) < 5 or count_item(ctx, 1010) < 1 do
      ctx
      |> mes("[Suspicious Man]")
      |> mes("Please bring")
      |> mes("^3355FF5 Cyfars^000000 and")
      |> mes("^3355FF1 Phracon^000000 to me as")
      |> mes("soon as you can. Then,")
      |> mes("I can help you find")
      |> mes("Red Leopard Joe.")
      |> close()
    else
      reveal_and_reply(ctx)
    end
  end

  defp reveal_and_reply(ctx) do
    player = "[#{char_name(ctx, 0)}]"

    ctx
    |> mes("[Suspicious Man]")
    |> mes("Good, good. You've")
    |> mes("brought the minerals...")
    |> mes("Now, it's my turn to")
    |> mes("help you now. Here,")
    |> mes("let me see that letter.")
    |> next()
    |> mes(player)
    |> mes("?????!!")
    |> next()
    |> mes("[Suspicious Man]")
    |> mes("Why? Didn't you bring Kuuga Gai's letter for me?")
    |> next()
    |> mes(player)
    |> mes("Are you...")
    |> mes("Are you Wildcat Joe?")
    |> next()
    |> mes("[Suspicious Man]")
    |> mes("...Yes, but I prefer to")
    |> mes("be called Red Leopard Joe.")
    |> mes("Kuuga Gai sent you to me, right?")
    |> mes("He's the only one who calls")
    |> mes("me that. So you want to be")
    |> mes("a Ninja, eh? Hmm, alright.")
    |> next()
    |> mes("[Red Leopard Joe]")
    |> mes("If you want to be a Ninja,")
    |> mes("you should always be careful")
    |> mes("of what you see and what you trust. Don't forget that if your")
    |> mes("secrets are ever discovered, then you're finished as a Ninja.")
    |> next()
    |> mes("[Red Leopard Joe]")
    |> mes("Remember to move")
    |> mes("quickly, and to always")
    |> mes("vanish without a trace.")
    |> mes("To remain hidden in the")
    |> mes("shadows is really our")
    |> mes("ultimate power.")
    |> next()
    |> mes(player)
    |> mes("I see...")
    |> mes("...........")
    |> next()
    |> mes("[Red Leopard Joe]")
    |> mes("For now, let me read")
    |> mes("this letter. Let's see...")
    |> mes("Hm. I thought that Kuuga Gai")
    |> mes("would want to challenge me")
    |> mes("again, but he actually wants")
    |> mes("a temporary truce? Hah!")
    |> next()
    |> mes("[Red Leopard Joe]")
    |> mes("Thanks to your help,")
    |> mes("I now have the minerals")
    |> mes("I need to construct a Kunai!")
    |> mes("Hahaha! I won't agree to a truce when I have the advantage!")
    |> next()
    |> mes("[Red Leopard Joe]")
    |> mes("Anyway, let me write my")
    |> mes("response to him. I'll also")
    |> mes("give you my recommendation...")
    |> mes("I think you'll make a very fine")
    |> mes("Ninja, even if I did trick you")
    |> mes("just earlier. Heh heh heh!")
    |> next()
    |> mes(player)
    |> mes("......")
    |> mes(".........")
    |> mes("............")
    |> next()
    |> mes("[Red Leopard Joe]")
    |> mes("Here you go.")
    |> mes("Please bring this")
    |> mes("letter to Kuuga Gai.")
    |> mes("It'll take a while to")
    |> mes("return to Amatsu, so let")
    |> mes("me send you there directly...")
    |> delitem(1010, 1)
    |> delitem(7053, 5)
    |> set_char_var(:NINJ_Q, 3)
    |> changequest(6016, 6017)
    |> close()
    |> warp("amatsu", 113, 127)
  end

  defp offer_return_trip(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Red Leopard Joe]")
      |> mes("Eh? I'm not sure what")
      |> mes("happened, but it seems")
      |> mes("that you haven't delivered")
      |> mes("my response to Kuuga Gai yet.")
      |> mes("Shall I directly send you")
      |> mes("to Amatsu right now?")
      |> next()
      |> select(["No, thanks.", "Yes, please."])

    if choice == 1 do
      ctx
      |> mes("[Red Leopard Joe]")
      |> mes("Alright. Well, I was")
      |> mes("just trying to save")
      |> mes("you some time.")
      |> close()
    else
      ctx
      |> mes("[Red Leopard Joe]")
      |> mes("Okay, then.")
      |> mes("Goodbye for now.")
      |> close()
      |> warp("amatsu", 113, 127)
    end
  end

  defp talk_after_reply(ctx, 4) do
    ctx
    |> mes("[Red Leopard Joe]")
    |> mes("Kuuga Gai asked you to")
    |> mes("gather some materials")
    |> mes("too? Oh well, I suppose")
    |> mes("that I can't blame him.")
    |> mes("Besides, I should be able")
    |> mes("to beat him in a fair fight~")
    |> close()
  end

  defp talk_after_reply(ctx, step) do
    if step == 5 and Rathena.job_id(base_class(ctx)) == Rathena.job_id(:ninja) do
      ctx
      |> mes("[Red Leopard Joe]")
      |> mes("Oh, you're a Ninja~")
      |> mes("I hope you continue to")
      |> mes("train yourself and master")
      |> mes("all the Ninja skills that")
      |> mes("you can. Always remember")
      |> mes("to blend into the shadows.")
      |> close()
    else
      ctx
      |> mes("[Tourist]")
      |> mes("I've traveled to many")
      |> mes("countries, but I've never")
      |> mes("been on a building as high")
      |> mes("as Einbroch Tower. All the")
      |> mes("buildings in my hometown")
      |> mes("are tiny in comparison...")
      |> close()
    end
  end
end
