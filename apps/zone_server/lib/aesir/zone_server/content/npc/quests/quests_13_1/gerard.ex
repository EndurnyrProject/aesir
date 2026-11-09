defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Gerard do
  @moduledoc """
  Gerard, the hungry field researcher of the Manuk field who awaits the camp's supplies.

  ## Behavior

  - On step 17, while the player carries the supplies, takes them, sets `ep13_newbs` to 18,
    hands over a Chocolate Pie and advances quest 11095 to 11096; without the supplies he only
    complains that he is starving.
  - On step 18 he is fed and ready to explore again.
  - On every other step he muses about the green field.

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
        map: "mid_camp",
        x: 30,
        y: 168,
        dir: 4,
        sprite: 939,
        name: "Gerard",
        scope: :shared,
        unique_name: "Gerard#ep13bs"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @supplies 6045
  @gift 12322

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :ep13_newbs, 0) do
      17 -> deliver_supplies(ctx)
      18 -> well_fed(ctx)
      _step -> field_notes(ctx)
    end
  end

  defp deliver_supplies(ctx) do
    if count_item(ctx, @supplies) > 0 do
      takes_supplies(ctx)
    else
      starving(ctx)
    end
  end

  defp takes_supplies(ctx) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Are you Gerard?")
      |> next()
      |> mes("[Gerard]")
      |> mes("Yes, I am.")
      |> mes("What brings you here?")
      |> next()
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Instructor Lugen sent")
      |> mes("me for an errand.")
      |> next()
      |> mes("[Gerard]")
      |> mes("Ah! Supplies.")
      |> mes("The supplies that ran out.")
      |> next()
      |> mes("[Gerard]")
      |> mes("I am so hungry that")
      |> mes("I was considering")
      |> mes("going back to the camp.")
      |> mes("I really appreciate this.")
      |> emotion(:hungry)
      |> next()
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("...")
      |> mes("You ran out of supplies, but")
      |> mes("you didn't go back to the camp?")
      |> next()

    ctx
    |> mes("[Gerard]")
    |> mes("Yes.")
    |> mes("This place is really interesting")
    |> mes("and I don't want to leave at all.")
    |> next()
    |> mes("[Gerard]")
    |> mes("Please tell the instructor that")
    |> mes("I won't be back for some time.")
    |> emotion(:best)
    |> delitem(@supplies, 1)
    |> set_char_var(:ep13_newbs, 18)
    |> give_item(@gift, 1)
    |> changequest(11095, 11096)
    |> close()
  end

  defp starving(ctx) do
    ctx
    |> mes("[Gerard]")
    |> mes("Hhhh, I am starving.")
    |> mes("When will the supplies come?")
    |> mes("It is killing me...")
    |> emotion(:cry)
    |> close()
  end

  defp well_fed(ctx) do
    ctx
    |> mes("[Gerard]")
    |> mes("Hu, I am full now.")
    |> mes("Time to continue on")
    |> mes("with the exploration!!!")
    |> close()
  end

  defp field_notes(ctx) do
    ctx
    |> mes("[Gerard]")
    |> mes("I was born in a desert")
    |> mes("and have never seen")
    |> mes("a field so green.")
    |> mes("So, to study here.")
    |> mes("is very interesting.")
    |> next()
    |> mes("[Gerard]")
    |> mes("By the way... is this a")
    |> mes("mushroom or a tree?")
    |> close()
  end
end
