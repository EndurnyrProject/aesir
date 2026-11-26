defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.MegingardSeal.SuspiciousMan do
  @moduledoc """
  Cuaque Donon, a broken former 1st Squad Crusader hiding in the Rogue Guild, is one of the
  witnesses of the Megingjard Seal quest.

  ## Behavior

  - Outside the Megingjard seal phase, or before the investigation starts, he panics and sends
    the player away.
  - During his part of the investigation he only calms down if the player carries a doll to
    talk through.
  - Asking how he has been and then about the Inn Maid makes him recall his sister's plans,
    advancing his part of the quest.
  - Asked about the final mission, he remembers the Megingjard; saying its name aloud scares him
    and resets his progress, while listening quietly earns his last memory.
  - Afterwards he only repeats that memory.

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
        map: "in_rogue",
        x: 243,
        y: 61,
        dir: 0,
        sprite: 748,
        name: "Suspicious Man",
        scope: :shared,
        unique_name: "Suspicious Man#megin"
      }
    ]

  @dolls [
    {740, "Puppet"},
    {741, "Poring Doll"},
    {742, "Chonchon Doll"},
    {743, "Spore Doll"},
    {750, "Baphomet Doll"},
    {751, "Osiris Doll"},
    {752, "Rocker Doll"},
    {753, "Yoyo Doll"},
    {754, "Racoon Doll"},
    {7206, "Black Cat Doll"},
    {7212, "Hung Doll"}
  ]

  @impl true
  def on_talk(ctx) do
    eremes = get_char_var(ctx, :god_eremes, 0)

    cond do
      not seal_open?(ctx) ->
        ctx
        |> startled()
        |> next()
        |> mes("[Cuaque Donon]")
        |> mes("Wahhhhh...!")
        |> mes("My head!")
        |> mes("It's hurting so bad!")
        |> mes("I'm so s-scared!")
        |> close()

      eremes == 18 ->
        ctx |> get_away() |> close()

      eremes > 18 ->
        investigation(ctx, get_char_var(ctx, :god_megin_2, 0))

      true ->
        ctx
    end
  end

  defp seal_open?(ctx) do
    get_server_var(ctx, "God1", 0) >= get_server_temp_var(ctx, "god_check1", 0) and
      get_server_var(ctx, "God2", 0) < get_server_temp_var(ctx, "god_check2", 0)
  end

  defp startled(ctx) do
    ctx
    |> mes("[Cuaque Donon]")
    |> mes("Wh-who are you?!")
    |> mes("How the hell did")
    |> mes("you get in here?!")
  end

  defp get_away(ctx) do
    ctx
    |> startled()
    |> mes("Get away from me!")
    |> mes("Geeeet awwwway!")
  end

  defp investigation(ctx, stage) when stage in 1..3 do
    ctx =
      ctx
      |> get_away()
      |> next()
      |> mes(
        "^3355FFYou try your best to calm him down and to tell him what you've found in the document.^000000"
      )
      |> next()

    case carried_doll(ctx) do
      nil ->
        ctx
        |> mes("^3355FFYou must find something")
        |> mes("that can calm Cuaque Donon.^000000")
        |> next()
        |> mes("^3355FFSadly, Chaque Donon seems")
        |> mes(
          "to have regressed to a very childish mentality. Perhaps if you brought something that children like. Something that would offer them comfort...^000000"
        )
        |> close()

      doll ->
        ctx
        |> mes("^3355FFYou pulled out a #{doll}")
        |> mes("to cover your face, and wiggled its arms as if it were talking.^000000")
        |> next()
        |> mes("^3355FFChaque Donon nodded his head")
        |> mes(
          "and happily sucked his thumb. It saddens you to see a former Crusader reduced to this state.^000000"
        )
        |> next()
        |> select([
          "Ask him about the Inn Maid.",
          "Ask him how he's been doing.",
          "Ask about 1st Squad's Final Mission."
        ])
        |> answer(stage)
    end
  end

  defp investigation(ctx, 4) do
    ctx
    |> mes("[Cuaque Donon]")
    |> mes(
      "I remember after we found Megingjard. One of us in the squad had a argument with our old leader. I was keeping night watch and happened to hear it. I think our leader was out of line..."
    )
    |> next()
    |> mes("[Cuaque Donon]")
    |> mes("Ergh...")
    |> mes("I can't remember")
    |> mes("more than that...")
    |> next()
    |> mes("[Cuaque Donon]")
    |> mes("I'm getting sleepy")
    |> mes("and my head hurts.")
    |> mes("Let me rest now...")
    |> close2()
  end

  defp investigation(ctx, _stage), do: ctx |> get_away() |> close2()

  defp carried_doll(ctx) do
    Enum.find_value(@dolls, fn {item_id, name} -> if count_item(ctx, item_id) > 0, do: name end)
  end

  defp answer({ctx, 1}, stage) do
    ctx =
      ctx
      |> mes("[Cuaque Donon]")
      |> mes("S-she's my sister.")
      |> mes("And she's also a Rogue.")
      |> mes("When I was retired from service....")
      |> next()
      |> mes("[Cuaque Donon]")
      |> mes("...")
      |> mes("......")
      |> next()
      |> mes("[Cuaque Donon]")
      |> mes("My family always expected")
      |> mes(
        "too much of me. That's why I used to be a Crusader. I mean, they're paid well and respected."
      )
      |> next()
      |> mes("[Cuaque Donon]")
      |> mes(
        "When I retired, my sister was so mad. She's the only one I can depend upon, but now that I've messed up my life like this..."
      )
      |> next()
      |> mes("[Cuaque Donon]")
      |> mes("But even after yelling at me, and saying I was worthless, she got ")
      |> mes("me a job at her Inn anyway.")
      |> next()
      |> mes("[Cuaque Donon]")
      |> mes("I've been working there,")
      |> mes(
        "living a quiet life. But now, for some reason, a lot of people want to talk to me about something important."
      )
      |> next()
      |> mes("[Cuaque Donon]")
      |> mes(
        "I don't know what I said or did, but I think when I gave them the right answer, after I could finally remember something, they tried to hurt me."
      )
      |> next()
      |> mes("[Cuaque Donon]")
      |> mes("So now my sister's been hiding")
      |> mes(
        "me here. It's boring and lonely, and the guy downstairs is always yelling at me to leave."
      )
      |> next()
      |> mes("[Cuaque Donon]")
      |> mes("Even the Rogue Guild that")
      |> mes(
        "my sister's a part of comes in sometimes to yell at me. They all want me to tell them something I'm supposed to know!"
      )
      |> next()
      |> mes("[Cuaque Donon]")
      |> mes("But I can't remember anything!")
      |> mes("This place is safe from dangerous people, but I don't know for how long.")
      |> next()
      |> mes("[Cuaque Donon]")
      |> mes(
        "Even my sister says I have to tell the Rogue Guild what I should know, or they won't protect us anymore."
      )
      |> next()
      |> mes("[Cuaque Donon]")
      |> mes("She looked really sad when she")
      |> mes("said that. I don't want to let her down or make her upset. She's")
      |> mes("all I have left...")

    if stage == 2 do
      ctx
      |> next()
      |> mes("[Cuaque Donon]")
      |> mes("Oh, I do remember something!")
      |> mes("My sister told me not to tell anyone, but I'm gonna tell you...")
      |> next()
      |> mes("^3355FFCuaque Donon")
      |> mes("whispers into your ears.^000000")
      |> next()
      |> mes("[Cuaque Donon]")
      |> mes(
        "^666666She said the Rogue Guild wants something from me. So she's gonna send to me to good people that we can trust and can help me.^000000"
      )
      |> next()
      |> mes("[Cuaque Donon]")
      |> mes(
        "^666666Still, this is the safest place for me for a while. But I'm always ready to run away if I have to.^000000"
      )
      |> set_char_var(:god_megin_2, 3)
      |> close()
    else
      close(ctx)
    end
  end

  defp answer({ctx, 2}, stage) do
    ctx =
      ctx
      |> mes("[Cuaque Donon]")
      |> mes("How have I been doing?")
      |> mes("Lots of people have been coming")
      |> mes("to see me. They all want me to tell them something I don't even know!")
      |> next()
      |> mes("[Cuaque Donon]")
      |> mes("The Rogue Guild promised to")
      |> mes(
        "protect me, but they scare the hell out of me sometimes by coming out of the floor all of a sudden."
      )
      |> next()
      |> mes("[Cuaque Donon]")
      |> mes("Oh, and my sister said she's")
      |> mes(
        "gonna complain to my old boss about something. She said I used to be fine, but now that I've retired, I'm not the same anymore."
      )
      |> next()
      |> mes("[Cuaque Donon]")
      |> mes(
        "But my old boss from when I was a Crusader doesn't wanna meet my sister. So she's gonna ask help from other Rogues to spread some rumors..."
      )
      |> next()
      |> mes("[Cuaque Donon]")
      |> mes(
        "Like anyone who works as a Crusader under my old boss will end up like me. You know... broken."
      )

    if stage == 1 do
      ctx |> set_char_var(:god_megin_2, 2) |> close()
    else
      close(ctx)
    end
  end

  defp answer({ctx, 3}, stage) do
    ctx =
      ctx
      |> mes("[Cuaque Donon]")
      |> mes("I don't know...")
      |> mes("I can't even remember.")

    if stage == 3 do
      ctx
      |> next()
      |> mes("[Cuaque Donon]")
      |> mes("Wait, that's right!")
      |> mes("^0000FFMegingjard^000000! Right.")
      |> mes("We found it, and")
      |> mes("we knew what it was")
      |> mes("just by looking at it!")
      |> next()
      |> recall_megingjard()
    else
      close2(ctx)
    end
  end

  defp answer({ctx, _choice}, _stage), do: ctx

  defp recall_megingjard(ctx) do
    if Enum.random(1..10) > 4 do
      case select(ctx, [
             "^FF0000Megingjard^000000!",
             "^FFFFFFListen to him quietly^000000."
           ]) do
        {ctx, 1} -> outburst(ctx)
        {ctx, 2} -> last_memory(ctx)
        {ctx, _} -> ctx
      end
    else
      case select(ctx, [
             "^FF0000Megingjard^000000!",
             "^FFFFFFMegingjard!^000000.",
             "^FFFFFFListen to him quitely^000000"
           ]) do
        {ctx, choice} when choice in [1, 2] -> outburst(ctx)
        {ctx, 3} -> last_memory(ctx)
        {ctx, _} -> ctx
      end
    end
  end

  defp outburst(ctx) do
    ctx
    |> mes("[Cuaque Donon]")
    |> mes("Waaaaaaaah~!")
    |> mes("You're the same")
    |> mes("as all the others!")
    |> mes("Go away from me!")
    |> set_char_var(:god_megin_2, 0)
    |> close()
  end

  defp last_memory(ctx) do
    ctx
    |> mes("[Cuaque Donon]")
    |> mes(
      "I remember after we found it. One of us in the squad had a argument with our old leader. I was keeping night watch and happened to hear it. I think our leader was out of line..."
    )
    |> next()
    |> mes("[Cuaque Donon]")
    |> mes("Ergh...")
    |> mes("I can't remember")
    |> mes("more than that...")
    |> set_char_var(:god_megin_2, 4)
    |> close()
  end
end
