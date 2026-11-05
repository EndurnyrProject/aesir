defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Elly do
  @moduledoc """
  Elly reveals the keys and letter needed to enter Kiel Hyre’s factory.

  ## Behavior

  - Repels premature visitors and remains unresponsive until the correct wake-up phrase is spoken.
  - Gives a Golden Key and Button, then opens the Grey Box to reveal a Blue Keycard and her grandfather’s letter.

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
      %{map: "kh_school", x: 178, y: 180, dir: 4, sprite: 895, name: "Elly", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    quest_stage = get_char_var(ctx, :KielHyreQuest, 0)

    cond do
      checkweight(ctx, [{908, 200}]) == 0 ->
        ctx
        |> mes("^3355FFJust a second...")
        |> mes("You're carrying too")
        |> mes("many items with you")
        |> mes("right now, so you'll")
        |> mes("need to free up more")
        |> mes("Inventory space first...^000000")
        |> close()

      quest_stage < 30 ->
        ctx
        |> mes("[Elly]")
        |> mes("Who the heck are you?")
        |> mes("Y-you're not supposed")
        |> mes("to be able to get inside!")
        |> mes("Get out of here right now!")
        |> close()
        |> percent_heal(hp: -99, sp: 0)
        |> warp("yuno_fild08", 100, 100)

      quest_stage < 32 ->
        ctx
        |> mes("[Elly]")
        |> mes("......")
        |> mes(".........")
        |> mes("............")
        |> close()

      quest_stage == 32 ->
        try_waking_elly(ctx)

      quest_stage == 34 ->
        open_grey_box(ctx)

      quest_stage >= 36 ->
        ctx
        |> mes("^3355FFThis is where you")
        |> mes("discovered the note")
        |> mes("locked inside the Grey Box.")
        |> mes("The following message was")
        |> mes("written in the note by Elly's")
        |> mes("grandfather, Kiel Hyre.^000000")
        |> next()
        |> read_letter()
        |> close()

      true ->
        ctx
    end
  end

  defp try_waking_elly(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Elly]")
      |> mes("......")
      |> mes(".........")
      |> mes("............")
      |> next()
      |> mes("^3355FFElly seems to have")
      |> mes("been cursed, and is")
      |> mes("completely still and")
      |> mes("lifeless. You've got to")
      |> mes("try something, but what?^000000")
      |> next()
      |> select(["Wake her up by shaking.", "Wake her up by yelling.", "Ignore"])

    case choice do
      1 ->
        shake_elly(ctx)

      2 ->
        call_to_elly(ctx)

      3 ->
        ctx
        |> mes("^3355FFAlright...")
        |> mes("But sooner or later,")
        |> mes("you should try to break")
        |> mes("the curse placed on Elly.^000000")
        |> close()

      _ ->
        ctx
    end
  end

  defp shake_elly(ctx) do
    ctx =
      ctx
      |> mes("^3355FFYou grab Elly by the")
      |> mes("shoulders, and try to get")
      |> mes("her to respond by violently")
      |> mes("shaking her entire body.^000000")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Elly? Elly! No!")
    |> mes("Come back to us!")
    |> next()
    |> mes("^3355FFElly's not responding...^000000")
    |> close()
  end

  defp call_to_elly(ctx) do
    {ctx, wake_up_phrase} = input(ctx, :string)
    ctx = set_local(ctx, :"KHInput$", wake_up_phrase)

    if get_local(ctx, :"KHInput$", "") == "Wake up, Elly!" do
      ctx
      |> mes("[Elly]")
      |> mes(".............")
      |> next()
      |> mes("^3355FFAs soon as you said those")
      |> mes("words, a ^000000Small Golden Key^3355FF")
      |> mes("and a ^000000Button^3355FF drop from Elly's")
      |> mes("hands. It looks like she woke")
      |> mes("up, but only for an instant.^000000")
      |> give_item(7493, 1)
      |> give_item(7494, 1)
      |> set_char_var(:KielHyreQuest, 34)
      |> close()
    else
      ctx
      |> mes("[Elly]")
      |> mes("......")
      |> mes(".........")
      |> mes("............")
      |> next()
      |> mes("^3355FFElly's not responding...^000000")
      |> close()
    end
  end

  defp open_grey_box(ctx) do
    if count_item(ctx, 7491) < 1 do
      ctx
      |> mes("^3355FFMaybe the golden key^000000")
      |> mes("unlocks something in the^000000")
      |> mes("Cottage. Let's take another look.^000000")
      |> close()
    else
      ctx
      |> mes("^3355FFIt looks like Elly's")
      |> mes("Golden Key might fit")
      |> mes("into the keyhole on the")
      |> mes("Grey Box you found inside")
      |> mes("Kiel Hyre's Cottage.^000000")
      |> next()
      |> mes("^3355FFYou successfully open the")
      |> mes("Grey Box with the Golden Key,")
      |> mes("and find a Blue Keycard, along")
      |> mes("with a folded note, inside the")
      |> mes("Grey Box. You quickly read")
      |> mes("the note's contents...^000000")
      |> next()
      |> read_letter()
      |> give_item(7495, 1)
      |> delitem(7491, 1)
      |> set_char_var(:KielHyreQuest, 36)
      |> close()
    end
  end

  defp read_letter(ctx) do
    ctx
    |> mes("Dearest Elly,")
    |> mes("Kiehl finally broke the taboo,")
    |> mes("and tried to transform you guys")
    |> mes("into something horrible.")
    |> mes("^FFFFFF_^000000")
    |> mes("By the time you read this,")
    |> mes("my life is probably in danger.")
    |> mes("Whether I live depends on you.")
    |> mes("^FFFFFF_^000000")
    |> mes("You'll already learn if you")
    |> mes("meet Puppet, but I want to tell")
    |> mes("you myself: you're not human.")
    |> mes("You'll learn the details if you")
    |> mes("enter the factory by using the")
    |> mes("entrance near the grave next")
    |> mes("to the church. Then, I want")
    |> mes("you to find Allysia inside")
    |> mes("the factory's secret room.")
    |> mes("I've registered your name in")
    |> mes("her security system, so don't")
    |> mes("worry. Hopefully, Allysia will")
    |> mes("then come to save me...")
    |> mes("^FFFFFF_^000000")
    |> mes("Sorry about that,")
    |> mes("Grandpa")
  end
end
