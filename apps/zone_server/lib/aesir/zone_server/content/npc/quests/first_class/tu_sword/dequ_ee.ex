defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuSword.DequEe do
  @moduledoc """
  Dequ'ee, the Knight in Geffen who leads the murder investigation of the Swordman training quest.

  ## Behavior

  - Novices are pointed towards the Swordman job; advanced Swordman classes and other jobs
    only get small talk.
  - Expects Shurank's exact message ("murderer", "who he is", "what are we"); the right
    wording grants experience, advances the quest and warps the player back to Izlude, any
    other combination is rejected.
  - Later sends the player to Morocc to interrogate four suspects, then asks for each
    suspect's code in turn; all four correct codes advance the quest.
  - Lets the player arrange the codes in an order: the two correct orders advance the quest,
    then naming Bankley as the murderer grants experience and warps the player near Morocc.
  - After Bankley's death is reported, closes the case, advances the quest and warps the
    player back to Izlude.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Jukka (fix up)
    - Lupus
    - SinSloth
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "geffen", x: 154, y: 143, dir: 3, sprite: 734, name: "Dequ'ee", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @codes %{
    muetro: "ConBanfoevidehi",
    hans: "victkleyundncem",
    geil: "TheisWesomeof",
    bankley: "hekdlfiDrindkelsd"
  }

  # Third-code prompts per first suspect, in select order. Each leaf is
  # {names line 1, names line 2, code order, quest step when the order is right}.
  @after_muetro [
    {"Hans...?", ["Geil", "Bankley"],
     [
       {"Muetro, Hans,", "Geil and Bankley.", [:muetro, :hans, :geil, :bankley], nil},
       {"Muetro, Hans,", "Geil and Bankley.", [:muetro, :hans, :bankley, :geil], nil}
     ]},
    {"Geil's...?", ["Hans", "Bankley"],
     [
       {"Muetro, Geil,", "Hans and Bankley.", [:muetro, :geil, :hans, :bankley], nil},
       {"Muetro, Geil,", "Bankley and Hans.", [:muetro, :geil, :bankley, :hans], nil}
     ]},
    {"Bankley's...?", ["Hans", "Geil"],
     [
       {"Muetro, Bankley,", "Hans and Geil.", [:muetro, :bankley, :hans, :geil], nil},
       {"Muetro, Bankley,", "Geil and Hans.", [:muetro, :bankley, :geil, :hans], nil}
     ]}
  ]

  @after_hans [
    {"Muestro's...?", ["Geil", "Bankley"],
     [
       {"Hans, Muetro,", "Geil and Bankley.", [:hans, :muetro, :geil, :bankley], nil},
       {"Hans, Muetro,", "Bankley and Geil.", [:hans, :muetro, :bankley, :geil], nil}
     ]},
    {"Geil's...?", ["Muetro", "Bankley"],
     [
       {"Hans, Geil,", "Muetro and Bankley.", [:hans, :geil, :muetro, :bankley], nil},
       {"Hans, Geil,", "Bankley and Muetro.", [:hans, :geil, :bankley, :muetro], nil}
     ]},
    {"Bankley's...?", ["Muetro", "Geil"],
     [
       {"Hans, Bankley,", "Muetro and Geil.", [:hans, :bankley, :muetro, :geil], nil},
       {"Hans, Bankley,", "Geil and Muetro.", [:hans, :bankley, :geil, :muetro], nil}
     ]}
  ]

  @after_geil [
    {"Muestro's...?", ["Hans", "Bankley"],
     [
       {"Geil, Muetro,", "Hans and Bankley.", [:geil, :muetro, :hans, :bankley], 17},
       {"Geil, Muetro,", "Bankley and Hans.", [:geil, :muetro, :bankley, :hans], nil}
     ]},
    {"Han's...?", ["Muetro", "Bankley"],
     [
       {"Geil, Hans,", "Muetro and Bankley.", [:geil, :hans, :muetro, :bankley], nil},
       {"Geil, Hans,", "Bankley and Muetro.", [:geil, :hans, :bankley, :muetro], nil}
     ]},
    {"Bankley's...?", ["Muetro", "Hans"],
     [
       {"Geil, Bankley,", "Muetro and Hans.", [:geil, :bankley, :muetro, :hans], nil},
       {"Geil, Bankley,", "Hans and Muetro.", [:geil, :bankley, :hans, :muetro], nil}
     ]}
  ]

  @after_bankley [
    {"Muestro's...?", ["Hans", "Geil"],
     [
       {"Bankley, Muetro,", "Hans and Geil.", [:bankley, :muetro, :hans, :geil], nil},
       {"Bankley, Muetro,", "Geil and Hans.", [:bankley, :muetro, :geil, :hans], nil}
     ]},
    {"Hans's...?", ["Muetro", "Geil"],
     [
       {"Bankley, Hans,", "Muetro and Geil.", [:bankley, :hans, :muetro, :geil], nil},
       {"Bankley, Hans,", "Geil and Muetro.", [:bankley, :hans, :geil, :muetro], nil}
     ]},
    {"Geil's...?", ["Muetro", "Hans"],
     [
       {"Bankley, Geil,", "Muetro, and Hans.", [:bankley, :geil, :muetro, :hans], 18},
       {"Bankley, Geil,", "Hans, Muetro.", [:bankley, :geil, :hans, :muetro], nil}
     ]}
  ]

  # Follow-up questions in select order: {question lines, "Why are we..." quote,
  # "What are we..." quote, whether the "What are we..." wording is Shurank's message}.
  @killer_follow_ups [
    {["Did you find", "out who he is?"],
     [
       "'What happened to the killer?",
       "Did you find out who he is? If you did, why are we sitting around, doing nothing?'"
     ],
     [
       "'What happened to the killer?",
       "Did you find out who he is? If you did, what are we supposed to do now?'"
     ], false},
    {["Did you figure out", "who's behind all this?"],
     [
       "'What happened to the killer?",
       "Did you figure out who's behind all this? If you did, why are we sitting around, doing nothing?'"
     ],
     [
       "'What happened to the killer?",
       "Did you figure out who's behind all this? If you did, what are we supposed to do now?'"
     ], false}
  ]

  @murderer_follow_ups [
    {["Did you find", "out who he is?"],
     [
       "'What happened to the",
       "murderer? Did you find",
       "out who he is? If you did,",
       "why are we sitting around,",
       "doing nothing?'"
     ],
     [
       "'What happened to the",
       "murderer? Did you find",
       "out who he is? If you did,",
       "what are we supposed to do now?'"
     ], true},
    {["Did you figure out", "who's behind all this?"],
     [
       "'What happened to the",
       "murderer? Did you figure",
       "out who's behind all this?",
       "If you did, why are we sitting around, doing nothing?'"
     ],
     [
       "'What happened to the",
       "murderer? Did you figure",
       "out who's behind all this?",
       "If you did, what are we",
       "supposed to do now?"
     ], false}
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:novice) ->
        recommend_swordman(ctx)

      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:swordman) and
          Rathena.truthy?(:erlang.band(eaclass(ctx), :erlang.bor(768, 1_048_576))) ->
        greet_fellow_swordman(ctx)

      Rathena.job_id(base_class(ctx)) != Rathena.job_id(:swordman) ->
        greet_other_class(ctx)

      true ->
        investigation(ctx, get_char_var(ctx, :tu_swordman, 0))
    end
  end

  defp recommend_swordman(ctx) do
    ctx
    |> mes("[Dequ'ee]")
    |> mes("Hey there.")
    |> mes("Frustrated with")
    |> mes("being a Novice?")
    |> mes("I know, I know,")
    |> mes("we've all been")
    |> mes("there once.")
    |> next()
    |> mes("[Dequ'ee]")
    |> mes("If you want to become stronger,")
    |> mes(
      "why don't you consider becoming a Swordman? It'll require discipline on your part, but that job will shape you into a tough warrior."
    )
    |> next()
    |> mes("[Dequ'ee]")
    |> mes("It's ultimately your decision.")
    |> mes(
      "I don't know how you want to live your life, but you should give the Swordman job some serious thought..."
    )
    |> close()
  end

  defp greet_fellow_swordman(ctx) do
    ctx
    |> mes("[Dequ'ee]")
    |> mes("Ah...")
    |> mes("A fellow sword wielder!")
    |> mes("How have you been doing?")
    |> next()
    |> mes("[Dequ'ee]")
    |> mes("There must be many who must")
    |> mes(
      "depend on the strength of your blade. It's an awesome responsibility, but we can never let our allies down in battle..."
    )
    |> close()
  end

  defp greet_other_class(ctx) do
    ctx
    |> mes("[Dequ'ee]")
    |> mes("Hello there.")
    |> mes("Not a fan of swords, are you?")
    |> mes("Well, if you were, we'd have")
    |> mes("something to talk about.")
    |> next()
    |> mes("[Dequ'ee]")
    |> mes("Yeah.")
    |> mes("Not much")
    |> mes("conversation")
    |> mes("happening here.")
    |> mes("Pretty boring...")
    |> close()
  end

  defp investigation(ctx, step) when step > 20, do: case_closed(ctx)
  defp investigation(ctx, 20), do: report_bankley_death(ctx)
  defp investigation(ctx, 19), do: hurry_to_bankley(ctx)
  defp investigation(ctx, step) when step in [17, 18], do: name_the_murderer(ctx, step)
  defp investigation(ctx, 16), do: arrange_codes(ctx)
  defp investigation(ctx, 15), do: collect_codes(ctx)
  defp investigation(ctx, 14), do: remind_interrogation(ctx)
  defp investigation(ctx, 13), do: start_investigation(ctx)
  defp investigation(ctx, step) when step > 7 and step < 13, do: still_training(ctx)
  defp investigation(ctx, 7), do: remind_reply(ctx)
  defp investigation(ctx, 6), do: receive_message(ctx)
  defp investigation(ctx, _step), do: ask_business(ctx)

  defp ask_business(ctx) do
    ctx |> mes("Hmm...?") |> mes("Do you have any") |> mes("business with me?") |> close()
  end

  defp case_closed(ctx) do
    ctx
    |> mes("[Dequ'ee]")
    |> mes("I hope you continue")
    |> mes("to train yourself in")
    |> mes("the ways of the sword.")
    |> mes("There's an art to")
    |> mes("wielding a blade...")
    |> close()
  end

  defp report_bankley_death(ctx) do
    ctx
    |> mes("[Dequ'ee]")
    |> mes("Huh...?")
    |> mes("Aren't you supposed")
    |> mes("to keep an eye on Bankley?")
    |> mes("What happened?")
    |> next()
    |> mes("[Dequ'ee]")
    |> mes("Suicide...?")
    |> mes("Are you serious?!")
    |> mes("But there's no need to kill")
    |> mes("himself if he suspected that he's been caught. Something shady's going on here!")
    |> next()
    |> mes("[Dequ'ee]")
    |> mes("Well, you've done a good job.")
    |> mes(
      "As for the other three suspects, I'll make sure that they're monitored by members of the Swordman Association."
    )
    |> next()
    |> mes("[Dequ'ee]")
    |> mes("Still, I don't think we'll learn anything new from those three.")
    |> mes("It looks like this case is closed for now. Once again, thanks for your help.")
    |> next()
    |> mes("[Dequ'ee]")
    |> mes("Why don't you report back to Shurank now? I guess he still")
    |> mes("wants to show you the ropes of Swordmanship.")
    |> set_char_var(:tu_swordman, 21)
    |> changequest(8226, 8227)
    |> close()
    |> warp_to_izlude()
  end

  defp hurry_to_bankley(ctx) do
    ctx
    |> mes("[Dequ'ee]")
    |> mes("What are still doing here?")
    |> mes("Hurry and check on Bankley!")
    |> mes("There's no telling what")
    |> mes("he might be up to!")
    |> close()
  end

  defp name_the_murderer(ctx, step) do
    ctx = mes(ctx, "[Dequ'ee]")

    ctx =
      if step == 17 do
        ctx
        |> mes("TheisWesomeof")
        |> mes("ConBanfoevidehi")
        |> mes("victkleyundncem")
        |> mes("hekdlfiDrindkelsd")
        |> next()
      else
        ctx
        |> mes("hekdlfiDrindkelsd")
        |> mes("TheisWesomeof")
        |> mes("ConBanfoevidehi")
        |> mes("victkleyundncem")
        |> next()
      end

    {ctx, suspect} =
      ctx
      |> mes("[Dequ'ee]")
      |> mes("I get it now!")
      |> mes(
        "This is a complex transposition cipher in which we remove one person's code from the rest of them. So who do you think is"
      )
      |> mes("the murderer?")
      |> next()
      |> select(["Hans", "Bankley", "Geil", "Muetro"])

    case suspect do
      1 -> reject_suspect(ctx, "Hans...?")
      2 -> accuse_bankley(ctx)
      3 -> reject_suspect(ctx, "Geil...?")
      4 -> reject_suspect(ctx, "Muetro...?")
      _ -> ask_business(ctx)
    end
  end

  defp reject_suspect(ctx, suspect_line) do
    ctx
    |> mes("[Dequ'ee]")
    |> mes(suspect_line)
    |> mes("That can't be right.")
    |> mes("It doesn't match with")
    |> mes("this algorithm I just")
    |> mes("made up. You've got")
    |> mes("to try it again!")
    |> close()
  end

  defp accuse_bankley(ctx) do
    ctx =
      ctx
      |> mes("[Dequ'ee]")
      |> mes("Bankley...?")
      |> mes("Hey, you might be")
      |> mes("right. Let me check...")
      |> next()
      |> mes("[Dequ'ee]")
      |> mes(
        "Yeah, when you take out Bankley's password from the rest of them and read it all in the right order..."
      )
      |> next()
      |> mes("[Dequ'ee]")
      |> mes(
        "Alright! It looks like Bankley is the murderer! Although we can't trust this 100%, this evidence is pretty conclusive."
      )
      |> next()
      |> mes("[Dequ'ee]")
      |> mes(
        "Hurry over to Morocc and monitor Bankley in case he does anything desperate. If something happens, report to me right away!"
      )
      |> set_char_var(:tu_swordman, 19)
      |> changequest(8224, 8225)

    ctx =
      if Rathena.truthy?(checkre(ctx, 3)) do
        getexp(ctx, 162, 0)
      else
        getexp(ctx, 1620, 0)
      end

    ctx |> close() |> warp("moc_fild07", 359, 201)
  end

  defp arrange_codes(ctx) do
    {ctx, first} =
      ctx
      |> mes("[Dequ'ee]")
      |> mes(
        "I guess these codes need to be arranged in a certain order before we can figure out its secrets."
      )
      |> next()
      |> mes("[Dequ'ee]")
      |> mes(
        "Hm, you guess the order and I'll try to formulate a cryptanalysis based on your guess."
      )
      |> next()
      |> select(["Muetro", "Hans", "Geil", "Bankley"])

    case first do
      1 -> choose_second_code(ctx, "Okay, Muetro's", ["Hans", "Geil", "Bankley"], @after_muetro)
      2 -> choose_second_code(ctx, "Okay, Hans's", ["Muetro", "Geil", "Bankley"], @after_hans)
      3 -> choose_second_code(ctx, "Okay, Geil's", ["Muetro", "Hans", "Bankley"], @after_geil)
      4 -> choose_second_code(ctx, "Okay, Bankley's", ["Muetro", "Hans", "Geil"], @after_bankley)
      _ -> ask_business(ctx)
    end
  end

  defp choose_second_code(ctx, first_line, options, third_code_prompts) do
    {ctx, second} =
      ctx
      |> mes("[Dequ'ee]")
      |> mes(first_line)
      |> mes("code is what we'll")
      |> mes("use first. Now, whose")
      |> mes("code do you think")
      |> mes("should go second?")
      |> next()
      |> select(options)

    if second in [1, 2, 3] do
      choose_third_code(ctx, Enum.drop(third_code_prompts, second - 1))
    else
      ask_business(ctx)
    end
  end

  # A cancelled third-code prompt falls through to the next one, as in the original switch.
  defp choose_third_code(ctx, []), do: ask_business(ctx)

  defp choose_third_code(ctx, [{second_line, options, [first_leaf, second_leaf]} | rest]) do
    {ctx, third} =
      ctx
      |> mes("[Dequ'ee]")
      |> mes(second_line)
      |> mes("Alright, then")
      |> mes("the person with")
      |> mes("the third code")
      |> mes("would be...?")
      |> next()
      |> select(options)

    case third do
      1 -> try_code_order(ctx, first_leaf)
      2 -> try_code_order(ctx, second_leaf)
      _ -> choose_third_code(ctx, rest)
    end
  end

  defp try_code_order(ctx, {names, last_names, suspects, solved_step}) do
    ctx =
      ctx
      |> mes("[Dequ'ee]")
      |> mes(names)
      |> mes(last_names)
      |> mes("So then the full")
      |> mes("code would be...")
      |> break_before_codes(suspects)
      |> mes(" ")

    suspects
    |> Enum.reduce(ctx, fn suspect, ctx -> mes(ctx, Map.fetch!(@codes, suspect)) end)
    |> next()
    |> mes("[Dequ'ee]")
    |> mes("No...")
    |> mes("There's no way")
    |> mes("I can decode it the")
    |> mes("way it is now. Let's")
    |> conclude_code_order(solved_step)
  end

  # The original script has no page break for this one order.
  defp break_before_codes(ctx, [:bankley, :hans, :geil, :muetro]), do: ctx
  defp break_before_codes(ctx, _suspects), do: ctx |> next() |> mes("[Dequ'ee]")

  defp conclude_code_order(ctx, nil), do: ctx |> mes("try another combination.") |> close()

  defp conclude_code_order(ctx, solved_step) do
    ctx
    |> mes("try... Wait!")
    |> next()
    |> mes("[Dequ'ee]")
    |> mes("I think that we")
    |> mes("can make sense of this")
    |> mes("thing! Give me a while")
    |> mes("to formulate an algorithm!")
    |> set_char_var(:tu_swordman, solved_step)
    |> close()
  end

  defp collect_codes(ctx) do
    ctx =
      ctx
      |> set_local(:"hans$", @codes.hans)
      |> set_local(:"bang$", @codes.bankley)
      |> set_local(:"mutr$", @codes.muetro)
      |> set_local(:"geil$", @codes.geil)
      |> mes("[Dequ'ee]")
      |> mes("Ah, you're back.")
      |> mes("I've just got a new")
      |> mes("lead on the possible")
      |> mes("identity of the killer.")
      |> next()
      |> mes("[Dequ'ee]")
      |> mes("I've just heard that all our suspects have pieces of some")
      |> mes(
        "sort of code. If we can put the code together and decipher it, we can figure out who the murderer might be."
      )
      |> next()
      |> mes("[Dequ'ee]")
      |> mes("Did you get all the codes")
      |> mes("from all the suspects? First,")
      |> mes("tell me the code that Hans had.")
      |> next()
      |> input_code()

    if code_matches?(ctx, :"hans$") do
      ask_bankley_code(ctx)
    else
      ctx
      |> mes("[Dequ'ee]")
      |> mes("Are you sure that's right?")
      |> mes("No, no, I don't think it is.")
      |> mes("Would you check that code and interrogate the suspects again")
      |> mes("if you need to?")
      |> close()
    end
  end

  defp ask_bankley_code(ctx) do
    ctx =
      ctx
      |> mes("[Dequ'ee]")
      |> mes("victkleyundncem?")
      |> mes("That's certainly")
      |> mes("strange sounding.")
      |> mes("Now, tell me Bankley's.")
      |> next()
      |> input_code()

    if code_matches?(ctx, :"bang$"), do: ask_muetro_code(ctx), else: doubt_code(ctx)
  end

  defp ask_muetro_code(ctx) do
    ctx =
      ctx
      |> mes("[Dequ'ee]")
      |> mes("hekdlfiDrindkelsd..")
      |> mes("What the hell is that...?")
      |> mes("It's certainly cryptic.")
      |> mes("What about Muetro's?")
      |> next()
      |> input_code()

    if code_matches?(ctx, :"mutr$"), do: ask_geil_code(ctx), else: doubt_code(ctx)
  end

  defp ask_geil_code(ctx) do
    ctx =
      ctx
      |> mes("[Dequ'ee]")
      |> mes("ConBanfoevidehi.")
      |> mes("This is going to")
      |> mes("be tough to figure")
      |> mes("out. Alright, now")
      |> mes("tell me Geil's.")
      |> next()
      |> input_code()

    if code_matches?(ctx, :"geil$") do
      ctx
      |> mes("[Dequ'ee]")
      |> mes("TheisWesomeof...")
      |> mes("Alright, great.")
      |> mes("Now all we have to")
      |> mes("do is figure out what")
      |> mes("all of this means.")
      |> next()
      |> mes("[Dequ'ee]")
      |> mes("This is going to")
      |> mes("be really difficult.")
      |> mes("Do you have any ideas?")
      |> mes("We have to figure this")
      |> mes("out, it's the only clue")
      |> mes("that we have...")
      |> set_char_var(:tu_swordman, 16)
      |> changequest(8223, 8224)
      |> close()
    else
      doubt_code(ctx)
    end
  end

  defp doubt_code(ctx) do
    ctx
    |> mes("[Dequ'ee]")
    |> mes("...Are you sure that you heard")
    |> mes("him right? Why don't you go check it out again?")
    |> close()
  end

  defp input_code(ctx) do
    {ctx, code} = input(ctx, :string)
    set_local(ctx, :"inputstr$", code)
  end

  defp code_matches?(ctx, suspect_code) do
    get_local(ctx, :"inputstr$", "") == get_local(ctx, suspect_code, "")
  end

  defp remind_interrogation(ctx) do
    ctx
    |> mes("[Dequ'ee]")
    |> mes("Didn't I ask you")
    |> mes("to interrogate the")
    |> mes("suspects over in Morocc?")
    |> mes("We need to finish this")
    |> mes("investigation as soon")
    |> mes("as possible!")
    |> close()
  end

  defp start_investigation(ctx) do
    ctx
    |> mes("[Dequ'ee]")
    |> mes("Ah, you're here!")
    |> mes("Shurank must have")
    |> mes("asked you to help me.")
    |> mes("I really appreciate that.")
    |> next()
    |> mes("[Dequ'ee]")
    |> mes(
      "As you've probably figured out, I'm currently investigating a murder. Basically, I want you to help me figure out who the killer is."
    )
    |> next()
    |> mes("[Dequ'ee]")
    |> mes("As for the victim, well, that's classified information. You understand, don't you?")
    |> next()
    |> mes("[Dequ'ee]")
    |> mes(
      "Now, I want you to go to Morocc and interrogate four suspects. Their names are ^5D478BMuetro^000000, ^5D478BGeil^000000, ^5D478BHans^000000"
    )
    |> mes("and ^5D478BBankley^000000. It shouldn't be too difficult.")
    |> next()
    |> mes("[Dequ'ee]")
    |> mes(
      "After you speak to all of them, come back and report to me. And it's especially important that you remember or write down any important clues you might get"
    )
    |> mes("from our suspects.")
    |> next()
    |> mes("[Dequ'ee]")
    |> mes(
      "Also, keep in mind that this is a special mission for the Swordman Association. So keep everything you learn a secret. Understood?"
    )
    |> next()
    |> mes("[Dequ'ee]")
    |> mes(
      "Now go and see if you can learn anything from Muetro, Geil, Hans and Bankley. We've got to figure out the killer's identity as soon as we can!"
    )
    |> next()
    |> mes("[Dequ'ee]")
    |> mes("Oh wait...")
    |> mes("Morocc is a little far. Alright, I'll drop you off somewhere")
    |> mes("near that city.")
    |> next()
    |> set_char_var(:tu_swordman, 14)
    |> changequest(8222, 8223)
    |> warp("moc_fild07", 359, 201)
    |> close()
  end

  defp still_training(ctx) do
    ctx
    |> mes("[Dequ'ee]")
    |> mes("Hmm...")
    |> mes("Still receiving")
    |> mes("special training")
    |> mes("from Shurank?")
    |> next()
    |> mes("[Dequ'ee]")
    |> mes("That's great.")
    |> mes(
      "Swordmen nowadays are getting sloppier and sloppier. Someone has to keep the new guys in line and on their toes!"
    )
    |> close()
  end

  defp remind_reply(ctx) do
    ctx
    |> mes("[Dequ'ee]")
    |> mes("What are you")
    |> mes("still doing here?")
    |> mes("Go and deliver my")
    |> mes("message to Shurank.")
    |> next()
    |> mes("[Dequ'ee]")
    |> mes("Let him now that we aren't")
    |> mes("sure of the killer's identity,")
    |> mes("but we have a list of suspects.")
    |> mes("Sooner or later, we'll figure")
    |> mes("out who he is.")
    |> close()
  end

  defp receive_message(ctx) do
    {ctx, subject} =
      ctx
      |> mes("[Dequ'ee]")
      |> mes("Ah...!")
      |> mes("Are you the Swordman")
      |> mes("sent by Shurank? Good,")
      |> mes("I've been waiting...")
      |> next()
      |> mes("[Dequ'ee]")
      |> mes("Now tell me...")
      |> mes("What message does")
      |> mes("Shurank have for me?")
      |> next()
      |> select(["Killer...", "Murderer..."])

    case subject do
      1 -> ask_about_culprit(ctx, "to the killer?", @killer_follow_ups)
      2 -> ask_about_culprit(ctx, "to the murderer?", @murderer_follow_ups)
      _ -> ask_business(ctx)
    end
  end

  defp ask_about_culprit(ctx, subject_line, follow_ups) do
    {ctx, question} =
      ctx
      |> player_says()
      |> mes("What happened")
      |> mes(subject_line)
      |> next()
      |> select(["Who he is...", "Who is behind..."])

    if question in [1, 2] do
      ask_follow_up(ctx, Enum.drop(follow_ups, question - 1))
    else
      ask_business(ctx)
    end
  end

  # A cancelled follow-up falls through to the next question, as in the original switch.
  defp ask_follow_up(ctx, []), do: ask_business(ctx)

  defp ask_follow_up(ctx, [{question_lines, why_quote, what_quote, what_accepted?} | rest]) do
    {ctx, ending} =
      ctx
      |> player_says()
      |> mes_lines(question_lines)
      |> mes("If you did...")
      |> next()
      |> select(["Why are we...", "What are we..."])

    case ending do
      1 -> repeat_message(ctx, ["Why are sitting", "around, doing nothing?!"], why_quote, false)
      2 -> repeat_message(ctx, ["What are we", "supposed to do now?"], what_quote, what_accepted?)
      _ -> ask_follow_up(ctx, rest)
    end
  end

  defp repeat_message(ctx, ending_lines, quote, accepted?) do
    ctx =
      ctx
      |> player_says()
      |> mes_lines(ending_lines)
      |> next()
      |> mes("[Dequ'ee]")
      |> mes("So Shurank is asking,")
      |> mes_lines(quote)
      |> next()

    if accepted?, do: answer_shurank(ctx), else: reject_message(ctx)
  end

  defp reject_message(ctx) do
    ctx
    |> mes("[Dequ'ee]")
    |> mes("Hmm...")
    |> mes("That doesn't seem to")
    |> mes(
      "be the message I'm supposed to receive from Shurack. I need his exact message or I can't send"
    )
    |> mes("a response...")
    |> close()
  end

  defp answer_shurank(ctx) do
    ctx =
      ctx
      |> mes("[Dequ'ee]")
      |> mes("Hmm...")
      |> mes("I understand")
      |> mes("his concerns.")
      |> mes("Alright, now please")
      |> mes("give him this answer.")
      |> next()
      |> mes("[Dequ'ee]")
      |> mes("We haven't found")
      |> mes("out who the murderer")
      |> mes("is for sure. However,")
      |> mes("we have a list of suspects")
      |> mes("and we'll figure it out soon.")
      |> next()
      |> mes("[Dequ'ee]")
      |> mes(
        "Thank you for taking the trouble to come this far. Let me reward you with some experience points."
      )
      |> set_char_var(:tu_swordman, 7)
      |> changequest(8216, 8217)

    ctx =
      if Rathena.truthy?(checkre(ctx, 3)) do
        getexp(ctx, 112, 0)
      else
        getexp(ctx, 1120, 0)
      end

    ctx
    |> next()
    |> mes("[Dequ'ee]")
    |> mes("Take care")
    |> mes("of yourself,")
    |> mes("brave Swordman.")
    |> next()
    |> warp_to_izlude()
    |> close()
  end

  defp player_says(ctx), do: mes(ctx, Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))

  defp mes_lines(ctx, lines), do: Enum.reduce(lines, ctx, fn line, ctx -> mes(ctx, line) end)

  defp warp_to_izlude(ctx) do
    if Rathena.truthy?(checkre(ctx, 0)) do
      warp(ctx, "izlude", 127, 100)
    else
      warp(ctx, "izlude", 35, 78)
    end
  end
end
