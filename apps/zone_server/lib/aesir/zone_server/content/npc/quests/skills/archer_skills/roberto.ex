defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.ArcherSkills.Roberto do
  @moduledoc """
  Roberto, a homesick archer in Morocc, teaches the Arrow Crafting quest skill.

  ## Behavior

  - Talks only to archer-line characters at Job Level 30 or higher, or to any Hunter, Bard, or
    Dancer; greets archers who already know the skill and brushes off everyone else.
  - Explains the materials he wants from home: 20 Resins, 7 Mushroom Spores, 41 Pointed Scales,
    13 Trunks, and 1 Red Potion.
  - Teaches Arrow Crafting once the materials are brought.

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
      %{map: "moc_ruins", x: 118, y: 99, dir: 5, sprite: 88, name: "Roberto", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @arrow_crafting 147
  @resin 907
  @mushroom_spore 921
  @pointed_scale 906
  @trunk 1019
  @red_potion 501

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      Rathena.job_id(base_class(ctx)) != Rathena.job_id(:archer) -> stranger(ctx)
      getskilllv(ctx, @arrow_crafting) == 1 -> fellow_crafter(ctx)
      experienced?(ctx) -> meet_archer(ctx)
      true -> too_low(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp experienced?(ctx) do
    job_level(ctx) >= 30 or
      (Rathena.job_id(base_job(ctx)) == Rathena.job_id(:hunter) or
         Rathena.job_id(base_job(ctx)) == Rathena.job_id(:bard) or
         Rathena.job_id(base_job(ctx)) == Rathena.job_id(:dancer))
  end

  defp fellow_crafter(ctx) do
    ctx
    |> mes("[Roberto]")
    |> mes("Ooh, you're from my home town!")
    |> mes("Nice to see you!")
    |> mes("How are you?")
    |> mes("Ah! That arrow!")
    |> mes("You made it, didn't you!")
    |> next()
    |> mes("[Roberto]")
    |> mes("Haha...!")
    |> mes("Do you think it's a lot better?")
    |> mes("Haha... anyways, I am glad.")
    |> mes("Come back with once in a while")
    |> mes("with news from home.")
    |> mes("Then byebye~")
    |> close()
  end

  defp meet_archer(ctx) do
    ctx = ctx |> mes("[Roberto]") |> mes("Eh!") |> mes(" ") |> mes("You are...") |> next()

    if has_materials?(ctx), do: teach(ctx), else: lonely(ctx)
  end

  defp has_materials?(ctx) do
    count_item(ctx, @resin) > 19 and count_item(ctx, @mushroom_spore) > 6 and
      count_item(ctx, @pointed_scale) > 40 and count_item(ctx, @trunk) > 12 and
      count_item(ctx, @red_potion) > 0
  end

  defp teach(ctx) do
    ctx
    |> mes("[Roberto]")
    |> mes("You brought them!")
    |> mes("Thank you very much.")
    |> mes("Then, as I promised, I will teach you the skill.")
    |> next()
    |> delitem(@resin, 20)
    |> delitem(@mushroom_spore, 7)
    |> delitem(@pointed_scale, 41)
    |> delitem(@trunk, 13)
    |> delitem(@red_potion, 1)
    |> skill(@arrow_crafting, 1, :permanent)
    |> mes("[Roberto]")
    |> mes("No need to worry about arrows now.")
    |> mes("Oh, and did you happen to see")
    |> mes("someone called Jason in Payon?")
    |> mes("Be careful. He is a")
    |> mes("ferocious one.")
    |> next()
    |> mes("[Roberto]")
    |> mes("You just have to be careful of Jason in Payon.")
    |> mes("Remember.")
    |> mes("Then bubye~ Thank you for the presents~")
    |> close()
  end

  defp lonely(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Roberto]")
      |> mes("An archer in Morocc!?")
      |> mes("Nice to see you! Meeting a fellow")
      |> mes("archer in a place like this! *sniffsniff*!")
      |> mes("I came alone to Morocc..")
      |> mes("but I was a newcomer, and the pressure... waaah~")
      |> mes("I was very lonely~")
      |> next()
      |> select(["It must be hard. It's ok have faith.", "Keep suffering."])

    case choice do
      1 -> request_materials(ctx)
      2 -> warn_at_night(ctx)
      _ -> too_low(ctx)
    end
  end

  defp request_materials(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Roberto]")
      |> mes("Yes. Thank you...")
      |> mes("You must be having a hard")
      |> mes("time in a place like this.")
      |> mes("Isn't it hard to find arrows?")
      |> mes("That's why I make my own.")
      |> next()
      |> select(["Eh, really?!"])

    {ctx, _} =
      ctx
      |> mes("[Roberto]")
      |> mes("Yeah! I gather different items")
      |> mes("and make arrows using them.")
      |> mes("It is a useful skill to help me")
      |> mes("survive alone in this tough world.")
      |> mes("If you'd like, I can teach you.")
      |> next()
      |> select(["That would be wonderful."])

    ctx
    |> mes("[Roberto]")
    |> mes("But.. I can't do it for free.")
    |> mes("Nothing is free in this world~")
    |> mes("Mmm... How about this?")
    |> mes("You bring me what I ask for.")
    |> mes("Then I will teach you the skill.")
    |> next()
    |> mes("[Roberto]")
    |> mes("I've been very lonely since I left my hometown.")
    |> mes("I would like to treat my homesickness")
    |> mes("with things from there.")
    |> mes("Bring me 20 Resins from the trees in the ")
    |> mes("Payon forest, and 1 Red Potion")
    |> mes("sold in the store.")
    |> next()
    |> mes("[Roberto]")
    |> mes("Also, 13 Trunks from the Willows that")
    |> mes("live near the Payon Forest,")
    |> mes("41 Pointed Scale,")
    |> mes("7 Mushroom Spores.")
    |> mes("If you bring me all of these,")
    |> next()
    |> mes("[Roberto]")
    |> mes("I will teach you the skill.")
    |> mes("Then.. I'll be waiting.")
    |> mes("For news from our home.")
    |> close()
  end

  defp warn_at_night(ctx) do
    ctx = mes(ctx, "[Roberto]")
    title = if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0), do: "mister", else: "miss"

    ctx
    |> mes("...hey #{title}.")
    |> mes("...be careful at night.")
    |> close()
  end

  defp too_low(ctx) do
    ctx
    |> mes("[Roberto]")
    |> mes("Hmm... Do you")
    |> mes("have something to say?")
    |> mes("I have nothing.")
    |> mes("Difference in levels")
    |> mes("cuts off conversations.")
    |> close()
  end

  defp stranger(ctx) do
    ctx
    |> mes("[?]")
    |> mes("Eh... First time seeing an archer or something?")
    |> mes("Just go where you were going.")
    |> mes("I only talk to high level archers.")
    |> mes("Won't open my mouth otherwise!")
    |> close()
  end
end
