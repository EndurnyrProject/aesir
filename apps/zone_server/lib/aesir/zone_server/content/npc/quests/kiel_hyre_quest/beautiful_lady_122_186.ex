defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.BeautifulLady122186 do
  @moduledoc """
  Allysia guides the rescue of Kiel Hyre from the robot factory.

  ## Behavior

  - Explains the factory and provides a red keycard for the rescue.
  - Receives Kiel Hyre’s metal fragment, then collects keycards and directs the player to the mansion.
  - Transfers players into the factory or outside according to quest progress.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "kh_school",
        x: 122,
        y: 186,
        dir: 4,
        sprite: 894,
        name: "Beautiful Lady",
        scope: :shared,
        unique_name: "Beautiful Lady#kh6"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if checkweight(ctx, [{7496, 1}]) == 0 do
      ctx
      |> mes("^3355FFJust a second...")
      |> mes("You're carrying too")
      |> mes("many items with you")
      |> mes("right now, so you'll")
      |> mes("need to free up more")
      |> mes("Inventory space first...^000000")
      |> close()
    else
      ctx |> cutin("kh_ellisia", 2) |> discuss_rescue()
    end
  end

  defp discuss_rescue(ctx) do
    quest = get_char_var(ctx, :KielHyreQuest, 0)

    cond do
      quest < 38 ->
        ctx
        |> mes("[??????]")
        |> mes("This is private property.")
        |> mes("Please leave immediately!")
        |> close()
        |> cutin("kh_ellisia", 255)
        |> warp("yuno_fild08", 73, 172)

      quest <= 38 ->
        introduce_rescue(ctx)

      quest == 40 ->
        ctx
        |> mes("[Allysia]")
        |> mes("I can still detect")
        |> mes("Kiel Hyre's heartbeat,")
        |> mes("but his sone Kiehl might")
        |> mes("do something desperate to")
        |> mes("him soon. Please locate Kiel")
        |> mes("Hyre before that can happen!")
        |> close()
        |> cutin("", 255)
        |> warp("kh_dun01", 22, 216)

      quest == 42 ->
        receive_fragment(ctx)

      quest == 44 ->
        collect_keycards(ctx)

      quest >= 44 ->
        ctx
        |> mes("[Allysia]")
        |> mes("I understand that this")
        |> mes("is sudden, and I'm not")
        |> mes("giving you a thorough")
        |> mes("explanation, but something")
        |> mes("horrible will happen if i don't")
        |> mes("hurry as quickly as possible.")
        |> close()
        |> warp("yuno_fild08", 73, 172)
        |> cutin("", 255)

      true ->
        ctx
    end
  end

  defp introduce_rescue(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Allysia]")
      |> mes("Friend of prototype Elly,")
      |> mes("I welcome you. As you may")
      |> mes("have figured out, I need your")
      |> mes("help. Kiel Hyre is being held")
      |> mes("somewhere inside this factory.")
      |> next()
      |> mes("[Allysia]")
      |> mes("It is imperative that")
      |> mes("you search for Kiel Hyre")
      |> mes("and rescue him as soon")
      |> mes("as you possibly can!")
      |> next()
      |> select(["What is this factory?", "What happened to ^FF0000Kiel Hyre^000000?"])

    case choice do
      1 ->
        ctx
        |> mes("[Allysia]")
        |> mes("This factory is part of")
        |> mes("the Kiel Hyre Foundation's")
        |> mes("secret business where humanoid")
        |> mes("robots are manufactured. Myself,")
        |> mes("and all of the academy's students")
        |> mes("are actually robots, not humans.")
        |> next()
        |> mes("[Allysia]")
        |> mes("The Kiel Hyre Foundation's")
        |> mes("ultimate goal is to develop")
        |> mes("superior robots that will help")
        |> mes("human society. As robots, we")
        |> mes("can handle tasks that are too")
        |> mes("dangerous or difficult for humans.")
        |> close()
        |> cutin("", 255)

      2 ->
        ctx
        |> mes("[Allysia]")
        |> mes("^3355FFKiehl^000000 has proceeded to")
        |> mes("perform abnormal modifications")
        |> mes("to the humanoid robots. This")
        |> mes("has been reported to Kiel Hyre,")
        |> mes("who has left to stop Kiehl.")
        |> mes("However, Hyre hasn't returned.")
        |> next()
        |> mes("[Allysia]")
        |> mes("Fearing that Kiehl would")
        |> mes("break me, Kiel Hyre brought")
        |> mes("a copy of me instead. I can still")
        |> mes("detect Kiel Hyre's heartbeat,")
        |> mes("so he should be alright, but his")
        |> mes("own son might harm him soon.")
        |> next()
        |> mes("[Allysia]")
        |> mes("Take this Keycard")
        |> mes("which will enable you")
        |> mes("to enter the secret areas")
        |> mes("inside this factory. If you")
        |> mes("locate Kiel Hyre, please")
        |> mes("let me know right away.")
        |> give_item(7496, 1)
        |> set_char_var(:KielHyreQuest, 40)
        |> close()
        |> cutin("", 255)

      _ ->
        ctx
    end
  end

  defp receive_fragment(ctx) do
    ctx
    |> mes("[Allysia]")
    |> mes("Have you already")
    |> mes("located Kiel Hyre?")
    |> next()
    |> mes("^3355FFYou tell Allysia where^000000")
    |> mes("^3355FFKiel Hyre has been locked^000000")
    |> mes("^3355FFup, and give her the metal^000000")
    |> mes("^3355FFfragment that Kiel Hyre handed^000000")
    |> mes("^3355FFto you. She took fragment^000000")
    |> mes("^3355FFand wore it around her wrist.^000000")
    |> next()
    |> mes("[Allysia]")
    |> mes("...Kiel Hyre's secret code")
    |> mes("confirmed. B_2_3 area.")
    |> mes("Vital signs are normal.")
    |> mes("Envelope received. Sending")
    |> mes("modified Puppet Designs...")
    |> next()
    |> mes("[Allysia]")
    |> mes("Alright, I've received")
    |> mes("Kiel Hyre's orders, and")
    |> mes("must carry them out...")
    |> delitem(7497, 1)
    |> set_char_var(:KielHyreQuest, 44)
    |> close()
    |> cutin("", 255)
  end

  defp collect_keycards(ctx) do
    ctx
    |> mes("[Allysia]")
    |> mes("Alright, I have a mission")
    |> mes("to carry out for Kiel Hyre,")
    |> mes("and I don't have much time.")
    |> mes("Let me give you some specific")
    |> mes("instructions very quickly.")
    |> next()
    |> mes("[Allysia]")
    |> mes("Firstly, I need to take your")
    |> mes("keycards for security reasons.")
    |> mes("Secondly, meet me at the Kiel")
    |> mes("Hyre Mansion in Lighthalzen.")
    |> mes("Present the Golden Key to")
    |> mes("be admitted to the premises.")
    |> delitem(7492, 1)
    |> delitem(7495, 1)
    |> delitem(7496, 1)
    |> set_char_var(:KielHyreQuest, 46)
    |> next()
    |> mes("[Allysia]")
    |> mes("I understand that this")
    |> mes("is sudden, and I'm not")
    |> mes("giving you a thorough")
    |> mes("explanation, but something")
    |> mes("horrible will happen if I don't")
    |> mes("hurry as quickly as possible.")
    |> close()
    |> warp("yuno_fild08", 73, 172)
    |> cutin("", 255)
  end
end
