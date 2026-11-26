defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.MegingardSeal.Man do
  @moduledoc """
  Royal Myst, a gambling former 1st Squad Crusader, is one of the witnesses of the Megingjard
  Seal quest.

  ## Behavior

  - Outside the Megingjard seal phase he only brushes the player off.
  - Before the investigation starts he chats about Rebarev Doug, his old squad, gambling and
    hobbies.
  - Once the other witnesses have been questioned he can be asked about Doug, which starts his
    part of the investigation.
  - Each Alcohol he helps himself to loosens his tongue; fully drunk, his talk of gambling hints
    that a Crusader was framed and moves the quest on.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Lupus
    - L0ne_W0lf
    - Samuray22
    - brianluau
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
        map: "cmd_in02",
        x: 190,
        y: 94,
        dir: 3,
        sprite: 828,
        name: "Man",
        scope: :shared,
        unique_name: "Man#megin"
      }
    ]

  @impl true
  def on_talk(ctx) do
    eremes = get_char_var(ctx, :god_eremes, 0)

    cond do
      not seal_open?(ctx) ->
        ctx |> grumble() |> close()

      eremes == 18 ->
        ctx |> grumble() |> next() |> chat_menu()

      eremes > 18 and eremes < 21 ->
        investigation(ctx)

      true ->
        ctx
        |> mes("[Royal Myst]")
        |> mes("Eh heh heh~")
        |> mes("I just know")
        |> mes("I'm gonna win")
        |> mes("this time!")
        |> close()
    end
  end

  defp seal_open?(ctx) do
    get_server_var(ctx, "God1", 0) >= get_server_temp_var(ctx, "god_check1", 0) and
      get_server_var(ctx, "God2", 0) < get_server_temp_var(ctx, "god_check2", 0)
  end

  defp grumble(ctx) do
    ctx
    |> mes("[Royal Myst]")
    |> mes("Wha...?")
    |> mes("You wanna talk?")
    |> next()
    |> mes("[Royal Myst]")
    |> mes("What am I, your personal psychiatrist?! Lemme alone,")
    |> mes("I'm busy here! Awright, now")
    |> mes("which one do I bet on...?")
  end

  defp chat_menu(ctx) do
    case select(ctx, [
           "Speak of Rebarev Doug.",
           "Speak of the 1st Squad.",
           "Talk about gambling.",
           "Discuss hobbies."
         ]) do
      {ctx, 1} ->
        ctx
        |> mes("[Royal Myst]")
        |> mes(
          "Wha--? Him again?! Tell him I'm fine! Dandy, even! Why's he gotta send all these people just to ask"
        )
        |> mes("a silly question?")
        |> close()

      {ctx, 2} ->
        ctx |> old_squad() |> close()

      {ctx, 3} ->
        ctx
        |> mes("[Royal Myst]")
        |> mes("Gambling? I love it, you")
        |> mes(
          "know? Eh, I don't win all the time, but I love it the most when I leave with more Zeny than I came in with! Hahaha!"
        )
        |> close()

      {ctx, 4} ->
        ctx |> mes("[Royal Myst]") |> hobby_brushoff()

      {ctx, _} ->
        ctx
    end
  end

  defp investigation(ctx) do
    cond do
      witnesses_questioned?(ctx) ->
        ctx |> grumble() |> next() |> investigation_menu()

      get_char_var(ctx, :god_megin_6, 0) > 0 ->
        ctx
        |> mes("[Royal Myst]")
        |> mes("Hmm?")
        |> mes("What's up?")
        |> next()
        |> investigation_menu()

      true ->
        ctx |> grumble() |> close()
    end
  end

  defp witnesses_questioned?(ctx) do
    get_char_var(ctx, :god_megin_6, 0) == 0 and get_char_var(ctx, :god_megin_5, 0) > 4 and
      get_char_var(ctx, :god_megin_4, 0) > 1 and get_char_var(ctx, :god_megin_3, 0) > 1 and
      get_char_var(ctx, :god_megin_2, 0) > 3 and get_char_var(ctx, :god_megin_1, 0) > 2
  end

  defp investigation_menu(ctx) do
    drunk = get_char_var(ctx, :god_megin_6, 0)

    if drunk < 16 do
      case select(ctx, [
             "Speak of Rebarev Doug.",
             "Speak of the 3rd squad.",
             "Talk about gambling.",
             "Discuss hobbies."
           ]) do
        {ctx, 1} -> talk_doug(ctx, drunk)
        {ctx, 2} -> talk_squad(ctx, drunk)
        {ctx, 3} -> talk_gambling(ctx, drunk)
        {ctx, 4} -> talk_hobbies(ctx, drunk)
        {ctx, _} -> ctx
      end
    else
      ctx
    end
  end

  defp talk_doug(ctx, 0) do
    ctx
    |> mes("[Royal Myst]")
    |> mes(
      "Huh? What's that old geezer want this time? Tell 'em I'm fine, dandy even! Why the hell does he keep sending people..."
    )
    |> set_char_var(:god_megin_6, 1)
    |> close()
  end

  defp talk_doug(ctx, drunk) when drunk in 1..14 do
    ctx
    |> mes("[Royal Myst]")
    |> mes(
      "What the hell!? Stop talking about him! I never wanna see his face again! Tell him to leave me the hell alone!"
    )
    |> close()
  end

  defp talk_doug(ctx, drunk) when drunk > 14 do
    ctx
    |> mes("[Royal Myst]")
    |> mes("Damn geezer...")
    |> mes(
      "How much is he being paid for studying what we all found?! Eh, somehow, I don't care as long as"
    )
    |> mes("he pays me...")
    |> next()
    |> mes("[Royal Myst]")
    |> mes("Yeah...")
    |> mes("I just don't")
    |> mes("care anymore.")
    |> close()
  end

  defp talk_doug(ctx, drunk), do: talk_squad(ctx, drunk)

  defp talk_squad(ctx, drunk) when drunk < 15, do: ctx |> old_squad() |> close()

  defp talk_squad(ctx, _drunk) do
    ctx
    |> mes("[Royal Myst]")
    |> mes("1st Squad?")
    |> mes("Don't know, don't care~")
    |> mes("Do I look like a stupid Crusader?")
    |> close()
  end

  defp talk_gambling(ctx, drunk) when drunk < 15 do
    ctx
    |> mes("[Royal Myst]")
    |> mes("Gambling? ! Oh man...")
    |> mes("I love gambling, you know!")
    |> mes("Heh, but I haven't been lucky enough to win yet. Hahaha~!")
    |> close()
  end

  defp talk_gambling(ctx, _drunk) do
    ctx
    |> mes("[Royal Myst]")
    |> mes("Gambling...!")
    |> mes("Heh heh! Some risks you take,")
    |> mes("and others you really shouldn't.")
    |> mes("I can't help but feel sorry for that guy, E--")
    |> next()
    |> mes("[Royal Myst]")
    |> mes("Ergh...?")
    |> mes(
      "Damn, I can never remember his name. You'd think I wouldn't forget the guy whose rap I'm taking but... Eh, I'll remember once I sober up."
    )
    |> next()
    |> mes("[Royal Myst]")
    |> mes(
      "Hey, what do you think happens to Crusaders when they're framed and killed, huh? Where exactly do they go? Niflheim, Vahalla...?"
    )
    |> set_char_var(:god_eremes, 20)
    |> close()
  end

  defp talk_hobbies(ctx, 0), do: hobby_brushoff(ctx)

  defp talk_hobbies(ctx, drunk) when drunk in 1..14 do
    if count_item(ctx, 970) > 0 do
      ctx
      |> mes("[Royal Myst]")
      |> mes("Speaking of which,")
      |> mes("I haven't had a drink")
      |> mes("for a looong time. Almost")
      |> mes("a couple hours now.")
      |> next()
      |> mes("[Royal Myst]")
      |> mes("Oooh, looks like you've got a tasty beverage I can enjoy. Bwahahaha! Gimmie~!")
      |> next()
      |> mes("^3355FFBefore you can even think,")
      |> mes(
        "Royal Myst dips his hand into your inventory and helps himself to an Alcohol.^000000"
      )
      |> delitem(970, 1)
      |> set_char_var(:god_megin_6, drunk + 2)
      |> close()
    else
      ctx
      |> mes("[Royal Myst]")
      |> mes(
        "Why mention it? You gonna bring me something I'll like? Cuz I'm more than willing to take it! Bwahahaha!"
      )
      |> close()
    end
  end

  defp talk_hobbies(ctx, drunk) when drunk > 14 do
    ctx
    |> mes("[Royal Myst]")
    |> mes(
      "^333333*Hiccup*^000000 Oh yeah, this is the stuff. Not like that imitation junk they've been serving at the Bars nowadays..."
    )
    |> next()
    |> mes("[Royal Myst]")
    |> mes("Hey! There anything you wanna")
    |> mes("know about me? You did me a favor, so I'll tell you anything! Eeeeeverythiiing~~!!")
    |> close()
  end

  defp talk_hobbies(ctx, _drunk), do: ctx

  defp old_squad(ctx) do
    ctx
    |> mes("[Royal Myst]")
    |> mes(
      "1st Squad? Yeah, I used to be in that. All of us in the squad used to be real good buddies too."
    )
    |> next()
    |> mes("[Royal Myst]")
    |> mes("Zan.Huadoku, Cuaque Donon,")
    |> mes("Jack O, Emma Searth and The Nineball. Yeah... I wonder what they're all up to?")
  end

  defp hobby_brushoff(ctx) do
    ctx
    |> mes("Hobbies?")
    |> mes("What, you comin'")
    |> mes("on to me?")
    |> next()
    |> mes("[Royal Myst]")
    |> mes(
      "A man's hobby is drinking, or didn't you know that? I happen to be real good at it too! Mwahahaha!"
    )
    |> close()
  end
end
