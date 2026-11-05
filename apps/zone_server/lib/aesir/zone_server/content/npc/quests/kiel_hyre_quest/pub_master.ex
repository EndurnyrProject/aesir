defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.PubMaster do
  @moduledoc """
  Vandt serves drinks and recruits a courier for the Kiel Hyre Academy.

  ## Behavior

  - Offers beer that restores HP and reduces SP, or explains unavailable drinks.
  - Introduces his delivery problem on touch and offers Culinary Wine for Lecollane.
  - Supplies another bottle and 1,000 zeny after the first delivery when no wine remains.

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
        map: "yuno_in01",
        x: 35,
        y: 179,
        dir: 4,
        sprite: 46,
        name: "Pub Master",
        scope: :shared,
        unique_name: "Pub Master#kh",
        trigger: {5, 5}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    if get_char_var(ctx, :KielHyreQuest, 0) < 1 do
      ctx
      |> mes("[Vandt]")
      |> mes("Arrrggghhh...")
      |> mes("This can't be good...")
      |> mes("This isn't good at all!")
      |> mes("What am I suposed to do?")
      |> set_char_var(:KielHyreQuest, 1)
      |> close()
    else
      ctx
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if checkweight(ctx, [{7487, 1}]) == 0 do
      ctx
      |> mes("[Vandt]")
      |> mes("Just a second! You're")
      |> mes("carrying too many items")
      |> mes("right now. You'd better")
      |> mes("put your stuff in Kafra")
      |> mes("Storage or you won't be")
      |> mes("able to pick up anything new...")
      |> close()
    else
      serve_customer(ctx)
    end
  end

  defp serve_customer(ctx) do
    quest = get_char_var(ctx, :KielHyreQuest, 0)

    cond do
      quest == 0 or quest == 1 ->
        offer_drinks(ctx, quest)

      quest >= 2 and quest < 6 ->
        ctx
        |> mes("[Vandt]")
        |> mes("Please deliver that bottle")
        |> mes("of Wine I gave you to Mrs.")
        |> mes("Mrs. ^ff0000Lecollane^000000, who should be")
        |> mes("inside the Kiel Hyre Academy.")
        |> mes("Hurry and get it to her before she")
        |> mes("can complain about the delivery.")
        |> close()

      quest == 6 ->
        finish_delivery(ctx)

      true ->
        ctx
        |> mes("[Vandt]")
        |> mes("You're a really good")
        |> mes("worker, you know that?")
        |> mes("Dependable, responsible,")
        |> mes("willing to help others, and")
        |> mes("proactive too! I think you'll")
        |> mes("go far in life, kid, I really do~")
        |> close()
    end
  end

  defp offer_drinks(ctx, quest) do
    options =
      if quest == 0 do
        ["Beer, please.", "A cocktail, please.", "Soju, please.", "Maybe later."]
      else
        [
          "Beer, please",
          "A cocktail, please",
          "Soju, please.",
          "You look worried, what's up?",
          "Cancel"
        ]
      end

    {ctx, choice} =
      ctx
      |> mes("[Vandt]")
      |> mes("Hi there, welcome")
      |> mes("to my pub. So what")
      |> mes("would you like to have?")
      |> next()
      |> select(options)

    case choice do
      1 ->
        serve_beer(ctx)

      2 ->
        ctx
        |> mes("[Vandt]")
        |> mes("I'm sorry, but I have to")
        |> mes("deliver all of our cocktail")
        |> mes("ingredients to other customers.")
        |> mes("Maybe I'll have enough to make")
        |> mes("you something next time, okay?")
        |> close()

      3 ->
        ctx
        |> mes("[Vandt]")
        |> mes("S-soju? I'm sorry,")
        |> mes("but we don't serve that")
        |> mes("here. It's too much of")
        |> mes("a tough guy drink for me...")
        |> close()

      4 when quest == 1 ->
        explain_delivery(ctx)

      4 ->
        decline_order(ctx)

      5 when quest == 1 ->
        decline_order(ctx)

      _ ->
        ctx
    end
  end

  defp serve_beer(ctx) do
    ctx =
      ctx
      |> mes("[Vandt]")
      |> mes("Alright, let me get")
      |> mes("you a glass of beer on")
      |> mes("tap. There you are, this")
      |> mes("is out special Schwaltz Beer.")
      |> next()
      |> mes("^3355FF*Gulp gulp gulp*^000000")
      |> percent_heal(hp: 5, sp: -5)
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Ahhh, it's really")
    |> mes("good! That really")
    |> mes("hits the spot!")
    |> close()
  end

  defp decline_order(ctx) do
    ctx
    |> mes("[Vandt]")
    |> mes("Sure, just take")
    |> mes("your time, relax,")
    |> mes("and order something")
    |> mes("when you're ready.")
    |> close()
  end

  defp explain_delivery(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Vandt]")
      |> mes("Oh, did you overhear?")
      |> mes("I'm sorry, it's just that one")
      |> mes("of my employees had an")
      |> mes("accident and was pretty hurt,")
      |> mes("so I have nodoby that can")
      |> mes("deliver this merchandise.")
      |> next()
      |> mes("[Vandt]")
      |> mes("I have an urgent order")
      |> mes("that I need to send to")
      |> mes("the Kiel Hyre Academy,")
      |> mes("but I can't find anyone")
      |> mes("that's available for this")
      |> mes("kind of temporary job.")
      |> next()
      |> select(["I'm sorry to hear that", "Do you want me to help you?"])

    case choice do
      1 ->
        ctx
        |> mes("[Vandt]")
        |> mes("Well, I'm sure that I'll")
        |> mes("figure something out.")
        |> mes("Do you know anyone")
        |> mes("that'd be interested in")
        |> mes("some part time work?")
        |> close()

      2 ->
        accept_delivery(ctx)

      _ ->
        ctx
    end
  end

  defp accept_delivery(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Vandt]")
      |> mes("Really? That's great!")
      |> mes("But first, I think it's fair to")
      |> mes("tell you that this job may not")
      |> mes("be as simple as you'd think.")
      |> mes("I expect you to complete the")
      |> mes("delivery, no matter what.")
      |> next()
      |> select(["Sure I'll do it", "Wait, let me think about it..."])

    case choice do
      1 ->
        ctx
        |> mes("[Vandt]")
        |> mes("I'm glad to hear that.")
        |> mes("Well then, please take this")
        |> mes("bottle of Culinary Wine to")
        |> mes("Mrs. ^ff0000Lecollane^000000 in the Kiel")
        |> mes("Hyre Academy. I'll pay you")
        |> mes("once you finish the job, okay?")
        |> give_item(7487, 1)
        |> set_char_var(:KielHyreQuest, 2)
        |> close()

      2 ->
        ctx
        |> mes("[Vandt]")
        |> mes("Sure thing. I really need")
        |> mes("to get this done, so if you")
        |> mes("can't do it, but know any")
        |> mes("capable, responsible")
        |> mes("people that can, then please")
        |> mes("tell them about my situation.")
        |> close()

      _ ->
        ctx
    end
  end

  defp finish_delivery(ctx) do
    if count_item(ctx, 7487) == 0 do
      {ctx, _} =
        ctx
        |> mes("[Vandt]")
        |> mes("Oh, you're back.")
        |> mes("Thanks for making that")
        |> mes("delivery. Just give me")
        |> mes("a moment, and then I can")
        |> mes("pay you in zeny, okay?")
        |> next()
        |> select(["I need more wine..."])

      ctx
      |> mes("[Vandt]")
      |> mes("Oh, you need to deliver")
      |> mes("another bottle? Alright,")
      |> mes("let me look around, and")
      |> mes("I'll give you the wine")
      |> mes("and your payment.")
      |> next()
      |> mes("^3355FFRummage Rummage^000000")
      |> mes("^3355FFRummage Rummage^000000")
      |> next()
      |> mes("[Vandt]")
      |> mes("There you go!")
      |> mes("Thank you so much")
      |> mes("for helping me out~")
      |> give_item(7487, 1)
      |> credit_zeny(1000)
      |> close()
    else
      ctx
      |> mes("[Vandt]")
      |> mes("Hey, thanks a lot")
      |> mes("for helping me out that")
      |> mes("last time. I knew I asked")
      |> mes("you out of the blue, but")
      |> mes("you ended up being a life")
      |> mes("saver! I really appreciate it!")
      |> close()
    end
  end
end
