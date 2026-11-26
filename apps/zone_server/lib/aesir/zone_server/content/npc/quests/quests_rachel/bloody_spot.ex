defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.BloodySpot do
  @moduledoc """
  A bloodstain reveals clues during the sanctuary investigation.

  ## Behavior

  - Lets adventurers investigate the stain and advance the quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_rachel",
        x: 28,
        y: 315,
        dir: 0,
        sprite: -1,
        name: "Bloody Spot",
        scope: :shared,
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
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ontouch(ctx) do
    case get_char_var(ctx, :ra_tem_q, 0) do
      6 ->
        investigate_first(ctx)

      7 ->
        investigate_again(ctx)

      8 ->
        ctx
        |> mes("^3355FFThis blood stain on the")
        |> mes("ground is a pretty bad")
        |> mes("sign. You might have to")
        |> mes("escape this place before")
        |> mes("whatever caused this much")
        |> mes("bleeding does the same to you.^000000")
        |> close()

      _ ->
        ctx
    end
  end

  defp investigate_first(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFThere's a spot on the")
      |> mes("ground that's darker than")
      |> mes("the rest of the floor...^000000")
      |> next()
      |> select(["Investigate", "Ignore"])

    if choice == 1 do
      ctx
      |> mes("^3355FFIt's too dark to")
      |> mes("really see the spot^000000")
      |> next()
      |> mes("...")
      |> mes("......")
      |> mes(".........")
      |> next()
      |> mes("^3355FFIt smells a little bit")
      |> mes("like copper or iron. Blood")
      |> mes("has probably been spilled here.^000000")
      |> set_char_var(:ra_tem_q, 7)
      |> close()
    else
      ignore(ctx)
    end
  end

  defp investigate_again(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFThis dark spot on the")
      |> mes("ground is really creepy,")
      |> mes("no matter how many")
      |> mes("times you look at it.^000000.")
      |> next()
      |> select(["Investigate Again", "Ignore"])

    if choice == 1 do
      ctx
      |> mes("^3355FFThe blood on the ground")
      |> mes("hasn't dried up yet, but")
      |> mes("it's probably cold by now.^000000")
      |> next()
      |> mes("...")
      |> mes("......")
      |> mes(".........")
      |> next()
      |> mes("^3355FFThe amount of blood")
      |> mes("on the ground is more")
      |> mes("than can be contained in just")
      |> mes("one person. You'd better get")
      |> mes("out of here before it's too late.^000000")
      |> set_char_var(:ra_tem_q, 8)
      |> close()
    else
      ignore(ctx)
    end
  end

  defp ignore(ctx) do
    ctx
    |> mes("^3355FFYou decide that your")
    |> mes("time would be better spent")
    |> mes("investigating something else.^000000")
    |> close()
  end
end
