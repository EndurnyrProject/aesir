defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.QueJob018077 do
  @moduledoc """
  Litheron's post at the entrance of the Morocc hideout's inner room, where a stranger has to
  earn the way in.

  ## Behavior

  - Fires on touch and on talk.
  - Lets an Assassin, a player with an active request or a player past `mao_morocc2` step 4
    straight into the inner room.
  - Everyone else is questioned by Litheron: a cursed player (`prt_curse` 24) may buy him a
    1,000 zeny drink to get in, refusing or carrying too little zeny sends them back to the
    entrance, and a player who is not on the poison errand is turned away by the Bar Master.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_job01",
        x: 80,
        y: 77,
        dir: 0,
        sprite: 45,
        name: "que_job01",
        scope: :shared,
        unique_name: "que_job01#04",
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @inner_room {61, 50}
  @entrance {85, 77}
  @bar_fee 1000

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx), do: enter(ctx)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: enter(ctx)

  defp enter(ctx) do
    if admitted?(ctx) do
      send_inside(ctx)
    else
      litheron_checks(ctx)
    end
  end

  defp admitted?(ctx) do
    Rathena.job_id(base_class(ctx)) == Rathena.job_id(:assassin) or
      get_char_var(ctx, :mao_request, 0) > 0 or get_char_var(ctx, :mao_morocc2, 0) > 4
  end

  defp send_inside(ctx), do: warp(ctx, "que_job01", elem(@inner_room, 0), elem(@inner_room, 1))

  defp litheron_checks(ctx) do
    ctx =
      ctx
      |> mes("[Litheron]")
      |> mes("Hey, wait.")
      |> mes("Only authorized personnel can enter the inner room.")
      |> mes("Hey Master, is it okay to let this guy in?")
      |> next()

    if get_char_var(ctx, :prt_curse, 0) == 24 do
      marjana_admission(ctx)
    else
      turned_away_by_the_master(ctx)
    end
  end

  defp marjana_admission(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("I, um, I'm looking")
      |> mes("for somebody named")
      |> mes("Marjana? I learned")
      |> mes("that she's around")
      |> mes("here somewhere?")
      |> next()
      |> mes("[Litheron]")
      |> mes("Marjana? How did you")
      |> mes("know that? Hey master,")
      |> mes("what do I do with this guy?")
      |> next()
      |> mes("[Master]")
      |> mes("Hmm. I sense no ill intent")
      |> mes("from this adventurer. I've")
      |> mes("also heard a rumor that the")
      |> mes("Prontera Church needs to")
      |> mes("investigate poison for")
      |> mes("some reason.")
      |> next()
      |> mes("[Master]")
      |> mes("However, there is no")
      |> mes("way to tell if this person")
      |> mes("has been sent by Prontera")
      |> mes("Church. I suppose whether")
      |> mes("this person can enter is")
      |> mes("really up to you, Litheron.")
      |> next()
      |> mes("[Litheron]")
      |> mes("Hah! Did you hear that?")
      |> mes("Alright, how about this?")
      |> mes("I'll let you in if you buy me")
      |> mes("a drink. Besides, you can't risk making trouble here: this place")
      |> mes("is full of deadly Assassins.")
      |> next()
      |> select(["Sure", "Why should I?!"])

    case choice do
      1 -> buy_a_drink(ctx)
      2 -> refuses_the_favor(ctx)
      _ -> ctx
    end
  end

  defp buy_a_drink(ctx) do
    ctx = mes(ctx, "[Litheron]")

    if zeny(ctx) > @bar_fee - 1 do
      ctx
      |> mes("Heh, that's what")
      |> mes("I'm talking about!")
      |> mes("Hey, bartender! Gimme")
      |> mes("the usual! I like your")
      |> mes("style, adventurer...")
      |> pay_zeny(@bar_fee)
      |> next()
      |> mes("[Litheron]")
      |> mes("Alright, you can come")
      |> mes("on in. But don't you dare")
      |> mes("breathe a word about this")
      |> mes("bar to another living soul.")
      |> close()
      |> send_inside()
    else
      ctx
      |> mes("Huh...")
      |> mes("Oh, you don't even")
      |> mes("have enough zeny to")
      |> mes("buy water here. Oh boy...")
      |> mes("If you really want to enter,")
      |> mes("make sure you have the cash!")
      |> close()
      |> warp("que_job01", elem(@entrance, 0), elem(@entrance, 1))
    end
  end

  defp refuses_the_favor(ctx) do
    ctx
    |> mes("[Litheron]")
    |> mes("Not the saavy type,")
    |> mes("are you...? Fine, fine.")
    |> mes("If you're not gonna do")
    |> mes("me any favors, then why")
    |> mes("should I help you? Go away!")
    |> close()
    |> warp("que_job01", elem(@entrance, 0), elem(@entrance, 1))
  end

  defp turned_away_by_the_master(ctx) do
    ctx
    |> mes("[Bar Master]")
    |> mes(
      "If you keep outsiders away from the entrance, every drink you drink today will be on the house."
    )
    |> mes("So keep up the good work.")
    |> next()
    |> mes("[Bar Master]")
    |> mes("Yay! Did you hear that?")
    |> mes("That's my cue to get you outta here!")
    |> close()
    |> warp("que_job01", elem(@entrance, 0), elem(@entrance, 1))
  end
end
