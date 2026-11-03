defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.MerchantSkills.Charlron do
  @moduledoc """
  Charlron, a cart-researching merchant in Alberta, teaches the Change Cart quest skill.

  ## Behavior

  - Talks business only with merchant-line characters at Job Level 30 or higher, or with any
    Blacksmith or Alchemist; asks lower-level merchants to come back at level 30.
  - Explains Change Cart and its materials: 50 Trunks, 10 Iron, and 20 Animal Skins.
  - Teaches Change Cart once the materials are brought.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - Silentdragon
    - IVBela
    - DracoRPG
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
      %{map: "alberta", x: 119, y: 221, dir: 6, sprite: 107, name: "Charlron", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @change_cart 154
  @trunk 1019
  @iron 998
  @animal_skin 919

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      Rathena.job_id(base_class(ctx)) != Rathena.job_id(:merchant) -> trader(ctx)
      getskilllv(ctx, @change_cart) == 1 -> enjoy_life(ctx)
      experienced?(ctx) -> famous_merchant(ctx)
      true -> beginner(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp experienced?(ctx) do
    job_level(ctx) >= 30 or
      (Rathena.job_id(base_job(ctx)) == Rathena.job_id(:blacksmith) or
         Rathena.job_id(base_job(ctx)) == Rathena.job_id(:alchemist))
  end

  defp enjoy_life(ctx) do
    ctx
    |> mes("[Charlron]")
    |> mes("Mmm? I was wondering who was making all")
    |> mes("the raucus carrying around a cart.")
    |> mes("It was you.")
    |> mes("Yes, I remember you.")
    |> mes("what do you think? The new cart..good, yeah?")
    |> next()
    |> mes("[Charlron]")
    |> mes("Enjoy life.")
    |> mes("Life isn't just simply moving")
    |> mes("forward..Slowly, looking around,")
    |> mes("dragging a heavy cart is")
    |> mes("the way us merchants live.")
    |> mes("Then see you next time.")
    |> next()
    |> mes("[Charlron]")
    |> mes("Be healthy~")
    |> close()
  end

  defp famous_merchant(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Charlron]")
      |> mes("Nice to see you fellow merchant")
      |> mes("If I remember correctly,")
      |> mes("you're that famous merchant")
      |> mes("these days.")
      |> next()
      |> mes("But your cart doesn't")
      |> mes("seem to fit your fame.")
      |> mes("How pitiful.")
      |> next()
      |> select([
        "That's why I came here.",
        "What about my cart?",
        "Two pairs is pitiful?"
      ])

    case choice do
      1 -> change_cart(ctx)
      2 -> explain_skill(ctx)
      3 -> ctx |> mes("[Charlron]") |> mes("...it's not 'CARD'!") |> close()
      _ -> beginner(ctx)
    end
  end

  defp change_cart(ctx) do
    if count_item(ctx, @trunk) > 49 and count_item(ctx, @iron) > 9 and
         count_item(ctx, @animal_skin) > 19 do
      teach(ctx)
    else
      missing_materials(ctx)
    end
  end

  defp teach(ctx) do
    ctx
    |> mes("[Charlron]")
    |> mes("Haha! Ok, ok!")
    |> mes("With the things you brought")
    |> mes("I will change your cart.")
    |> next()
    |> delitem(@trunk, 50)
    |> delitem(@iron, 10)
    |> delitem(@animal_skin, 20)
    |> skill(@change_cart, 1, :permanent)
    |> mes("[Charlron]")
    |> mes("Congratulations.")
    |> mes("You can choose a cart")
    |> mes("according to your taste.")
    |> mes("And now you don't even need")
    |> mes("me to help you. All you")
    |> mes("need is some SP.")
    |> next()
    |> mes("[Charlron]")
    |> mes("Convenient, don't you think?")
    |> mes("Oh and one more thing!")
    |> mes("Each time you level, you can")
    |> mes("have a new different cart")
    |> mes("So work hard.")
    |> next()
    |> mes("[Charlron]")
    |> mes("But anyways, it looks very nice on you!")
    |> mes("Hahaha! Have a nice day!")
    |> close()
  end

  defp missing_materials(ctx) do
    ctx
    |> mes("[Charlron]")
    |> mes("Mmm... It's true that I")
    |> mes("change carts but...")
    |> mes("In order to do so, I need")
    |> mes("some materials to use.")
    |> next()
    |> mes("[Charlron]")
    |> mes("50 Trunks.")
    |> mes("10 Iron.")
    |> mes("20 Animal Skins.")
    |> mes("I need at least these things")
    |> mes("to change your cart.")
    |> next()
    |> mes("[Charlron]")
    |> mes("So come see me when you")
    |> mes("have prepared everything.")
    |> close()
  end

  defp explain_skill(ctx) do
    ctx
    |> mes("[Charlron]")
    |> mes("Oh no, you don't know at all?(changes tone)")
    |> mes("A new way to show off a merchant's ego!")
    |> mes("An expression of an excellent brain!")
    |> mes("Change Cart is a skill that")
    |> mes("makes a merchant stand out!")
    |> next()
    |> mes("[Charlron]")
    |> mes("A fun skill that allows you to")
    |> mes("use a cart according to your")
    |> mes("level with only 40 SP!")
    |> next()
    |> mes("[Charlron]")
    |> mes("That is Change Cart!")
    |> mes("A basic skill for any merchant.")
    |> mes("I'll teach you how to make")
    |> mes("one so watch carefully, and")
    |> mes("do exactly what I do to make")
    |> mes("your own in the future!")
    |> next()
    |> mes("[Charlron]")
    |> mes("But, since it's the first time")
    |> mes("you need to prepare some materials.")
    |> mes("50 Trunks!")
    |> mes("10 Iron!")
    |> mes("20 Animal skins!")
    |> mes("-bring these please!")
    |> next()
    |> mes("[Charlron]")
    |> mes("All we have to do is")
    |> mes("make one using those materials,")
    |> mes("so come back when you are ready.")
    |> mes("Ok?")
    |> close()
  end

  defp beginner(ctx) do
    ctx
    |> mes("[Charlron]")
    |> mes("Welcome young one.")
    |> mes("Is selling fun? I am the")
    |> mes("merchant Charlron. I have been")
    |> mes("doing some research about.")
    |> mes("carts recently.")
    |> next()
    |> mes("[Charlron]")
    |> mes("Aren't you tired of that cart?")
    |> mes("Come to me if you want to")
    |> mes("change your cart. I'll do a good job.")
    |> mes("But, there are some conditions.")
    |> next()
    |> mes("[Charlron]")
    |> mes("I'm a pretty famous merchant,")
    |> mes("so I don't really deal with beginners.")
    |> mes("Once you are level 30")
    |> mes("I may consider establishing")
    |> mes("a deal with you.")
    |> close()
  end

  defp trader(ctx) do
    ctx
    |> mes("[Charlron]")
    |> mes("I am a merchant that")
    |> mes("deals with many things, Charlron.")
    |> mes("If you ever find anything interesting")
    |> mes("come back and try to ")
    |> mes("negotiate a deal with me.")
    |> close()
  end
end
