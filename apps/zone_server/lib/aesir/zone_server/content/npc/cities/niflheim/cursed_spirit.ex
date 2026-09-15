defmodule Aesir.ZoneServer.Content.Npc.Cities.Niflheim.CursedSpirit do
  @moduledoc """
  Challenges visitors to handle cursed books and recite a curse-breaking spell.

  ## Behavior

  - Summons or warps away visitors who touch the first two forbidden books.
  - Tests a three-part spell when the third book is touched.
  - Updates matching quest variables on selected successful outcomes or summons seven monsters after failure.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Fyrien
    - Dizzy
    - PKGINGO
    - Celest

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "niflheim",
        x: 350,
        y: 258,
        dir: 1,
        sprite: 802,
        name: "Cursed Spirit",
        scope: :shared,
        unique_name: "Cursed Spirit#nif"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnMyMobDead", ctx), do: ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> killmonster("niflheim", "Cursed Spirit#nif::OnMyMobDead")
      |> mes("[Ashe Bruce]")
      |> mes("I sense you're cursed")
      |> mes("by a powerful spell...")
      |> mes("Hmm... It's clear what")
      |> mes("you must be up to....")
      |> next()
      |> mes("[Ashe Bruce]")
      |> mes("You wish to get")
      |> mes("rid of your curse....")
      |> mes("By giving it to me!!")
      |> next()
      |> mes("[Ashe Bruce]")
      |> mes(
        "Just because I'm a cursed spirit, you adventurers think you can just dump your curses on me?!"
      )
      |> emotion(:fret)
      |> next()
      |> mes("[Ashe Bruce]")
      |> mes("I refuse to let")
      |> mes("you remain here.....")
      |> mes("Leave now, or I will")
      |> mes("remove you by force....")
      |> next()
      |> mes("[Ashe Bruce]")
      |> mes("....And...")
      |> mes("....Whatever you do...")
      |> mes("....Do NOT touch my books...")
      |> next()
      |> select([
        "Touch the first book.",
        "Touch the second book.",
        "Touch the third book.",
        "Okay, I am leaving."
      ])

    case choice do
      1 -> touch_first_book(ctx)
      2 -> touch_second_book(ctx)
      3 -> touch_third_book(ctx)
      4 -> leave_books_alone(ctx)
      _ -> ctx
    end
  end

  defp touch_first_book(ctx) do
    ctx
    |> summon_mob(
      mob_id: 1478,
      map: "niflheim",
      at: {349, 259},
      event: "Cursed Spirit#nif::OnMyMobDead"
    )
    |> mes("[Ashe Bruce]")
    |> mes("...!...")
    |> mes("How dare you touch my books")
    |> mes("when I specifically said")
    |> mes("'Don't touch my books!'")
    |> next()
    |> mes("[Ashe Bruce]")
    |> mes("....!...Grrrrr!")
    |> mes("I shall tear you apart...!")
    |> mes("Be bound by an eternal curse...!")
    |> close()
  end

  defp touch_second_book(ctx) do
    ctx
    |> mes("[Ashe Bruce]")
    |> mes("...!...")
    |> mes("You dare touch my books?!")
    |> mes("Right after I said not")
    |> mes("to touch them...?!")
    |> mes("Foolish mortal!")
    |> mes("...BEGONE!")
    |> close()
    |> warp("niflheim", 34, 162)
  end

  defp touch_third_book(ctx) do
    {ctx, first_word} =
      ctx
      |> mes("[Ashe Bruce]")
      |> mes("Muhahahaha....")
      |> mes("Stubborn mortal~!")
      |> mes("Fine! I will give you")
      |> mes("a fighting chance and let")
      |> mes("you cast a spell.")
      |> next()
      |> mes("[Ashe Bruce]")
      |> mes("But Blessings won't")
      |> mes("work with the curse")
      |> mes("that you have...")
      |> mes("And the spell to lift")
      |> mes("your curse has been")
      |> mes("lost to the ages~!")
      |> emotion(:kik)
      |> next()
      |> select(["Clover", "Klaatu", "Klaytos"])

    {ctx, second_word} = select(ctx, ["Verit", "Veritas", "Verata"])
    {ctx, third_word} = select(ctx, ["Necktie", "Necklace", "Nero", "^FFFFFFNictu!!!^000000"])

    if first_word == 2 and second_word == 3 and third_word == 4 do
      resolve_correct_spell(ctx)
    else
      punish_wrong_spell(ctx)
    end
  end

  defp resolve_correct_spell(ctx) do
    case Enum.random(1..5) do
      1 -> resolve_meat_curse(ctx)
      2 -> resolve_first_head_curse(ctx)
      3 -> resolve_second_head_curse(ctx)
      4 -> resist_correct_spell(ctx)
      _ -> punish_wrong_spell(ctx)
    end
  end

  defp resolve_meat_curse(ctx) do
    if get_char_var(ctx, :morison_meat, 0) < 15 do
      ctx
      |> set_char_var(:morrison_meat, 15)
      |> mes("[Ashe Bruce]")
      |> mes("You... You broke the curse!")
      |> mes("How did you know that spell?!")
      |> next()
      |> mes("[Ashe Bruce]")
      |> mes("I suppose you expect for me to")
      |> mes("melt in agony about now, don't")
      |> mes("you? Well... Sorry to disappoint")
      |> mes("you, mortal, but I can never die!")
      |> close()
    else
      ctx
      |> mes("[Ashe Bruce]")
      |> mes("...! You cast the correct spell?!")
      |> mes("...!...")
      |> mes("But...You're still cursed...")
      |> mes("Umhaaaaaaaaaaaaaaaaa.....!")
      |> close()
    end
  end

  defp resolve_first_head_curse(ctx) do
    if get_char_var(ctx, :thai_head, 0) == 1 do
      ctx
      |> set_char_var(:thai_head, 2)
      |> mes("[Ashe Bruce]")
      |> mes("What's...")
      |> mes("this feeling?")
      |> next()
      |> mes("[Ashe Bruce]")
      |> mes("No...!")
      |> mes("NOOOOOOOOOOOOOOOO!")
      |> next()
      |> mes("[Ashe Bruce]")
      |> mes("Why did your spell have to work?!")
      |> close()
    else
      ctx
      |> mes("[Ashe Bruce]")
      |> mes("You...")
      |> mes("cast the correct spell?!")
      |> next()
      |> mes("[Ashe Bruce]")
      |> mes("Hoho~")
      |> mes("But you're still cursed...")
      |> close()
    end
  end

  defp resolve_second_head_curse(ctx) do
    if get_char_var(ctx, :thai_head, 0) == 8 do
      ctx
      |> set_char_var(:thai_head, 7)
      |> mes("[Ashe Bruce]")
      |> mes("You... You broke the curse!")
      |> mes("Who taught you that spell?!")
      |> next()
      |> mes("[Ashe Bruce]")
      |> mes("I suppose you expect for me to")
      |> mes("melt in agony about now, don't")
      |> mes("you? Well... Sorry to disappoint")
      |> mes("you, mortal, but I can never die!")
      |> next()
      |> mes("[Ashe Bruce]")
      |> mes("So long as I'm...")
      |> mes("still...")
      |> mes("cursed.")
      |> next()
      |> mes("[Ashe Bruce]")
      |> mes("NOOOOOOOOOO!")
      |> close()
    else
      ctx
      |> mes("[Ashe Bruce]")
      |> mes("...! You cast the correct spell?!")
      |> mes("...!...")
      |> mes("But...You're still cursed...")
      |> mes("Umhaaaaaaaaaaaaaaaaa.....!")
      |> close()
    end
  end

  defp resist_correct_spell(ctx) do
    ctx
    |> mes("[Ashe Bruce]")
    |> mes("...! You cast the correct spell?!")
    |> mes("...!...")
    |> mes("But...You're still cursed...")
    |> mes("Mwahahahaaaa.....!")
    |> close()
  end

  defp punish_wrong_spell(ctx) do
    ctx
    |> summon_mob(
      mob_id: 1462,
      map: "niflheim",
      at: {345, 259},
      event: "Cursed Spirit#nif::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1462,
      map: "niflheim",
      at: {347, 261},
      event: "Cursed Spirit#nif::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1462,
      map: "niflheim",
      at: {344, 253},
      event: "Cursed Spirit#nif::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1462,
      map: "niflheim",
      at: {346, 251},
      event: "Cursed Spirit#nif::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1462,
      map: "niflheim",
      at: {349, 249},
      event: "Cursed Spirit#nif::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1462,
      map: "niflheim",
      at: {350, 260},
      event: "Cursed Spirit#nif::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1462,
      map: "niflheim",
      at: {353, 256},
      event: "Cursed Spirit#nif::OnMyMobDead"
    )
    |> mes("[Ashe Bruce]")
    |> mes("Muhahahahahaha!")
    |> mes("That's not the right spell!")
    |> mes("Now, death awaits you!")
    |> mes("You're eternally bound")
    |> mes("to the curse...!")
    |> close()
  end

  defp leave_books_alone(ctx) do
    ctx
    |> mes("[Ashe Bruce]")
    |> mes("...")
    |> mes(".....")
    |> next()
    |> mes("[Ashe Bruce]")
    |> mes("Well then.")
    |> mes("Try not to trip on")
    |> mes("your feet in your")
    |> mes("rush to leave.")
    |> close()
  end
end
