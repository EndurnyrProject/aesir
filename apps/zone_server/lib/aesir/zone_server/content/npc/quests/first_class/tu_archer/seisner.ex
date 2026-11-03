defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuArcher.Seisner do
  @moduledoc """
  Seisner, the Icarus Archer who teaches archery theory on the training hills.

  ## Behavior

  - Once Master Kavaruk's letter is shown (training step 1 or above 2), opens a lesson menu
    about Archers and their stats; hearing any lesson at step 1 advances the training
    step to 2.
  - At step 2 she sends the player back to Kavaruk, advancing the training step to 3 and
    granting job experience by Job Level (30 at level 1, 80 up to 10, 100 up to 20, 120
    beyond).
  - Without the letter she only shows off her Double Strafe.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Jukka (fix up)
    - Lupus
    - L0ne_W0lf
    - SinSloth
    - Capuche
    - Euphy
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "pay_arche", x: 84, y: 139, dir: 3, sprite: 727, name: "Seisner", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> specialeffect(:hit2)
      |> mes("[Seisner]")
      |> mes("Aaaah!")
      |> mes("Double Strafe!")
      |> specialeffect(:hit2)
      |> next()
      |> mes("[Seisner]")
      |> mes("I did it!")
      |> mes("Only an Archer")
      |> mes("could make that shot!")
      |> next()
      |> mes("[Seisner]")
      |> mes("Now, there are some")
      |> mes(
        "Thief class people who also use arrows, but they're better suited to using Knives. We Archers are"
      )
      |> mes("the arrow specialists!")

    step = get_char_var(ctx, :tu_archer01, 0)

    cond do
      step == 1 or step > 2 ->
        ctx
        |> next()
        |> mes("^3355FFYou show Seisner")
        |> mes("the letter that Master")
        |> mes("Kavaruk has written")
        |> mes("to her for you.^000000")
        |> next()
        |> mes("[Seisner]")
        |> mes("So Master Kavaruk")
        |> mes("wants me to teach you")
        |> mes("about Archers and Archery? Alright, what would you like to know more about?")
        |> topics_menu()

      step == 2 ->
        finish_lessons(ctx)

      true ->
        close(ctx)
    end
  end

  defp finish_lessons(ctx) do
    ctx =
      ctx
      |> next()
      |> mes("[Seisner]")
      |> mes("Thanks for listening.")
      |> mes("I know I gave you a lot of information, but I think it's important that everyone")
      |> mes("understands archery.")
      |> next()
      |> mes("[Seisner]")
      |> mes(
        "If you feel comfortable enough with the knowledge I've taught you, you should go back to Master Kavaruk. But if you still have questions, you can always come and ask me."
      )
      |> close()
      |> specialeffect2(:wind)
      |> set_char_var(:tu_archer01, 3)

    cond do
      job_level(ctx) == 1 -> getexp(ctx, 0, 30)
      job_level(ctx) > 1 and job_level(ctx) < 11 -> getexp(ctx, 0, 80)
      job_level(ctx) > 10 and job_level(ctx) < 21 -> getexp(ctx, 0, 100)
      true -> getexp(ctx, 0, 120)
    end
  end

  defp topics_menu(ctx) do
    {ctx, choice} =
      ctx |> next() |> select(["About Archers.", "Stats for Archers", "End Conversation."])

    case choice do
      1 ->
        ctx
        |> about_archers()
        |> mark_lesson_heard()
        |> topics_menu()

      2 ->
        ctx
        |> mes("[Seisner]")
        |> mes("So you want to")
        |> mes("know more about Stats")
        |> mes("and how they affect Archer abilities? I'll do my best to explain.")
        |> next()
        |> stats_menu()
        |> topics_menu()

      3 ->
        ctx
        |> mes("[Seisner]")
        |> mes("Once an Archer shoots an arrow,")
        |> mes(
          "he can't stop its flight or change his target. That's why Archers need to be level headed and really careful in battle."
        )
        |> next()
        |> mes("[Seisner]")
        |> mes(
          "Someday, I'd like to become a great Archer and use my skills for the good of Rune-Midgarts."
        )
        |> close()

      _ ->
        topics_menu(ctx)
    end
  end

  defp about_archers(ctx) do
    ctx
    |> mes("[Seisner]")
    |> mes("Archers specialize")
    |> mes(
      "in shooting ^3131FFarrows^000000. We usually attack from a distance, but before we increase our Dodge Rate, we're pretty weak when it comes to one on one battles."
    )
    |> next()
    |> mes("[Seisner]")
    |> mes("Therefore, Archers tend to attack before the enemy gets too close.")
    |> mes("We also like to party with other people who can offer close")
    |> mes("range protection.")
    |> next()
    |> mes("[Seisner]")
    |> mes("Now, only Novices can")
    |> mes("become Archers after reaching")
    |> mes("Job Level 10 and learning all of the Basic Skills.")
    |> next()
    |> mes("[Seisner]")
    |> mes(
      "Well experienced Archers can move on and change to the Second Job Class, becoming ^3131FFHunters^000000, ^3131FFBards^000000 if they are male, or ^3131FFDancers^000000 if they are female."
    )
    |> next()
    |> mes("[Seisner]")
    |> mes("If you reach Level 99")
    |> mes(
      "as a Second Job Class character, you can change to a Transcendent Class with Valkyrie's help."
    )
    |> next()
    |> mes("[Seisner]")
    |> mes(
      "Hunters can ultimately transcend into ^3131FFSnipers^000000, Bards into ^3131FFMinstrels^000000, and Dancers into ^3131FFGypsies^000000. I know that's pretty complex."
    )
  end

  defp stats_menu(ctx) do
    {ctx, choice} =
      select(ctx, [
        "STR",
        "^3131FFAGI^000000",
        "VIT",
        "^FF9900INT^000000",
        "^FF3131DEX^000000",
        "LUK",
        "End Conversation."
      ])

    case choice do
      7 ->
        ctx
        |> mes("[Seisner]")
        |> mes("So is there")
        |> mes("anything else that")
        |> mes("you want to ask me?")

      stat when stat in 1..6 ->
        ctx
        |> explain_stat(stat)
        |> next()
        |> mark_lesson_heard()
        |> stats_menu()

      _ ->
        ctx
    end
  end

  defp explain_stat(ctx, 1) do
    ctx
    |> mes("[Seisner]")
    |> mes(
      "STR typically increases the damage of attacks. However, Archer class characters use weapons that rely on ^FF3131DEX^000000 to increase their damage."
    )
    |> next()
    |> mes("[Seisner]")
    |> mes(
      "In a sense, STR might not be necessary for Archers, although I'm sure there are skills or situations where STR will come in handy."
    )
    |> next()
    |> mes("[Seisner]")
    |> mes(
      "For instance, if you run out of arrows (which is every Archer's nightmare) and need to equip a Knife, having some STR might"
    )
    |> mes("be helpful.")
    |> next()
    |> mes("[Seisner]")
    |> mes("Increasing STR will also")
    |> mes("increase the amount of weight")
    |> mes(
      "that any character can carry. So if you have more STR, you can carry around more arrows."
    )
  end

  defp explain_stat(ctx, 2) do
    ctx
    |> mes("[Seisner]")
    |> mes("^FF3131AGI^000000 as you know, ")
    |> mes("^3131Ffincreases Attack Speed")
    |> mes("(ASPD)^000000 and affects ^3131FF Dodge Rate^000000.")
    |> next()
    |> mes("[Seisner]")
    |> mes(
      "One of the drawbacks of being an Archer is having weaker strength and lower Dodge Rate. However, the Dodge Rate disadvantage is lessened by increasing your ^FF3131AGI^000000."
    )
  end

  defp explain_stat(ctx, 3) do
    ctx
    |> mes("[Seisner]")
    |> mes("^3131FFVIT^000000 will increase")
    |> mes("your Maximum HP and")
    |> mes("resistance to damage.")
    |> next()
    |> mes("[Seisner]")
    |> mes("Although Archers don't")
    |> mes(
      "specialize in having any special kind of defense, having VIT will help alleviate the defensive weakness of the Archer class."
    )
    |> next()
    |> mes("[Seisner]")
    |> mes("VIT might be helpful")
    |> mes(
      "depending on how you use it. Still, I wouldn't recommend focusing too much on increasing your VIT if you're an Archer."
    )
  end

  defp explain_stat(ctx, 4) do
    ctx
    |> mes("[Seisner]")
    |> mes("^FF0000INT^000000 is more")
    |> mes("important to the")
    |> mes("Archer class than")
    |> mes("you would think~")
    |> next()
    |> mes("[Seisner]")
    |> mes("As you increase ^FF0000INT^000000, you'll raise your Maximum SP, meaning you")
    |> mes("can use special skills more often.")
    |> next()
    |> mes("[Seisner]")
    |> mes(
      "For Hunters, one of the Second Job Classes for Archers, having higher INT will increase the damage inflicted by ^3131FFFalcons^000000."
    )
  end

  defp explain_stat(ctx, 5) do
    ctx
    |> mes("[Seisner]")
    |> mes("Now DEX is almost")
    |> mes("without a doubt the")
    |> mes("most important stat")
    |> mes("for any Archer.")
    |> next()
    |> mes("[Seisner]")
    |> mes("^FF3131DEX^000000 ^3131Ffincreases the damage^000000")
    |> mes(
      "of Archer class weapons that fire arrows. These include ^3131FFBows^000000, ^3131FFInstruments^000000 and ^3131FFWhips^000000."
    )
    |> next()
    |> mes("[Seisner]")
    |> mes(
      "Dexterity enhances an Archer's ability to hit weak points and do more damage, which is why weapons that use arrows don't rely on STR like weapons used by other classes."
    )
    |> next()
    |> mes("[Seisner]")
    |> mes(
      "Just like any other class, ^FF3131DEX^000000 increases ^3131FFAccuracy (HIT)^000000 and slightly enhances Attack Speed (ASPD)."
    )
  end

  defp explain_stat(ctx, 6) do
    ctx
    |> mes("[Seisner]")
    |> mes("^FF0000LUK^000000 affects your")
    |> mes("Perfect Dodge rate")
    |> mes("and Critical rate.")
    |> next()
    |> mes("[Seisner]")
    |> mes(
      "For Hunters, one of the Second Classes for the Archer, LUK increases the chance of ^3131FFBlitz Beat^000000 occurring automatically. So Hunters who rely on their Falcons might want to invest in LUK."
    )
  end

  defp mark_lesson_heard(ctx) do
    if get_char_var(ctx, :tu_archer01, 0) == 1, do: set_char_var(ctx, :tu_archer01, 2), else: ctx
  end
end
