defmodule Aesir.ZoneServer.Content.Npc.Jobs.Novice.Supernovice.Tzerero do
  @moduledoc """
  Tzerero, director of the Novice Society, who runs the Super Novice job change quest.

  ## Behavior

  - Invites Novices of at least Base Level 45 who can change jobs to the society and asks for
    30 Sticky Mucus and 30 Resin, starting the quest log.
  - On delivery, takes the items, clears job quest variables, gives a pair of Panties, and
    changes the player to Super Novice (or Super Baby for baby classes).
  - Reminds players of the request and greets Super Novices and other classes.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Darkchild
    - Samuray22
    - L0ne_W0lf
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "aldeba_in",
        x: 223,
        y: 167,
        dir: 3,
        sprite: 709,
        name: "Tzerero",
        scope: :shared,
        unique_name: "Tzerero#sn"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FClearjobvar
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:super_novice) ->
        ctx
        |> mes("[Tzerero]")
        |> mes("I trust that you are enjoying")
        |> mes("life as a Super Novice? Ah,")
        |> mes("good good...just as I expected.")
        |> mes("Verily, the light of mediocrity is shining brightly within you...")
        |> next()
        |> mes("[Tzerero]")
        |> mes("I encourage you to live")
        |> mes("life as Mister Kimu-Shaun did...")
        |> mes("Become a Jack of All Trades...")
        |> mes("...and a master of none.")
        |> close()

      count_item(ctx, 938) > 29 and count_item(ctx, 907) > 29 and
          get_char_var(ctx, :SUPNOV_Q, 0) == 1 ->
        complete_job_change(ctx)

      get_char_var(ctx, :SUPNOV_Q, 0) == 1 ->
        ctx
        |> mes("[Tzerero]")
        |> mes("Huh? Did you forget what I")
        |> mes("wanted from you? Okay,")
        |> mes("I will let you know once")
        |> mes("again. Please remember")
        |> mes("this time...")
        |> next()
        |> mes("[Tzerero]")
        |> mes("I asked you to bring me")
        |> mes("^FF000030 Sticky Mucus^000000 and")
        |> mes("^FF000030 Resin^000000.")
        |> close()

      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:novice) and upper(ctx) != 1 ->
        novice_offer(ctx)

      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:super_novice) ->
        ctx
        |> mes("[Tzerero]")
        |> mes("How do you like living")
        |> mes("life simply as a Super")
        |> mes("Novice? I'm sure that")
        |> mes("you're enjoying it~")
        |> next()
        |> mes("[Tzerero]")
        |> mes("Please grow as a Super")
        |> mes("Novice by helping the")
        |> mes("common man while being")
        |> mes("one at the same time...")
        |> next()
        |> mes("[Tzerero]")
        |> mes("I encourage you to")
        |> mes("grow in your Super")
        |> mes("Noviceness, and lead")
        |> mes("an example in living")
        |> mes("an exceptionally")
        |> mes("mundane life.")
        |> close()

      true ->
        ctx
        |> mes("[Tzerero]")
        |> mes("Hello, I am Tzerero,")
        |> mes("the unofficial executive")
        |> mes("director of the Great")
        |> mes("Novice Society.")
        |> next()
        |> mes("[Tzerero]")
        |> mes("Hmmm...you seem to be well")
        |> mes("above the average person.")
        |> mes("Yes, you're definitely more")
        |> mes("'extraordinary' than you are")
        |> mes("'ordinary...'")
        |> next()
        |> mes("[Tzerero]")
        |> mes("*Sigh* I suppose you")
        |> mes("could never understand")
        |> mes("our way of life, the")
        |> mes("subtle greatness in")
        |> mes("being ordinary. But")
        |> mes("that's alright.")
        |> next()
        |> mes("[Tzerero]")
        |> mes("Well...there are thousands")
        |> mes("of different people in this")
        |> mes("world, so I just try to accept")
        |> mes("all of our differences.")
        |> mes("I hope you will too.")
        |> close()
    end
  end

  defp complete_job_change(ctx) do
    {ctx, _} =
      ctx
      |> delitem(938, 30)
      |> delitem(907, 30)
      |> mes("[Tzerero]")
      |> mes("Ah, you've brought the")
      |> mes("items I've requested!")
      |> mes("You've proven yourself")
      |> mes("worthy of joining our")
      |> mes("Super Novice Society.")
      |> next()
      |> mes("[Tzerero]")
      |> mes("Then, as promised, I will")
      |> mes("change your job into a")
      |> mes("^3355FFSuper Novi--^000000Huh?")
      |> mes("What's that behind you?")
      |> next()
      |> select(["Huh?", "What is that?"])

    {ctx, _} =
      ctx
      |> mes("^3355FFYou look behind you, but...")
      |> mes("There's nothing's there.")
      |> mes("Something fishy is going on here!^000000")
      |> next()
      |> completequest(6010)
      |> FClearjobvar.call([])

    ctx = give_item(ctx, 2339, 1)
    ctx = if upper(ctx) == 0, do: jobchange(ctx, :super_novice), else: ctx
    ctx = if upper(ctx) == 2, do: jobchange(ctx, :super_baby), else: ctx

    ctx
    |> mes("[Tzerero]")
    |> mes("Bwaha! I got you!")
    |> mes("So...how do you like my joke?")
    |> mes("Oh well, let's forget that...")
    |> next()
    |> mes("[Tzerero]")
    |> mes("As well as any possible")
    |> mes("reason a grown man such as")
    |> mes("myself would carry around")
    |> mes("a pair of Panties.")
    |> next()
    |> mes("[Tzerero]")
    |> mes("The important thing is...")
    |> mes("you have joined the esteemed")
    |> mes("ranks of the great Super Novices.")
    |> next()
    |> mes("[Tzerero]")
    |> mes("Consider these Panties a gift...")
    |> mes("This very garment is rumored")
    |> mes("to be worn by Mister Kimu-Shaun,")
    |> mes("our legendary club founder, in")
    |> mes("his early days in striving for")
    |> mes("exemplary mediocrity.")
    |> next()
    |> mes("[Tzerero]")
    |> mes("Go out, and enjoy your new life")
    |> mes("as a Super Novice! Venture")
    |> mes("forth and help the common")
    |> mes("man, while being one at at")
    |> mes("the same time!")
    |> close()
  end

  defp novice_offer(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Tzerero]")
      |> mes("...Hmm?")
      |> mes("Stop.")
      |> mes("Let me look at you.")
      |> next()
      |> mes("[Tzerero]")
      |> mes(".....")
      |> mes(".......")
      |> mes(".........")
      |> emotion(:think)
      |> next()
      |> mes("[Tzerero]")
      |> mes("I see that the light")
      |> mes("of mediocrity shines")
      |> mes("brightly within you...")
      |> next()
      |> mes("[Tzerero]")
      |> mes("Why don't you join us,")
      |> mes("young Novice? Join")
      |> mes("us and learn the subtle")
      |> mes("greatness of being")
      |> mes("mediocre...")
      |> next()
      |> mes("[Tzerero]")
      |> mes("Accept my offer...")
      |> mes("Cast off your those")
      |> mes("brown, dusty garments")
      |> mes("and bloom into...")
      |> next()
      |> mes("[Tzerero]")
      |> mes("...a ^CE6300Super Novice^000000.")
      |> next()
      |> select(["Accept his offer.", "Reject his offer.", "Listen more carefully."])

    novice_choice(choice, ctx)
  end

  defp novice_choice(1, ctx) do
    cond do
      not Rathena.truthy?(can_change_job?(ctx)) ->
        ctx
        |> mes("[Tzerero]")
        |> mes("Hmm...But do you truly")
        |> mes("appreciate the value of")
        |> mes("finding strength in")
        |> mes("weakness? You must")
        |> mes("prove to me that you")
        |> mes("are a true underachiever.")
        |> next()
        |> mes("[Tzerero]")
        |> mes("Live life as a Novice...")
        |> mes("And return when you")
        |> mes("have mastered the")
        |> mes("Basic Skills...")
        |> mes("Grow in mediocrity and")
        |> mes("Become a Level 10 Novice...")
        |> close()

      base_level(ctx) < 45 ->
        ctx
        |> mes("[Tzerero]")
        |> mes("Hmm...But do you truly")
        |> mes("value the relaxed lifestyle")
        |> mes("of the banal adventurer?")
        |> mes("Prove to me that you do not")
        |> mes("lust for power...")
        |> next()
        |> mes("[Tzerero]")
        |> mes("Live life mundanely...")
        |> mes("Become a Level 45 Novice...")
        |> mes("It will be then that you can join us...")
        |> close()

      true ->
        ctx
        |> mes("[Tzerero]")
        |> mes("I can see in your eyes")
        |> mes("the determination to")
        |> mes("live life simply...")
        |> next()
        |> mes("[Tzerero]")
        |> mes("Only the truly wise can")
        |> mes("see that being ordinary")
        |> mes("and banal is the best")
        |> mes("way to live life.")
        |> next()
        |> mes("[Tzerero]")
        |> mes("However, we do not welcome")
        |> mes("just anyone into our society.")
        |> mes("You must first pass our")
        |> mes("qualification test.")
        |> next()
        |> mes("[Tzerero]")
        |> mes("For this test, you must")
        |> mes("bring me some items which")
        |> mes("are dropped from normal,")
        |> mes("unexceptional monsters.")
        |> next()
        |> mes("[Tzerero]")
        |> mes("Hmmmm...")
        |> mes("^FF000030 Sticky Mucus^000000")
        |> mes("and ^FF000030 Resin")
        |> mes("^000000will be suitable to test your")
        |> mes("ability to fight meager enemies.")
        |> next()
        |> mes("[Tzerero]")
        |> mes("Also, the number 30")
        |> mes("is significant. It's not")
        |> mes("anything special...just")
        |> mes("an ordinary number.")
        |> mes("Hahahahaha~")
        |> next()
        |> set_char_var(:SUPNOV_Q, 1)
        |> setquest(6010)
        |> mes("[Tzerero]")
        |> mes("Good luck, my friend.")
        |> close()
    end
  end

  defp novice_choice(2, ctx) do
    ctx
    |> mes("[Tzerero]")
    |> mes("Well, well...I suppose the")
    |> mes("value of the simple life")
    |> mes("is difficult for you to")
    |> mes("to grasp. It's...okay...")
    |> mes("Your life is your own.")
    |> next()
    |> mes("[Tzerero]")
    |> mes("But, if you ever see the")
    |> mes("light of banality, you")
    |> mes("are welcome to visit me")
    |> mes("anytime...")
    |> next()
    |> mes("[Tzerero]")
    |> mes("As our Novice club")
    |> mes("grows more popular and")
    |> mes("we gain more followers,")
    |> mes("we may consider using")
    |> mes("a more difficult test...")
    |> close()
  end

  defp novice_choice(3, ctx) do
    ctx
    |> mes("[Tzerero]")
    |> mes("Our Novice Society was founded")
    |> mes("by the legendary Mister")
    |> mes("Kimu-Shaun...perhaps the")
    |> mes("greatest man in our generation.")
    |> next()
    |> mes("[Tzerero]")
    |> mes("He realized that there")
    |> mes("was much suffering in the")
    |> mes("world, especially among")
    |> mes("the common people of")
    |> mes("Midgard...")
    |> next()
    |> mes("[Tzerero]")
    |> mes("He learned many skills from")
    |> mes("all the different people he")
    |> mes("met...but since he didn't")
    |> mes("stay in one place for long,")
    |> mes("he became a jack of all")
    |> mes("trades...and a master of none.")
    |> next()
    |> mes("[Tzerero]")
    |> mes("In sharing the pain of")
    |> mes("the common man, he became")
    |> mes("became one himself...")
    |> mes("the greatest ordinary")
    |> mes("man ever.")
    |> next()
    |> mes("[Tzerero]")
    |> mes("The members of our society")
    |> mes("try to live as Mister")
    |> mes("Kimu-Shaun did, according to")
    |> mes("the principles he laid before us...")
    |> close()
  end

  defp novice_choice(_, ctx), do: ctx
end
