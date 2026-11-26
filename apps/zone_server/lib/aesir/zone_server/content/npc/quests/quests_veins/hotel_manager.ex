defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.HotelManager do
  @moduledoc """
  The hotel manager welcomes the performers and thanks their bodyguard.

  ## Behavior

  - Entering the party and speaking to the manager advances the escort quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ein_in01",
        x: 279,
        y: 221,
        dir: 0,
        sprite: 903,
        name: "Hotel Manager",
        scope: :shared,
        unique_name: "Hotel Manager#sch",
        trigger: {5, 5}
      }
    ]

  @impl true
  def on_event("OnTouch", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :que_sch, 0)

    cond do
      stage < 15 ->
        ctx
        |> mes("[Manager]")
        |> mes("It'd be a really great")
        |> mes("party if our customers")
        |> mes("were a little less rowdy")
        |> mes("Recently, they've been")
        |> mes("more than a handful...")
        |> close()

      stage == 15 ->
        ctx
        |> mes("[Manager]")
        |> mes("I'm glad our customers")
        |> mes("enjoyed the performance")
        |> mes("I was a little worried about")
        |> mes("what they were going to think,")
        |> mes("but I guess I was just being")
        |> mes("overly anxious about it all.")
        |> close()

      stage == 16 ->
        ctx
        |> mes("[Manager]")
        |> mes("Thank you so much for")
        |> mes("your services. I'll be sure to")
        |> mes("have one of my employees")
        |> mes("send you your payment")
        |> mes("Have a safe trip back~")
        |> set_char_var(:que_sch, 17)
        |> close()

      true ->
        ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :que_sch, 0) == 14 do
      ctx
      |> mes("[Manager]")
      |> mes("Oh, did you enjoy")
      |> mes("your trip? I'm glad to")
      |> mes("see that everyone arrived")
      |> mes("safely. The dinner party")
      |> mes("will start shortly, so")
      |> mes("please get ready~")
      |> set_char_var(:que_sch, 15)
      |> close()
    else
      ctx
    end
  end
end
