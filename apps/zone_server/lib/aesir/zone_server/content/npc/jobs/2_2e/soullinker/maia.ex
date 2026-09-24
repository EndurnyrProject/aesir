defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22e.Soullinker.Maia do
  @moduledoc """
  Maia conducts the Soul Linker job change ceremony inside the candidate's mind.

  ## Behavior

  - On touch, explains the ceremony to newly arrived candidates and sends them to meet the
    warrior spirits.
  - Once a spirit has been heard, lets candidates keep talking to spirits or complete the
    ceremony, refusing mounted candidates and those with unspent skill points.
  - Completing the ceremony changes the job to Soul Linker, clears job quest variables, stops
    the ceremony timer and returns the new Soul Linker to Morocc.
  - Frees the ceremony and returns anyone else who is not supposed to be here to Morocc.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Celestria
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
        map: "job_soul",
        x: 35,
        y: 30,
        dir: 6,
        sprite: 716,
        name: "Maia",
        scope: :shared,
        unique_name: "Maia#link6"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FClearjobvar
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    if Rathena.job_id(class(ctx)) == Rathena.job_id(:taekwon) do
      guide_taekwon(ctx)
    else
      send_away(ctx)
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp guide_taekwon(ctx) do
    if job_level(ctx) < 40 do
      ctx
      |> set_npc_var_of("SoulLinkerTest", "Kid#link1", 0)
      |> mes("[Maia]")
      |> mes("Hm? How did you come")
      |> mes("here? You're not qualified")
      |> mes("for this ceremony yet. Come,I will bring you back to Morocc...")
      |> close()
      |> warp("morocc", 157, 47)
    else
      soul_quest = get_char_var(ctx, :SOUL_Q, 0)

      cond do
        soul_quest == 2 -> explain_mind(ctx)
        soul_quest == 3 -> urge_to_listen(ctx)
        soul_quest == 4 -> offer_ceremony(ctx)
        true -> return_early_arrival(ctx)
      end
    end
  end

  defp explain_mind(ctx) do
    ctx
    |> mes("[Maia]")
    |> mes("Do you recognize this")
    |> mes("place? Right now, we're")
    |> mes("inside your mind. The spirits")
    |> mes("of warriors that have died")
    |> mes("hover here, waiting for you")
    |> mes("to call upon their power.")
    |> next()
    |> mes("[Maia]")
    |> mes("Right now, there are only")
    |> mes("a few of them here, but if")
    |> mes("you continue to train, you")
    |> mes("will be able to call upon")
    |> mes("more spirits as a Soul Linker.")
    |> next()
    |> set_char_var(:SOUL_Q, 3)
    |> changequest(6006, 6007)
    |> mes("[Maia]")
    |> mes("We can only remain in")
    |> mes("your mind for 3 minutes.")
    |> mes("I suggest that you speak")
    |> mes("to the spirits while you")
    |> mes("have the opportunity.")
    |> close()
  end

  defp urge_to_listen(ctx) do
    ctx
    |> mes("[Maia]")
    |> mes("Listen to what")
    |> mes("spirits are tending to say.")
    |> mes("There is a reason why")
    |> mes("they cannot move on")
    |> mes("to the next world.")
    |> close()
  end

  defp offer_ceremony(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Maia]")
      |> mes("I believe that you are")
      |> mes("now ready to become")
      |> mes("a Soul Linker. However,")
      |> mes("you may continue to")
      |> mes("speak with the spirits")
      |> mes("if that is what you wish.")
      |> next()
      |> select(["Converse more with the spirits", "Become a Soul Linker"])

    cond do
      choice == 1 ->
        ctx
        |> mes("[Maia]")
        |> mes("Alright. Try to hurry")
        |> mes("since we can remain in")
        |> mes("your mind for a limited")
        |> mes("time. Although, we can")
        |> mes("go back inside your mind")
        |> mes("if you talk to me later...")
        |> close()

      Rathena.truthy?(ismounting(ctx)) ->
        ctx
        |> mes("[Maia]")
        |> mes("You are on a riding pet,")
        |> mes("so you cannot change your job.")
        |> mes("Please unequip your riding pet and try again!")
        |> close()

      true ->
        perform_ceremony(ctx)
    end
  end

  defp perform_ceremony(ctx) do
    ctx =
      ctx
      |> mes("[Maia]")
      |> mes("Then let us begin the")
      |> mes("ceremony. These items will")
      |> mes("be used to endow you with")
      |> mes("the ability to borrow the power")
      |> mes("of the fallen warriors and lend")
      |> mes("it to your friends in battle.")
      |> next()
      |> mes("[Maia]")
      |> mes("This Witherless Rose will")
      |> mes("wither away instead of you...")
      |> specialeffect(:mappillar2)
      |> next()
      |> mes("[Maia]")
      |> mes("This Witherless Rose will")
      |> mes("wither away instead of you...")
      |> mes("This Immortal Heart will cease")
      |> mes("to pump blood, instead of yours. ")
      |> next()
      |> mes("[Maia]")
      |> mes("This Witherless Rose will")
      |> mes("wither away instead of you...")
      |> mes("This Immortal Heart will cease")
      |> mes("to pump blood, instead of yours. This Diamond will turn to dust,")
      |> mes("in place of your mortal body.")
      |> next()
      |> mes("[Maia]")
      |> mes("The dead who wish")
      |> mes("to continue fighting...")
      |> mes("Will fight for you! Use your")
      |> mes("powers as a Soul Linker")
      |> mes("wisely and for just purposes.")
      |> next()

    if Rathena.truthy?(skill_point(ctx)) do
      ctx
      |> mes(
        "^0000ffYou still have unused skill points. Please use all remaining skill points and try again!^000000"
      )
      |> close()
    else
      change_to_soul_linker(ctx)
    end
  end

  defp change_to_soul_linker(ctx) do
    {ctx, _} =
      ctx
      |> completequest(6008)
      |> jobchange(:soul_linker)
      |> FClearjobvar.call([])

    ctx
    |> set_char_var(:SOUL_Q, 0)
    |> mes("[Maia]")
    |> mes("I wish the best of luck")
    |> mes("in your new life. Surround")
    |> mes("yourself with allies, and the")
    |> mes("spirits will be able to protect")
    |> mes("you and help you fight in your battles. Farewell for now, friend.")
    |> close()
    |> set_npc_var_of("SoulLinkerTest", "Kid#link1", 0)
    |> donpcevent("Timer#link3::OnDisable")
    |> warp("morocc", 157, 47)
  end

  defp return_early_arrival(ctx) do
    ctx
    |> set_npc_var_of("SoulLinkerTest", "Kid#link1", 0)
    |> mes("[Maia]")
    |> mes("Hmm...?")
    |> mes("The time for you")
    |> mes("to be here has not")
    |> mes("arrived. Let's go")
    |> mes("back to Morocc...")
    |> close()
    |> warp("morocc", 157, 47)
  end

  defp send_away(ctx) do
    ctx = set_npc_var_of(ctx, "SoulLinkerTest", "Kid#link1", 0)

    ctx =
      if Rathena.job_id(class(ctx)) == Rathena.job_id(:soul_linker) do
        ctx
        |> mes("[Maia]")
        |> mes("The time has come for")
        |> mes("you to venture out into the")
        |> mes("wide world! More Soul Linkers")
        |> mes("will definitely be needed in the ongoing battle against evil...")
      else
        ctx
        |> mes("[Maia]")
        |> mes("That's strange...")
        |> mes("You're not supposed to")
        |> mes("be here. Let me guide")
        |> mes("you back to Morocc...")
      end

    ctx |> close() |> warp("morocc", 157, 47)
  end
end
