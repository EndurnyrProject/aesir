defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.ArcherSkills.Jason do
  @moduledoc """
  Jason, a wounded archer in Payon, teaches the Arrow Repel quest skill.

  ## Behavior

  - Groans at players who walk near him.
  - Explains Arrow Repel and its materials to archer-line characters at Job Level 35 or higher,
    or to any Hunter, Bard, or Dancer.
  - Teaches Arrow Repel in exchange for 2 Emeralds, 3 Yoyo Tails, 10 Tentacles, 10 Bills of
    Birds, and 36 Banana Juices.
  - Greets archers who already know the skill or are not yet experienced enough, and brushes off
    everyone else.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - kobra_k88
    - Lupus
    - Silentdragon
    - IVBela
    - L0ne_W0lf
    - Masao
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "payon",
        x: 103,
        y: 63,
        dir: 3,
        sprite: 88,
        name: "Jason",
        scope: :shared,
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @arrow_repel 148
  @emerald 721
  @yoyo_tail 942
  @tentacle 962
  @bill_of_birds 925
  @banana_juice 532

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx) do
    ctx |> mes("[???]") |> mes("Errrrrrr...") |> close()
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      Rathena.job_id(base_class(ctx)) != Rathena.job_id(:archer) -> stranger(ctx)
      getskilllv(ctx, @arrow_repel) == 1 -> meet_again(ctx)
      experienced?(ctx) -> offer_skill(ctx)
      true -> encourage(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp experienced?(ctx) do
    job_level(ctx) >= 35 or
      (Rathena.job_id(base_job(ctx)) == Rathena.job_id(:hunter) or
         Rathena.job_id(base_job(ctx)) == Rathena.job_id(:bard) or
         Rathena.job_id(base_job(ctx)) == Rathena.job_id(:dancer))
  end

  defp meet_again(ctx) do
    ctx
    |> mes("[Jason]")
    |> mes("Eh, we meet again.")
    |> mes("Ehhhh so weird.")
    |> mes("Whenever I see someone again")
    |> mes("I start eh-ing a lot.")
    |> mes("Ehhh... anyways nice to see you again.")
    |> mes("Ehhhh... don't come any more ehh...")
    |> close()
  end

  defp offer_skill(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Jason]")
      |> mes("Darn... my wound isn't healing.")
      |> mes("Bleh.. I was too careless... ")
      |> mes("to become like this.. err...")
      |> mes("But still, hurting me like this")
      |> mes("giving me so many injuries...")
      |> next()
      |> mes("What should I do about Roberto.")
      |> mes("Mmmm... Ah!")
      |> mes("You? How long have you been there?")
      |> mes("Mmm... very high level.")
      |> mes("Someone like you would definitely be")
      |> mes("able to know how to use Arrow Repel.")
      |> next()
      |> select(["What is that?", "Teach me."])

    case choice do
      1 -> explain_skill(ctx)
      2 -> learn_skill(ctx)
      _ -> encourage(ctx)
    end
  end

  defp explain_skill(ctx) do
    ctx
    |> mes("[Jason]")
    |> mes("...you're kidding, right?")
    |> mes("Oh my, you don't even know")
    |> mes("Arrow Repel at that level?")
    |> mes("You're a strange person.")
    |> next()
    |> mes("[Jason]")
    |> mes("(Jason was in the lala land.)")
    |> next()
    |> mes("[Jason]")
    |> mes("Well, ok. I'll teach you what")
    |> mes("Arrow Repel is.")
    |> next()
    |> mes("[Jason]")
    |> mes("Arrow Repel is a skill that allows you to")
    |> mes("push the opponent away as soon as you attack.")
    |> mes("You can only use it when you aim exactly")
    |> mes("at the target. But unlike magic, ")
    |> mes("it doesn't de-spell.")
    |> next()
    |> mes("[Jason]")
    |> mes("It is very useful for an archer")
    |> mes("that is weak in close ranges.")
    |> mes("If you would like to learn,")
    |> mes("come find me again.")
    |> mes("There are some necessary materials.")
    |> next()
    |> mes("[Jason]")
    |> mes("First, because you must modify a bow")
    |> mes("bring a crossbow you do not use.")
    |> mes("10 Tentacles, 10 Bill of Birds,")
    |> mes("3 Yoyo Tails.. these are very elastic.")
    |> mes("Also, 2 Emeralds. And last but not least...")
    |> mes("36 bottles of Banana Juice that I love!")
    |> next()
    |> mes("[Jason]")
    |> mes("......Ehem!")
    |> mes("If you bring all of these,")
    |> mes("I shall teach you Arrow Repel.")
    |> mes("Then, see you again.")
    |> mes("(I'm going to be mad if you don't bring the Banana Juice.)")
    |> close()
  end

  defp learn_skill(ctx) do
    if has_materials?(ctx), do: teach(ctx), else: missing_materials(ctx)
  end

  defp has_materials?(ctx) do
    count_item(ctx, @emerald) > 1 and count_item(ctx, @yoyo_tail) > 2 and
      count_item(ctx, @tentacle) > 9 and count_item(ctx, @bill_of_birds) > 9 and
      count_item(ctx, @banana_juice) > 35
  end

  defp teach(ctx) do
    ctx
    |> mes("[Jason]")
    |> mes("Ok! Perfect!")
    |> mes("I shall teach you the nationally")
    |> mes("renowned skill, Arrow Repel!")
    |> next()
    |> delitem(@emerald, 2)
    |> delitem(@yoyo_tail, 3)
    |> delitem(@tentacle, 10)
    |> delitem(@bill_of_birds, 10)
    |> delitem(@banana_juice, 36)
    |> skill(@arrow_repel, 1, :permanent)
    |> mes("[Jason]")
    |> mes("Oh, works better than I expected!")
    |> mes("Won't be needing to modify the bow!")
    |> mes("You can take this back~")
    |> mes("And enjoy using your newly inherited")
    |> mes("skill in fields and dungeons!")
    |> mes("He~heh~!")
    |> close()
  end

  defp missing_materials(ctx) do
    ctx
    |> mes("[Jason]")
    |> mes("Mmm... too bad.")
    |> mes("You are missing some things.")
    |> mes("Once again, you need 2 Emeralds,")
    |> mes("3 Yoyo Tails, 10 Tentacles,")
    |> mes("10 Bill of Birds, and last but")
    |> mes("not least 36 bottles of Banana juice!")
    |> next()
    |> mes("[Jason]")
    |> mes("Make sure you have all of them and come again!")
    |> close()
  end

  defp encourage(ctx) do
    ctx
    |> mes("[Jason]")
    |> mes("Ooh... you are an archer.")
    |> mes("If you try a little more")
    |> mes("you will have a great")
    |> mes("reputation as an archer!")
    |> mes("Exert yourself!")
    |> close()
  end

  defp stranger(ctx) do
    ctx
    |> mes("[?]")
    |> mes("What does life need from")
    |> mes("a lonely lad like me?")
    |> close()
  end
end
